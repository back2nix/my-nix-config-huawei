# Откат на НЕзашифрованный DNS — только по тумблеру.
#
# По умолчанию (и после каждой перезагрузки) DNS строго зашифрованный:
#   приложение → blocky (127.0.0.1:53) → dnscrypt-proxy (127.0.0.1:5300)
#             → sing-box socks 1082 → Quad9 DoH
# Если тоннель лежит — имена НЕ резолвятся вообще. Это и есть цель: раньше
# откат был молчаливым, и открытым текстом запросы уходили в трёх местах:
#   1. blocky: upstream'ы 9.9.9.9 / 149.112.112.112 после 5300 (strict);
#   2. /etc/resolv.conf: 8.8.8.8 и 1.1.1.1 после 127.0.0.1 при timeout:1 —
#      любой ответ blocky дольше секунды (а DoH через тоннель бывает 2–8 с)
#      уходил в Google открыто, тоннель при этом мог быть жив;
#   3. blocky bootstrapDns: имена хостов блок-листов при каждом старте.
#
# Тумблер «Открытый DNS (откат)» в Quick Settings / `dns-fallback on`
# возвращает все три пункта как было. Нужен, когда:
#   * captive portal (отель, аэропорт): его страницу отдаёт только DNS сети;
#   * тоннель не поднимается, а чинить его надо с рабочим DNS;
#   * холодный старт с неверными часами: TLS к Quad9 не проходит → нет DNS →
#     chrony не резолвит NTS-серверы → часы не чинятся. Включи откат, дождись
#     синхронизации, выключи.
# Состояние живёт в /run: перезагрузка всегда возвращает строгий режим.
#
# Строгий режим ещё и принудительный (nft table inet dns_strict): исходящий
# порт 53 через физические интерфейсы (wl*/en*/eth*/usb*/ww*) отклоняется для
# всех процессов, а не только для тех, кто читает resolv.conf. `dig @8.8.8.8`
# и программы с зашитым резолвером получат отказ. DNS внутри туннелей (awg-*)
# и контейнеров (forward, не output) не затронут.
#
# Переключение перезапускает blocky (он перечитывает блок-листы, ~секунды).
{
  config,
  lib,
  pkgs,
  ...
}: let
  yaml = pkgs.formats.yaml {};
  blocky = lib.getExe config.services.blocky.package;

  flag = "/run/dns-fallback-on";
  resolvFile = "/run/dns-resolv.conf";

  plainUpstreams = ["9.9.9.9" "149.112.112.112"];
  plainResolvers = ["8.8.8.8" "1.1.1.1"];

  # services.blocky.settings (module/blocky/default.nix) — строгий вариант.
  strictSettings = config.services.blocky.settings;
  fallbackSettings = lib.recursiveUpdate strictSettings {
    bootstrapDns = ["9.9.9.9" "1.1.1.1"];
    upstreams.groups.default = strictSettings.upstreams.groups.default ++ plainUpstreams;
  };
  strictCfg = yaml.generate "blocky-strict.yaml" strictSettings;
  fallbackCfg = yaml.generate "blocky-fallback.yaml" fallbackSettings;

  # Один резолвер и запас по времени: DoH через тоннель бывает медленным,
  # а откатываться здесь некуда.
  strictResolv = ''
    nameserver 127.0.0.1
    options edns0 trust-ad timeout:5 attempts:2
  '';
  fallbackResolv = ''
    nameserver 127.0.0.1
    ${lib.concatMapStringsSep "\n" (ip: "nameserver ${ip}") plainResolvers}
    options edns0 trust-ad timeout:1 attempts:1
  '';
  strictResolvFile = pkgs.writeText "resolv-strict.conf" strictResolv;
  fallbackResolvFile = pkgs.writeText "resolv-fallback.conf" fallbackResolv;

  # Первые две строки делают загрузку идемпотентной.
  strictRules = pkgs.writeText "dns_strict.nft" ''
    table inet dns_strict
    delete table inet dns_strict
    table inet dns_strict {
      chain output {
        type filter hook output priority -10; policy accept;
        oifname "wl*" meta l4proto { tcp, udp } th dport 53 counter reject
        oifname "en*" meta l4proto { tcp, udp } th dport 53 counter reject
        oifname "eth*" meta l4proto { tcp, udp } th dport 53 counter reject
        oifname "usb*" meta l4proto { tcp, udp } th dport 53 counter reject
        oifname "ww*" meta l4proto { tcp, udp } th dport 53 counter reject
      }
    }
  '';

  path = lib.makeBinPath [pkgs.coreutils pkgs.nftables pkgs.systemd];

  # install пишет во временный файл и переименовывает: читатели resolv.conf
  # никогда не видят его пустым.
  setResolv = file: "install -m 0644 ${file} ${resolvFile}.tmp && mv -f ${resolvFile}.tmp ${resolvFile}";

  onScript = pkgs.writeShellScript "dns-fallback-on" ''
    set -u
    PATH=${path}
    touch ${flag}
    nft delete table inet dns_strict 2>/dev/null || true
    ${setResolv fallbackResolvFile}
    systemctl try-restart blocky.service || true
  '';

  # Порядок: сначала закрываем открытый путь, потом перезапускаем blocky.
  offScript = pkgs.writeShellScript "dns-fallback-off" ''
    set -u
    PATH=${path}
    rm -f ${flag}
    ${setResolv strictResolvFile}
    nft -f ${strictRules}
    systemctl try-restart blocky.service || true
  '';

  # При загрузке и при switch: правила ставим, только если откат не включён.
  strictBoot = pkgs.writeShellScript "dns-strict" ''
    set -u
    PATH=${path}
    if [ -e ${flag} ]; then exit 0; fi
    ${setResolv strictResolvFile}
    nft -f ${strictRules}
  '';

  blockyStart = pkgs.writeShellScript "blocky-start" ''
    if [ -e ${flag} ]; then cfg=${fallbackCfg}; else cfg=${strictCfg}; fi
    exec ${blocky} --config "$cfg"
  '';

  dnsFallback = pkgs.writeShellScriptBin "dns-fallback" ''
    set -u
    PATH=${lib.makeBinPath [pkgs.systemd pkgs.libnotify]}:$PATH
    UNIT=dns-fallback.service
    active() { systemctl is-active --quiet "$UNIT"; }
    case "''${1:-toggle}" in
      on) systemctl start "$UNIT" ;;
      off) systemctl stop "$UNIT" ;;
      status)
        if active; then echo ON; else echo OFF; fi
        ;;
      toggle)
        if active; then
          systemctl stop "$UNIT" || exit 1
          notify-send -i security-high "Открытый DNS выключен" \
            "Только зашифрованный DNS через тоннель. Нет тоннеля — нет резолва."
        else
          systemctl start "$UNIT" || exit 1
          notify-send -u critical -i dialog-warning "Открытый DNS включён" \
            "Если зашифрованный DNS не отвечает, запросы идут открытым текстом (9.9.9.9, 8.8.8.8, 1.1.1.1). Не забудь выключить."
        fi
        ;;
      *) echo "usage: dns-fallback [on|off|toggle|status]" >&2; exit 2 ;;
    esac
  '';
