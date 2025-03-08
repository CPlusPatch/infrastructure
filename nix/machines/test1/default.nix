{pkgs, ...}: {
  imports = [../../partitions/single-zfs.nix ../../features/packages.nix ../../features/ssh.nix];

  disko.devices.disk.main.device = "/dev/sda";

  networking.hostName = "test1";
}
