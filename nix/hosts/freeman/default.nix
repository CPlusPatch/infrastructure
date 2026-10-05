{
  imports = [
    ../../services/clickhouse.nix
    ../../services/postgresql.nix
    ../../services/prometheus.nix
    ../../services/redis.nix
    ../../services/influxdb.nix
  ];

  # 4 GiB of RAM shared by every database. PostgreSQL has its own 1 GiB buffer cache, so cap
  # ZFS' cache instead of letting both cache the same pages
  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (1024 * 1024 * 1024)}";

  # PostgreSQL's data, with records closer to its 8K pages: with the default 128K, each page
  # write rewrote a whole record. Backed up by pgbackrest, not by snapshots
  disko.devices.zpool.zroot.datasets.postgresql = {
    type = "zfs_fs";
    options = {
      mountpoint = "legacy";
      recordsize = "32K";
      "com.sun:auto-snapshot" = "false";
    };
    mountpoint = "/var/lib/postgresql";
  };

  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "24d142e4";
  };
}
