{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
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
  # Substituted into server files (@VARNAME@) by nix-minecraft
  sops.templates."minecraft.env" = {
    content = ''
      RCON_PASSWORD=${config.sops.placeholder."minecraft/rcon_password"}
    '';
    owner = config.services.minecraft-servers.user;
  };

  services.minecraft-servers = {
    enable = true;
    eula = true;

    environmentFile = config.sops.templates."minecraft.env".path;

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
      # 5 GiB leaves ~2 GiB for the system on this 8 GiB host. G1 with Aikar's flags, see
      # https://docs.papermc.io/paper/aikars-flags: ZGC needs spare heap and maps it as shared
      # memory that the kernel can't reclaim
      jvmOpts = lib.concatStringsSep " " [
        "-Djava.net.preferIPv6Addresses=true"
        "-Xms5G"
        "-Xmx5G"
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
      ];

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
        "rcon.password" = "@RCON_PASSWORD@";
        broadcast-rcon-to-ops = true;
        enable-command-block = true;
        # Don't wait for each chunk write to reach the disk, which stutters during saves
        sync-chunk-writes = false;
      };
    };
  };

  services.backups.jobs.minecraft.source = "/srv/minecraft";
}
