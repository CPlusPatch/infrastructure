{config, ...}: {
  sops.templates."vaultwarden.env" = {
    content = ''
      DATABASE_URL=postgresql://vaultwarden:${config.sops.placeholder."postgresql/vaultwarden"}@10.147.19.243/vaultwarden
    '';
    owner = "vaultwarden";
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = config.sops.templates."vaultwarden.env".path;
    config = {
      ROCKET_ADDRESS = "::1";
      ROCKET_PORT = 8222;
      DOMAIN = "https://vault.cpluspatch.com";
      SIGNUPS_ALLOWED = false;
    };
  };

  services.traefik.dynamicConfigOptions.http.routers.vaultwarden = {
    rule = "Host(`vault.cpluspatch.com`)";
    service = "vaultwarden";
  };

  services.traefik.dynamicConfigOptions.http.services.vaultwarden = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}";}
      ];
    };
  };
}
