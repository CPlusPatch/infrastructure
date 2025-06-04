{config, ...}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../packages/sharkey/import.mod.nix
    ../secrets/postgresql/sharkey.nix
    ../secrets/redis/sharkey.nix
  ];

  sops = {
    secrets."postgresql/sharkey".owner = "sharkey";
    secrets."redis/sharkey".owner = "sharkey";
  };

  services.sharkey = {
    enable = true;

    domain = "mk.cpluspatch.com";

    database = {
      host = ips.freeman;
      port = 5432;
      name = "misskey";
      passwordFile = config.sops.secrets."postgresql/sharkey".path;
    };

    redis = {
      host = ips.freeman;
      port = 6380;
      passwordFile = config.sops.secrets."redis/sharkey".path;
    };

    settings = {
      port = 3813;
      id = "aidx";

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
