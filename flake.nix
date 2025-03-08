{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    lix-module,
    disko,
    ...
  } @ inputs: {
    nixosConfigurations = {
      test4 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lix-module.nixosModules.default
          disko.nixosModules.disko
          ./nix/machines/base
          ./nix/partitions/single-zfs.nix
          ./nix/machines/test4
        ];

        # This is needed otherwise you get recursion errors
        # because the nixosConfigurations attribute set is
        # being used in the nixosSystem function
        specialArgs = {
          inherit inputs;
        };
      };
    };
  };
}
