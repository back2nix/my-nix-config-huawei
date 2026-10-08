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
  singBox = (pkgs-unstable.sing-box.override {
    withNaiveOutbound = false;
  }).overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace protocol/ssh/outbound.go \
        --replace-fail 'client.Dial(network, destination.String())' \
                       'client.DialContext(ctx, network, destination.String())'
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
      ExecStart = "${singBox}/bin/sing-box run -c ${config.sops.templates."sing-box-config.json".path}";
      Restart = "always";
      RestartSec = "5s";
      # Под cache.db из experimental.cache_file (sops/sops.nix): в нём живёт
      # выбранный режим selector'а usa-select, иначе после рестарта юнита
      # маршрут молча откатывался бы к default. Каталог = /var/lib/sing-box.
      StateDirectory = "sing-box";
    };
  };

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
