{
  config,
  lib,
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
  };

  config = {
    services.nginx = {
      # Change ports to 8080 and 8443, because 80/443 are already used by HAProxy
      defaultHTTPListenPort = 8080;
      defaultSSLListenPort = 8443;
    };

    services.haproxy = {
      enable = true;
      config = ''
        global
          log /dev/log local0
          log /dev/log local1 notice
          stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
          stats timeout 30s
          daemon

          # Don't use SSLv3 or TLSv1.0/1.1
          ssl-default-bind-ciphers EECDH+AESGCM:EDH+AESGCM
          ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

          # Enable SSL session caching
          tune.ssl.cachesize 50000
          tune.ssl.lifetime 300

        defaults
          log     global
          mode    http
          option  httplog
          option  dontlognull
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
          http-request use-service prometheus-exporter if { path /metrics }
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

        frontend https
          mode http
          bind :::443 v4v6 ssl ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "crt ${value.directory}/full.pem") config.security.acme.certs)}
          http-response set-header Strict-Transport-Security "max-age=15552000; includeSubDomains"
          http-response set-header X-Content-Type-Options nosniff
          # Opt out of FLoC
          http-response set-header Permissions-Policy "interest-cohort=()"
          # Offload compression to HAProxy, stripping the Accept-Encoding header
          compression offload

          # Redirect cpluspatch.dev to cpluspatch.com
          #acl is_old_site hdr(host) -i cpluspatch.dev
          #http-request redirect code 301 location https://cpluspatch.com%[capture.req.uri] if is_old_site !{ path_beg /.well-known/matrix }

        ${lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: value: "  ${lib.concatStringsSep "\n  " (lib.splitString "\n" value)}")
            config.modules.haproxy.acls)}

        # Backends
        # Redirect acme requests to the nginx static file server
        backend acme
          server acme localhost${config.security.acme.defaults.listenHTTP}

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
