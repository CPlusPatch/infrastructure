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
    ../../features/fs-01b.nix

    ../../services/haproxy.nix
    ../../services/varnish.nix
    ../../services/keycloak.nix
    ../../services/servarr.nix
    ../../services/nzbget.nix
    ../../services/uptime-kuma.nix
    ../../services/synapse.nix
    ../../services/vaultwarden.nix
    ../../services/plausible.nix
    ../../services/mail.nix
    ../../services/transmission.nix
    ../../services/grafana.nix
    ../../services/jellyfin.nix
    ../../services/nextcloud.nix
    ../../services/sharelists.nix
    ../../services/sharkey.nix
    ../../services/immich.nix
    ../../services/bitchbot.nix
    ../../services/syncbot.nix
    ../../services/versia.nix
    ../../services/versia2.nix
    ../../services/glance.nix
    ../../services/nexus.nix
    ../../services/static.nix
    ../../services/neko.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    hostName = "faithplate";
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";
    firewall = {
      allowedTCPPorts = [
        80 # HTTP
        443 # HTTPS
        25 # SMTP
        465 # SMTP over SSL
        587 # SMTP submission
        993 # IMAP over SSL
      ];
      allowedUDPPorts = [
        443 # HTTP/3
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
