{
  config,
  pkgs,
  lib,
  ...
}: let
  zfsKernel = import ../../lib/zfs-kernel.nix {
    inherit lib pkgs config;
  };
  variables =
    (import ../../lib/vars.nix {
      inherit config;
    })
    .currentVars;

  zfsCompatibleKernelPackages = zfsKernel.getZfsCompatibleKernelPackages;
  latestKernelPackage = zfsKernel.getLatestZfsKernelPackage zfsCompatibleKernelPackages;
in {
  imports = [
    ./hardware-configuration.nix

    ../../features/packages.nix
    ../../features/ssh.nix
    ../../features/zerotier.nix
    ../../features/tailscale.nix

    ../../services/clickhouse.nix
    ../../services/postgresql.nix
    ../../services/prometheus.nix
    ../../services/redis.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    hostName = "freeman";
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "24d142e4";
  };

  systemd.network = {
    enable = true;
    networks."30-wan" = {
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "no";
      address = [
        "${variables.ipv6}/64"
      ];
      routes = [
        {Gateway = "fe80::1";}
      ];
    };
    networks."31-lan" = {
      matchConfig.Name = "enp7s0";
      networkConfig.DHCP = "ipv4";
    };
  };

  boot.kernelPackages = latestKernelPackage;
}
