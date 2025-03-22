{
  config,
  pkgs,
  ...
}: {
  imports = [./keycloak-themes];

  services.keycloak = {
    enable = true;

    database = {
      type = "postgresql";
      username = "keycloak";
      passwordFile = config.sops.secrets."postgresql/keycloak".path;
      name = "keycloak";
      # Address of freeman through the VPN
      host = "10.147.19.243";
      useSSL = false;
      createLocally = false;
    };

    themes = with pkgs; {
      keywind = custom_keycloak_themes.keywind;
    };

    settings = {
      hostname = "https://id.cpluspatch.com";
      http-host = "localhost";
      http-port = 6000;
      http-enabled = true;
      proxy-headers = "xforwarded";
    };
  };

  services.traefik.dynamicConfigOptions.http.routers.keycloak = {
    entryPoints = ["websecure"];
    rule = "Host(`id.cpluspatch.com`)";
    service = "keycloak";
    middlewares = ["compress@file"];
  };

  services.traefik.dynamicConfigOptions.http.services.keycloak = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:6000";}
      ];
    };
  };

  # HACK: Redirect https://id.cpluspatch.com/realms/master/protocol/openid-connect/userinfo/emails to https://id.cpluspatch.com/realms/master/protocol/openid-connect/userinfo
  # Fixes Grafana being stupid and dumb and looking for the email attribute in the userinfo endpoint
  services.traefik.dynamicConfigOptions.http.routers.keycloak-redirect = {
    entryPoints = ["websecure"];
    rule = "Host(`id.cpluspatch.com`) && PathPrefix(`/realms/master/protocol/openid-connect/userinfo/emails`)";
    service = "keycloak";
    middlewares = ["keycloak-redirect"];
  };

  services.traefik.dynamicConfigOptions.http.middlewares.keycloak-redirect = {
    redirectRegex = {
      regex = "^https://id.cpluspatch.com/realms/master/protocol/openid-connect/userinfo/emails$";
      replacement = "/realms/master/protocol/openid-connect/userinfo";
    };
  };
}
