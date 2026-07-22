{pkgs, ...}: {
  programs.fish = {
    enable = true;

    plugins = with pkgs.fishPlugins; [
      { name = "tide"; src = tide.src; }
    ];

    shellAliases = {
      cat = "bat --plain";
      docker-up = "docker-compose up -d";
      docker-down = "docker-compose down";
    };
  };
}
