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

  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "24d142e4";
  };
}
