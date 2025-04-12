{
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs.nix-minecraft.lib) collectFilesAt;
  commit = "c380348d98ff3f76b7d1b36cbccf900ed28391a4";
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/CPlusPatch/cpluscraft/raw/${commit}/pack.toml";
    packHash = "sha256-n8NWITV86yXTN2cfvg7/nZAkDjBYbLL77JaAxh/r2G4=";
  };
  serverIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/CPlusPatch/cpluscraft/${commit}/server-icon.png";
    sha256 = "sha256-xwHTw7A6CtjCKVNEi/OIMll9BQlIm0ijNYNI+1urS6g=";
  };
in {
  services.minecraft-servers = {
    enable = true;
    eula = true;

    managementSystem.systemd-socket.enable = true;

    servers.cpluscraft = {
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
      jvmOpts = "-Djava.net.preferIPV4stack=false -Djava.net.preferIPv6Addresses=true -Xms3G -Xmx3G -XX:+UnlockExperimentalVMOptions -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -Dfile.encoding=UTF-8";
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
        "rcon.password" = "test";
        broadcast-rcon-to-ops = true;
        pause-when-empty-seconds = 0;
      };
    };
  };
}
