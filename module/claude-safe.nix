{
  pkgs,
  lib,
  ...
}: let
  consumers = import ./proxy-routes-data.nix;
  agentProxyPort = agent:
    (lib.findFirst (route: route.name == agent)
      (throw "Missing dedicated proxy route for ${agent}") consumers.routes).httpPort;
  # Fixed SSH destinations reachable from the host network, never a general proxy.
  sshEndpoints = [
    { name = "bagau"; aliases = "bagau"; address = "192.168.0.102"; }
    { name = "bagau-vpn"; aliases = "bagau-vpn"; address = "10.101.0.3"; }
    { name = "desktop"; aliases = "desktop"; address = "192.168.0.171"; }
    { name = "kz-astana"; aliases = "kz-astana"; address = "89.126.194.91"; }
    { name = "winjoy-beget"; aliases = "winjoy-beget"; address = "159.194.224.13"; }
    { name = "winjoy-frankfurt"; aliases = "winjoy-frankfurt winjoy-mivocloud-frankfurt"; address = "5.252.179.162"; }
  ];
  safeSsh = pkgs.writeShellScriptBin "ssh" ''
    exec ${pkgs.openssh}/bin/ssh -F "$CLAUDE_SAFE_SSH_CONFIG" "$@"
  '';
  mkSafe = {
    name,
    program,
    proxyPort,
    noDaemon ? false,
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
      # Wait for both listeners, without requiring k3s to be running.
      ready=0
      for _ in {1..100}; do
        if [ -n "$(${pkgs.iproute2}/bin/ss -H -ltn 'sport = :${toString proxyPort}')" ] && \
           [ -n "$(${pkgs.iproute2}/bin/ss -H -ltn 'sport = :6443')" ]; then
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
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 DISABLE_AUTOUPDATER=1
      export DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DO_NOT_TRACK=1
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
            if [ -s "$relay_log" ]; then
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
        # Expose only port 22 of explicitly allowed hosts via Unix sockets.
        ${lib.concatMapStringsSep "\n" (endpoint: ''
          setsid socat -lp ${name}-ssh-${endpoint.name}-host "UNIX-LISTEN:$relay_dir/ssh-${endpoint.name},fork,mode=0600" TCP4:${endpoint.address}:22 2>>"$relay_log_dir/ssh-${endpoint.name}-host.log" &
          relay_pids+=("$!")
        '') sshEndpoints}
        cat > "$relay_dir/ssh-config" <<EOF
        ${lib.concatMapStringsSep "\n" (endpoint: ''
        Host ${endpoint.aliases}
          ProxyCommand ${pkgs.socat}/bin/socat STDIO UNIX-CONNECT:$relay_dir/ssh-${endpoint.name}
        '') sshEndpoints}
        Host *
          Include "$HOME/.ssh/config"
        EOF
        ready=0
        for _ in {1..100}; do
          if [ -S "$relay_dir/proxy" ] && [ -S "$relay_dir/k3s" ] ${lib.concatMapStrings (endpoint: "&& [ -S \"$relay_dir/ssh-${endpoint.name}\" ] ") sshEndpoints}; then
            ready=1
            break
          fi
          sleep 0.05
        done
        if [ "$ready" != 1 ]; then
          echo 'claude-safe: host relays did not start' >&2
          exit 1
        fi
        # Mandatory isolation: never retry without namespaces on failure.
        bwrap --unshare-user --unshare-net --unshare-pid \
          --disable-userns --assert-userns-disabled --cap-drop ALL \
          --die-with-parent --bind / / --dev-bind /dev /dev --proc /proc \
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
              program =
                if agent == "claude"
                then "${final.claude-code}/bin/claude"
                else "${final.codex}/bin/codex";
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
          proxyPort = agentProxyPort "claude";
        };
        codex-safe = mkSafe {
          name = "codex-safe";
          program = "${final.codex}/bin/codex";
          proxyPort = agentProxyPort "codex";
          noDaemon = true;
        };
        claude = prev.writeShellScriptBin "claude" ''
          exec ${final.claude-safe}/bin/claude-safe "$@"
        '';
        codex-routed = prev.writeShellScriptBin "codex" ''
          exec ${final.codex-safe}/bin/codex-safe "$@"
        '';
      })
  ];
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
