{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-23-11.url = "github:nixos/nixpkgs/nixos-23.11";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      # url = "github:nix-community/nixvim/nixos-24.05";
      url = "github:back2nix/nixvim";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    musnix = {
      url = "github:musnix/musnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ld-rs = {
      url = "github:nix-community/nix-ld-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # nur.url = "github:nix-community/NUR";

    # arion = {
    #   url = "github:hercules-ci/arion";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-master,
    nixpkgs-23-11,
    home-manager,
    sops-nix,
    # nur,
    # arion,
    ...
  } @ inputs: {
    lsFiles = path:
      map (f: "${path}/${f}") (
        builtins.filter (i: builtins.readFileType "${path}/${i}" == "regular") (
          builtins.attrNames (builtins.readDir path)
        )
      );
    nixosConfigurations = let
      system = "x86_64-linux";
      pkgs-master = import inputs.nixpkgs-master {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs-23-11 = import inputs.nixpkgs-23-11 {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit self inputs pkgs-master pkgs-unstable pkgs-23-11;
        };
        modules = [
          ./module/spoofdpi.nix
          inputs.musnix.nixosModules.musnix
          sops-nix.nixosModules.sops
          # ./module/xray/default.nix
          # arion.nixosModules.arion
          ./configuration.nix
          # (import ./overlays)
          # {nixpkgs.overlays = [nur.overlay];}
          # ({pkgs, ...}: let
          #   nur-no-pkgs = import nur {
          #     nurpkgs = import nixpkgs {system = "x86_64-linux";};
          #   };
          # in {
          #   imports = [nur-no-pkgs.repos.iopq.modules.xraya];
          #   services.xraya.enable = true;
          # })

          {
            imports = self.lsFiles ./overlays;
          }

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              extraSpecialArgs = {
                inherit self inputs pkgs-master pkgs-unstable pkgs-23-11;
              };

              useGlobalPkgs = true;
              useUserPackages = true;
              users."bg" = import ./module/users/bg/home.nix; # CHANGE ME
            };
          }
        ];
      };
    };
  };
}
