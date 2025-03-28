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
    ../../features/fs-01b.nix

    ../../services/traefik.nix
    ../../services/keycloak.nix
    ../../services/servarr.nix
    ../../services/uptime-kuma.nix
    ../../services/synapse.nix
    ../../services/vaultwarden.nix
    ../../services/plausible.nix
    ../../services/mail.nix
    ../../services/transmission.nix
    ../../services/grafana.nix
    ../../services/jellyfin.nix
    ../../services/nextcloud.nix
    ../../services/sharkey.nix
    ../../services/immich.nix
    ../../services/bitchbot.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    hostName = "faithplate";
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";
  };

  systemd.network = {
    enable = true;
    networks."30-wan" = {
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "ipv4";
      address = [
        "${variables.ipv6}"
      ];
      routes = [
        {Gateway = "fe80::1";}
      ];
    };
  };

  boot.kernelPackages = latestKernelPackage;
}
