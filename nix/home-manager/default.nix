{ inputs, ... }: {
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jessew = { ... }: { imports = [ ./home.nix ]; };
    extraSpecialArgs = { inherit inputs; };
  };
}
