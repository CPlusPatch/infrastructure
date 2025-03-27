{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-synapse127.url = "github:NixOS/nixpkgs/02588b5ff18d8c1b572d406a52fe86e62fd6a1d9";
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0-1.tar.gz";
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    lix-module,
    disko,
    sops-nix,
    simple-nixos-mailserver,
    ...
  } @ inputs: {
    nixosConfigurations = {
      faithplate = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          simple-nixos-mailserver.nixosModule
          ./nix/machines/base
          ./nix/partitions/single-zfs.nix
          ./nix/machines/faithplate
        ];

        # This is needed otherwise you get recursion errors
        # because the nixosConfigurations attribute set is
        # being used in the nixosSystem function
        specialArgs = {
          inherit inputs;
        };
      };

      freeman = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./nix/machines/base
          ./nix/partitions/single-zfs.nix
          ./nix/machines/freeman
        ];

        specialArgs = {
          inherit inputs;
        };
      };
    };
  };
}
