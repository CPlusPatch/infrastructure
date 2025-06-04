{config, ...}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../secrets/redis/sharkey.nix
    ../secrets/redis/immich.nix
    ../secrets/redis/bitchbot.nix
    ../secrets/redis/versia2.nix
    ../secrets/redis/synapse.nix

    ../modules/backups.nix
  ];

  services.redis = {
    vmOverCommit = true;

    servers = {
      sharkey = {
        enable = true;
        port = 6380;
        bind = ips.freeman;
        requirePassFile = config.sops.secrets."redis/sharkey".path;
      };

      immich = {
        enable = true;
        port = 6381;
        bind = ips.freeman;
        requirePassFile = config.sops.secrets."redis/immich".path;
      };

      bitchbot = {
        enable = true;
        port = 6382;
        bind = ips.freeman;
        requirePassFile = config.sops.secrets."redis/bitchbot".path;
      };

      versia = {
        enable = true;
        port = 6383;
        bind = ips.freeman;
        requirePassFile = config.sops.secrets."redis/versia2".path;
      };

      synapse = {
        enable = true;
        port = 6384;
        bind = ips.freeman;
        requirePassFile = config.sops.secrets."redis/synapse".path;
      };
    };
  };

  services.backups.jobs = {
    redis-sharkey.source = "/var/lib/redis-sharkey";
    redis-immich.source = "/var/lib/redis-immich";
    redis-bitchbot.source = "/var/lib/redis-bitchbot";
    redis-versia.source = "/var/lib/redis-versia";
    redis-synapse.source = "/var/lib/redis-synapse";
  };
}
