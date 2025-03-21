{config, ...}: {
  nixpkgs.overlays = [
    (import ../overlays/flaresolverr-unstable.nix)
  ];

  services.radarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-radarr = {
    enable = true;
    port = 9708;
    url = "https://radarr.lgs.cpluspatch.com";
    apiKeyFile = config.sops.secrets."radarr/key".path;
  };

  services.traefik.dynamicConfigOptions.http.routers.radarr = {
    rule = "Host(`radarr.lgs.cpluspatch.com`)";
    service = "radarr";
  };

  services.traefik.dynamicConfigOptions.http.services.radarr = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:7878";}
      ];
    };
  };

  services.prowlarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-prowlarr = {
    enable = true;
    port = 9709;
    url = "https://prowlarr.lgs.cpluspatch.com";
    apiKeyFile = config.sops.secrets."prowlarr/key".path;
  };

  services.traefik.dynamicConfigOptions.http.routers.prowlarr = {
    rule = "Host(`prowlarr.lgs.cpluspatch.com`)";
    service = "prowlarr";
  };

  services.traefik.dynamicConfigOptions.http.services.prowlarr = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:9696";}
      ];
    };
  };

  services.sonarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-sonarr = {
    enable = true;
    port = 9710;
    url = "https://sonarr.lgs.cpluspatch.com";
    apiKeyFile = config.sops.secrets."sonarr/key".path;
  };

  services.traefik.dynamicConfigOptions.http.routers.sonarr = {
    rule = "Host(`sonarr.lgs.cpluspatch.com`)";
    service = "sonarr";
  };

  services.traefik.dynamicConfigOptions.http.services.sonarr = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:8989";}
      ];
    };
  };

  services.flaresolverr = {
    enable = true;
    port = 8191;
  };

  systemd.services.flaresolverr.serviceConfig = {
    Environment = [
      "LOG_LEVEL=debug"
    ];
  };
}
