{
  config,
  lib,
  infra,
  ...
}: let
  # Port of each instance, whose password is the redis/<name> secret
  ports = {
    sharkey = 6380;
    immich = 6381;
    versia = 6383;
    synapse = 6384;
  };
in {
  services.redis = {
    vmOverCommit = true;

    servers =
      lib.mapAttrs (name: port: {
        enable = true;
        inherit port;
        bind = infra.ips.freeman;
        requirePassFile = config.sops.secrets."redis/${name}".path;
        # Snapshot at most every 5 minutes. Redis' default also snapshots every minute after
        # 10000 changes, which rewrote Sharkey's whole dataset almost every minute (~50 GB a day)
        save = [
          [3600 1]
          [300 1000]
        ];
      })
      ports;
  };

  services.backups.jobs = lib.mapAttrs' (name: port: lib.nameValuePair "redis-${name}" {source = "/var/lib/redis-${name}";}) ports;
}
