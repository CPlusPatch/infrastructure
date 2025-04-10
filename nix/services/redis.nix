{config, ...}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  services.redis = {
    vmOverCommit = true;

    servers = {
      sharkey = {
        enable = true;
        port = 6380;
        bind = ips.zerotier-ips.freeman;
        requirePassFile = config.sops.secrets."redis/sharkey".path;
      };

      immich = {
        enable = true;
        port = 6381;
        bind = ips.zerotier-ips.freeman;
        requirePassFile = config.sops.secrets."redis/immich".path;
      };

      bitchbot = {
        enable = true;
        port = 6382;
        bind = ips.zerotier-ips.freeman;
        requirePassFile = config.sops.secrets."redis/bitchbot".path;
      };
    };
  };
}
