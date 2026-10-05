{
  imports = [
    ./hardware-configuration.nix

    ../../services/minecraft.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

  # ZFS' cache can grow to most of the RAM by default, leaving the 5 GiB Minecraft heap
  # little room. 1 GiB is plenty for a single game world
  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (1024 * 1024 * 1024)}";

  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "3e9e1221";

    firewall = {
      allowedTCPPorts = [
        25565 # Minecraft
        25566 # Minecraft 2
      ];
      allowedUDPPorts = [
        24454 # Minecraft Simple Voice Chat
      ];
    };
  };
}
