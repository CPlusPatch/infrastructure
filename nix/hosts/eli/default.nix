{
  imports = [
    ../../services/minecraft.nix
  ];

  # ZFS' cache can grow to most of the RAM by default, leaving the 5 GiB Minecraft heap
  # little room. 1 GiB is plenty for a single game world
  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (1024 * 1024 * 1024)}";

  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "3e9e1221";

    # Players connect through HAProxy on faithplate, over the private network
    firewall.allowedUDPPorts = [
      24454 # Minecraft Simple Voice Chat
    ];
  };
}
