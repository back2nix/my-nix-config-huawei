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
    ./chrome-ssl-keylog.nix
    ./chrome-mcp.nix
    ./chrome-debug.nix
    ./dconf.nix
    ./tmux/tmux.nix
    # ./zsh/zsh.nix
    ./fish/fish.nix
    ./nixvim.nix
    ./nix-tools.nix
    ./mimeapps.nix
  ];

  programs.chrome-with-ssl-keylog = {
    enable = true;
    keylogFile = "/tmp/sslkeylog.txt";
  };

  programs.chrome-mcp = {
    enable = true;
  };

  programs.chrome-debug = {
    enable = true;
  };

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

    # --- Разрешён только *-china запуск claude / gemini ---
    # Единственные допустимые команды — claude-code-china и gemini-china
    # (ставятся в configuration.nix, ходят через China proxy). Любые другие
    # точки запуска должны отсутствовать:
    #   * нативный установщик Claude Code кладёт ~/.local/bin/claude ->
    #     ~/.local/share/claude/versions/*, который ходит в сеть НАПРЯМУЮ;
    #   * ~/.local/bin в PATH стоит раньше /run/current-system/sw/bin, поэтому
    #     любой бинарь оттуда перекрыл бы china-обёртки.
    # На каждом home-manager switch вычищаем нативную установку и generic-имена
    # claude/claude-code/gemini из ~/.local/bin, ничего взамен не создаём.
    activation.enforceAiChinaOnly = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run rm -rf $VERBOSE_ARG "$HOME/.local/share/claude"
      run rm -f $VERBOSE_ARG \
        "$HOME/.local/bin/claude" \
        "$HOME/.local/bin/claude-code" \
        "$HOME/.local/bin/gemini"
    '';

    packages = with pkgs; [
      # # Adds the 'hello' command to your environment. It prints a friendly
      # # "Hello, world!" when run.
      # pkgs.hello

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.droid-sans-mono

      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')
      gcc
      xclip
      gnumake
      # multipass
      pkgs-unstable.telegram-desktop
      # telegram-desktop
      keepassxc
      proxychains
      # arion
      deadnix
      # rnix-lsp
      # inputs.xremap-flake.packages.${stdenv.hostPlatform.system}.default
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
      adwaita-icon-theme
      devbox
      tig # diff and commit view
      file
      python3
      # python313
      # python313Packages.pygments
      duf # pretty monitoring memory device
      glow # terminal markdown viewer
      asciinema # record the terminal
      # drawio # diagram design
      xmind # draw
      insomnia # rest client with graphql support
      sqlite
      gh-dash # github pull request
      hub # create pull request
      rm-improved
      pcmanfm
      # pkgs-master.google-chrome
      eog # image viewer
      evince # pdf reader
      zoom-us
      # GIMP forced onto XWayland: under native Wayland on GNOME the tablet path
      # drops the Wacom stylus tip-down event, so the pen only drew while a pen
      # button was held. GDK_BACKEND=x11 routes GIMP through XWayland, where the
      # tip maps to button 1 normally. Wraps gimp-3.0 (used by the .desktop too).
      (symlinkJoin {
        name = "gimp-x11";
        paths = [gimp];
        nativeBuildInputs = [makeWrapper];
        postBuild = ''
          for b in gimp-3.0 gimp-console-3.0; do
            rm -f "$out/bin/$b"
            makeWrapper "${gimp}/bin/$b" "$out/bin/$b" --set GDK_BACKEND x11
          done
          ln -sf gimp-3.0 "$out/bin/gimp"
          ln -sf gimp-3.0 "$out/bin/gimp-3"
          ln -sf gimp-console-3.0 "$out/bin/gimp-console"
          ln -sf gimp-console-3.0 "$out/bin/gimp-console-3"
        '';
      })
      pkgs-master.rawtherapee
      # ffmpeg_5-full
      ffmpeg-full
      # genymotion
      qemu
      firefox
      # anydesk
      audacity
      # yandex-browser
      distrobox
      # zoxide

      # golang
      pkgs-unstable.go
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
      # python311Packages.jupytext
      eza
      bashInteractive
      bashdbInteractive
      bash-completion
      # lunarvim удалён из nixpkgs (заброшен upstream)
      yazi
      blender
      lazydocker
      dive # A tool for exploring each layer in a docker image
      rnr # пакетное рекурсивное переименование
      difftastic # difft
      pkgs-master.serpl # replacy like a vscode
      # pkgs-master.golangci-lint
      # pkgs-master.golangci-lint-langserver
      kondo # delete depedenc
      hyperfine # замер времени запуска
      btop
      devenv
      # bottles # Wine Easy-to-use wineprefix manager
      gomodifytags
      simplescreenrecorder
      sshuttle
      dig
      inetutils
      git-lfs
      xh
      xxh
      # tmux-cssh # tmux-cssh user@host1 user@host2 user@host3
      # pkgs-master.youtube-dl
      # chromium

      # pkgs-unstable.code-cursor
      # pkgs-unstable.vscode
      # pkgs-unstable.windsurf

      (pkgs.writeScriptBin "mfiles" (builtins.readFile ./bash/print-files.sh))
      (pkgs.writeScriptBin "mreplace" (builtins.readFile ./bash/smart-replace.sh))
      inputs.replacer.packages.${pkgs.stdenv.hostPlatform.system}.default

      s3cmd
      minio-client
      # audio-recorder удалён из nixpkgs (заброшен, сломан); альтернатива: gnome-sound-recorder

      (pkgs-master.inkscape-with-extensions.override {
        inkscapeExtensions = with pkgs-master.inkscape-extensions; [
          inkstitch
        ];
      })

      (pkgs.writeShellScriptBin "jasonbourne" ''
        exec ${pkgs.kitty}/bin/kitty --class jasonbourne --title jasonbourne "$@"
      '')

      gnomeExtensions.window-calls
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

  # NOTE: nixpkgs.config here is ignored because home-manager.useGlobalPkgs = true.
  # allowUnfree / allowUnfreePredicate are configured in configuration.nix instead.

  programs = {
    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    jq.enable = true;

    fzf = {
      enable = true;
      enableZshIntegration = false;
      enableFishIntegration = true;
      tmux.enableShellIntegration = true;
    };

    lazygit.enable = config.programs.git.enable;
    # thefuck.enable = true;
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
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true; # быстрый кеш для nix-shell/flake use
    };

    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        core = {
          quotepath = false; # показывать кириллицу в именах файлов, а не \320\260
        };
        user = {
          name = "back2nix";
          email = "back2nix@list.ru";
        };
        alias = {
          pu = "push";
          co = "checkout";
          cm = "commit";
          # dt = "diff";
          lg = "log --stat";
        };
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

    # chromium.enable = true;
    chromium.extensions = [
      "padekgcemlokbadohgkifijomclgjgif" # Proxy SwitchyOmega
      "dmghijelimhndkbmpgbldicpogfkceaj" # Dark Mode
      "jhlfcnmbhnelhkfoicmfkdhbhaonadoh" # DarkPDF
      "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
      "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey + https://raw.githubusercontent.com/ilyhalight/voice-over-translation/master/dist/vot.user.js
      "pihphjfnfjmdbhakhjifipfdgbpenobg" # DocsAfterDark
      # "nffaoalbilbmmfgbnbgppjihopabppdk" # Video Speed Controller
      "fddjpichkajmnkjhcmpbbjdmmcodnkej" # РуТрекер
      # "nlmmgnhgdeffjkdckmikfpnddkbbfkkk" # Lightning Autofill
      "jpbjcnkcffbooppibceonlgknpkniiff" # global-speed
      # "dbclpoekepcmadpkeaelmhiheolhjflj" # User agent switcher
      # "mnjggcdmjocbbbhaepdhchncahnbgone" # sponsorblock for yt/inv
    ];
  };

  # gpu wayland
  # google-chrome --ozone-platform=wayland --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --use-angle=vulkan --disable-gpu-video-decode
  programs.google-chrome = {
    enable = true;
    package = pkgs-master.google-chrome;

    # GPU-композитинг на этом Intel Lunar Lake + Mesa:
    #   - ANGLE-GL вообще не инициализируется → всё software.
    #   - ANGLE-Vulkan даёт HW растеризацию/WebGL/видео, НО под нативным
    #     --ozone-platform=wayland Chromium не умеет VK_KHR_wayland_surface
    #     для display-композитора → "Compositing: Software only" (весь
    #     backbuffer композитится на CPU, GPU-процесс жрёт ~30мс/кадр).
    # Решение: Vulkan + --ozone-platform=x11 (XWayland) — там композитор
    # использует VK_KHR_xcb_surface, который поддержан → "Compositing:
    # Hardware accelerated" + WebGL без "reduced performance". Проверено на
    # chrome://gpu. Размен: XWayland вместо нативного Wayland.
    # См. brave/brave-browser#55345 (DefaultANGLEVulkan + Wayland = soft-composite).
    # --disable-gpu-video-decode убран: на Vulkan-пути Video Decode встаёт на HW.
    commandLineArgs = [
      "--ozone-platform=x11"
      # RawDraw / TreesInViz — экспериментальные GPU-фичи, держатся в ОДНОМ
      # --enable-features (второй такой флаг затёр бы Vulkan-список → soft-compositing).
      # Проверено chrome://gpu: , "TreesInViz: Enabled",  "Raw Draw: Enabled" - не дает запустить chrome белый экран
      # Vulkan/WebGPU/Compositing остались Hardware accelerated.
      "--enable-features=Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,WebRTCPipeWireCapturer,TreesInViz"
      "--use-angle=vulkan"
      "--ignore-gpu-blocklist"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--disable-features=GlobalMediaControls"
      # WebGPU: chrome://gpu показывал "WebGPU: Disabled". На Linux WebGPU
      # за флагом — включается ОТДЕЛЬНЫМ switch'ем --enable-unsafe-webgpu,
      # а НЕ вторым --enable-features=... . Прошлая попытка (ece7c8a) добавила
      # webgpu вторым "--enable-features=SkiaGraphite,..." — Chrome берёт только
      # ПОСЛЕДНИЙ --enable-features, из-за чего затирался Vulkan-список и падал
      # композитинг → всё откатили (5a90d96). Отдельный switch не конфликтует.
      # Проверено: chrome://gpu → "WebGPU: Hardware accelerated",
      # navigator.gpu.requestAdapter() → Intel xe-2lpg, Vulkan/Compositing целы.
      "--enable-unsafe-webgpu"
      "--remote-debugging-port=9222"
    ];
  };

  # xdg.mimeApps = {
  #   # enable = true;
  #   defaultApplications = {
  #     "image/*" = ["org.gnome.eog.desktop"];
  #     "text/palin" = ["nvim"];
  #     "video/*" = ["mvp.desktop"];
  #     "application/pdf" = ["evince"];
  #     "application/x-bzpdf" = ["evince"];
  #     "application/x-ext-pdf" = ["evince"];
  #     "application/x-gzpdf" = ["evince"];
  #     "application/x-xzpdf" = ["evince"];
  #   };
  #   # associations.removed = {
  #   #     "image/*" = ["gimp.desktop"];
  #   # };
  # };
}
