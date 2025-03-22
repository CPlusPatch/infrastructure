{
  services.jellyfin = {
    enable = true;
  };

  services.traefik.dynamicConfigOptions.http.routers.jellyfin = {
    rule = "Host(`stream.cpluspatch.com`)";
    service = "jellyfin";
  };

  services.traefik.dynamicConfigOptions.http.services.jellyfin = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:8096";}
      ];
    };
  };
}
