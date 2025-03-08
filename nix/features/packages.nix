{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    p7zip
    age
    asciinema
    ffmpeg-full
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
    resources
    restic
    unrar
    unzip
    usbutils # For lsusb
    vhs
    warp
    wget
    btop
    eza
    which
  ];

  programs = {
    bat.enable = true;
    direnv.enable = true;
    git.enable = true;
  };
}
