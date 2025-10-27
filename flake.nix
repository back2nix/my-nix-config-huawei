{
  description = "A multi-device NixOS flake with flake-parts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-23-11.url = "github:nixos/nixpkgs/nixos-23.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

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

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    replacer = {
      url = "github:back2nix/replacer";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mutter-src = {
      # url = "path:./mutter";
      type = "git";
      url = "https://github.com/back2nix/mutter.git";
      ref = "zero";
      rev = "95390dd6c612747941aeac44c7a131ab9aff0f55";
      flake = false;
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      # Указываем системы, которые поддерживаем
      systems = ["x86_64-linux"];

      # Импортируем модули flake-parts (если будут)
      imports = [
        # Здесь можно импортировать дополнительные модули
        # ./parts/packages.nix
        # ./parts/overlays.nix
      ];

      # perSystem - для вещей, специфичных для каждой системы
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        # Создаём дополнительные pkgs для unstable/master/23.11
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
        # Здесь можно определить packages, devShells и т.д. для каждой системы
        # packages.default = pkgs.hello;
        # devShells.default = pkgs.mkShell { ... };

        # Можно добавить форматтер
        # formatter = pkgs.alejandra;
      };

      # flake - для системно-независимых вещей
      flake = let
        system = "x86_64-linux";

        # Создаём pkgs для использования в nixosConfigurations
        mkPkgs = nixpkgs: system:
          import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

        pkgs-master = mkPkgs inputs.nixpkgs-master system;
        pkgs-unstable = mkPkgs inputs.nixpkgs-unstable system;
        pkgs-23-11 = mkPkgs inputs.nixpkgs-23-11 system;

        # Общая функция для создания системы
        mkSystem = deviceName: extraModules:
          inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit
                inputs
                pkgs-master
                pkgs-unstable
                pkgs-23-11
                ;
              self = inputs.self;
            };
            modules =
              [
                inputs.nixos-hardware.nixosModules.lenovo-yoga-7-14ILL10
                inputs.musnix.nixosModules.musnix
                inputs.sops-nix.nixosModules.sops
                ./configuration.nix
                # --- НАЧАЛО ИЗМЕНЕНИЯ ---
                # Применяем наш оверлей с исправленным mutter
                ./overlays/default.nix
                # --- КОНЕЦ ИЗМЕНЕНИЯ ---

                # Home Manager
                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager = {
                    extraSpecialArgs = {
                      inherit
                        inputs
                        pkgs-master
                        pkgs-unstable
                        pkgs-23-11
                        ;
                      self = inputs.self;
                    };
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    users."bg" = import ./module/users/bg/home.nix;
                  };
                }

                # Конфигурация конкретного устройства
                ./devices/${deviceName}
              ]
              ++ extraModules;
          };
      in {
        # NixOS конфигурации
        nixosConfigurations = {
          asus = mkSystem "asus-ux3405m" [];
          huawei = mkSystem "huawei-rlef-x" [];
          yoga14 = mkSystem "yoga14" [];
          desktop = mkSystem "desktop" [];
        };

        # Можно также экспортировать модули для повторного использования
        # nixosModules.myModule = import ./modules/my-module.nix;

        # Или оверлеи
        # overlays.default = final: prev: { ... };
      };
    };
}
