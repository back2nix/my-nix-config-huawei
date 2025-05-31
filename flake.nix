{
  description = "A multi-device NixOS flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-23-11.url = "github:nixos/nixpkgs/nixos-23.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:back2nix/nixvim";
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
    # openvpn3-pr.url = "github:JarvisCraft/nixpkgs/openvpn3-v22_dev";
    replacer = {
      url = "github:back2nix/replacer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-master,
    nixpkgs-23-11,
    home-manager,
    sops-nix,
    replacer,
    # openvpn3-pr,
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
      mkSystem = deviceName: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              self
              inputs
              pkgs-master
              pkgs-unstable
              pkgs-23-11
              ;
          };
          modules =
            [
              # ./module/spoofdpi.nix
              # ./module/spoofdpi_with_proxy.nix
              inputs.nixos-hardware.nixosModules.lenovo-yoga-7-14ILL10
              inputs.musnix.nixosModules.musnix
              sops-nix.nixosModules.sops
              ./configuration.nix
              {
                imports = self.lsFiles ./overlays;
              }
              (
                {pkgs, ...}: {
                  nixpkgs.overlays = [
                    (final: prev: {
                      # openvpn3 = openvpn3-pr.legacyPackages.${system}.openvpn3;
                    })
                  ];
                }
              )
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  extraSpecialArgs = {
                    inherit
                      self
                      inputs
                      pkgs-master
                      pkgs-unstable
                      pkgs-23-11
                      ;
                  };
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users."bg" = import ./module/users/bg/home.nix;
                };
              }
              ./devices/${deviceName}
            ]
            ++ extraModules;
        };
    in {
      asus = mkSystem "asus-ux3405m" [];
      huawei = mkSystem "huawei-rlef-x" [];
      yoga14 = mkSystem "yoga14" []; # lenovo yoga14 ILL10
    };
  };
}
