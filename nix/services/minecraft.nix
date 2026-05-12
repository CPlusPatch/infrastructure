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

    servers.jerver-creative = {
      enable = true;
      autoStart = false;

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
