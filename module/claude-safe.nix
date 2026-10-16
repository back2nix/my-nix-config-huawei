{
  config,
  pkgs,
  lib,
  ...
}: let
  consumers = import ./proxy-routes-data.nix;
  agentProxyPort = agent:
    (lib.findFirst (route: route.name == agent)
      (throw "Missing dedicated proxy route for ${agent}") consumers.routes).httpPort;
  # Fixed SSH destinations reachable from the host network, never a general proxy.
  # Kept in sops: one "name address alias..." line per host.
  sshEndpointsFile = config.sops.secrets."claude-safe/ssh_endpoints".path;
  secretPaths = [
    ".gnupg"
    ".config/sops"
    ".mozilla"
    ".config/google-chrome"
    ".config/chromium"
    ".local/share/TelegramDesktop"
    ".local/share/keyrings"
    ".config/dconf" # keyboard layouts, input sources, recent files
    ".local/share/fish/fish_history"
    ".bash_history"
    ".zsh_history"
    ".netrc"
  ];
  claudeState = [".claude" ".claude.json"];
  codexState = [".codex"];
  # Codex: no product analytics and no feedback uploads.
  codexBin = codex: "${codex}/bin/codex -c analytics.enabled=false -c feedback.enabled=false -c otel.exporter=none -c otel.metrics_exporter=none -c otel.trace_exporter=none -c otel.log_user_prompt=false";
  safeSsh = pkgs.writeShellScriptBin "ssh" ''
    exec ${pkgs.openssh}/bin/ssh -F "$CLAUDE_SAFE_SSH_CONFIG" "$@"
  '';
  mkSafe = {
    name,
    program,
    proxyPort,
    noDaemon ? false,
    chromeDevtools ? false,
    # Extra $HOME-relative paths hidden from this agent (e.g. other agents' state).
    hide ? [],
  }: let
    inside = pkgs.writeShellScript "${name}-inside" ''
      set -euo pipefail
      relay_dir=$1
      relay_log_dir=$2
      shift 2
      relay_pids=()
      cleanup() {
        for relay_pid in "''${relay_pids[@]}"; do
          kill "$relay_pid" 2>/dev/null || true
        done
      }
      trap cleanup EXIT
      ${pkgs.socat}/bin/socat -lp ${name}-proxy-inside TCP4-LISTEN:${toString proxyPort},bind=127.0.0.1,reuseaddr,fork \
        "UNIX-CONNECT:$relay_dir/proxy" 2>>"$relay_log_dir/proxy-inside.log" &
      relay_pids+=("$!")
      ${pkgs.socat}/bin/socat -lp ${name}-k3s-inside TCP4-LISTEN:6443,bind=127.0.0.1,reuseaddr,fork \
        "UNIX-CONNECT:$relay_dir/k3s" 2>>"$relay_log_dir/k3s-inside.log" &
      relay_pids+=("$!")
      ${lib.optionalString chromeDevtools ''
        ${pkgs.socat}/bin/socat -lp ${name}-chrome-inside TCP4-LISTEN:9333,bind=127.0.0.1,reuseaddr,fork \
          "UNIX-CONNECT:$relay_dir/chrome" 2>>"$relay_log_dir/chrome-inside.log" &
        relay_pids+=("$!")
      ''}
      # Wait for listeners, without requiring their destinations to be running.
      ready=0
      for _ in {1..100}; do
        if [ -n "$(${pkgs.iproute2}/bin/ss -H -ltn 'sport = :${toString proxyPort}')" ] && \
           [ -n "$(${pkgs.iproute2}/bin/ss -H -ltn 'sport = :6443')" ] ${lib.optionalString chromeDevtools ''&& [ -n "$(${pkgs.iproute2}/bin/ss -H -ltn 'sport = :9333')" ]''}; then
          ready=1
          break
        fi
        ${pkgs.coreutils}/bin/sleep 0.05
      done
      if [ "$ready" != 1 ]; then
        echo 'claude-safe: local relays did not start' >&2
        exit 1
      fi
      export CLAUDE_SAFE_SSH_CONFIG="$relay_dir/ssh-config"
      export PATH=${safeSsh}/bin:$PATH
      export HTTP_PROXY=http://127.0.0.1:${toString proxyPort}
      export HTTPS_PROXY=$HTTP_PROXY ALL_PROXY=$HTTP_PROXY
      export http_proxy=$HTTP_PROXY https_proxy=$HTTP_PROXY all_proxy=$HTTP_PROXY
      export NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1
      unset DBUS_SESSION_BUS_ADDRESS
      # Neutral identity: English only, New York time.
      for var in $(${pkgs.coreutils}/bin/env | ${pkgs.gnused}/bin/sed -n 's/^\(LC_[A-Z_]*\)=.*/\1/p'); do
        unset "$var"
      done
      export LANG=en_US.UTF-8 LANGUAGE=en LC_ALL=en_US.UTF-8 TZ=America/New_York
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 DISABLE_AUTOUPDATER=1
      export DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DO_NOT_TRACK=1
      export DISABLE_BUG_COMMAND=1 CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
      unset CLAUDE_CODE_ENABLE_TELEMETRY
      for var in $(${pkgs.coreutils}/bin/env | ${pkgs.gnused}/bin/sed -n 's/^\(OTEL_[A-Z_]*\)=.*/\1/p'); do
        unset "$var"
      done
      if [ "''${1:-}" = --check ]; then
        echo 'Checking direct IPv4 and IPv6 (must fail)...'
        for target in https://1.1.1.1 'https://[2606:4700:4700::1111]'; do
          if ${pkgs.curl}/bin/curl -kfsS --noproxy '*' --connect-timeout 2 --max-time 3 "$target" >/dev/null 2>&1; then
            echo "FAIL: direct connection succeeded: $target" >&2
            exit 1
          fi
        done
        echo 'Checking fixed proxy...'
        ${pkgs.curl}/bin/curl -fsS --connect-timeout 10 --max-time 30 https://api.ipify.org
        echo
        echo 'Checking local k3s with current kubeconfig...'
        ${pkgs.kubectl}/bin/kubectl --request-timeout=10s get --raw=/version
        exit
      fi
      ${lib.optionalString noDaemon ''
        # Never hand this session to a shared daemon outside the namespace.
        daemon_args=(--no-daemon)
        for arg in "$@"; do
          if [ "$arg" = -- ]; then break; fi
          if [ "$arg" = --no-daemon ]; then
            daemon_args=()
            break
          fi
        done
        set -- "''${daemon_args[@]}" "$@"
      ''}
      ${program} "$@"
    '';
    launcher = pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.util-linux pkgs.socat pkgs.bubblewrap];
      text = ''
        umask 077
        relay_log_root="''${XDG_STATE_HOME:-$HOME/.local/state}/${name}/relays"
        mkdir -p -- "$relay_log_root"
        relay_log_dir=$(mktemp -d "$relay_log_root/session.XXXXXXXX")
        relay_dir=$(mktemp -d /tmp/claude-safe.XXXXXXXX)
        relay_pids=()
        cleanup() {
          for relay_pid in "''${relay_pids[@]}"; do
            kill -- "-$relay_pid" 2>/dev/null || true
          done
          rm -rf -- "$relay_dir"
          relay_errors=0
          for relay_log in "$relay_log_dir"/*.log; do
            # Normal shutdown of relays logs "exiting on signal 15"; not an error.
            if grep -qv 'exiting on signal 15' "$relay_log" 2>/dev/null; then
              relay_errors=1
              break
            fi
          done
          if [ "$relay_errors" = 1 ]; then
            echo "${name}: relay reported errors; logs: $relay_log_dir" >&2
          else
            rm -rf -- "$relay_log_dir"
          fi
        }
        trap cleanup EXIT
        # Each host-side relay has exactly one fixed TCP destination.
        setsid socat -lp ${name}-proxy-host "UNIX-LISTEN:$relay_dir/proxy,fork,mode=0600" TCP4:127.0.0.1:${toString proxyPort} 2>>"$relay_log_dir/proxy-host.log" &
        relay_pids+=("$!")
        setsid socat -lp ${name}-k3s-host "UNIX-LISTEN:$relay_dir/k3s,fork,mode=0600" TCP4:127.0.0.1:6443 2>>"$relay_log_dir/k3s-host.log" &
        relay_pids+=("$!")
        ${lib.optionalString chromeDevtools ''
          setsid socat -lp ${name}-chrome-host "UNIX-LISTEN:$relay_dir/chrome,fork,mode=0600" TCP4:127.0.0.1:9333 2>>"$relay_log_dir/chrome-host.log" &
          relay_pids+=("$!")
        ''}
        # Expose only port 22 of explicitly allowed hosts via Unix sockets.
        ssh_endpoints=()
        : > "$relay_dir/ssh-config"
        if [ -r ${sshEndpointsFile} ]; then
          while read -r ep_name ep_address ep_aliases; do
            case "$ep_name" in ""|"#"*) continue ;; esac
            ssh_endpoints+=("$ep_name")
            setsid socat -lp ${name}-ssh-"$ep_name"-host "UNIX-LISTEN:$relay_dir/ssh-$ep_name,fork,mode=0600" "TCP4:$ep_address:22" 2>>"$relay_log_dir/ssh-$ep_name-host.log" &
            relay_pids+=("$!")
            printf 'Host %s\n  ProxyCommand ${pkgs.socat}/bin/socat STDIO UNIX-CONNECT:%s\n\n' \
              "$ep_name $ep_address $ep_aliases" "$relay_dir/ssh-$ep_name" >> "$relay_dir/ssh-config"
          done < ${sshEndpointsFile}
        fi
        cat >> "$relay_dir/ssh-config" <<EOF
        Host *
          # Private keys are hidden: always sign via the agent (first match wins).
          IdentityAgent ''${SSH_AUTH_SOCK:-none}
          Include "$HOME/.ssh/config"
        EOF
        ready=0
        for _ in {1..100}; do
          if [ -S "$relay_dir/proxy" ] && [ -S "$relay_dir/k3s" ] ${lib.optionalString chromeDevtools ''&& [ -S "$relay_dir/chrome" ] ''}; then
            ready=1
            for ep_name in "''${ssh_endpoints[@]}"; do
              [ -S "$relay_dir/ssh-$ep_name" ] || ready=0
            done
            [ "$ready" = 1 ] || { sleep 0.05; continue; }
            break
          fi
          sleep 0.05
        done
        if [ "$ready" != 1 ]; then
          echo 'claude-safe: host relays did not start' >&2
          exit 1
        fi
        # Hide personal data: secrets, browser profiles, messengers, keyrings.
        hide_args=()
        for rel in ${lib.escapeShellArgs (secretPaths ++ hide)}; do
          path="$HOME/$rel"
          if [ -d "$path" ]; then
            hide_args+=(--tmpfs "$path")
          elif [ -e "$path" ]; then
            hide_args+=(--ro-bind /dev/null "$path")
          fi
        done
        # Private SSH keys stay usable only through ssh-agent (via their .pub).
        for path in "$HOME"/.ssh/*; do
          if [ -f "$path" ] && head -c 64 -- "$path" | grep -q 'PRIVATE KEY'; then
            # ssh accepts a public key as IdentityFile and signs via the agent.
            # Copy is 0600 (umask 077): ssh rejects group/world-readable identity files.
            if [ -f "$path.pub" ]; then
              mkdir -p -- "$relay_dir/ssh-pub"
              cp -- "$path.pub" "$relay_dir/ssh-pub/''${path##*/}"
              hide_args+=(--ro-bind "$relay_dir/ssh-pub/''${path##*/}" "$path")
            else
              hide_args+=(--ro-bind /dev/null "$path")
            fi
          fi
        done
        # Runtime dir without D-Bus, keyring, KeePassXC: only allowed sockets.
        runtime_dir="/run/user/$(id -u)"
        hide_args+=(--tmpfs "$runtime_dir")
        for rel in gcr cc-socks wayland-0 pipewire-0 pulse; do
          if [ -e "$runtime_dir/$rel" ]; then
            hide_args+=(--bind "$runtime_dir/$rel" "$runtime_dir/$rel")
          fi
        done
        echo 00000000000000000000000000000000 > "$relay_dir/machine-id"
        echo LANG=en_US.UTF-8 > "$relay_dir/locale.conf"
        echo KEYMAP=us > "$relay_dir/vconsole.conf"
        # /etc entries are symlinks on NixOS: bwrap needs the resolved target.
        etc_args=()
        for entry in machine-id locale.conf vconsole.conf; do
          if [ -e "/etc/$entry" ]; then
            etc_args+=(--ro-bind "$relay_dir/$entry" "$(readlink -f "/etc/$entry")")
          fi
        done
        # gh keeps its token in the keyring (D-Bus is hidden): pass it explicitly.
        if [ -z "''${GH_TOKEN:-}" ] && command -v gh >/dev/null; then
          if GH_TOKEN=$(gh auth token 2>/dev/null); then
            export GH_TOKEN
          else
            unset GH_TOKEN
          fi
        fi
        # Mandatory isolation: never retry without namespaces on failure.
        bwrap --unshare-user --unshare-net --unshare-pid --unshare-uts \
          --hostname sandbox \
          --disable-userns --assert-userns-disabled --cap-drop ALL \
          --die-with-parent --bind / / --dev-bind /dev /dev --proc /proc \
          "''${hide_args[@]}" \
          "''${etc_args[@]}" \
          --chdir "$PWD" ${inside} "$relay_dir" "$relay_log_dir" "$@"
      '';
    };
  in
    launcher;
