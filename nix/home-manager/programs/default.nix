{
  imports = [./zsh.nix];

  programs = {
    home-manager.enable = true;
    eza = {
      enable = true;
      enableZshIntegration = true;
    };
    gh.enable = true;
    micro.enable = true;
  };
}
