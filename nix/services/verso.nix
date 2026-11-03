{
  config,
  infra,
  nodes,
  ...
}: let
  # Databases on freeman
  db = nodes.freeman.config.services;

  credential = name: "\${file:/run/credentials/verso.service/${name}}";
  port = 9228;
in {
  sops.secrets = {
    "postgresql/verso" = {};
    "keycloak/verso" = {};
    "s3/verso/access_key_id" = {};
    "s3/verso/secret_key" = {};
  };

  services.verso = {
    enable = true;
    database.createLocally = false;

    credentials = {
      postgres = config.sops.secrets."postgresql/verso".path;
      oidc = config.sops.secrets."keycloak/verso".path;
      s3-access-key-id = config.sops.secrets."s3/verso/access_key_id".path;
      s3-secret-key = config.sops.secrets."s3/verso/secret_key".path;
    };

    settings = {
      domain = "verso.cpluspatch.com";

      database.postgres = "postgresql://verso:${credential "postgres"}@${infra.ips.freeman}:${toString db.postgresql.settings.port}/verso";

      # Only reached through HAProxy, on this host
      http.port = port;

      instance = {
        name = "Jesse's Stupendous Carnival";
        description = "My personal self-hosted Verso instance.";
        contact.email = "admin+verso@cpluspatch.com";
      };

      media.storage.s3 = {
        endpoint = "http://${infra.ips.eli}:3900";
        region = "eu-central";
        bucket = "verso";
        access_key_id = credential "s3-access-key-id";
        secret_access_key = credential "s3-secret-key";
        public_url = "https://cdn.cpluspatch.com/verso";
      };

      auth.issuers = [
        {
          name = "CPlusPatch ID";
          url = "https://id.cpluspatch.com/realms/default";
          client_id = "verso";
          client_secret = credential "oidc";
          registration = "open";
        }
      ];
    };
  };

  systemd.services.verso = {
    wants = ["network-online.target"];
    after = ["network-online.target"];
    # Keep retrying while the databases are down (e.g. while freeman reboots)
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = "10s";
  };

  modules.haproxy.vhosts.verso = {
    domain = "verso.cpluspatch.com";
    server = "127.0.0.1:${toString port}";
  };
}
