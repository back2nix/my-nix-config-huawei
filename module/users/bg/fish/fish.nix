{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-unstable,
  lib,
  ...
}: {
  home.file.".config/fish/completions/_mfiles.fish".source = ./_mfiles;
  home.file.".config/fish/completions/_ssh_port_completion.fish".source =
    ./_ssh_port_completion;

  programs.fish = {
    enable = true;

    # Включаем интерактивные функции
    interactiveShellInit = ''
      # Настройка окружения
      set -gx LANG en_US.UTF-8
      set -gx PATH $PATH $HOME/.cargo/bin

      # Настройка direnv
      direnv hook fish | source

      # Поддержка цветного вывода для IP
      set -gx IP_COLOR true

      # Настройка fzf
      set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border"

      set -g fish_greeting

      set -g theme_display_user yes
      set -g theme_hide_hostname no
      set -g color_user_bg black
      set -g color_user_str yellow
      set -g color_dir_bg blue
      set -g color_dir_str black
      set -g color_git_dirty_bg yellow
      set -g color_git_dirty_str black
      set -g color_git_bg green
      set -g color_git_str black
      set -g color_status_nonzero_bg black
      set -g color_status_nonzero_str red
      set -g color_status_superuser_bg black
      set -g color_status_superuser_str yellow
      set -g VIRTUAL_ENV_DISABLE_PROMPT 1
    '';

    plugins = [
      # Enable a plugin (here grc for colorized command output) from nixpkgs
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      # git blugin
      {
        name = "plugin-git";
        src = pkgs.fishPlugins.plugin-git.src;
      }
      # theme
      {
        name = "agnoster";
        src = pkgs.fetchFromGitHub {
          owner = "back2nix";
          repo = "theme-agnoster";
          rev = "4e9237196d4bc34743f61a79f8492ede661b690a";
          sha256 = "sha256-WS0/2ygFtd3wqAMza/B2Z3Eh7VLSSyJHCTxrHEjXQy4=";
        };
      }
      # theme
      # {
      #   name = "agnoster";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "jeanlucthumm";
      #     repo = "theme-agnoster";
      #     rev = "502ff4f34224c9aa90a8d0a3ad517940eaf4d4fd";
      #     sha256 = "12gc6mw5cb3pdqp8haqx9abgjw64v3960g0f0hgb122xa3z7qldm";
      #   };
      # }
      # Автодополнение путей
      {
        name = "autopair";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "autopair.fish";
          rev = "1.0.4";
          sha256 = "sha256-s1o188TlwpUQEN3X5MxUlD/2CFCpEkWu83U9O+wg3VU=";
        };
      }
      # z - быстрая навигация по каталогам
      {
        name = "z";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "z";
          rev = "e0e1b9dfdba362f8ab1ae8c1afc7ccf62b89f7eb";
          sha256 = "0dbnir6jbwjpjalz14snzd3cgdysgcs3raznsijd6savad3qhijc";
        };
      }
      # Подсветка синтаксиса
      {
        name = "fish-colored-man";
        src = pkgs.fetchFromGitHub {
          owner = "PatrickF1";
          repo = "colored_man_pages.fish";
          rev = "f885c2507128b70d6c41b043070a8f399988bc7a";
          sha256 = "sha256-ii9gdBPlC1/P1N9xJzqomrkyDqIdTg+iCg0mwNVq2EU=";
        };
      }
    ];

    functions = {
      # prompt_virtual_env = ''
      #   set envs

      #   if test "$CONDA_DEFAULT_ENV"
      #   set envs $envs "conda[$CONDA_DEFAULT_ENV]"
      #   end

      #   if test "$VIRTUAL_ENV"
      #   set py_env (basename $VIRTUAL_ENV)
      #   set envs $envs "py[$py_env]"
      #   end

      #   # Show only if we're in a nix-shell
      #   if test "$IN_NIX_SHELL"
      #   set envs $envs "nix[$IN_NIX_SHELL]"
      #   end

      #   if test "$envs"
      #   prompt_segment $color_virtual_env_bg $color_virtual_env_str (string join " " $envs)
      #   end
      # '';
      # Аналог вашей функции cdroot
      cdroot = ''
        set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
        if test -n "$git_root"
          cd "$git_root"
          echo "Changed to project root: $git_root"
        else
          echo "Not in a Git repository or Git is not installed."
        end
      '';

      # Аналог r2l
      r2l = ''
        set -l port (random 1024 61024)
        set -l server $argv[2]
        echo ssh -L "$port":localhost:$argv[1] "$server" -N
        echo http://localhost:"$port" or https://localhost:"$port"
        ssh -L "$port":localhost:$argv[1] "$server" -N
      '';

      r2l-port = ''
        local server=$3
        echo ssh -L "$2":localhost:$1 "$server" -N
        echo http://localhost:"$2" or https://localhost:"$2"
        ssh -L "$2":localhost:$1 "$server" -N
      '';

      l2r = ''
        local port=$((RANDOM % 60000 + 1024))
        local server=$2
        echo ssh -R "$port":0.0.0.0:$1 "$server" -N
        echo http://"$server":"$port" or https://"$server":"$port"
        ssh -R "$port":0.0.0.0:$1 "$server" -N
      '';

      l2r-port = ''
        local server=$3
        echo ssh -R "$2":0.0.0.0:$1 "$server" -N
        echo http://"$server":"$2" or https://"$server":"$2"
        ssh -R "$2":0.0.0.0:$1 "$server" -N
      '';

      # Аналогичные функции для r2l-port, l2r, l2r-port можно добавить по такому же принципу
    };

    shellAliases = let
      normcap_lang = "-l eng rus";
    in {
      # Те же алиасы, что у вас в zsh
      ls = "eza";
      ll = "eza -l --color=always";
      la = "eza -a --color=always";
      lla = "eza -al --color=always";
      tree = "eza --tree";
      gco = "git checkout";
      open = "xdg-open";
      nfl = "nix flake lock";
      nflu = "nix flake lock --update-input";
      img = "eog";
      pdf = "evince";
      n = "nvim";
      sh = "stat --format '%a'";
      cdspeak = "cd ~/Documents/code/github.com/back2nix/speaker";
      cdgo = "cd ~/Documents/code/github.com/back2nix";
      update = "sudo nixos-rebuild switch";
      hupdate = "home-manager switch";
      ip = "ip --color=auto";
      dt = "difft";
      bcat = "bat --pager=never --style=changes,rule,numbers,snip";
      tk = "tokei";
      sctl = "systemctl";

      # screen2text = "${pkgs-master.normcap}/bin/normcap ${normcap_lang}";
      # s2t = "${pkgs-master.normcap}/bin/normcap -l eng";
      # # s2tf = "${pkgs-master.gnome-frog}/bin/frog";
      # en = "${pkgs-master.normcap}/bin/normcap -l eng";
      # ru = "${pkgs-master.normcap}/bin/normcap -l rus";
      # diff = ''
      #   ${pkgs-master.delta}/bin/delta --side-by-side --line-numbers --syntax-theme="Dracula" --file-style="bold yellow" --hunk-header-style="omit" --plus-style="syntax #003800" --minus-style="syntax #3f0001" --zero-style="syntax" --whitespace-error-style="magenta reverse" --navigate'';
      # # cover = ''
      # #   local t=$(mktemp)
      # #   go test $COVERFLAGS -coverprofile=$t $@ \
      # #   && go tool cover -func=$t \
      # #   && unlink $t
      # # '';
      # # coverweb = ''
      # #   local t=$(mktemp)
      # #   go test $COVERFLAGS -coverprofile=$t $@ \
      # #   && go tool cover -html=$t \
      # #   && unlink $t
      # # '';

      st = "stat --format '%a'";
      # fe = ''
      #   selected_file=$(rg --files ''${1:-.} | fzf)
      #   if [ -n "$selected_file" ]; then
      #   $EDITOR ''${selected_file%%:*}
      #   fi
      # '';
      # # Search content and Edit
      # se = ''
      #   fileline=$(rg -n ''${1:-.} | fzf --preview 'bat -f `echo {} | cut -d ":" -f 1` -r `echo {} | cut -d ":" -f 2`:$((`echo {} | cut -d ":" -f 2`+150))' | awk '{print $1}' | sed 's/.$//')
      #   if [[ -n $fileline ]]; then
      #   $EDITOR ''${fileline%%:*} +''${fileline##*:}
      #   fi
      # '';
      # fl = ''
      #   git log --oneline --color=always | fzf --ansi --preview=" echo { } | cut - d ' ' - f 1 | xargs - I @ sh -c 'git log --pretty=medium -n 1 @; git diff @^ @' | bat --color=always" | cut -d ' ' -f 1 | xargs git log --pretty=short -n 1'';
      # gd = "git diff --name-only --diff-filter=d $@ | xargs bat --diff";
      cdnix = "cd ~/Documents/code/github.com/back2nix/nix/my-nix-config-*";
      cdinfo = "cd ~/Documents/code/github.com/back2nix/info";
      clip = "head -c -1|xclip -i -selection clipboard";
      rd = "readlink -f";
      sudo = "sudo ";
    };

    shellInit = ''
      # if command -q nix-your-shell
      #   nix-your-shell fish | source
      # end

      # if test (id -u) -eq 0
      #   set -g fish_color_cwd red
      #   set -g fish_color_user red
      #   set -g fish_color_host red
      #   set -g agnoster_color_user_root red  # Agnoster-specific setting
      # end
    '';
  };

  # Дополнительные пакеты, которые могут понадобиться
  home.packages = with pkgs; [
    bat
    eza
    fd
    fzf
    ripgrep
    delta
    direnv
    nix-your-shell
    fishPlugins.grc
    grc
  ];
}
