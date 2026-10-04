{
  config,
  infra,
  ...
}: let
  inherit (infra) ips;
in {
  imports = [
    ../lib/secrets.nix
  ];

  sops = {
    templates."sharkey.env".content = ''
      MK_CONFIG_DB_PASS=${config.sops.placeholder."postgresql/sharkey"}
      MK_CONFIG_REDIS_PASS=${config.sops.placeholder."redis/sharkey"}
    '';
  };

  services.sharkey = {
    enable = true;
    setupRedis = false;
    setupPostgresql = false;

    environmentFiles = [
      config.sops.templates."sharkey.env".path
    ];

    settings = {
      port = 3813;
      id = "aidx";
      url = "https://mk.cpluspatch.com/";
      fulltextSearch.provider = "sqlLike";

      db = {
        host = ips.freeman;
        port = 5432;
        user = "misskey";
        db = "misskey";
      };

      redis = {
        host = ips.freeman;
        port = 6380;
      };

      maxNoteLength = 100000;
    };
  };

  modules.haproxy.vhosts.sharkey = {
    domain = "mk.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.sharkey.settings.port}";
  };
}
