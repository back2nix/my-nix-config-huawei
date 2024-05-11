{ config
, pkgs
, inputs
, lib
, ...
}:
let
  user = "bg";
  # zellij = pkgs.callPackage ./zellij.nix {
  #   inherit (pkgs.darwin.apple_sdk.frameworks) DiskArbitration Foundation;
  # };
in
{
  imports = [
    # inputs.nix-colors.homeManagerModules.default
    # inputs.xremap-flake.homeManagerModules.default
    # ./mime.nix
    #./overlays.nix
    ./dconf.nix
  ];

  nixpkgs.overlays = [
    (self: super: {
      yandex-browser = self.callPackage ./overlays/yandex-browser.nix { };
      genymotion = self.callPackage ./overlays/genymotion.nix { };
    })
  ];

  xdg.configFile = {
    "kitty/kitty.conf".source = ./kitty.conf;
    "wal/templates/colorskitty.conf".source = ./pywalkittytemplate;
  };

  # services.lorri.enable = true;


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
  home.stateVersion = "23.11"; # Please read the comment before changing.

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
    (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

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
    telegram-desktop
    keepassxc
    docker-compose
    proxychains
    # arion
    deadnix
    # rnix-lsp
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
    marksman
    encfs
    difftastic
    bat
    tokei
    android-tools
    patchelf
    gtk3
    gnome3.adwaita-icon-theme
    devbox
    # git diff
    # diff-so-fancy
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
    # opera
    sqlite
    # zellij
    gh-dash # github pull request
    hub # create pull request
    rm-improved
    pcmanfm
    # firefox
    google-chrome
    gnome.eog # image viewer
    evince # pdf reader
    zoom-us
    gimp
    rawtherapee
    ffmpeg_5-full
    # QT_QPA_PLATFORM=xcb genymotion
    genymotion
    qemu
    firefox
    anydesk
    audacity
    yandex-browser
    distrobox
    zoxide
    # wordpress6_4
    # virtualbox
    # curl-impersonate-chrome
    # microsoft-edge
    # my-yandex-browser
    # (pkgs.callPackage ./yandex-browser.nix { })
    # gnome.gnome-terminal
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "curl-impersonate-chrome-0.5.4"
  ];

  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # "opera"
      "google-chrome"
      "zoom"
      "xmind"
      "genymotion"
      "anydesk"
      # "yandex-browser-stable-24.1.1.940-1"
      # "yandex-browser"
      # "microsoft-edge-stable"
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ".tmux.conf".source = ./tmux/tmux.conf;
    ".gitconfig".source = ./gitconfig;
    ".cargo/config".source = ./cargoconfig;
    ".gdbinit".source = ./gdbinit;
    ".gdbinit.d/init".source = ./gdbinit.d_init;
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
    GTK_THEME = "Adwaita:dark";
  };

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
        DIRSTACKSIZE=90
        setopt autopushd pushdsilent pushdtohome
        ## Remove duplicate entries
        setopt pushdignoredups
        ## This reverts the +/- operators.
        setopt pushdminus

        export XDG_DATA_DIRS=$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"

        eval "$(zoxide init zsh)" #
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
      custom = "/etc/nixos/module/users/bg";
      theme = "agnoster-nix";
    };
    shellAliases = {
      img = "eog"; # image viewer
      pdf = "evince"; # pdf reader
      cover = ''
        local t=$(mktemp)
          go test $COVERFLAGS -coverprofile=$t $@ \
          && go tool cover -func=$t \
          && unlink $t
      '';
      coverweb = ''
        local t=$(mktemp)
          go test $COVERFLAGS -coverprofile=$t $@ \
          && go tool cover -html=$t \
          && unlink $t
      '';
      ll = "ls -l";
      # z = "zellij";
      n = "nvim";
      rem2loc = ''
        function ssh-port() { 
                  local port=$((RANDOM % 60000 + 1024)); 
                  echo ssh -L "$port":localhost:$1 desktop -N;
                  echo http://localhost:"$port" or https://localhost:"$port"; 
                  ssh -L "$port":localhost:$1 desktop -N; 
                }; ssh-port'';
      rem2loc_norand = ''
        function ssh-port() { 
                  echo ssh -L "$2":localhost:$1 desktop -N;
                  echo http://localhost:"$2" or https://localhost:"$2"; 
                  ssh -L "$2":localhost:$1 desktop -N; 
                }; ssh-port'';
      sh = "stat --format '%a'";
      cdspeak = "cd ~/Documents/code/github.com/back2nix/speaker";
      cdgo = "cd ~/Documents/code/github.com/back2nix";
      st = "stat --format '%a'";
      fe = ''
        selected_file=$(rg --files ''${1:-.} | fzf)
        if [ -n "$selected_file" ]; then
         $EDITOR ''${selected_file%%:*}
        fi
      '';
      # Search content and Edit
      se = ''
        fileline=$(rg -n ''${1:-.} | fzf --preview 'bat -f `echo {} | cut -d ":" -f 1` -r `echo {} | cut -d ":" -f 2`:$((`echo {} | cut -d ":" -f 2`+150))' | awk '{print $1}' | sed 's/.$//')
        if [[ -n $fileline ]]; then
          $EDITOR ''${fileline%%:*} +''${fileline##*:}
        fi
      '';
      fl = ''git log --oneline --color=always | fzf --ansi --preview=" echo { } | cut - d ' ' - f 1 | xargs - I @ sh -c 'git log --pretty=medium -n 1 @; git diff @^ @' | bat --color=always" | cut -d ' ' -f 1 | xargs git log --pretty=short -n 1'';
      gd = "git diff --name-only --diff-filter=d $@ | xargs bat --diff";
      cdnix = "cd ~/Documents/code/github.com/back2nix/nix/my-nix-config-*";
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

  xdg.mimeApps.defaultApplications = {
    "text/palin" = [ "nvim" ];
    "video/png" = [ "mvp.destop" ];
    "video/*" = [ "mvp.destop" ];
    "application/pdf" = [ "evince" ];
    "application/x-bzpdf" = [ "evince" ];
    "application/x-ext-pdf" = [ "evince" ];
    "application/x-gzpdf" = [ "evince" ];
    "application/x-xzpdf" = [ "evince" ];
  };

  programs.chromium.extensions = [
    "padekgcemlokbadohgkifijomclgjgif" # https://chromewebstore.google.com/detail/proxy-switchyomega/padekgcemlokbadohgkifijomclgjgif
  ];
}
