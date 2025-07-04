{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-unstable,
  lib,
  ...
}: let
  isRoot = config.home.username == "root";
in {
  imports = [];

  home.file.".config/nixpkgs/zsh-completions/_mfiles".source = ./_mfiles;
  home.file.".config/nixpkgs/zsh-completions/_ssh_port_completion".source = ./_ssh_port_completion;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    # enableVteIntegration = true;
    syntaxHighlighting.enable = true;

    autocd = true;

    initExtra = ''
      fpath=(${config.home.homeDirectory}/.config/nixpkgs/zsh-completions $fpath)
      autoload -U compinit && compinit

      # Добавляем условие для промпта root
      if [[ $UID -eq 0 ]]; then
        prompt_context() {
          prompt_segment "red" "white" "root@%m"
        }
      fi

      ORIGINAL_PROMPT="$PROMPT"
      update_prompt() {
        if [[ -n $IN_NIX_SHELL ]]; then
        PROMPT="$ORIGINAL_PROMPT"
        else
        PROMPT="$ORIGINAL_PROMPT"
        fi
      }
      precmd_functions+=(update_prompt)

      export LANG=en_US.UTF-8
      DIRSTACKSIZE=90
      setopt autopushd pushdsilent pushdtohome
      setopt pushdignoredups
      setopt pushdminus

      export XDG_DATA_DIRS=$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share
      export PATH=$PATH:$HOME/.cargo/bin

      # Set ZVM_VI_INSERT_ESCAPE_BINDKEY to Ctrl+C
      # export ZVM_VI_INSERT_ESCAPE_BINDKEY='^C'

      cdroot() {
        local git_root
        git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [ -n "$git_root" ]; then
          cd "$git_root"
          echo "Changed to project root: $git_root"
        else
          echo "Not in a Git repository or Git is not installed."
        fi
      }

      # Define the functions directly instead of using aliases
      r2l() {
        local port=$((RANDOM % 60000 + 1024))
        local server=$2
        echo ssh -L "$port":localhost:$1 "$server" -N
        echo http://localhost:"$port" or https://localhost:"$port"
        ssh -L "$port":localhost:$1 "$server" -N
      }

      r2l-port() {
        local server=$3
        echo ssh -L "$2":localhost:$1 "$server" -N
        echo http://localhost:"$2" or https://localhost:"$2"
        ssh -L "$2":localhost:$1 "$server" -N
      }

      l2r() {
        local port=$((RANDOM % 60000 + 1024))
        local server=$2
        echo ssh -R "$port":0.0.0.0:$1 "$server" -N
        echo http://"$server":"$port" or https://"$server":"$port"
        ssh -R "$port":0.0.0.0:$1 "$server" -N
      }

      l2r-port() {
        local server=$3
        echo ssh -R "$2":0.0.0.0:$1 "$server" -N
        echo http://"$server":"$2" or https://"$server":"$2"
        ssh -R "$2":0.0.0.0:$1 "$server" -N
      }
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "extract"
        "adb"
        "sudo"
        "systemd"
        "argocd"
        "direnv"
        "golang"
        "httpie"
        "nomad"
        "pass"
        "podman"
        "ssh-agent"

        # "helm"
        # "web-search"
        # "kubectl"
        # "kubectx"
        # "command-not-found"
      ];
      custom = "/etc/nixos/module/users/bg";
      theme = "agnoster-nix";
      # theme = "alanpeabody";
      # theme = "romkatv/powerlevel10k";
    };
    shellAliases = let
      normcap_lang = "-l eng rus";
    in {
      # https://github.com/jonringer/nixpkgs-config/blob/987c6e3d647e90ef2bbd00171b5c1bb8bf5e1757/bash.nix#L159
      screen2text = "${pkgs-master.normcap}/bin/normcap ${normcap_lang}";
      s2t = "${pkgs-master.normcap}/bin/normcap -l eng";
      # s2tf = "${pkgs-master.gnome-frog}/bin/frog";
      en = "${pkgs-master.normcap}/bin/normcap -l eng";
      ru = "${pkgs-master.normcap}/bin/normcap -l rus";
      diff = ''${pkgs-master.delta}/bin/delta --side-by-side --line-numbers --syntax-theme="Dracula" --file-style="bold yellow" --hunk-header-style="omit" --plus-style="syntax #003800" --minus-style="syntax #3f0001" --zero-style="syntax" --whitespace-error-style="magenta reverse" --navigate'';
      ls = "eza ";
      ll = "eza -l --color=always";
      la = "eza -a --color=always";
      lla = "eza -al --color=always";
      tree = "eza --tree";
      gco = "git checkout";
      open = "xdg-open";
      nfl = "nix flake lock";
      nflu = "nix flake lock --update-input";
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
      # z = "zellij";
      n = "nvim";
      # Usage:
      # ssh-port <remote_port> [server]
      #
      # Examples:
      # ssh-port 8080           # Uses 'desktop' as the server
      # ssh-port 8080 myserver  # Uses 'myserver' as the server
      #
      # This function creates an SSH tunnel, forwarding a random local port
      # to the specified remote port on the given server (or 'desktop' if not specified).
      # r2l = ''
      #   function ssh-port() {
      #   local port=$((RANDOM % 60000 + 1024));
      #   local server=$2;
      #   echo ssh -L "$port":localhost:$1 "$server" -N;
      #   echo http://localhost:"$port" or https://localhost:"$port";
      #   ssh -L "$port":localhost:$1 "$server" -N;
      #   }; ssh-port'';
      # r2l-port = ''
      #   function ssh-port() {
      #   local server=$3;
      #   echo ssh -L "$2":localhost:$1 "$server" -N;
      #   echo http://localhost:"$2" or https://localhost:"$2";
      #   ssh -L "$2":localhost:$1 "$server" -N;
      #   }; ssh-port'';
      # # vim /etc/ssh/sshd_config
      # # GatewayPorts yes
      # # systemctl restart ssh
      # l2r = ''
      #   function ssh-port() {
      #   local port=$((RANDOM % 60000 + 1024));
      #   local server=$2;
      #   echo ssh -R "$port":0.0.0.0:$1 "$server" -N;
      #   echo http://"$server":"$port" or https://"$server":"$port";
      #   ssh -R "$port":0.0.0.0:$1 "$server" -N;
      #   }; ssh-port'';
      # l2r-port = ''
      #   function ssh-port() {
      #   local server=$3;
      #   echo ssh -R "$2":0.0.0.0:$1 "$server" -N;
      #   echo http://"$server":"$2" or https://"$server":"$2";
      #   ssh -R "$2":0.0.0.0:$1 "$server" -N;
      #   }; ssh-port'';
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
      # gd = "git diff --name-only --diff-filter=d $@ | xargs bat --diff";
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
      extended = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    plugins = let
      mkZshPlugin = {
        pkg,
        file ? "${pkg.pname}.plugin.zsh",
      }: {
        name = pkg.pname;
        src = pkg.src;
        inherit file;
      };
    in
      with pkgs; [
        (mkZshPlugin {pkg = zsh-vi-mode;})
        (mkZshPlugin {pkg = zsh-autosuggestions;})
        (mkZshPlugin {pkg = zsh-autopair;})
        (mkZshPlugin {pkg = zsh-history-substring-search;})
        (mkZshPlugin {pkg = nix-zsh-completions;})
        (mkZshPlugin {pkg = zsh-abbr;})
        (mkZshPlugin {pkg = zsh-you-should-use;})
        (mkZshPlugin {pkg = zsh-nix-shell;})
        # (mkZshPlugin {pkg = zsh-z;})
        (mkZshPlugin {pkg = zsh-fzf-tab;})
        (mkZshPlugin {pkg = zsh-autoenv;})
        (mkZshPlugin {pkg = zsh-navigation-tools;})
        (mkZshPlugin {pkg = zsh-fzf-history-search;})
        (mkZshPlugin {pkg = zsh-fast-syntax-highlighting;})
        # (mkZshPlugin {pkg = zsh-syntax-highlighting;})
      ];
  };
}
