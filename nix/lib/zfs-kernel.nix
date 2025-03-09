{
  lib,
  pkgs,
  config,
}: {
  # Find the latest kernel package that is compatible with ZFS
  # Because ZFS isn't built into the Linux kernel so we need to
  # find the latest compatible version
  getZfsCompatibleKernelPackages =
    lib.filterAttrs (
      name: kernelPackages:
        (builtins.match "linux_[0-9]+_[0-9]+" name)
        != null
        && (builtins.tryEval kernelPackages).success
        && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
    )
    pkgs.linuxKernel.packages;

  getLatestZfsKernelPackage = zfsCompatibleKernelPackages:
    lib.last (
      lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
        builtins.attrValues zfsCompatibleKernelPackages
      )
    );
}
