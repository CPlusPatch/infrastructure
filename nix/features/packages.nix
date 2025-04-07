{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    p7zip
    age
    file
    gnutar
    gping
    jq
    micro
    lftp
    linuxPackages_latest.perf
    lshw
    fastfetch
    magic-wormhole-rs
    nvd
    pciutils # For lspci
    unrar
    unzip
    usbutils # For lsusb
    wget
    btop
    curl
    eza
    which
  ];

  programs = {
    bat.enable = true;
    direnv.enable = true;
    git.enable = true;
    tmux = {
      enable = true;
      terminal = "xterm-256color";
      extraConfig = ''
        set -g mouse on
      '';
    };
  };
}
