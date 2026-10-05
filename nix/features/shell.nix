# My login shell: fish with the tide prompt
{pkgs, ...}: {
  programs.fish = {
    enable = true;

    shellAliases = {
      cat = "bat --plain";
      docker-up = "docker-compose up -d";
      docker-down = "docker-compose down";
      ls = "eza";
      ll = "eza -l";
      la = "eza -a";
      lt = "eza --tree";
      lla = "eza -la";
    };
  };

  # fish loads plugins from installed packages' vendor directories
  environment.systemPackages = [pkgs.fishPlugins.tide];
}
