{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [../../home-manager ../../features/sops.nix];

  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["flakes" "nix-command"];
      allowed-users = ["@wheel"];
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "admin+acme@cpluspatch.com";
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  boot = {
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    loader = {
      # Don't enable EFI, Hetzner still uses legacy boot
      # I think I could get it to work but wehhh
      grub = {
        enable = true;
        zfsSupport = true;
        # No need to set devices, disko will do it for us
        # since we have an EF02 partition
      };
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };
  };

  networking = {
    networkmanager.enable = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22 # SSH
        80 # HTTP
        443 # HTTPS
        25 # SMTP
        465 # SMTP over SSL
        587 # SMTP submission
        993 # IMAP over SSL
      ];
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

  # yo dawg, I heard you like RAM, so I put some RAM in your RAM so you can RAM while you RAM
  zramSwap = {enable = true;};

  hardware = {
    enableRedistributableFirmware = true;
  };

  security.rtkit.enable = true;
  services = {
    fstrim.enable = true;
    earlyoom = {
      enable = true;
      freeMemThreshold = 5; # 5% free memory
    };
  };

  systemd.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';

  environment = {
    pathsToLink = ["/share/zsh"];
    # Makes ghostty and kitty work
    enableAllTerminfo = true;
  };

  programs.zsh.enable = true;

  users.users = {
    root = {
      # Prevent root login
      hashedPassword = "!";
      openssh.authorizedKeys.keys = config.users.users.jessew.openssh.authorizedKeys.keys;
    };

    jessew = {
      isNormalUser = true;
      extraGroups = ["networkmanager" "wheel"];
      description = "Jesse Wierzbinski";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoDpeLv3ZiLr4T0RTFtpKtE66qEzMxuzk/BHA97YUEX contact@cpluspatch.com"
      ];
      hashedPassword = "$y$j9T$BpzyG1xwJplTgqYZndvU/1$F5LHlA9KNmPyTPviRDVgAuO2wedP95IyO8HPn502Lp2";
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    # Enable IPv6 :)
    daemon.settings = {
      fixed-cidr-v6 = "fd00::/80";
      ipv6 = true;
    };
  };

  # Ban all the things!
  services.fail2ban = {
    enable = true;
    maxretry = 5;
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
