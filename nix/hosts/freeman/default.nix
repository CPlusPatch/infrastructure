{
  imports = [
    ./hardware-configuration.nix

    ../../services/clickhouse.nix
    ../../services/postgresql.nix
    ../../services/prometheus.nix
    ../../services/redis.nix
    ../../services/influxdb.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "24d142e4";
  };
}
