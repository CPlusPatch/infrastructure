{
  imports = [./fish.nix];

  programs = {
    home-manager.enable = true;
    eza.enable = true;
    gh.enable = true;
    micro.enable = true;
  };
}
