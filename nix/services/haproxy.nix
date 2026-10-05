{
  config,
  lib,
  pkgs,
  infra,
  ...
}: let
  separateModule = modules: lib.concatStringsSep "\n\n" modules;
  inherit (infra) ips;
  cfg = config.modules.haproxy;

  # PC at home, reached over Tailscale
  kleiner = "100.113.206.105";

  # Service rules for the https frontend, as a list of lines
  aclLines = lib.filter (line: lib.trim line != "") (
    lib.concatMap (lib.splitString "\n") (lib.attrValues cfg.acls)
  );
  directives = ["acl " "http-request " "use_backend "];
  # HAProxy evaluates all http-request rules before any use_backend rule whatever their
  # order, so grouping lines by directive keeps behaviour and avoids ordering warnings
  aclLinesOf = directive:
    lib.concatMapStringsSep "\n" (line: "  ${line}") (
      lib.filter (lib.hasPrefix directive) (map lib.trim aclLines)
    );
  unsupportedAclLines = lib.filter (line: !(lib.any (d: lib.hasPrefix d (lib.trim line)) directives)) aclLines;
in {
  options.modules.haproxy = {
    backends = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };

    frontends = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };

    acls = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };

    vhosts = lib.mkOption {
      description = "HTTPS services by domain. Each one gets a routing rule, a backend and a certificate";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
          };

          server = lib.mkOption {
            type = lib.types.str;
            description = "Address of the backend server, e.g. 127.0.0.1:8080";
          };

          extraRules = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Extra acl and http-request lines. The is_<name> ACL matches the domain";
          };
        };
      });
    };

    enableConfigCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check the HAProxy configuration at build time, failing on errors and warnings";
    };
  };

  config = lib.mkMerge [
    {
      modules.haproxy.acls =
        lib.mapAttrs (name: vhost: ''
          acl is_${name} hdr(host) -i ${vhost.domain}
          ${vhost.extraRules}
          use_backend ${name} if is_${name}
        '')
        cfg.vhosts;

      modules.haproxy.backends =
        lib.mapAttrs (name: vhost: ''
          backend ${name}
            server ${name} ${vhost.server}
        '')
        cfg.vhosts;

      security.acme.certs = lib.mapAttrs' (name: vhost: lib.nameValuePair vhost.domain {}) cfg.vhosts;

      modules.dns.domains =
        lib.mapAttrsToList (name: vhost: vhost.domain) cfg.vhosts
        ++ ["mc.cpluspatch.com" "broken.cpluspatch.com" "text.cpluspatch.com"];
    }
    {
      modules.haproxy.frontends.minecraft-eli-fe = ''
        frontend minecraft-eli-fe
          mode tcp
          bind :::25565 v4v6
          default_backend minecraft-eli
      '';

      # Allow Minecraft traffic
      networking.firewall.allowedTCPPorts = [25565];

      modules.haproxy.backends.minecraft-eli = ''
        backend minecraft-eli
          mode tcp
          server minecraft-eli ${ips.eli}:25565
      '';

      modules.haproxy.vhosts = {
        jellyfin2 = {
          domain = "tv.cpluspatch.com";
          server = "${kleiner}:8096";
        };
        seer = {
          domain = "seer.cpluspatch.com";
          server = "${kleiner}:5055";
        };
        radarr = {
          domain = "radarr.lgs.cpluspatch.com";
          server = "${kleiner}:7878";
        };
        sonarr = {
          domain = "sonarr.lgs.cpluspatch.com";
          server = "${kleiner}:8989";
        };
      };

      security.acme.certs."mc.cpluspatch.com" = {};

      services.nginx = {
        # Change ports to 8080 and 8443, because 80/443 are already used by HAProxy
        defaultHTTPListenPort = 8080;
        defaultSSLListenPort = 8443;
      };

      environment.etc."tls.certlist" = {
        text = "${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${value.directory}/full.pem") config.security.acme.certs)}\n";
      };

      assertions = [
        {
          assertion = unsupportedAclLines == [];
          message = "modules.haproxy.acls only supports acl, http-request and use_backend lines, got: ${lib.concatStringsSep ", " unsupportedAclLines}";
        }
      ];

      system.checks = lib.mkIf cfg.enableConfigCheck [
        (pkgs.runCommand "check-haproxy-config" {
            nativeBuildInputs = [config.services.haproxy.package pkgs.openssl];
          } ''
            # The real certificates only exist at runtime, so check against a self-signed one
            openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
              -subj /CN=check -days 1 -keyout key.pem -out cert.pem 2>/dev/null
            cat cert.pem key.pem > full.pem
            echo "$PWD/full.pem" > certlist
            sed "s|/etc/tls.certlist|$PWD/certlist|g" ${config.environment.etc."haproxy.cfg".source} > haproxy.cfg

            # -dW makes warnings fatal
            haproxy -dW -c -f haproxy.cfg > $out 2>&1 || { cat $out; exit 1; }
          '')
      ];

      # The module doesn't reload HAProxy when its configuration or certificate list change
      systemd.services.haproxy.reloadTriggers = [
        config.environment.etc."haproxy.cfg".source
        config.environment.etc."tls.certlist".source
      ];

      services.haproxy = {
        enable = true;
        config = ''
          global
            log /dev/log local0 notice
            stats timeout 30s
            daemon
            limited-quic
            maxconn 50000

            # Don't use SSLv3 or TLSv1.0/1.1
            ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
            ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
            ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

            # Enable SSL session caching
            tune.ssl.cachesize 50000
            tune.ssl.lifetime 300

            # Prevent hangs during uploads
            tune.bufsize        131072   # 128KB — covers most upload chunks
            tune.maxrewrite     8192
            tune.recv_enough    131072

          http-errors errors
            errorfile 503 ${pkgs.cpluspatch-pages}/503.http
            errorfile 502 ${pkgs.cpluspatch-pages}/502.http

          defaults
            log     global
            mode    http
            option  dontlognull
            # option  dontlog-normal
            timeout connect 5s
            timeout client  50s
            timeout server  5m
            timeout tunnel  1h   # for tunneled (WebSockets) connections

            # Compression config
            compression algo gzip
            compression type text/html text/plain text/css application/javascript application/json

          userlist credentials
            user admin password $2b$05$d4BsCumQdqQ2ESUYjVyLT.ptJBpqGHKOw4Wn6B6gvGbLfT3.0lJRG

          frontend metrics
            bind :::8899 v4v6
            mode http
            http-request use-service prometheus-exporter if { path /metrics }
            no log
            stats enable
            stats uri /
            stats refresh 10s
            stats http-request auth unless { http_auth(credentials) }

          frontend http
            mode http
            bind :::80 v4v6
            # Don't redirect ACME requests
            acl is_acme path -i -m beg /.well-known/acme-challenge
            http-request redirect scheme https unless { ssl_fc } || is_acme

            http-request capture req.hdr(Host) len 20
            log-format "%ci:%cp [%tr] %ft %b/%s %ST %ac/%fc/%bc/%sc/%rc %[capture.req.hdr(0)] %HM %{+Q}HU"

            errorfiles errors

            use_backend acme if is_acme

          frontend https
            mode http
            bind :::443 v4v6 ssl prefer-client-ciphers crt-list /etc/tls.certlist alpn h2,http/1.1
            bind quic4@:443 ssl prefer-client-ciphers crt-list /etc/tls.certlist alpn h3
            bind quic6@:443 ssl prefer-client-ciphers crt-list /etc/tls.certlist alpn h3
            option forwardfor
            http-request set-header X-Forwarded-Proto https
            # Opt out of FLoC
            http-response set-header Permissions-Policy "interest-cohort=()"

            # Advertise QUIC
            http-after-response add-header alt-svc 'h3=":443"; ma=60'

            stick-table type ipv6 size 1m expire 2d store gpt(2)
            http-request track-sc0 src

            default_backend default
            http-request capture req.hdr(Host) len 20
            log-format "%ci:%cp [%tr] %ft %b/%s %ST %ac/%fc/%bc/%sc/%rc %[capture.req.hdr(0)] %HM %{+Q}HU"

            # Bot protection ACLs
            acl protected_backend hdr(host) -i shutup.cpluspatch.com
            acl is_challenge_req path_beg /_challenge

            # Ban Applebot because it makes sharkey crash
            acl applebot hdr_sub(User-Agent) Applebot

            http-request return status 401 if applebot

            # Matches the default config of anubis of triggering on "Mozilla"
            acl protected_ua hdr(User-Agent) -m beg Mozilla/
            acl protected acl(protected_backend,protected_ua,!is_challenge_req)

            http-response set-header X-Clacks-Overhead "GNU memdmp"

            acl accepted sc_get_gpt(1,0) gt 0
            http-request return status 200 content-type "text/html; charset=UTF-8" hdr "Cache-control" "max-age=0, no-cache" lf-file ${pkgs.cpluspatch-pages}/challenge.html if protected !accepted

            errorfiles errors

            # AP ACLs
            acl is_activitypub_req hdr(Accept) -i ld+json application/activity+json
            acl is_activitypub_payload hdr(Content-Type) -i application/ld+json application/activity+json

            acl is_servarr hdr(host) -i -m end lgs.cpluspatch.com

            # Redirect cpluspatch.dev to cpluspatch.com
            acl is_old_site hdr(host) -i cpluspatch.dev
            http-request redirect code 301 location https://cpluspatch.com%[capture.req.uri] if is_old_site !{ path_beg /.well-known/matrix }

            # Redirect text.cpluspatch.com to cpluspatch.com/text
            acl is_text_site hdr(host) -i text.cpluspatch.com
            http-request redirect code 301 location https://cpluspatch.com/text%[capture.req.uri] if is_text_site

            acl is_broken hdr(host) -i broken.cpluspatch.com

            # Service rules
          ${aclLinesOf "acl "}

          ${aclLinesOf "http-request "}

            use_backend challenge if is_challenge_req
            use_backend broken if is_broken
          ${aclLinesOf "use_backend "}

          ${separateModule (lib.mapAttrsToList (name: value: value) config.modules.haproxy.frontends)}

          # Backends
          backend default
            mode http
            http-request deny

          # To test what happens when a request is made to a non-existent backend
          backend broken
            mode http
            server broken 127.0.0.1:9999

          # Redirect acme requests to the lego client
          backend acme
            server acme localhost${config.security.acme.defaults.listenHTTP}

          # Used for Anubis-style challenges
          # Based on David Leadbeater's work
          # See https://github.com/dgl/haphash
          backend challenge
            mode http
            option http-buffer-request

            # Must match the stick table used in the frontend.
            http-request track-sc0 src table https
            acl challenge_req method POST

            # Calculate the challenge
            http-request set-var(txn.tries) req.body_param(tries)
            http-request set-var(txn.timestamp) req.body_param(timestamp)
            http-request set-var(txn.host) hdr(Host),host_only
            http-request set-var(txn.hash) src,concat(;,txn.host,),concat(;,txn.timestamp,),concat(;,txn.tries),digest(SHA-256),hex
            acl timestamp_recent date,neg,add(txn.timestamp) ge -60

            # 4 is the difficulty, should match "diff" in challenge.html.
            acl hash_good var(txn.hash) -m reg 0{4}.*
            http-request sc-set-gpt(1,0) 1 if challenge_req timestamp_recent hash_good
            http-request return status 200 if challenge_req hash_good
            http-request return status 400 content-type "text/html; charset=UTF-8" hdr "Cache-control" "max-age=0" string "Bad request" if !challenge_req OR !hash_good

          ${separateModule (lib.mapAttrsToList (name: value: value) config.modules.haproxy.backends)}
        '';
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          listenHTTP = ":1360";
          group = config.services.haproxy.group;
          # HAProxy only reads certificates when it (re)starts
          reloadServices = ["haproxy.service"];
        };
      };

      # Wildcard certificates, issued with DNS challenges through Cloudflare
      sops.templates."acme-cloudflare.env" = {
        content = ''
          CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."acme/cloudflare_dns_token"}
        '';
        owner = "acme";
      };

      security.acme.certs.wildcard-cpluspatch-com = {
        domain = "*.cpluspatch.com";
        extraDomainNames = ["*.lgs.cpluspatch.com"];
        dnsProvider = "cloudflare";
        listenHTTP = null;
        # The local resolver can cache the challenge record as missing, and never see it appear
        dnsResolver = "1.1.1.1:53";
        environmentFile = config.sops.templates."acme-cloudflare.env".path;
      };
      security.acme.certs.wildcard-cpluspatch-dev = {
        domain = "cpluspatch.dev";
        extraDomainNames = ["*.cpluspatch.dev"];
        dnsProvider = "cloudflare";
        listenHTTP = null;
        # The local resolver can cache the challenge record as missing, and never see it appear
        dnsResolver = "1.1.1.1:53";
        environmentFile = config.sops.templates."acme-cloudflare.env".path;
      };

      # Also served by HAProxy; the mail server module sets its own reloadServices
      security.acme.certs."${config.networking.hostName}.infra.cpluspatch.com".reloadServices = ["haproxy.service"];
      security.acme.certs."broken.cpluspatch.com" = {};
      security.acme.certs."text.cpluspatch.com" = {};
    }
  ];
}
