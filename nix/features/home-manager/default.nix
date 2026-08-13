{...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jessew = {...}: {imports = [./home.nix];};
  };
}
