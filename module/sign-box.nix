# module/sing-box.nix
{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  systemd.services."sing-box" = {
    enable = true;
    description = "sing-box proxy";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs-unstable.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config.json".path}";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  # Watchdog: china каждые 15 секунд проверяет туннель, если мёртв — рестартует sing-box
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
