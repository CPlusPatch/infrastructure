{
  pkgs,
  config,
  ...
}: {
  imports = [
    ../../features/hetzner-network.nix
    ../../features/hetzner-vm.nix
    ../../features/monitoring-agent.nix
    ../../features/packages.nix
    ../../features/shell.nix
    ../../features/ssh.nix
    ../../features/tailscale.nix
    ../../modules/backups.nix
    ../../modules/dns.nix
    ../../modules/secrets.nix
  ];

  nix = {
    # nixpkgs' native Lix support is enabled by using it as the Nix package
    package = pkgs.lix;

    settings = {
      auto-optimise-store = true;
      experimental-features = ["flakes" "nix-command"];
      allowed-users = ["@wheel"];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin+acme@cpluspatch.com";
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "pnpm-10.34.0"
    ];
  };

  boot = {
    # The default kernel is the latest LTS, which ZFS always supports
    loader = {
      # Don't enable EFI, Hetzner still uses legacy boot
      # I think I could get it to work but wehhh
      grub = {
        enable = true;
        zfsSupport = true;
        # No need to set devices, disko will do it for us
        # since we have an EF02 partition
      };
    };

    tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
      ];
      allowedUDPPorts = [];
    };
  };

  time.timeZone = "Europe/Paris";

  # I want everything as the French format except the actual language,
  # because I'm French but I hate the French language.
  i18n = {
    defaultLocale = "en_GB.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "fr_FR.UTF-8";
      LC_IDENTIFICATION = "fr_FR.UTF-8";
      LC_MEASUREMENT = "fr_FR.UTF-8";
      LC_MONETARY = "fr_FR.UTF-8";
      LC_NAME = "fr_FR.UTF-8";
      LC_NUMERIC = "fr_FR.UTF-8";
      LC_PAPER = "fr_FR.UTF-8";
      LC_TELEPHONE = "fr_FR.UTF-8";
      LC_TIME = "fr_FR.UTF-8";
    };
  };

  services = {
    fstrim.enable = true;
    earlyoom = {
      enable = true;
      freeMemThreshold = 5; # 5% free memory
    };
  };

  users.users = {
    root = {
      # Prevent root login
      hashedPassword = "!";
      openssh.authorizedKeys.keys = config.users.users.jessew.openssh.authorizedKeys.keys;
    };

    jessew = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      description = "Jesse Wierzbinski";
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoDpeLv3ZiLr4T0RTFtpKtE66qEzMxuzk/BHA97YUEX contact@cpluspatch.com"
      ];
      hashedPassword = "$y$j9T$BpzyG1xwJplTgqYZndvU/1$F5LHlA9KNmPyTPviRDVgAuO2wedP95IyO8HPn502Lp2";
    };
  };

  system = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "24.11"; # Did you read the comment?
  };
}
