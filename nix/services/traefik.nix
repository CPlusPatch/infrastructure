{config, ...}: {
  services.traefik = {
    enable = true;
    # Required for Docker backend
    group = "docker";

    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
          };
        };

        websecure = {
          address = ":443";
          asDefault = true;
          http = {
            tls.certResolver = "letsencrypt";
            middlewares = ["compress@file"];
          };
        };

        metrics = {
          address = ":8899";
        };
      };

      log = {
        level = "INFO";
        filePath = "${config.services.traefik.dataDir}/traefik.log";
        format = "json";
      };

      providers = {
        docker = {
          endpoint = "unix:///var/run/docker.sock";
          exposedByDefault = false;
          allowEmptyServices = true;
        };
      };

      certificatesResolvers = {
        letsencrypt.acme = {
          email = "acme@cpluspatch.com";
          storage = "${config.services.traefik.dataDir}/acme.json";
          httpChallenge.entryPoint = "web";
        };
      };

      api = {};

      metrics.prometheus = {
        entryPoint = "metrics";
        addEntryPointsLabels = true;
        addServicesLabels = true;
        buckets = [0.1 0.3 1.2 5.0];
      };
    };

    dynamicConfigOptions = {
      http = {
        middlewares = {
          hsts.headers.customResponseHeaders = {
            Strict-Transport-Security = "max-age=15552000; includeSubDomains";
          };

          dashboard-auth.basicAuth = {
            users = [
              # Password can be found in secrets/traefik.yaml
              "admin:$2y$05$dBZpkEKXOM6l.e.g/4xkKeG/nz2bG1/TwZAsCWoH/b1BfGqho8DWW"
            ];
          };

          csp.headers.customResponseHeaders = {
            Content-Security-Policy = "default-src 'none'; frame-ancestors 'none'; form-action 'none'";
          };

          compress.compress = {
            # Disable zstd and br because of memory leaks
            encodings = ["gzip"];
          };

          # Injects Plausible Analytics script
          plausible.plugin = {
            "plugin-rewritebody" = {
              lastModified = "true";
              rewrites = [
                {
                  regex = "<meta charset=\"utf-8\">";
                  replacement = "<meta charset=\"utf-8\"><script defer data-domain=\"social.lysand.org\" src=\"https://logs.cpluspatch.com/js/script.js\"></script>";
                }
              ];
            };
          };

          # Redirect cpluspatch.dev to cpluspatch.com
          newsite-redirect.redirectRegex = {
            permanent = true;
            regex = "(.)*";
            replacement = "https://cpluspatch.com";
          };

          nextcloud-redirectregex.redirectRegex = {
            permanent = true;
            regex = "https://(.*)/.well-known/(?:card|cal)dav";
            replacement = "https://\${1}/remote.php/dav";
          };
        };

        routers = {
          # Set a router for ${hostname}.infra.cpluspatch.com to the Traefik dashboard
          traefik = {
            rule = "Host(`${config.networking.hostName}.infra.cpluspatch.com`)";
            service = "api@internal";
            middlewares = ["dashboard-auth"];
          };

          newsite = {
            rule = "Host(`cpluspatch.dev`) && !((PathPrefix(`/_matrix`) || PathPrefix(`/_synapse`) || PathPrefix(`/.well-known/matrix`)))";
            service = "stub";
            middlewares = ["newsite-redirect"];
          };
        };

        services = {
          stub = {
            loadBalancer = {
              servers = [
                {url = "https://cpluspatch.com";}
              ];
            };
          };
        };
      };
    };
  };
}
