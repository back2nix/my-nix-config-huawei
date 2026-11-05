# module/sing-box.nix
{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: let
  # SSH channel opens must honor DNS cancellation too. In sing-box 1.14.1,
  # client.Dial ignores ctx and can block until sshd's TCP timeout (~2 min).
  # No NaiveProxy outbounds are configured; avoid its Cronet/LLVM toolchain.
  singBox =
    (pkgs-unstable.sing-box.override {
      withNaiveOutbound = false;
    }).overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace protocol/ssh/outbound.go \
            --replace-fail 'client.Dial(network, destination.String())' \
                           'client.DialContext(ctx, network, destination.String())'
          # Cached answers belong to the selected exit. Flush on every selector
          # change (including GUI/API changes), before opening new connections.
          substituteInPlace protocol/group/selector.go \
            --replace-fail 's.interruptGroup.Interrupt(s.interruptExternalConnections)' \
              'if dnsRouter := service.FromContext[adapter.DNSRouter](s.ctx); dnsRouter != nil { dnsRouter.ClearCache() }; s.interruptGroup.Interrupt(s.interruptExternalConnections)'
        '';
    });
in {
  systemd.services."sing-box" = {
    enable = true;
    description = "sing-box proxy";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      # Защита: outbound с отсутствующим private_key_path (ключ не скопирован
      # на эту машину) валит весь sing-box FATAL'ом, и вместе с ним git/nix.
      # Перед стартом выкидываем такие outbound'ы (и зависящие от них через
      # detour), чистим их из selector/urltest и route.rules.
      ExecStartPre = pkgs.writeShellScript "sing-box-prune-missing-keys" ''
        set -eu
        src=${config.sops.templates."sing-box-config.json".path}
        dst=/run/sing-box/config.json
        missing=$(${pkgs.jq}/bin/jq -r '.outbounds[] | select(.private_key_path) | "\(.tag)\t\(.private_key_path)"' "$src" \
          | while IFS=$'\t' read -r tag key; do [ -r "$key" ] || { echo "WARN: $tag: нет ключа $key, outbound отключён" >&2; echo "$tag"; }; done \
          | ${pkgs.jq}/bin/jq -Rsc 'split("\n") | map(select(length > 0))')
        ${pkgs.jq}/bin/jq --argjson bad "$missing" -f ${./sing-box/prune-missing-keys.jq} "$src" > "$dst.tmp" \
          || cp "$src" "$dst.tmp"
        mv "$dst.tmp" "$dst"
      '';
      RuntimeDirectory = "sing-box";
      ExecStart = "${singBox}/bin/sing-box run -c /run/sing-box/config.json";
      Restart = "always";
      RestartSec = "5s";
      # Под cache.db из experimental.cache_file (sops/sops.nix): в нём живёт
      # выбранный режим selector'а usa-select, иначе после рестарта юнита
      # маршрут молча откатывался бы к default. Каталог = /var/lib/sing-box.
      StateDirectory = "sing-box";
    };
  };

  # A new Wi-Fi/Ethernet connection can keep the interface name while changing
  # its address/gateway. Drop old SSH and DoH sessions once connectivity returns.
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "sing-box-network-up" ''
        case "''${1:-}" in
          wl*|en*|eth*) ;;
          *) exit 0 ;;
        esac
        case "''${2:-}" in
          up)
            ${pkgs.systemd}/bin/systemctl --no-block try-restart sing-box.service
            ;;
        esac
      '';
    }
  ];

  # Watchdog: прокси каждые 15 секунд проверяет туннель, если мёртв — рестартует sing-box
  # systemd.services."sing-box-watchdog" = {
  #   description = "sing-box tunnel watchdog";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = pkgs.writeShellScript "sing-box-watchdog" ''
  #       set -e
  #       # Проверяем что socks порт отвечает и реально проксирует
  #       if ! ${pkgs.curl}/bin/curl \
  #         --silent \
  #         --max-time 10 \
  #         --proxy socks5h://127.0.0.1:1084 \
  #         http://www.gstatic.com/generate_204 \
  #         -o /dev/null \
  #         -w "%{http_code}" | grep -q "204"; then
  #         echo "sing-box tunnel dead, restarting..."
  #         ${pkgs.systemd}/bin/systemctl restart sing-box.service
  #       fi
  #     '';
  #   };
  # };

  # systemd.timers."sing-box-watchdog" = {
  #   wantedBy = ["timers.target"];
  #   timerConfig = {
  #     OnBootSec = "1m";
  #     OnUnitActiveSec = "15s";
  #     Unit = "sing-box-watchdog.service";
  #   };
  # };
}
