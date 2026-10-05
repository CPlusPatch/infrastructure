{
  config,
  infra,
  nodes,
  ...
}: let
  # Databases on freeman
  db = nodes.freeman.config.services;
in {
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
        host = infra.ips.freeman;
        port = db.postgresql.settings.port;
        user = "misskey";
        db = "misskey";
      };

      redis = {
        host = db.redis.servers.sharkey.bind;
        port = db.redis.servers.sharkey.port;
      };

      maxNoteLength = 100000;
    };
  };

  modules.haproxy.vhosts.sharkey = {
    domain = "mk.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.sharkey.settings.port}";
  };
}
