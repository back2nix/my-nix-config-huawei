{ config
, pkgs
, inputs
, lib
, ...
}:
let
  user = "bg";
in
{
  imports = [
    # inputs.nix-colors.homeManagerModules.default
    # inputs.xremap-flake.homeManagerModules.default
  ];

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

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "${user}";
  home.homeDirectory = "/home/${user}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  programs.direnv.enable = true;

  # my-yandex-browser =

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

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
    fzf
    multipass
    telegram-desktop
    keepassxc
    docker-compose
    proxychains
    # arion
    deadnix
    rnix-lsp
    unzip
    cargo
    luarocks
    screenkey
    wshowkeys
    gnome-frog
    alejandra
    niv
    distrobox
    dconf
    # inputs.xremap-flake.packages.${system}.default
    # libnotify
    tree
    nix-template
    python3
    marksman
    encfs
    difftastic
    bat
    tokei
    android-tools
    patchelf
    # my-yandex-browser
    # (pkgs.callPackage ./yandex-browser.nix { })
    # gnome.gnome-terminal
  ];

  # nixpkgs.config.allowUnfreePredicate = pkg:
  #   builtins.elem (lib.getName pkg) [
  #     "yandex-browser"
  #   ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ".tmux.conf".source = ./tmux/tmux.conf;

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

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/bg/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  #environment.systemPackages = [ pkgs.neovim ];

  programs.neovim = {
    enable = true;
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
  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initExtra =
      ''
        # >>> mamba initialize >>>
        # !! Contents within this block are managed by 'mamba init' !!
        # export MAMBA_EXE="/nix/store/9dkj1d9xa3dn3yf8dx1h61z0cp3j6832-micromamba-1.2.0/bin/micromamba";
        # export MAMBA_ROOT_PREFIX="/home/bg/micromamba";
        # __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
        # if [ $? -eq 0 ]; then
        #     eval "$__mamba_setup"
        # else
        #     if [ -f "/home/bg/micromamba/etc/profile.d/micromamba.sh" ]; then
        #         . "/home/bg/micromamba/etc/profile.d/micromamba.sh"
        #     else
        #         export  PATH="/home/bg/micromamba/bin:$PATH"  # extra space after export prevents interference from conda init
        #     fi
        # fi
        # unset __mamba_setup
        # <<< mamba initialize <<<

        DIRSTACKFILE="$HOME/.dirs"
        if [[ -f $DIRSTACKFILE ]] && [[ $#dirstack -eq 0 ]]; then
            dirstack=( $''
      + ''        {(f)"$(< $DIRSTACKFILE)"} )
            [[ -d $dirstack[1] ]] && cd $dirstack[1]
        fi
        chpwd() {
            print -l $PWD $''
      + ''        {(u)dirstack} >$DIRSTACKFILE
        }

        DIRSTACKSIZE=90
        setopt autopushd pushdsilent pushdtohome
        ## Remove duplicate entries
        setopt pushdignoredups
        ## This reverts the +/- operators.
        setopt pushdminus

        export XDG_DATA_DIRS=$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share
      '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "web-search"
        "extract"
        "adb"
        "sudo"
        "systemd"
      ];
      custom = "$HOME/.config/home-manager";
      theme = "agnoster-nix";
    };
    shellAliases = {
      ll = "ls -l";
      ch = "stat --format '%a'";
      cdgo = "cd ~/Documents/code/github.com/back2nix";
      cdnix = "cd ~/Documents/code/github.com/back2nix/nix/my-nix-config-huawei";
      cdinfo = "cd ~/Documents/code/github.com/back2nix/info";
      clip = "head -c -1|xclip -i -selection clipboard";
      rd = "readlink -f";
      update = "sudo nixos-rebuild switch";
      hupdate = "home-manager switch";
      # https://github.com/name-snrl/nixos-configuration/blob/master/modules/home/aliases.nix
      ip = "ip --color=auto";
      dt = "difft";
      bcat = "bat --pager=never --style=changes,rule,numbers,snip";
      tk = "tokei";
      sctl = "systemctl";
      sudo = "sudo ";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    plugins = [
      {
        # will source zsh-autosuggestions.plugin.zsh
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.4.0";
          sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
        };
      }
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.5.0";
          sha256 = "0za4aiwwrlawnia4f29msk822rj9bgcygw6a8a6iikiwzjjz0g91";
        };
      }
    ];
  };

  programs.git = {
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
    difftastic = {
      enable = true;
    };
    # extraConfig = {
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

  # xdg.mimeApps.defaultApplications = {
  #   "text/palin" = ["nvim"];
  #   "video/png" = ["mvp.destop"];
  #   "video/*" = ["mvp.destop"];
  # };
}
