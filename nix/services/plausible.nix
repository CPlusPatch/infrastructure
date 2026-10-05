{
  config,
  lib,
  infra,
  ...
}: {
  sops.templates."plausible.env" = {
    content = ''
      DATABASE_URL=postgres://plausible:${config.sops.placeholder."postgresql/plausible"}@${infra.ips.freeman}:5432/plausible
      CLICKHOUSE_DATABASE_URL=http://plausible:${config.sops.placeholder."clickhouse/plausible_password"}@${infra.ips.freeman}:8123/plausible_events_db
    '';
  };

  services.plausible = {
    enable = true;

    server = {
      disableRegistration = true;
      baseUrl = "https://logs.cpluspatch.com";
      port = 10239;
      secretKeybaseFile = config.sops.secrets."plausible/secret_key_base".path;
    };

    database = {
      postgres = {
        setup = false;
      };

      clickhouse = {
        # The real URL, with credentials, is set in plausible.env
        url = "http://${infra.ips.freeman}:8123/plausible_events_db";
        setup = false;
      };
    };
  };

  # HACK: Inject the database URLs, because the service config doesn't have an option for them.
  # SECRET_KEY_BASE is already loaded by the module from server.secretKeybaseFile
  systemd.services.plausible = {
    # Remove the default NixOS DATABASE_URL that just points to a local socket for some reason
    environment.DATABASE_URL = lib.mkForce null;
    # Credentials can't go in the Nix store
    environment.CLICKHOUSE_DATABASE_URL = lib.mkForce null;
    serviceConfig = {
      EnvironmentFile = config.sops.templates."plausible.env".path;
    };
  };

  modules.haproxy.vhosts.plausible = {
    domain = "logs.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.plausible.server.port}";
  };
}
