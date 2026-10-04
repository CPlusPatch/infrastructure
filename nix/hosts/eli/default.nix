{
  imports = [
    ./hardware-configuration.nix

    ../../services/minecraft.nix
  ];

  disko.devices.disk.main.device = "/dev/sda";

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
