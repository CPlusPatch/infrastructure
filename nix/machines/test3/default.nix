{
  config,
  pkgs,
  lib,
  ...
}: let
  # Find the latest kernel package that is compatible with ZFS
  # Because ZFS isn't built into the Linux kernel so we need to
  # findmaxx the latest compatible version
  zfsCompatibleKernelPackages =
    lib.filterAttrs (
      name: kernelPackages:
        (builtins.match "linux_[0-9]+_[0-9]+" name)
        != null
        && (builtins.tryEval kernelPackages).success
        && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
    )
    pkgs.linuxKernel.packages;
  latestKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );
in {
  imports = [./hardware-configuration.nix ../../features/packages.nix ../../features/ssh.nix];

  disko.devices.disk.main.device = "/dev/sda";

  networking = {
    hostName = "test3";
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";
  };

  boot.kernelPackages = latestKernelPackage;
}
