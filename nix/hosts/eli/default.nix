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

    ../../services/minecraft.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    hostName = "eli";
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "3e9e1221";

    firewall = {
      allowedTCPPorts = [
        25565 # Minecraft
      ];
      allowedUDPPorts = [
        24454 # Minecraft Simple Voice Chat
      ];
    };
  };

  systemd.network = {
    enable = true;
    networks."30-wan" = {
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "no";
      address = [
        "${variables.ipv4}/32"
        "${variables.ipv6}/64"
      ];
      routes = [
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
        }
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
