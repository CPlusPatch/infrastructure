{pkgs, ...}: {
  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers.fabric = {
      enable = true;
      autoStart = true;

      package = pkgs.fabricServers.fabric-1_21_1;
      whitelist = {
        CPlusPatch = "ca8539a0-654d-48a8-8a01-32cfc94458ce";
      };
      serverProperties = {
        server-port = 29372;
        allow-flight = true;
        difficulty = "hard";
        enforce-secure-profile = true;
        enforce-whitelist = true;
        max-players = 100;
        motd = "\u00a7l \u00a7c          \u00a7k$$\u00a76 Join now for \u00a74\u00a7lFREE ROBUX!\u00a7c  \u00a7k$$\u00a7r\n\u00a7l  \u00a7c               \u00a7k$$\u00a76 Obama is here too! \u00a7c\u00a7k$$";
        online-mode = true;
        pvp = true;
        spawn-protection = 0;
        white-list = true;
      };
    };
  };

  modules.haproxy.frontends.minecraft-fabric = ''
    frontend minecraft-fabric
      bind :::25565 v4v6
      mode tcp
      option tcplog
      default_backend minecraft-fabric
  '';

  modules.haproxy.backends.minecraft-fabric = ''
    backend minecraft-fabric
      mode tcp
      option tcplog
      server server1 127.0.0.1:29372
  '';
}
