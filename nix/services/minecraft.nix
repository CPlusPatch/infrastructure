{
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs.nix-minecraft.lib) collectFilesAt;
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/CPlusPatch/camaradcraft/raw/60340cf298d1b2c5c0e56846ca92d5a3cefc07da/pack.toml";
    packHash = "sha256-ZTOXti8v5Oy0G2JjL0b1aeuvgmz22kATc+zsHJWZQCY=";
  };
  serverIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/CPlusPatch/camaradcraft/60340cf298d1b2c5c0e56846ca92d5a3cefc07da/server-icon.png";
    sha256 = "sha256-cAe4B0oJYdrGGs5rKOx1cQgsAbAW2h9p+PcMHTlo5Sw=";
  };
in {
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true;

    managementSystem.systemd-socket.enable = true;

    servers.camaradcraft = {
      enable = true;
      autoStart = true;

      symlinks =
        collectFilesAt modpack "mods";
      files =
        collectFilesAt modpack "config"
        // {
          "server-icon.png" = serverIcon;
        };

      package = pkgs.fabricServers.fabric-1_21_5;
      whitelist = {
        CPlusPatch = "ca8539a0-654d-48a8-8a01-32cfc94458ce";
      };
      jvmOpts = "";
      serverProperties = {
        server-port = 25565;
        allow-flight = true;
        difficulty = "hard";
        enforce-secure-profile = true;
        enforce-whitelist = true;
        max-players = 100;
        motd = "\\u00a7l \\u00a7c          \\u00a7k$$\\u00a76 Join now for \\u00a74\\u00a7lFREE ROBUX!\\u00a7c  \\u00a7k$$\\u00a7r\\n\\u00a7l  \\u00a7c               \\u00a7k$$\\u00a76 Obama is here too! \\u00a7c\\u00a7k$$";
        online-mode = true;
        pvp = true;
        spawn-protection = 0;
        white-list = true;
        enable-rcon = true;
        "rcon.port" = 10293;
        broadcast-rcon-to-ops = true;
        pause-when-empty-seconds = 0;
      };
    };
  };

  modules.haproxy.acls.minecraft-camaradcraft = ''
    acl is_camaradcraft hdr(host) -i camaradcraft.cpluspatch.com
    use_backend minecraft-camaradcraft-bluemap if is_camaradcraft
  '';

  modules.haproxy.backends.minecraft-camaradcraft-bluemap = ''
    backend minecraft-camaradcraft-bluemap
      server minecraft-camaradcraft-bluemap 127.0.0.1:8100
  '';

  security.acme.certs."camaradcraft.cpluspatch.com" = {};
}