in {
  nixpkgs.overlays = [
    (final: prev:
      lib.listToAttrs (lib.concatMap (
        agent:
          map (pair: let
            name = "${agent}-${toString pair.port}-safe";
          in {
            inherit name;
            value = mkSafe {
              inherit name;
              proxyPort = pair.proxyPort;
              noDaemon = agent == "codex";
              chromeDevtools = true;
              hide =
                if agent == "claude"
                then codexState
                else claudeState;
              program =
                if agent == "claude"
                then "${final.claude-code}/bin/claude"
                else codexBin final.codex;
            };
          }) [
            {
              port = 1082;
              proxyPort = 1093;
            }
            {
              port = 1088;
              proxyPort = 1095;
            }
            {
              port = 1090;
              proxyPort = 1097;
            }
          ]
      ) ["claude" "codex"])
      // {
        antigravity-safe = mkSafe {
          name = "antigravity-safe";
          program = "${final.antigravity-cli}/bin/agy";
          hide = claudeState ++ codexState;
          proxyPort = agentProxyPort "antigravity";
        };
        agy = prev.writeShellScriptBin "agy" ''
          exec ${final.antigravity-safe}/bin/antigravity-safe "$@"
        '';
        antigravity-routed = prev.writeShellScriptBin "antigravity-cli" ''
          exec ${final.antigravity-safe}/bin/antigravity-safe "$@"
        '';
        claude-safe = mkSafe {
          name = "claude-safe";
          program = "${final.claude-code}/bin/claude";
          hide = codexState;
          proxyPort = agentProxyPort "claude";
          chromeDevtools = true;
        };
        codex-safe = mkSafe {
          name = "codex-safe";
          program = codexBin final.codex;
          hide = claudeState;
          proxyPort = agentProxyPort "codex";
          noDaemon = true;
          chromeDevtools = true;
        };
        claude = prev.writeShellScriptBin "claude" ''
          exec ${final.claude-safe}/bin/claude-safe "$@"
        '';
        codex-routed = prev.writeShellScriptBin "codex" ''
          exec ${final.codex-safe}/bin/codex-safe "$@"
        '';
      })
  ];
  sops.secrets."claude-safe/ssh_endpoints" = {
    owner = "bg";
    mode = "0400";
  };
  environment.systemPackages = map (name: pkgs.${name}) [
    "antigravity-safe"
    "agy"
    "antigravity-routed"
    "claude-safe"
    "codex-safe"
    "claude"
    "codex-routed"
    "claude-1082-safe"
    "claude-1088-safe"
    "claude-1090-safe"
    "codex-1082-safe"
    "codex-1088-safe"
    "codex-1090-safe"
  ];
}
