{
  config,
  lib,
  infra,
  nodes,
  ...
}: let
  # Databases on freeman
  db = nodes.freeman.config.services;
  clickhouseUrl = "${infra.ips.freeman}:${toString db.clickhouse.serverConfig.http_port}/plausible_events_db";
in {
  sops.templates."plausible.env" = {
    content = ''
      DATABASE_URL=postgres://plausible:${config.sops.placeholder."postgresql/plausible"}@${infra.ips.freeman}:${toString db.postgresql.settings.port}/plausible
      CLICKHOUSE_DATABASE_URL=http://plausible:${config.sops.placeholder."clickhouse/plausible_password"}@${clickhouseUrl}
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
        url = "http://${clickhouseUrl}";
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
