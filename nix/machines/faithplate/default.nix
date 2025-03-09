{
  config,
  pkgs,
  lib,
  ...
}: let
  zfsKernel = import ../../lib/zfs-kernel.nix {
    inherit lib pkgs config;
  };
  zfsCompatibleKernelPackages = zfsKernel.getZfsCompatibleKernelPackages;
  latestKernelPackage = zfsKernel.getLatestZfsKernelPackage zfsCompatibleKernelPackages;
in {
  imports = [./hardware-configuration.nix ../../features/packages.nix ../../features/ssh.nix ../../services/traefik.nix ../../services/postgresql.nix ../../features/zerotier.nix];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    hostName = "faithplate";
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";
  };

  boot.kernelPackages = latestKernelPackage;
}
