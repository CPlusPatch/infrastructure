{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.haproxy = {
    backends = lib.mkOption {
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
          log /dev/log local0
          log /dev/log local1 notice
          stats timeout 30s
          daemon

          # Don't use SSLv3 or TLSv1.0/1.1
          ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
          ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
          ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

          # Enable SSL session caching
          tune.ssl.cachesize 50000
          tune.ssl.lifetime 300

        http-errors errors
          errorfile 503 ${../../html/503.http}
          errorfile 502 ${../../html/502.http}

        defaults
          log     global
          mode    http
          option  dontlognull
          option  dontlog-normal
          timeout connect 5000ms
          timeout client  50000ms
          timeout server  50000ms

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

        ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: value: "  ${lib.concatStringsSep "\n  " (lib.splitString "\n" value)}")
            config.modules.haproxy.acls)}

        frontend https
          mode http
          bind :::443 v4v6 ssl prefer-client-ciphers crt-list /etc/tls.certlist
          option forwardfor
          # Opt out of FLoC
          http-response set-header Permissions-Policy "interest-cohort=()"

          default_backend default
          http-request capture req.hdr(Host) len 20
          log-format "%ci:%cp [%tr] %ft %b/%s %ST %ac/%fc/%bc/%sc/%rc %[capture.req.hdr(0)] %HM %{+Q}HU"

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

        ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: value: "  ${lib.concatStringsSep "\n  " (lib.splitString "\n" value)}")
            config.modules.haproxy.acls)}

        # Backends
        backend default
          mode http
          http-request deny

        # Redirect acme requests to the lego client
        backend acme
          server acme localhost${config.security.acme.defaults.listenHTTP}

        # Varnish backend
        backend varnish
          mode http
          # Varnish must tell it's ready to accept traffic
          option httpchk HEAD /healthcheck
          http-check expect status 200
          option forwardfor
          hash-type consistent
          server varnish1 127.0.0.1:6081

        ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: value: value) config.modules.haproxy.backends)}
      '';
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        listenHTTP = ":1360";
        group = config.services.haproxy.group;
      };
      certs."${config.networking.hostName}.infra.cpluspatch.com" = {};
    };
  };
}
