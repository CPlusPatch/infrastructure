{config, ...}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  sops.secrets."grafana/secret-key" = {
    owner = "grafana";
  };

  sops.secrets."postgresql/grafana" = {
    owner = "grafana";
  };

  sops.secrets."grafana/client-secret" = {
    owner = "grafana";
  };

  services.grafana = {
    enable = true;

    settings = {
      users = {
        allow_sign_up = false;
      };

      server = {
        root_url = "https://stats.cpluspatch.com";
        http_port = 3651;
      };

      security = {
        secret_key = "$__file{${config.sops.secrets."grafana/secret-key".path}}";
      };

      database = {
        type = "postgres";
        host = "${ips.zerotier-ips.freeman}:5432";
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
        client_secret = "$__file{${config.sops.secrets."grafana/client-secret".path}}";
        scopes = "openid email profile offline_access";
        email_attribute_path = "email";
        login_attribute_path = "username";
        name_attribute_path = "full_name";
        auth_url = "https://id.cpluspatch.com/realms/master/protocol/openid-connect/auth";
        token_url = "https://id.cpluspatch.com/realms/master/protocol/openid-connect/token";
        api_url = "https://id.cpluspatch.com/realms/master/protocol/openid-connect/userinfo";
      };
    };
  };

  services.traefik.dynamicConfigOptions.http.routers.grafana = {
    rule = "Host(`stats.cpluspatch.com`)";
    service = "grafana";
  };

  services.traefik.dynamicConfigOptions.http.services.grafana = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${toString config.services.grafana.settings.server.http_port}";}
      ];
    };
  };
}
