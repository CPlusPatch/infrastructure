{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-bun12.url = "github:NixOS/nixpkgs/8f5ad84f711da68f7a5798905c533860b942f749";
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/release-2.93.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.url = "git+https://git.lix.systems/lix-project/lix";
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
    nixpkgs-bun12,
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
            nixpkgs.overlays = [
              nix-minecraft.overlay
              versia-server.overlays.default
              versia-fe.overlays.default
              bitchbot.overlays.default
              (final: prev: {
                # Keep Bun at 1.2 because 1.3 doesn't build for whatever stupid fuckass reason
                inherit (nixpkgs-bun12.legacyPackages.${prev.stdenv.hostPlatform.system}) bun;
              })
            ];
          }
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          simple-nixos-mailserver.nixosModule
          nix-minecraft.nixosModules.minecraft-servers
          syncbot.nixosModules.${system}.syncbot
          ./nix/hosts/base
          ./nix/features/partitions/single-zfs.nix
          ./nix/hosts/faithplate
          versia-server.nixosModules.versia-server
          bitchbot.nixosModules.bitchbot
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
          ./nix/hosts/base
          ./nix/features/partitions/single-zfs.nix
          ./nix/hosts/freeman
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
          ./nix/hosts/base
          ./nix/features/partitions/single-zfs.nix
          ./nix/hosts/eli
        ];

        specialArgs = {
          inherit inputs;
        };
      };
    };
  };
}
