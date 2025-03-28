{config, ...}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  imports = [../packages/sharkey/import.mod.nix];

  sops.secrets."postgresql/sharkey" = {
    owner = "sharkey";
  };

  sops.secrets."redis/sharkey" = {
    owner = "sharkey";
  };

  services.sharkey = {
    enable = true;

    domain = "mk.cpluspatch.com";

    database = {
      host = ips.zerotier-ips.freeman;
      port = 5432;
      name = "misskey";
      passwordFile = config.sops.secrets."postgresql/sharkey".path;
    };

    redis = {
      host = ips.zerotier-ips.freeman;
      port = 6380;
      passwordFile = config.sops.secrets."redis/sharkey".path;
    };

    settings = {
      port = 3813;
      id = "aidx";

      maxNoteLength = 100000;
    };
  };

  services.traefik.dynamicConfigOptions.http.routers.sharkey = {
    rule = "Host(`mk.cpluspatch.com`)";
    service = "sharkey";
  };

  services.traefik.dynamicConfigOptions.http.services.sharkey = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${toString config.services.sharkey.settings.port}";}
      ];
    };
  };
}
