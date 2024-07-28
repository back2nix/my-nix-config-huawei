{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-unstable,
  lib,
  ...
}: let
  inherit (import ../../../variables.nix) mainUser;
in {
  imports = [
    # inputs.nix-colors.homeManagerModules.default
    # inputs.xremap-flake.homeManagerModules.default
    # ./mime.nix
    # ./overlays.nix
    # inputs.nixvim.homeManagerModules.nixvim
    ./dconf.nix
    ./tmux/tmux.nix
    ./zsh/zsh.nix
    # ./zsh/zsh_zinit.nix
    # ./nixvim/nixvim.nix
    ./nixvim.nix
    # ./nixvim/plugins/spell.nix
    ./nix-tools.nix
    # inputs.nix-index-database.hmModules.nix-index
  ];

  # inputs.nixpkgs.overlays = [
  #   # (import (builtins.fetchTarball https://github.com/NixOS/nixpkgs/archive/master.tar.gz))
  #   (self: super: {
  #     # yandex-browser = self.callPackage ./overlays/yandex-browser.nix {};
  #     # genymotion = self.callPackage ./overlays/genymotion.nix {};
  #     bashdbInteractive = self.bashdb.overrideAttrs {
  #       buildInputs = (super.buildInputs or []) ++ [self.bashInteractive];
  #     };
  #     # neovim = masterPkg.neovim;
  #   })
  # ];

  xdg.configFile = {
    "kitty/kitty.conf".source = ./kitty.conf;
    "wal/templates/colorskitty.conf".source = ./pywalkittytemplate;
  };

  # services.xremap = {
  #   config = {
  #     keymap = [
  #       {
  #         name = "default map";
  #         remap = {
  #           super-d = {
  #             remap = {
  #               t = {
  #                 launch = [ "telegram-desktop" ];
  #               };
  #               g = {
  #                 launch = [ "google-chrome-stable" ];
  #               };
  #             };
  #           };
  #         };
  #       }
  #       {
  #         name = "speaker not terminal";
  #         # application = {
  #         #   not = [ "kgx" ];
  #         # };
  #         remap = {
  #           M-f = {
  #             remap = {
  #               p = {
  #                 launch = [ "curl" "http://localhost:3111/echo/L_CTRL+L_ALT+P" ];
  #               };
  #               c = {
  #                 launch = [ "curl" "http://localhost:3111/echo/L_CTRL+C" ];
  #               };
  #               f = {
  #                 launch = [ "curl" "http://localhost:3111/echo/L_ALT+F" ];
  #               };
  #               z = {
  #                 launch = [ "curl" "http://localhost:3111/echo/L_ALT+Z" ];
  #               };
  #             };
  #           };
  #         };
  #       }
  #     ];
  #   };
  # };

  # colorScheme = inputs.nix-colors.colorSchemes.dracula;

  home = {
    username = "${mainUser}";
    homeDirectory = "/home/${mainUser}";
    stateVersion = "23.11";
    packages = with pkgs; [
      # # Adds the 'hello' command to your environment. It prints a friendly
      # # "Hello, world!" when run.
      # pkgs.hello

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      (pkgs.nerdfonts.override {fonts = ["FiraCode" "DroidSansMono"];}) # "FantasqueSansMono"

      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')
      nodejs_18
      gcc
      xclip
      gnumake
      multipass
      pkgs-master.telegram-desktop
      keepassxc
      proxychains
      # arion
      deadnix
      # rnix-lsp
      # inputs.xremap-flake.packages.${system}.default
      # libnotify
      # git diff
      # diff-so-fancy
      # opera
      # zellij
      # firefox
      # QT_QPA_PLATFORM=xcb genymotion
      # wordpress6_4
      # virtualbox
      # curl-impersonate-chrome
      # microsoft-edge
      # my-yandex-browser
      # (pkgs.callPackage ./yandex-browser.nix { })
      # gnome.gnome-terminal
      unzip
      cargo
      luarocks
      screenkey
      wshowkeys
      # gnome-frog
      niv
      distrobox
      dconf
      tree
      nix-template
      marksman
      encfs
      bat
      tokei
      android-tools
      patchelf
      gtk3
      gnome3.adwaita-icon-theme
      devbox
      tig # diff and commit view
      file
      python310
      python310Packages.pygments
      duf # pretty monitoring memory device
      glow # terminal markdown viewer
      asciinema # record the terminal
      drawio # diagram design
      xmind # draw
      insomnia # rest client with graphql support
      sqlite
      gh-dash # github pull request
      hub # create pull request
      rm-improved
      pcmanfm
      pkgs-master.google-chrome
      gnome.eog # image viewer
      evince # pdf reader
      zoom-us
      gimp
      rawtherapee
      ffmpeg_5-full
      genymotion
      qemu
      firefox
      anydesk
      audacity
      # yandex-browser
      distrobox
      # zoxide

      # golang
      go_1_21
      go-outline
      gopls
      gopkgs
      go-tools
      delve
      # inputs.nixpkgs-unstable.mitmproxy
      gedit
      libreoffice
      gh
      # neovim
      # inputs.nixpkgs-unstable.neovim
      python311Packages.jupytext
      eza
      bashInteractive
      bashdbInteractive
      bash-completion
      nodejs_18
      lunarvim
      yazi
      blender
      lazydocker
      dive # A tool for exploring each layer in a docker image
      rnr # пакетное рекурсивное переименование
      difftastic # difft
      pkgs-master.serpl # replacy like a vscode
      pkgs-master.golangci-lint
      pkgs-master.golangci-lint-langserver
      kondo # delete depedenc
      hyperfine # замер времени запуска
      btop
      inkscape-with-extensions
      pkgs-master.devenv
      # bottles # Wine Easy-to-use wineprefix manager
      gomodifytags
      simplescreenrecorder
    ];

    file = {
      # # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;

      # ".tmux.conf".source = ./tmux/tmux.conf;
      ".gitconfig".source = ./gitconfig.txt;
      ".cargo/config".source = ./cargoconfig.txt;
      ".gdbinit".source = ./gdbinit.txt;
      ".gdbinit.d/init".source = ./gdbinit.d_init.txt;
      # ".config/zellij/config.kdl".source = ./zellij;

      # ".tmux.conf" = {
      #   text = builtins.readFile ./tmux/tmux.conf;
      # };

      #".config/nvim/init.lua" = {
      #  text = (builtins.readFile ./init.lua);
      #};

      # # You can also set the file content immediately.
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };
    sessionVariables = {
      EDITOR = "nvim";
      GTK_THEME = "Adwaita:dark";
    };
  };

  nixpkgs.config = {
    permittedInsecurePackages = [
      "curl-impersonate-chrome-0.5.4"
    ];

    allowUnfree = true;

    allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        # "opera"
        "google-chrome"
        "zoom"
        "xmind"
        "genymotion"
        "anydesk"
        # "yandex-browser-stable-24.4.1.915-1"
        # "yandex-browser"
        # "microsoft-edge-stable"
      ];
  };

  programs = {
    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };

    jq.enable = true;

    fzf = {
      enable = true;
      enableZshIntegration = true;
      tmux.enableShellIntegration = true;
    };

    lazygit.enable = config.programs.git.enable;
    thefuck.enable = true;
    # bash.enable = true;
    # bash.package = pkgs.bashInteractive;

    neovim = {
      enable = false;
      defaultEditor = true;
      plugins = with pkgs.vimPlugins; [
        # ...
      ];
      # extraConfig = builtins.readFile ./config/init.vim;
      # extraConfig = ''
      #  set number relativenumber
      #  '';
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    git = {
      enable = true;
      userName = "back2nix";
      userEmail = "back2nix@list.ru";
      aliases = {
        pu = "push";
        co = "checkout";
        cm = "commit";
        # dt = "diff";
        lg = "log --stat";
      };
      # difftastic.enable = true; # git diff
      # delta.enable = true; # git diff

      # extraConfig = {
      #   core = {
      #     pager = "diff-so-fancy | less --tabs=4 -RFX";
      #   };
      # };

      # iniContent = {
      #   init.defaultBranch = "main";
      #   url = {
      #     "git@github.com:".pushInsteadOf = "https://github.com/";
      #     "git@gist.github.com:".pushInsteadOf = "https://gist.github.com/";
      #   };
      #   pager.difftool = true;
      #
      #   diff = {
      #     tool = "difftastic";
      #   };
      #
      #   difftool = {
      #     prompt = false;
      #     "difftastic".cmd = ''difft "$LOCAL" "$REMOTE"'';
      #   };
      # };
    };

    chromium.extensions = [
      "padekgcemlokbadohgkifijomclgjgif" # https://chromewebstore.google.com/detail/proxy-switchyomega/padekgcemlokbadohgkifijomclgjgif
    ];
  };

  xdg.mimeApps.defaultApplications = {
    "text/palin" = ["nvim"];
    "video/png" = ["mvp.desktop"];
    "video/*" = ["mvp.desktop"];
    "application/pdf" = ["evince"];
    "application/x-bzpdf" = ["evince"];
    "application/x-ext-pdf" = ["evince"];
    "application/x-gzpdf" = ["evince"];
    "application/x-xzpdf" = ["evince"];
  };
}
