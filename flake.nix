{
  description = "Home manager configuration of";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors.url = "github:misterio77/nix-colors";
    xremap-flake.url = "github:xremap/nix-flake";
    rustc-nixpkgs.url = "github:nixos/nixpkgs/517501bcf14ae6ec47efd6a17dda0ca8e6d866f9"; # 1.72.0
    # nixpkgs-go_1_21.url = "github:tie/nixpkgs/go121-distpack";
  };

  outputs =
    { nixpkgs
    , home-manager
    , # , nix-colors
      ...
    } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."bg" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          # inherit nix-colors;
          inherit inputs;
        };
        modules = [ ./home.nix ];
      };
    };
}
