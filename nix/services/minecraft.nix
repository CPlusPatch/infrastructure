{
  pkgs,
  inputs,
  lib,
  ...
}: let
  modpack = pkgs.fetchModrinthModpack {
    src = ../../assets/Jerver2.1.mrpack;
    packHash = "sha256-2KrxD6gU0JYtu3rOE9R7yYxU0lxkV6XwsTp8mKeDBXY=";
    side = "server";
  };
  creativeModpack = pkgs.fetchModrinthModpack {
    src = ../../assets/Jerver2-creative.mrpack;
    packHash = "sha256-xF8tqXEqGhU6Rj9Mh3wtK6r/kGbBnW0OqYvc2L3PD+4=";
    side = "server";
  };
  wikiModpack = pkgs.fetchModrinthModpack {
    src = ../../assets/Yuri-Aero.mrpack;
    packHash = "sha256-qaUcmu3cGHIcTtsr3M1ptiP2F+x4fsLPNjhu7RrmXp8=";
    side = "server";
  };
  collectFilesAt = inputs.nix-minecraft.lib.collectFilesAt;
  excludedMods = [
    "statuseffectbars-1.21.1-NeoForge-1.0.2.jar"
    "bocchud-0.4.1+mc1.21.1.jar"
    "colorwheel-neoforge-1.2.7+mc1.21.1.jar"
    "continuity-3.0.0+0.0.1+1.21.1.neoforge-all.jar"
    "soundsbegone-neoforge-1.5.2+mc1.21.jar"
    "screenshotgallery-neoforge-2.0.jar"
    "createframed-1.21.1-1.8.2.jar"
    "bits_n_bobs-2.1.13-beta.jar"
  ];
  filterOutMods = mods: lib.filterAttrs (name: path: !(lib.elem name (map (x: "mods/${x}") excludedMods))) mods;
in {
  imports = [
    ../modules/backups.nix
  ];

  services.minecraft-servers = {
    enable = true;
    eula = true;

    managementSystem.systemd-socket.enable = true;

    servers.wiki = {
      enable = true;
      autoStart = true;

      files = {
        "server-icon.png" = "${../../assets/server-icon-wiki.png}";
      };

      # Using collectFilesAt prevents an issue with mods that try to edit the mods folder
      # # e.g. Sinytra Connector
      symlinks = filterOutMods (collectFilesAt wikiModpack "mods");

      package = pkgs.neoforgeServers.neoforge-1_21_1;
      jvmOpts = "-Djava.net.preferIPV4stack=false -Djava.net.preferIPv6Addresses=true -Xms6G -Xmx6G -XX:+UseZGC";

      serverProperties = {
        server-port = 25565;
        allow-flight = true;
        difficulty = "easy";
        enforce-secure-profile = false;
        enforce-whitelist = true;
        max-players = 64;
        motd = "\\u00a7dJeffrey Epstein's favourite server\\u00a7r\n\\u00a75Now with road rage!";
        online-mode = true;
        pvp = true;
        spawn-protection = 0;
        white-list = true;
        enable-rcon = true;
        "rcon.port" = 10003;
        "rcon.password" = "test";
        broadcast-rcon-to-ops = true;
        pause-when-empty-seconds = 0;
        enable-command-block = true;
      };
    };

    servers.jerver2 = {
      enable = false;
      autoStart = false;

      symlinks =
        # Exclude mods that cause crashes on startup
        filterOutMods (collectFilesAt modpack "mods");

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

    servers.jerver-creative = {
      enable = false;
      autoStart = false;

      symlinks =
        # Exclude mods that cause crashes on startup
        filterOutMods (collectFilesAt creativeModpack "mods");

      files = {
        "config" = "${creativeModpack}/config";
        "server-icon.png" = "${../../assets/server-icon.png}";
      };

      package = pkgs.neoforgeServers.neoforge-1_21_1;
      jvmOpts = "-Djava.net.preferIPV4stack=false -Djava.net.preferIPv6Addresses=true -Xms6G -Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -Dfile.encoding=UTF-8";
      serverProperties = {
        server-port = 25566;
        allow-flight = true;
        difficulty = "peaceful";
        enforce-secure-profile = true;
        enforce-whitelist = true;
        max-players = 100;
        motd = "ough ough im creating it";
        online-mode = true;
        pvp = true;
        spawn-protection = 0;
        white-list = true;
        enable-rcon = true;
        "rcon.port" = 10001;
        "rcon.password" = "test";
        broadcast-rcon-to-ops = true;
        pause-when-empty-seconds = 0;
        enable-command-block = true;
        level-type = "minecraft:flat";
        generate-structures = false;
        generator-settings = "{\"biome\":\"minecraft:plains\",\"layers\":[{\"block\":\"minecraft:bedrock\",\"height\":1},{\"block\":\"minecraft:stone\",\"height\":59},{\"block\":\"minecraft:dirt\",\"height\":3},{\"block\":\"minecraft:grass_block\",\"height\":1}]}";
      };
    };
  };

  services.backups.jobs.minecraft.source = "/srv/minecraft/jerver2";
}
