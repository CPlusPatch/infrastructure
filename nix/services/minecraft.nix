{
  pkgs,
  inputs,
  lib,
  ...
}: let
  modpack = pkgs.fetchModrinthModpack {
    src = ../../assets/jerver21.mrpack;
    packHash = "sha256-nKH8P05hfzgUmCOcrREJ+B7ElAT0yEmfF6zqFb99W0Q=";
    side = "server";
  };
  excludedMods = [
    "statuseffectbars-1.21.1-NeoForge-1.0.2.jar"
    "bocchud-0.4.1+mc1.21.1.jar"
  ];
in {
  imports = [
    ../modules/backups.nix
  ];

  services.minecraft-servers = {
    enable = true;
    eula = true;

    managementSystem.systemd-socket.enable = true;

    servers.jerver2 = {
      enable = true;
      autoStart = true;

      symlinks =
        # Exclude mods that cause crashes on startup
        lib.filterAttrs (name: path: !(lib.elem name (map (x: "mods/${x}") excludedMods))) (inputs.nix-minecraft.lib.collectFilesAt modpack "mods");

      files = {
        "config" = "${modpack}/config";
        "server-icon.png" = "${../../assets/server-icon.png}";
      };

      package = pkgs.neoforgeServers.neoforge-1_21_1;
      jvmOpts = "-Djava.net.preferIPV4stack=false -Djava.net.preferIPv6Addresses=true -Xms6G -Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -Dfile.encoding=UTF-8";
      serverProperties = {
        server-port = 25565;
        allow-flight = true;
        difficulty = "easy";
        enforce-secure-profile = true;
        enforce-whitelist = true;
        max-players = 100;
        motd = "\\u00a7l \\u00a7c          \\u00a7k$$\\u00a76 Join now for \\u00a74\\u00a7lFREE ROBUX!\\u00a7c  \\u00a7k$$\\u00a7r\\n\\u00a7l  \\u00a7c               \\u00a7k$$\\u00a76 Obama is here too! \\u00a7c\\u00a7k$$";
        online-mode = true;
        pvp = true;
        spawn-protection = 0;
        white-list = true;
        level-seed = 6812872647578521762;
        enable-rcon = true;
        "rcon.port" = 10000;
        "rcon.password" = "test";
        broadcast-rcon-to-ops = true;
        pause-when-empty-seconds = 0;
        enable-command-block = true;
      };
    };
  };

  services.backups.jobs.minecraft.source = "/srv/minecraft/jerver2";
}
