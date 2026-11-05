# «Анонимный режим»: весь трафик ноутбука — только через Tor, всё, что знает
# тебя в лицо, — остановлено.
#
# Включённый режим (system-юнит anon-mode.service):
#   1. Kill-switch (nft table inet anon_mode). Наружу выпускается только
#      процесс tor; весь остальной IPv4 TCP прозрачно заворачивается в
#      TransPort, DNS (UDP/53, любой адрес) — в DNSPort Tor. Остальное, включая
#      весь IPv6 (кроме NDP) и UDP, дропается. Уже открытые соединения рвутся:
#      established мимо Tor тоже не пропускаем.
#   2. Останавливает и runtime-маскирует сервисы, которые ходят на ТВОИ
#      серверы с ТВОИМИ ключами (sing-box, awg-туннели, attic, nix-daemon с
#      токеном кеша, docker, k3s...) и те, что слушают сеть (sshd, cups).
#      Маска нужна, чтобы их не поднял обратно socket/path/NM-dispatcher.
#   3. NetworkManager: случайный MAC на каждое подключение, DHCP client-id
#      от этого MAC (а не DUID от machine-id); переподключает активные
#      Wi-Fi/Ethernet уже со случайным MAC.
#   4. Блокирует Bluetooth радио (rfkill).
# Выключение возвращает ровно то, что было активно до включения.
#
# ⚠️ Чего режим НЕ делает (и не может):
#   * не защищает от тебя самого: логин в свой Google/Telegram/GitHub, git
#     push с back2nix@list.ru, Claude/Codex с твоим токеном — всё это через
#     Tor привяжет анонимную сессию к тебе. Браузер — только `anon-browser`.
#   * не прячет, что ты пользуешься Tor (с мостами — затрудняет).
#   * лучше включать ДО подключения к «чужой» сети: если ноут уже подключился
#     со стабильным MAC, точка доступа его видела.
#   * hostname не меняется: при выключенном dhcp-send-hostname и avahi
#     (module/network-configuration.nix) он в сеть не уходит, а смена на лету
#     ломает Xauthority у X11-приложений текущей сессии.
#
# Секрет anon/tor_bridges (secrets/secrets.yaml) — это фрагмент torrc,
# подключается через %include. Мосты НЕЛЬЗЯ держать в публичном репо: их
# заблокируют, и любое подключение к ним однозначно указывает на тебя.
# Пустой (только комментарий) — Tor ходит напрямую без мостов.
# Заполнить:  sops secrets/secrets.yaml  →  anon.tor_bridges, например:
#   UseBridges 1
#   ClientTransportPlugin obfs4,webtunnel exec <путь к lyrebird, см. ниже>
#   Bridge obfs4 1.2.3.4:443 FINGERPRINT cert=... iat-mode=0
# Путь к lyrebird в стор: `readlink -f $(which lyrebird)`; мосты — у
# @GetBridgesBot в Telegram или https://bridges.torproject.org.
#
# Управление: тумблер «Анонимный режим» в Quick Settings, Ctrl+Alt+A,
# CLI: anon-mode [on|off|toggle|status].
{
  config,
  lib,
  pkgs,
  ...
}: let
  transPort = 9040;
  dnsPort = 9053;
  bridgesInChroot = "/anon-bridges.conf";

  # Глобы юнитов, которые гасим. Несуществующие просто пропускаются.
  stopGlobs = [
    "sing-box*.service"
    "amneziawg-*.service"
    "dnscrypt-proxy.service"
    "blocky.service"
    "atticd.service"
    "nix-daemon.socket"
    "nix-daemon.service"
    "docker.socket"
    "docker.service"
    "docker-registry.service"
    "k3s.service"
    "sshd.service"
    "cups.socket"
    "cups.path"
    "cups.service"
    "fwupd.service"
    "ModemManager.service"
    "chronyd.service"
  ];

  stateDir = "/run/anon-mode";

  path = lib.makeBinPath (with pkgs; [
    coreutils
    gnugrep
    gawk
    systemd
    nftables
    networkmanager
    util-linux # rfkill
    shadow # id
  ]);

  rules = torUid: ''
    table inet anon_mode {
      chain nat_out {
        type nat hook output priority -100; policy accept;
        meta skuid ${torUid} return
        udp dport 53 redirect to :${toString dnsPort}
        ip daddr 127.0.0.0/8 return
        meta nfproto ipv4 tcp flags & (syn | ack) == syn redirect to :${toString transPort}
      }
      chain filter_out {
        type filter hook output priority 10; policy drop;
        oif "lo" accept
        ip daddr 127.0.0.0/8 accept
        meta skuid ${torUid} accept
        udp sport 68 udp dport 67 accept comment "DHCPv4"
        icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept
      }
      chain filter_in {
        type filter hook input priority -10; policy drop;
        iif "lo" accept
        ct state established,related accept
        udp sport 67 udp dport 68 accept comment "DHCPv4"
        icmpv6 type { nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
      }
      chain fwd {
        type filter hook forward priority -10; policy drop;
      }
    }
  '';

  nmConf = ''
    # anon-mode: секции [connection-*] имеют приоритет над [connection]
    [connection-anon-mode]
    wifi.cloned-mac-address=random
    ethernet.cloned-mac-address=random
    ipv4.dhcp-client-id=mac
    ipv4.dhcp-iaid=mac
    ipv6.dhcp-duid=ll
    ipv4.dhcp-send-hostname=0
    ipv6.dhcp-send-hostname=0
  '';

  reconnect = ''
    nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '($2=="wifi"||$2=="ethernet") && $3=="connected"{print $1}' |
      while read -r dev; do
        nmcli device disconnect "$dev" >/dev/null 2>&1 || true
        nmcli device connect "$dev" >/dev/null 2>&1 || echo "anon-mode: $dev не переподключился" >&2
      done
  '';

  onScript = pkgs.writeShellScript "anon-mode-on" ''
    set -u
    PATH=${path}
    mkdir -p ${stateDir}

    # 1. Сначала kill-switch — чтобы между шагами ничего не утекло.
    torUid=$(id -u tor)
    nft delete table inet anon_mode 2>/dev/null || true
    nft -f - <<EOF
    ${rules "$torUid"}
    EOF
    systemctl start tor.service

    # 2. Гасим и маскируем; запоминаем, что было активно.
    : > ${stateDir}/units
    for u in $(systemctl list-units --all --plain --no-legend ${lib.escapeShellArgs stopGlobs} | awk '{print $1}'); do
      if systemctl is-active --quiet "$u"; then echo "$u" >> ${stateDir}/units; fi
      systemctl mask --runtime --quiet "$u" 2>/dev/null || true
      systemctl stop "$u" 2>/dev/null || true
    done

    # 3. Bluetooth.
    if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: no"; then
      touch ${stateDir}/bt-was-on
    fi
    rfkill block bluetooth || true

    # 4. Случайный MAC и переподключение.
    mkdir -p /run/NetworkManager/conf.d
    cat > /run/NetworkManager/conf.d/99-anon-mode.conf <<'EOF'
    ${nmConf}
    EOF
    systemctl reload NetworkManager
    ${reconnect}
  '';

  offScript = pkgs.writeShellScript "anon-mode-off" ''
    set -u
    PATH=${path}

    systemctl stop tor.service || true

    rm -f /run/NetworkManager/conf.d/99-anon-mode.conf
    systemctl reload NetworkManager || true

    # Kill-switch снимаем ДО запуска сервисов, иначе они стартуют в стену.
    nft delete table inet anon_mode 2>/dev/null || true

    # Возвращаемся в обычную сеть со своим stable MAC.
    ${reconnect}

    if [ -f ${stateDir}/units ]; then
      while read -r u; do
        systemctl unmask --runtime --quiet "$u" 2>/dev/null || true
      done < ${stateDir}/units
    fi
    # Маски сняты у всех, даже у тех, что не были активны.
    for u in $(systemctl list-unit-files --plain --no-legend --state=masked-runtime | awk '{print $1}'); do
      for g in ${lib.escapeShellArgs stopGlobs}; do
        case "$u" in $g) systemctl unmask --runtime --quiet "$u" 2>/dev/null || true ;; esac
      done
    done
    if [ -f ${stateDir}/units ]; then
      # Сокеты первыми, потом сервисы.
      grep -E '\.(socket|path)$' ${stateDir}/units | xargs -r systemctl start || true
      grep -E '\.service$' ${stateDir}/units | xargs -r systemctl start --no-block || true
    fi

    if [ -f ${stateDir}/bt-was-on ]; then rfkill unblock bluetooth || true; fi
    rm -rf ${stateDir}
  '';

  anonMode = pkgs.writeShellScriptBin "anon-mode" ''
    set -u
    PATH=${lib.makeBinPath [pkgs.systemd pkgs.libnotify]}:$PATH
    UNIT=anon-mode.service
    active() { systemctl is-active --quiet "$UNIT"; }
    case "''${1:-toggle}" in
      on) systemctl start "$UNIT" ;;
      off) systemctl stop "$UNIT" ;;
      status)
        if active; then echo ON; else echo OFF; fi
        ;;
      toggle)
        if active; then
          systemctl stop "$UNIT"
          notify-send -i network-wired "Анонимный режим выключен" "Обычная сеть, сервисы возвращены."
        else
          systemctl start "$UNIT"
          notify-send -u critical -i security-high "Анонимный режим включён" \
            "Весь трафик — через Tor. Браузер: anon-browser. Не логинься в свои аккаунты, не делай git push."
        fi
        ;;
      *) echo "usage: anon-mode [on|off|toggle|status]" >&2; exit 2 ;;
    esac
  '';

  # Tor Browser без своего tor: ходит через системный kill-switch.
  # Отпечаток браузера (UTC, en-US, letterboxing) — штатный Tor Browser.
  anonBrowser = pkgs.writeShellScriptBin "anon-browser" ''
    if ! systemctl is-active --quiet anon-mode.service; then
      echo "anon-mode выключен — включи сначала: anon-mode on" >&2
      exit 1
    fi
    export TOR_PROVIDER=none TOR_SKIP_LAUNCH=1 TOR_TRANSPROXY=1
    exec ${pkgs.tor-browser}/bin/tor-browser "$@"
  '';
in {
  sops.secrets."anon/tor_bridges" = {
    owner = "tor";
    group = "tor";
    mode = "0400";
    restartUnits = ["tor.service"];
  };

  services.tor = {
    enable = true;
    client = {
      enable = true;
      dns.enable = true; # DNSPort 127.0.0.1:9053 + automap .onion
    };
    settings = {
      TransPort = [
        {
          addr = "127.0.0.1";
          port = transPort;
        }
      ];
      "%include" = bridgesInChroot;
    };
  };

  systemd.services.tor = {
    # Только по включению режима: постоянный Tor сам по себе отпечаток.
    wantedBy = lib.mkForce [];
    # tor живёт в RootDirectory= без /run/secrets — пробрасываем один файл.
    serviceConfig.BindReadOnlyPaths = [
      "${config.sops.secrets."anon/tor_bridges".path}:${bridgesInChroot}"
    ];
  };

  systemd.services.anon-mode = {
    description = "Anonymous mode: Tor-only kill-switch, identity services stopped";
    # Никаких wantedBy: только руками.
    after = ["NetworkManager.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = onScript;
      ExecStop = offScript;
      TimeoutSec = 120;
    };
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "anon-mode.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [anonMode anonBrowser pkgs.obfs4];
}
