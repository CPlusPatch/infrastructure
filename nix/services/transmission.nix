{
  pkgs,
  config,
  ...
}: {
  sops.templates."transmission.json" = {
    content = ''
      {
          "rpc-password": "${config.sops.placeholder."transmission/password"}"
      }
    '';
  };

  services.transmission = {
    enable = true;
    performanceNetParameters = true;
    package = pkgs.transmission_4;
    openPeerPorts = true;
    credentialsFile = config.sops.templates."transmission.json".path;
    webHome = pkgs.flood-for-transmission;

    settings = {
      rpc-bind-address = "localhost";
      download-dir = "/mnt/fs-01b/torrents/downloads";
      rpc-authentication-required = true;
      rpc-username = "admin";
    };
  };

  services.traefik.dynamicConfigOptions.http.routers.transmission = {
    entryPoints = ["websecure"];
    rule = "Host(`dl.lgs.cpluspatch.com`)";
    service = "transmission";
    middlewares = ["compress@file"];
  };

  services.traefik.dynamicConfigOptions.http.services.transmission = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${toString config.services.transmission.settings.rpc-port}";}
      ];
    };
  };
}
