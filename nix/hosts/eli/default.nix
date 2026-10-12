{
  imports = [
    ../../services/garage.nix
    ../../services/minecraft.nix
  ];

  # ZFS' cache can grow to most of the RAM by default, leaving the 5 GiB Minecraft heap
  # little room. 1 GiB is plenty for a single game world
  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (1024 * 1024 * 1024)}";

  # Garage's metadata and blocks, one dataset so snapshots are consistent. The blocks are
  # already compressed by Garage and read through Garage's own handling, so ZFS only caches
  # metadata, keeping the ARC small for Minecraft. The quota keeps a runaway bucket from
  # filling the pool the game and the system share
  disko.devices.zpool.zroot.datasets.garage = {
    type = "zfs_fs";
    options = {
      mountpoint = "legacy";
      compression = "off";
      primarycache = "metadata";
      quota = "40G";
      "com.sun:auto-snapshot" = "false";
    };
    mountpoint = "/var/lib/garage";
  };

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
