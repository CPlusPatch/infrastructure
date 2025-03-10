{config, ...}: {
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_PORT = "6001";
    };
  };

  services.traefik.dynamicConfigOptions.http.routers."uptime-kuma" = {
    rule = "Host(`status.cpluspatch.com`)";
    service = "uptime-kuma";
  };

  services.traefik.dynamicConfigOptions.http.services."uptime-kuma" = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${config.services.uptime-kuma.settings.UPTIME_KUMA_PORT}";}
      ];
    };
  };
}
