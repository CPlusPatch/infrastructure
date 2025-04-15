{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    bitchbot = {
      url = "github:CPlusPatch/jesses-vengeance";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    syncbot = {
      url = "github:CPlusPatch/syncbot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    versia-server = {
      url = "github:versia-pub/server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    versia-fe = {
      url = "github:versia-pub/frontend";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    lix-module,
    disko,
    sops-nix,
    simple-nixos-mailserver,
    bitchbot,
    syncbot,
    versia-server,
    nix-minecraft,
    versia-fe,
    ...
  } @ inputs: {
    nixosConfigurations = {
      faithplate = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        modules = [
          {
            nixpkgs.overlays = [nix-minecraft.overlay versia-server.overlays.default versia-fe.overlays.default];
          }
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          simple-nixos-mailserver.nixosModule
          nix-minecraft.nixosModules.minecraft-servers
          bitchbot.nixosModules.${system}.bitchbot
          syncbot.nixosModules.${system}.syncbot
          ./nix/machines/base
          ./nix/partitions/single-zfs.nix
          ./nix/machines/faithplate
          versia-server.nixosModules.versia-server
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

      eli = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          nix-minecraft.nixosModules.minecraft-servers
          {
            nixpkgs.overlays = [nix-minecraft.overlay];
          }
          ./nix/machines/base
          ./nix/partitions/single-zfs.nix
          ./nix/machines/eli
        ];

        specialArgs = {
          inherit inputs;
        };
      };
    };
  };
}
