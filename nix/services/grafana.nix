{
  config,
  infra,
  nodes,
  ...
}: let
  # Databases on freeman
  db = nodes.freeman.config.services;
in {
  sops = {
    secrets."grafana/secret_key".owner = "grafana";
    secrets."postgresql/grafana".owner = "grafana";
    secrets."keycloak/grafana".owner = "grafana";
  };

  services.grafana = {
    enable = true;

    # Updates the datasource created in the UI, matched by name. Keeps its uid so dashboards
    # still find it
    provision = {
      enable = true;

      # Read-only in the UI: edit the JSON in the repository instead
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "infra";
            type = "file";
            # Kept apart from the dashboards made in the UI
            folder = "Infrastructure";
            disableDeletion = true;
            allowUiUpdates = false;
            options.path = ./grafana-dashboards;
          }
        ];
      };

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "prometheus";
            uid = "eegmzxgejop34d";
            type = "prometheus";
            access = "proxy";
            url = "http://${infra.ips.freeman}:${toString db.prometheus.port}";
            isDefault = true;
            jsonData = {
              httpMethod = "POST";
              prometheusType = "Prometheus";
              prometheusVersion = db.prometheus.package.version;
            };
          }
        ];
      };
    };

    settings = {
      users = {
        allow_sign_up = false;
      };

      server = {
        root_url = "https://stats.cpluspatch.com";
        http_port = 3651;
      };

      security = {
        secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";
      };

      database = {
        type = "postgres";
        host = "${infra.ips.freeman}:${toString db.postgresql.settings.port}";
        user = "grafana";
        password = "$__file{${config.sops.secrets."postgresql/grafana".path}}";
        name = "grafana";
      };

      auth = {
        # HACK: Grafana is dumb and doesn't look up emails in a way that Keycloak can handle
        # https://github.com/grafana/grafana/issues/68678
        oauth_allow_insecure_email_lookup = true;
      };

      "auth.generic_oauth" = {
        enabled = true;
        name = "CPlusPatch ID";
        allow_sign_up = true;
        skip_org_role_sync = true;
        client_id = "grafana";
        client_secret = "$__file{${config.sops.secrets."keycloak/grafana".path}}";
        scopes = "openid email profile offline_access";
        email_attribute_path = "email";
        login_attribute_path = "username";
        name_attribute_path = "full_name";
        auth_url = "https://id.cpluspatch.com/realms/default/protocol/openid-connect/auth";
        token_url = "https://id.cpluspatch.com/realms/default/protocol/openid-connect/token";
        api_url = "https://id.cpluspatch.com/realms/default/protocol/openid-connect/userinfo";
      };
    };
  };

  modules.haproxy.vhosts.grafana = {
    domain = "stats.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
  };
}