in {
  # /etc/resolv.conf — симлинк на файл в /run, чтобы режим менялся на лету.
  # Пока файла нет (самое начало загрузки), glibc по умолчанию идёт на
  # 127.0.0.1 — то есть тоже в blocky, а не наружу.
  environment.etc."resolv.conf".source = resolvFile;
  systemd.tmpfiles.rules = [
    "C ${resolvFile} 0644 root root - ${strictResolvFile}"
  ];

  systemd.services.blocky.serviceConfig.ExecStart = lib.mkForce blockyStart;
  # Блок-листы теперь качаются через зашифрованный DNS; на старте тоннель
  # может ещё подниматься — даём ~5 минут повторов вместо трёх попыток подряд.
  services.blocky.settings.blocking.loading.downloads = {
    attempts = 20;
    cooldown = "15s";
  };

  systemd.services.dns-strict = {
    description = "Strict DNS: reject plaintext port 53 on physical interfaces";
    after = ["nftables.service"];
    wants = ["nftables.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = strictBoot;
    };
  };

  systemd.services.dns-fallback = {
    description = "Allow fallback to unencrypted DNS";
    # Никаких wantedBy: только руками, и только до перезагрузки.
    after = ["nftables.service" "dns-strict.service"];
    # Пересборка не должна молча выключать откат посреди работы.
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = onScript;
      ExecStop = offScript;
    };
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "dns-fallback.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [dnsFallback];
}
