{config, ...}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../secrets/postgresql/sharkey.nix
    ../secrets/redis/sharkey.nix
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

  modules.haproxy.acls.sharkey = ''
    acl is_sharkey hdr(host) -i mk.cpluspatch.com
    use_backend sharkey if is_sharkey
  '';

  modules.haproxy.backends.sharkey = ''
    backend sharkey
      server sharkey 127.0.0.1:${toString config.services.sharkey.settings.port}
  '';

  security.acme.certs."mk.cpluspatch.com" = {};
}
