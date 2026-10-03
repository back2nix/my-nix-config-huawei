{pkgs, ...}: let
  inside = pkgs.writeShellScript "claude-safe-inside" ''
    set -euo pipefail
    relay_dir=$1
    shift
    relay_pids=()
    cleanup() {
      for relay_pid in "''${relay_pids[@]}"; do
        kill "$relay_pid" 2>/dev/null || true
      done
    }
    trap cleanup EXIT
    ${pkgs.socat}/bin/socat TCP4-LISTEN:1083,bind=127.0.0.1,reuseaddr,fork \
      "UNIX-CONNECT:$relay_dir/proxy" &
    relay_pids+=("$!")
    ${pkgs.socat}/bin/socat TCP4-LISTEN:6443,bind=127.0.0.1,reuseaddr,fork \
      "UNIX-CONNECT:$relay_dir/k3s" &
    relay_pids+=("$!")
    # Wait for both listeners, without requiring k3s to be running.
    ready=0
    for _ in {1..100}; do
      if (exec 3<>/dev/tcp/127.0.0.1/1083) 2>/dev/null && \
         (exec 3<>/dev/tcp/127.0.0.1/6443) 2>/dev/null; then
        ready=1
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.05
    done
    if [ "$ready" != 1 ]; then
      echo 'claude-safe: local relays did not start' >&2
      exit 1
    fi
    export HTTP_PROXY=http://127.0.0.1:1083
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
    ${pkgs.claude-code}/bin/claude "$@"
  '';
  launcher = pkgs.writeShellApplication {
    name = "claude-1082-safe";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux pkgs.socat pkgs.bubblewrap];
    text = ''
      umask 077
      relay_dir=$(mktemp -d /tmp/claude-safe.XXXXXXXX)
      relay_pids=()
      cleanup() {
        for relay_pid in "''${relay_pids[@]}"; do
          kill -- "-$relay_pid" 2>/dev/null || true
        done
        rm -rf -- "$relay_dir"
      }
      trap cleanup EXIT
      # Each host-side relay has exactly one fixed TCP destination.
      setsid socat "UNIX-LISTEN:$relay_dir/proxy,fork,mode=0600" TCP4:127.0.0.1:1093 &
      relay_pids+=("$!")
      setsid socat "UNIX-LISTEN:$relay_dir/k3s,fork,mode=0600" TCP4:127.0.0.1:6443 &
      relay_pids+=("$!")
      ready=0
      for _ in {1..100}; do
        if [ -S "$relay_dir/proxy" ] && [ -S "$relay_dir/k3s" ]; then
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
        --chdir "$PWD" ${inside} "$relay_dir" "$@"
    '';
  };
in {
  environment.systemPackages = [launcher];
}
