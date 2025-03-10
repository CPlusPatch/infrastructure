{
  config,
  pkgs,
  ...
}: {
  imports = [./keycloak-themes];

  modules.postgresql.databases = [
    {
      name = "keycloak";
      user = "keycloak";
      password = config.sops.placeholder."postgresql/keycloak";
    }
  ];

  # Keycloak requires that we pass the db password via a file, so we create this
  sops.templates."keycloak-password" = {
    content = "${config.sops.placeholder."postgresql/keycloak"}";
  };

  services.keycloak = {
    enable = true;

    database = {
      type = "postgresql";
      username = "keycloak";
      passwordFile = config.sops.templates."keycloak-password".path;
      name = "keycloak";
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
}
