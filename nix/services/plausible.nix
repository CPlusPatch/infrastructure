{
  config,
  lib,
  ...
}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  sops.templates."plausible.env" = {
    content = ''
      DATABASE_URL=postgres://plausible:${config.sops.placeholder."postgresql/plausible"}@${ips.zerotier-ips.freeman}:5432/plausible
      SECRET_KEY_BASE=${config.sops.placeholder."plausible/secret-key-base"}
    '';
  };

  services.plausible = {
    enable = true;

    server = {
      disableRegistration = true;
      baseUrl = "https://logs.cpluspatch.com";
      port = 10239;
      secretKeybaseFile = config.sops.secrets."plausible/secret-key-base".path;
    };

    database = {
      postgres = {
        setup = false;
      };

      clickhouse = {
        url = "http://${ips.zerotier-ips.freeman}:8123/plausible_events_db";
        setup = false;
      };
    };
  };

  # HACK: Inject Plausible secrets, because the service config doesn't have an option for that
  systemd.services.plausible = {
    # Remove the default NixOS DATABASE_URL that just points to a local socket for some reason
    environment.DATABASE_URL = lib.mkForce null;
    serviceConfig = {
      EnvironmentFile = config.sops.templates."plausible.env".path;
    };
  };

  services.traefik.dynamicConfigOptions.http.routers.plausible = {
    rule = "Host(`logs.cpluspatch.com`)";
    service = "plausible";
  };

  services.traefik.dynamicConfigOptions.http.services.plausible = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${toString config.services.plausible.server.port}";}
      ];
    };
  };
}
