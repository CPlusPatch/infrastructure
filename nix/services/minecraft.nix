{
  pkgs,
  inputs,
  ...
}: let
  inherit (inputs.nix-minecraft.lib) collectFilesAt;
  commit = "03166631d9f5efd4ca059a75a47297f364303015";
  modpack = pkgs.fetchPackwizModpack {
    url = "https://github.com/CPlusPatch/dumber-server/raw/${commit}/pack.toml";
    packHash = "sha256-MhQal9WM8bjj/ehgqRDiyXcVarwDPXeub+uf6H9WGT8=";
  };
  serverIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/CPlusPatch/dumber-server/${commit}/icon.png";
    sha256 = "sha256-9JQmsN6LxCibmrnWxRwntpa+AOBGkduqUkuUviYC+OI=";
  };
in {
  imports = [
    ../modules/backups.nix
  ];

  services.minecraft-servers = {
    enable = true;
    eula = true;

    managementSystem.systemd-socket.enable = true;

    servers.dumber-server = {
      enable = true;
      autoStart = true;

      symlinks = removeAttrs (collectFilesAt modpack "mods") [
        # "mods/DistantHorizons-2.3.3-b-1.21.7-fabric-neoforge.jar"
        "mods/Chunky-Fabric-1.4.40.jar"
      ];
      files =
        /*
           collectFilesAt modpack "config"
        //
        */
        {
          "server-icon.png" = serverIcon;
        };

      package = pkgs.fabricServers.fabric-1_21_8;
      jvmOpts = "-Djava.net.preferIPV4stack=false -Djava.net.preferIPv6Addresses=true -Xms6G -Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseShenandoahGC -XX:ShenandoahGCMode=iu -XX:+UseNUMA -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -Dfile.encoding=UTF-8";
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
        level-seed = 878234104968078356;
        enable-rcon = true;
        "rcon.port" = 10000;
        "rcon.password" = "test";
        broadcast-rcon-to-ops = true;
        pause-when-empty-seconds = 0;
        enable-command-block = true;
      };
    };
  };

  services.backups.jobs.minecraft.source = "/srv/minecraft/dumber-server";
}
