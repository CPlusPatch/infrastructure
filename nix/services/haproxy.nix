{
  config,
  lib,
  pkgs,
  ...
}: let
  # Pad a string, adding a prefix to each line
  padString = prefix: str: lib.concatStringsSep "\n" (lib.map (line: "${prefix}${line}") (lib.splitString "\n" str));
  separateModule = modules: lib.concatStringsSep "\n\n" modules;
  inherit (import ../lib/ips.nix) ips;
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

    enableConfigCheck = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable syntax checking of the HAProxy configuration";
    };
  };

  config = {
    modules.haproxy.frontends.minecraft-eli-fe = ''
      frontend minecraft-eli-fe
        mode tcp
        bind :::25565 v4v6
        default_backend minecraft-eli

      frontend minecraft-eli-voicechat-fe
        bind :::24454 v4v6
        default_backend minecraft-eli-voicechat
    '';

    # Allow Minecraft traffic
    networking.firewall.allowedTCPPorts = [25565];
    networking.firewall.allowedUDPPorts = [24454];

    modules.haproxy.backends.minecraft-eli = ''
      backend minecraft-eli
        mode tcp
        server minecraft-eli ${ips.eli}:25565

      backend minecraft-eli-voicechat
        server minecraft-eli-voicechat ${ips.eli}:24454
    '';

    /*
       modules.haproxy.acls.minecraft-cpluscraft = ''
      acl is_cpluscraft hdr(host) -i mc.cpluspatch.com
      use_backend minecraft-cpluscraft-bluemap if is_cpluscraft
    '';

    modules.haproxy.backends.minecraft-cpluscraft-bluemap = ''
      backend minecraft-cpluscraft-bluemap
        server minecraft-cpluscraft-bluemap ${ips.eli}:8100
    '';
    */

    modules.haproxy.acls.jellyfin2 = ''
      acl is_jellyfin2 hdr(host) -i tv.cpluspatch.com
      use_backend jellyfin2 if is_jellyfin2
    '';

    modules.haproxy.backends.jellyfin2 = ''
      backend jellyfin2
        server jellyfin2 kleiner:8096
    '';

    modules.haproxy.acls.radarr = ''
      acl is_radarr hdr(host) -i radarr.lgs.cpluspatch.com
      use_backend radarr if is_radarr
    '';

    modules.haproxy.backends.radarr = ''
      backend radarr
        server radarr kleiner:7878
    '';

    modules.haproxy.acls.sonarr = ''
      acl is_sonarr hdr(host) -i sonarr.lgs.cpluspatch.com
      use_backend sonarr if is_sonarr
    '';

    modules.haproxy.backends.sonarr = ''
      backend sonarr
        server sonarr kleiner:8989
    '';

    security.acme.certs."mc.cpluspatch.com" = {};
    security.acme.certs."tv.cpluspatch.com" = {};
    security.acme.certs."radarr.lgs.cpluspatch.com" = {};
    security.acme.certs."sonarr.lgs.cpluspatch.com" = {};

    services.nginx = {
      # Change ports to 8080 and 8443, because 80/443 are already used by HAProxy
      defaultHTTPListenPort = 8080;
      defaultSSLListenPort = 8443;
    };

    environment.etc."tls.certlist" = {
      text = "${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${value.directory}/full.pem") config.security.acme.certs)}\n";
    };

    system.checks = lib.mkIf config.modules.haproxy.enableConfigCheck [
      (pkgs.runCommand "check-haproxy-syntax" {} ''
        ${pkgs.haproxy}/bin/haproxy -c -f ${config.environment.etc."haproxy.cfg".source} 2> $out || (cat $out; exit 1)
      '')
    ];

    services.haproxy = {
      enable = true;
      config = ''
        global
          log /dev/log local0 notice
          stats timeout 30s
          daemon
          limited-quic

          # Don't use SSLv3 or TLSv1.0/1.1
          ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
          ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
          ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

          # Enable SSL session caching
          tune.ssl.cachesize 50000
          tune.ssl.lifetime 300

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
          stats auth admin:admin

        frontend http
          mode http
          bind :::80 v4v6
          # Don't redirect ACME requests
          acl is_acme path -i -m beg /.well-known/acme-challenge
          http-request redirect scheme https unless { ssl_fc } || is_acme
          use_backend acme if is_acme

          http-request capture req.hdr(Host) len 20
          log-format "%ci:%cp [%tr] %ft %b/%s %ST %ac/%fc/%bc/%sc/%rc %[capture.req.hdr(0)] %HM %{+Q}HU"

          errorfiles errors

        # Used by Varnish when updating its cache
        frontend varnish_cache
          mode http
          bind :::19872 v4v6
          # TODO: Make this actually fail on errors
          monitor-uri /healthcheck

          # Preserve X-Forwarded-For header, set by Varnish
          option forwardfor if-none

          default_backend default

        ${separateModule (lib.mapAttrsToList (name: value: padString "  " value) config.modules.haproxy.acls)}

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

          # Matches the default config of anubis of triggering on "Mozilla"
          acl protected_ua hdr(User-Agent) -m beg Mozilla/
          acl protected acl(protected_backend,protected_ua,!is_challenge_req)

          acl accepted sc_get_gpt(1,0) gt 0
          http-request return status 200 content-type "text/html; charset=UTF-8" hdr "Cache-control" "max-age=0, no-cache" lf-file ${pkgs.cpluspatch-pages}/challenge.html if protected !accepted
          use_backend challenge if is_challenge_req

          errorfiles errors

          # AP ACLs
          acl is_activitypub_req hdr(Accept) -i ld+json application/activity+json
          acl is_activitypub_payload hdr(Content-Type) -i application/ld+json application/activity+json

          # Static content detection
          acl static_content path_end .jpg .gif .png .css .js .htm .html .ico .svg .webp
          acl pseudo_static path_end .php ! path_beg /dynamic/
          acl varnish_available nbsrv(varnish) ge 1

          acl is_servarr hdr(host) -i -m end lgs.cpluspatch.com

          # Caches health detection + routing decision
          use_backend varnish if varnish_available static_content !is_servarr
          use_backend varnish if varnish_available pseudo_static !is_servarr

          # Redirect cpluspatch.dev to cpluspatch.com
          acl is_old_site hdr(host) -i cpluspatch.dev
          http-request redirect code 301 location https://cpluspatch.com%[capture.req.uri] if is_old_site !{ path_beg /.well-known/matrix }

          # Redirect text.cpluspatch.com to cpluspatch.com/text
          acl is_text_site hdr(host) -i text.cpluspatch.com
          http-request redirect code 301 location https://cpluspatch.com/text%[capture.req.uri] if is_text_site

          acl is_broken hdr(host) -i broken.cpluspatch.com
          use_backend broken if is_broken

        ${separateModule (lib.mapAttrsToList (name: value: padString "  " value) config.modules.haproxy.acls)}

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

        # Varnish backend
        backend varnish
          mode http
          # Varnish must tell it's ready to accept traffic
          option httpchk HEAD /healthcheck
          http-check expect status 200
          option forwardfor
          hash-type consistent
          server varnish1 127.0.0.1:6081

        ${separateModule (lib.mapAttrsToList (name: value: value) config.modules.haproxy.backends)}
      '';
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        listenHTTP = ":1360";
        group = config.services.haproxy.group;
      };
    };

    security.acme.certs."${config.networking.hostName}.infra.cpluspatch.com" = {};
    security.acme.certs."broken.cpluspatch.com" = {};
    security.acme.certs."text.cpluspatch.com" = {};
  };
}
