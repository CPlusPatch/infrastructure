{
  config,
  infra,
  ...
}: {
  services.redis = {
    vmOverCommit = true;

    servers = {
      sharkey = {
        enable = true;
        port = 6380;
        bind = infra.ips.freeman;
        requirePassFile = config.sops.secrets."redis/sharkey".path;
      };

      immich = {
        enable = true;
        port = 6381;
        bind = infra.ips.freeman;
        requirePassFile = config.sops.secrets."redis/immich".path;
      };

      versia = {
        enable = true;
        port = 6383;
        bind = infra.ips.freeman;
        requirePassFile = config.sops.secrets."redis/versia".path;
      };

      synapse = {
        enable = true;
        port = 6384;
        bind = infra.ips.freeman;
        requirePassFile = config.sops.secrets."redis/synapse".path;
      };
    };
  };

  services.backups.jobs = {
    redis-sharkey.source = "/var/lib/redis-sharkey";
    redis-immich.source = "/var/lib/redis-immich";
    redis-versia.source = "/var/lib/redis-versia";
    redis-synapse.source = "/var/lib/redis-synapse";
  };
}
