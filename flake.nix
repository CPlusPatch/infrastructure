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
    ...
  } @ inputs: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          config = {
            allowUnfree = true;
          };
        };

        specialArgs = {
          # Fixes some weird recursion errors
          # Passes inputs to all modules
          inherit inputs;
        };
      };

      # Also see the non-Flakes hive.nix example above.
      defaults = {pkgs, ...}: {
        imports = [
          lix-module.nixosModules.default
          ./nix/machines/base
        ];
      };

      test1 = {
        deployment = {
          targetHost = "test1.infra.cpluspatch.com";
        };

        imports = [
          ./nix/machines/test1
        ];
      };
    };
  };
}
