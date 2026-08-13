{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    colmena.url = "github:zhaofengli/colmena";
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
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bitchbot = {
      url = "github:CPlusPatch/jesses-vengeance";
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
    versia-server,
    home-manager,
    nix-minecraft,
    versia-fe,
    colmena,
    ...
  } @ inputs: {
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [
            nix-minecraft.overlay
            versia-server.overlays.default
            versia-fe.overlays.default
            bitchbot.overlays.default
          ];
        };

        specialArgs = {inherit inputs;};
      };

      faithplate = {
        deployment = {
          targetHost = "faithplate.infra.cpluspatch.com";
          tags = ["infra"];
        };

        imports = [
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          simple-nixos-mailserver.nixosModules.default
          nix-minecraft.nixosModules.minecraft-servers
          versia-server.nixosModules.versia-server
          home-manager.nixosModules.home-manager
          ./nix/hosts/base
          ./nix/features/partitions/single-zfs.nix
          ./nix/hosts/faithplate
        ];
      };

      freeman = {
        deployment = {
          targetHost = "freeman.infra.cpluspatch.com";
          tags = ["infra"];
        };

        imports = [
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          ./nix/hosts/base
          ./nix/features/partitions/single-zfs.nix
          ./nix/hosts/freeman
        ];
      };

      eli = {
        deployment = {
          targetHost = "eli.infra.cpluspatch.com";
          tags = ["infra"];
        };

        imports = [
          lix-module.nixosModules.lixFromNixpkgs
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          nix-minecraft.nixosModules.minecraft-servers
          home-manager.nixosModules.home-manager
          ./nix/hosts/base
          ./nix/features/partitions/single-zfs.nix
          ./nix/hosts/eli
        ];
      };
    };

    devShells = let
      pkgs = import nixpkgs { inherit system; };
      system = "x86_64-linux";
    in {
      x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          colmena.packages.x86_64-linux.colmena
          pkgs.nixd
          pkgs.sops
        ];
      };
    };
  };
}
