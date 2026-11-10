# «Анонимный режим»: весь трафик ноутбука — только через Tor, всё, что знает
# тебя в лицо, — остановлено.
#
# Включённый режим (system-юнит anon-mode.service):
#   1. Kill-switch (nft table inet anon_mode). Наружу выпускается только
#      процесс tor; весь остальной IPv4 TCP прозрачно заворачивается в
#      TransPort, DNS (UDP/53, любой адрес) — в DNSPort Tor. Остальное, включая
#      ВЕСЬ IPv6 (и NDP/RA тоже) и UDP, дропается. Уже открытые соединения
#      рвутся: established мимо Tor тоже не пропускаем.
#      NDP закрыт намеренно: link-local адрес (stable-privacy) выводится из
#      ID профиля, а не из MAC, и пережил бы смену MAC — та же сеть связала бы
#      анонимную сессию с обычной.
#   2. Останавливает и runtime-маскирует сервисы, которые ходят на ТВОИ
#      серверы с ТВОИМИ ключами (sing-box, awg-туннели, attic, nix-daemon с
#      токеном кеша, docker, k3s...) и те, что слушают сеть (sshd, cups).
#      Маска нужна, чтобы их не поднял обратно socket/path/NM-dispatcher.
#   3. NetworkManager: случайный MAC на каждое подключение, DHCP client-id
#      от этого MAC (а не DUID от machine-id), случайный stable-id;
#      переподключает активные Wi-Fi/Ethernet уже со случайным MAC.
#      DHCP-аренды (/var/lib/NetworkManager/internal-*.lease) на время режима
#      убираются: иначе NM при переподключении просит у DHCP-сервера свой
#      прежний IP (INIT-REBOOT) и этим называет себя. Аренды анонимной сессии
#      при выключении стираются, прежние возвращаются.
#   4. Блокирует Bluetooth радио (rfkill).
#   5. Замораживает (SIGSTOP) приложения с твоими аккаунтами — список
#      freezeApps ниже. Иначе они переподключатся через Tor со своими токенами
#      и привяжут цепочки к тебе; заодно в замороженное окно ничего не введёшь.
#      Запущенное ПОСЛЕ включения режима не замораживается.
# Выключение возвращает ровно то, что было активно до включения.
#
# «С чистой сети» (anon-mode fresh, Ctrl+Alt+Shift+A): то же, но сеть не
# переподключается, а отключается и ждёт. Переподключение к той же точке с
# новым MAC в ту же секунду тривиально связывается по времени, поэтому:
# включил fresh дома/в дороге → пришёл в другую сеть → подключился руками.
# Точка доступа видит только случайный MAC и никогда не видела постоянный.
#
# ⚠️ Чего режим НЕ делает (и не может):
#   * не защищает от тебя самого: логин в свой Google/Telegram/GitHub, git
#     push с back2nix@list.ru, Claude/Codex с твоим токеном — всё это через
#     Tor привяжет анонимную сессию к тебе. Браузер — только `anon-browser`
#     (Tor Browser в bwrap: пустой tmpfs-дом, свой machine-id/hostname, без
#     /sys (DMI, серийники), без D-Bus; всё стирается при закрытии. Звук —
#     только с `anon-browser --audio`).
#   * не прячет, что ты пользуешься Tor (с мостами — затрудняет).
#   * лучше включать ДО подключения к «чужой» сети: если ноут уже подключился
#     со стабильным MAC, точка доступа его видела.
#   * hostname не меняется: при выключенном dhcp-send-hostname и avahi
#     (module/network-configuration.nix) он в сеть не уходит, а смена на лету
#     ломает Xauthority у X11-приложений текущей сессии.
#
# Мосты. Секрет anon/tor_bridges (secrets/secrets.yaml) — строки мостов ровно
# в том виде, как их выдаёт BridgeDB, по одной на строку:
#   obfs4 1.2.3.4:443 FINGERPRINT cert=... iat-mode=0
#   webtunnel [2001:db8::1]:443 FINGERPRINT url=https://... ver=0.0.1
# Заполнить:  sops secrets/secrets.yaml  →  anon.tor_bridges; мосты — у
# @GetBridgesBot в Telegram или https://bridges.torproject.org.
# `UseBridges 1` и `ClientTransportPlugin ... lyrebird` дописывает
# anon-bridges.service (путь к lyrebird в сторе меняется с обновлениями — в
# секрете ему не место; старые такие строки в секрете игнорируются). Прочие
# строки секрета уходят в torrc как есть.
# Мосты НЕЛЬЗЯ держать в публичном репо: их заблокируют, и любое подключение
# к ним однозначно указывает на тебя.
# Пустой секрет — Tor ходит напрямую, провайдер видит сам факт Tor; режим об
# этом предупреждает при включении. Проверить: `anon-mode bridges`.
#
# Управление: тумблер «Анонимный режим» в Quick Settings, Ctrl+Alt+A,
# CLI: anon-mode [on|fresh|off|toggle|status|bridges].
{
  config,
  lib,
  pkgs,
  ...
}: let
  transPort = 9040;
  dnsPort = 9053;
  bridgesInChroot = "/anon-bridges.conf";
  bridgesDir = "/run/anon-bridges";
  freshFlag = "/run/anon-mode-fresh";
  nmLeases = "/var/lib/NetworkManager";

  # Что замораживать при включении: регэкспы (без учёта регистра) по пути к
  # бинарнику процесса и по имени его app-*.scope (так ловятся flatpak'и).
  # Только GUI с аккаунтами. CLI в терминале (claude, codex, ssh, git) сюда не
  # добавлять: SIGSTOP отдаст терминал шеллу, после выключения придётся `fg`.
  freezeApps = [
    "google[-.]chrome"
    "chromium"
    "brave"
    "vivaldi"
    "firefox"
    "librewolf"
    "thunderbird"
    "telegram"
    "discord"
    "slack"
    "signal-desktop"
    "element-desktop"
    "vscode"
    "zoom"
    "steam"
    "spotify"
  ];
  freezeRe = lib.concatStringsSep "|" freezeApps;
  # Анонимные браузеры не трогаем, даже если совпали с "firefox".
  freezeSkipRe = "tor-browser|mullvad-browser";

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
    findutils
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
      }
      chain filter_in {
        type filter hook input priority -10; policy drop;
        iif "lo" accept
        ct state established,related accept
        udp sport 67 udp dport 68 accept comment "DHCPv4"
      }
      # Не называть цепочку "fwd": это ключевое слово nft, таблица не загрузится.
      chain forward_drop {
        type filter hook forward priority -10; policy drop;
      }
    }
  '';

  nmConf = ''
    # anon-mode: секции [connection-*] имеют приоритет над [connection]
    [connection-anon-mode]
    connection.stable-id=''${RANDOM}
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

  # После `device disconnect` NM сам это устройство не поднимает (autoconnect
  # блокируется до ручного подключения) — ровно то, что нужно для fresh.
  disconnectAll = ''
    nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '($2=="wifi"||$2=="ethernet") && $3 ~ /^connect/{print $1}' |
      while read -r dev; do
        nmcli device disconnect "$dev" >/dev/null 2>&1 || echo "anon-mode: $dev не отключился" >&2
      done
  '';

  # SIGSTOP всем процессам обычных пользователей, чей exe или app-*.scope
  # совпал с freezeApps. Два прохода: второй ловит успевших форкнуться.
  freezeScript = ''
    shopt -s nocasematch
    : > ${stateDir}/frozen
    : > ${stateDir}/frozen-names
    for pass in 1 2; do
      for p in $(find /proc -maxdepth 1 -regex '/proc/[0-9]+' -uid +999 2>/dev/null); do
        exe=$(readlink "$p/exe" 2>/dev/null) || continue
        [[ "$exe" =~ ${freezeSkipRe} ]] && continue
        cg=""
        read -r cg < "$p/cgroup" 2>/dev/null || true
        cg=''${cg##*/}
        cg=''${cg//\\x2d/-}
        [[ "$cg" == app-* ]] || cg=""
        if [[ "$exe" =~ ${freezeRe} ]]; then
          name=''${exe##*/}
        elif [[ -n "$cg" && "$cg" =~ ${freezeRe} ]]; then
          name=''${cg#app-}
          name=''${name%-*}
        else
          continue
        fi
        pid=''${p#/proc/}
        if kill -STOP "$pid" 2>/dev/null; then
          echo "$pid" >> ${stateDir}/frozen
          echo "$name" >> ${stateDir}/frozen-names
        fi
      done
    done
    shopt -u nocasematch
    sort -u -o ${stateDir}/frozen ${stateDir}/frozen
    sort -u -o ${stateDir}/frozen-names ${stateDir}/frozen-names
  '';

  onScript = pkgs.writeShellScript "anon-mode-on" ''
    set -u
    PATH=${path}
    mkdir -p ${stateDir}

    # Флаг «с чистой сети» ставит anon-mode-fresh.service прямо перед нами.
    # Старше 30 с — протухший (запуск тогда не состоялся), игнорируем.
    fresh=0
    if [ -e ${freshFlag} ]; then
      if [ $(( $(date +%s) - $(stat -c %Y ${freshFlag}) )) -lt 30 ]; then fresh=1; fi
      rm -f ${freshFlag}
    fi

    # 1. Сначала kill-switch — чтобы между шагами ничего не утекло.
    torUid=$(id -u tor)
    nft delete table inet anon_mode 2>/dev/null || true
    if ! nft -f - <<EOF
    ${rules "$torUid"}
    EOF
    then
      # Без kill-switch режим хуже выключенного: создаёт ложное чувство защиты.
      echo "anon-mode: kill-switch не загрузился — режим НЕ включён" >&2
      rm -rf ${stateDir}
      exit 1
    fi
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

    # 4. Замораживаем приложения с аккаунтами (до смены сети: после неё они
    #    уже побежали бы переподключаться через Tor).
    ${freezeScript}

    # 5. Случайный MAC, чистые DHCP-аренды и переподключение (или, для fresh,
    #    отключение: дальше подключаешься руками уже в другой сети).
    mkdir -p /run/NetworkManager/conf.d
    cat > /run/NetworkManager/conf.d/99-anon-mode.conf <<'EOF'
    ${nmConf}
    EOF
    systemctl reload NetworkManager
    mkdir -p ${stateDir}/leases
    find ${nmLeases} -maxdepth 1 -name 'internal-*.lease' -exec mv -t ${stateDir}/leases {} + 2>/dev/null || true
    if [ "$fresh" = 1 ]; then
      touch ${stateDir}/fresh
      ${disconnectAll}
    else
      ${reconnect}
    fi
  '';

  offScript = pkgs.writeShellScript "anon-mode-off" ''
    set -u
    PATH=${path}

    systemctl stop tor.service || true

    rm -f /run/NetworkManager/conf.d/99-anon-mode.conf
    systemctl reload NetworkManager || true

    # Kill-switch снимаем ДО запуска сервисов, иначе они стартуют в стену.
    nft delete table inet anon_mode 2>/dev/null || true

    # Аренды анонимной сессии стираем, прежние возвращаем.
    find ${nmLeases} -maxdepth 1 -name 'internal-*.lease' -delete 2>/dev/null || true
    if [ -d ${stateDir}/leases ]; then
      find ${stateDir}/leases -maxdepth 1 -name 'internal-*.lease' -exec mv -t ${nmLeases} {} + 2>/dev/null || true
    fi

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

    # Размораживаем. SIGCONT неостановленному процессу безвреден, так что
    # переиспользованный за это время pid не страшен.
    if [ -s ${stateDir}/frozen ]; then
      while read -r pid; do kill -CONT "$pid" 2>/dev/null || true; done < ${stateDir}/frozen
    fi
    rm -rf ${stateDir}
  '';

  anonMode = pkgs.writeShellScriptBin "anon-mode" ''
    set -u
    PATH=${lib.makeBinPath [pkgs.systemd pkgs.libnotify pkgs.coreutils]}:$PATH
    UNIT=anon-mode.service
    active() { systemctl is-active --quiet "$UNIT"; }
    bridges() { cat ${bridgesDir}/count 2>/dev/null || echo 0; }
    # Текст для уведомления: мосты и что заморожено.
    summary() {
      n=$(bridges)
      if [ "$n" -gt 0 ]; then echo "Мосты: $n."; else echo "⚠ Мостов нет: провайдер видит, что это Tor."; fi
      if [ -s ${stateDir}/frozen-names ]; then
        echo "Заморожено: $(paste -sd, ${stateDir}/frozen-names | sed 's/,/, /g')."
      fi
    }
    case "''${1:-toggle}" in
      on)
        systemctl start "$UNIT" || exit 1
        if [ "$(bridges)" -eq 0 ]; then
          notify-send -u critical -i security-low "Анонимный режим без мостов" \
            "Провайдер видит, что ты в Tor. Мосты: sops secrets/secrets.yaml → anon.tor_bridges."
        fi
        ;;
      fresh)
        if active; then
          echo "anon-mode уже включён: сначала anon-mode off" >&2
          exit 1
        fi
        systemctl start anon-mode-fresh.service && systemctl start "$UNIT" || exit 1
        notify-send -u critical -i security-high "Анонимный режим: с чистой сети" \
          "Сеть отключена. Перейди в ДРУГУЮ сеть и подключись вручную — MAC будет случайным. $(summary)"
        ;;
      off) systemctl stop "$UNIT" ;;
      status)
        if active; then echo ON; else echo OFF; fi
        ;;
      bridges)
        n=$(bridges)
        if [ "$n" -gt 0 ]; then
          echo "мостов в секрете anon/tor_bridges: $n"
        else
          echo "мостов нет — Tor ходит напрямую, провайдер это видит"
          echo "заполнить: sops secrets/secrets.yaml → anon.tor_bridges (см. module/anon-mode.nix)"
          exit 1
        fi
        ;;
      toggle)
        if active; then
          systemctl stop "$UNIT"
          notify-send -i network-wired "Анонимный режим выключен" "Обычная сеть, сервисы и приложения возвращены."
        else
          systemctl start "$UNIT" || exit 1
          notify-send -u critical -i security-high "Анонимный режим включён" \
            "Весь трафик — через Tor. Браузер: anon-browser. Не логинься в свои аккаунты, не делай git push. $(summary)"
        fi
        ;;
      *) echo "usage: anon-mode [on|fresh|off|toggle|status|bridges]" >&2; exit 2 ;;
    esac
  '';

  # Tor Browser без своего tor (ходит через системный kill-switch), запертый
  # в bwrap. Отпечаток браузера (UTC, en-US, letterboxing) — штатный.
  # Чего внутри нет: твоего $HOME (пустой tmpfs, пропадает при закрытии —
  # загрузки тоже), /etc (свой machine-id, passwd с юзером "user"), hostname
  # (localhost), /sys (DMI, серийники, MAC), /dev/dri (рендер программный),
  # D-Bus (keyring, порталы, уведомления), X11. Сеть общая с хостом — она и
  # так закрыта kill-switch'ем.
  anonBrowser = pkgs.writeShellScriptBin "anon-browser" ''
    set -u
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet anon-mode.service; then
      echo "anon-mode выключен — включи сначала: anon-mode on" >&2
      exit 1
    fi
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "anon-browser: нужен Wayland-сеанс (X11 даёт окну доступ к чужому вводу)" >&2
      exit 1
    fi
    rt=''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}
    wl=$WAYLAND_DISPLAY
    case "$wl" in /*) ;; *) wl="$rt/$wl" ;; esac

    audio=()
    if [ "''${1:-}" = "--audio" ]; then
      shift
      # PulseAudio-сокет — это ещё и микрофон, и имена устройств. Только явно.
      audio=(--ro-bind "$rt/pulse/native" /run/user/1000/pulse/native
             --setenv PULSE_SERVER unix:/run/user/1000/pulse/native)
    fi

    uuid() { ${pkgs.coreutils}/bin/tr -d - < /proc/sys/kernel/random/uuid; }

    exec ${pkgs.bubblewrap}/bin/bwrap \
      --unshare-user --unshare-ipc --unshare-pid --unshare-uts --unshare-cgroup \
      --uid 1000 --gid 1000 --hostname localhost \
      --die-with-parent --new-session --clearenv \
      --ro-bind /nix/store /nix/store \
      --proc /proc --dev /dev --tmpfs /tmp \
      --ro-bind-data 10 /proc/cmdline \
      --ro-bind-data 11 /proc/sys/kernel/random/boot_id \
      --dir /etc \
      --file 12 /etc/machine-id \
      --file 13 /etc/passwd \
      --file 14 /etc/group \
      --file 15 /etc/resolv.conf \
      --file 16 /etc/hosts \
      --tmpfs /home/user \
      --perms 0700 --dir /run/user/1000 \
      --ro-bind "$wl" /run/user/1000/wayland-0 \
      "''${audio[@]}" \
      --chdir /home/user \
      --setenv HOME /home/user --setenv USER user --setenv LOGNAME user \
      --setenv PATH ${pkgs.coreutils}/bin \
      --setenv XDG_RUNTIME_DIR /run/user/1000 \
      --setenv WAYLAND_DISPLAY wayland-0 --setenv MOZ_ENABLE_WAYLAND 1 \
      --setenv TZ UTC --setenv LANG C.UTF-8 \
      --setenv TOR_PROVIDER none --setenv TOR_SKIP_LAUNCH 1 --setenv TOR_TRANSPROXY 1 \
      ${pkgs.tor-browser}/bin/tor-browser "$@" \
      10< <(echo) \
      11< <(${pkgs.coreutils}/bin/cat /proc/sys/kernel/random/uuid) \
      12< <(uuid) \
      13< <(echo "user:x:1000:1000:user:/home/user:/bin/sh") \
      14< <(echo "user:x:1000:") \
      15< <(echo "nameserver 127.0.0.1") \
      16< <(echo "127.0.0.1 localhost")
  '';

  # Секрет -> фрагмент torrc. Строки мостов в «сыром» виде BridgeDB получают
  # префикс Bridge; UseBridges/ClientTransportPlugin дописываем сами.
  bridgesScript = pkgs.writeShellScript "anon-bridges" ''
    set -u
    PATH=${lib.makeBinPath [pkgs.coreutils]}
    umask 077
    src=${config.sops.secrets."anon/tor_bridges".path}
    n=0
    out=""
    if [ -r "$src" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        line="''${line#"''${line%%[![:space:]]*}"}"
        case "$line" in
          "" | "#"*) continue ;;
          UseBridges* | ClientTransportPlugin*) continue ;;
          Bridge[[:space:]]*) n=$((n + 1)) ;;
          obfs4[[:space:]]* | webtunnel[[:space:]]* | snowflake[[:space:]]* | meek_lite[[:space:]]* | [0-9]*.[0-9]*:[0-9]* | "["*)
            line="Bridge $line"
            n=$((n + 1))
            ;;
        esac
        out+="$line"$'\n'
      done < "$src"
    fi
    if [ "$n" -gt 0 ]; then
      out+="UseBridges 1"$'\n'
      out+="ClientTransportPlugin meek_lite,obfs4,snowflake,webtunnel exec ${pkgs.obfs4}/bin/lyrebird"$'\n'
    fi
    printf '%s' "$out" > ${bridgesDir}/bridges.conf
    chown tor:tor ${bridgesDir}/bridges.conf
    chmod 0400 ${bridgesDir}/bridges.conf
    # Число мостов — не секрет, его читает `anon-mode bridges` от пользователя.
    echo "$n" > ${bridgesDir}/count
    chmod 0644 ${bridgesDir}/count
  '';
in {
  # Читает только root (anon-bridges.service). restartUnits на tor.service
  # ставить НЕЛЬЗЯ: активация «рестартит» и остановленный юнит, то есть
  # поднимает Tor при выключенном режиме (так он и висел сутками).
  sops.secrets."anon/tor_bridges" = {
    mode = "0400";
    restartUnits = ["anon-bridges.service"];
  };

  systemd.services.anon-bridges = {
    description = "Render Tor bridges secret into a torrc fragment";
    wantedBy = ["multi-user.target"];
    requiredBy = ["tor.service"];
    before = ["tor.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "anon-bridges";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = true;
      ExecStart = bridgesScript;
    };
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
    # Страховка от случайного старта (nixos-rebuild рестартит изменившиеся
    # юниты, кто-то дёрнул руками): без включённого режима tor не запустится.
    unitConfig.ConditionPathExists = stateDir;
    # tor живёт в RootDirectory= без /run — пробрасываем один файл.
    serviceConfig.BindReadOnlyPaths = [
      "${bridgesDir}/bridges.conf:${bridgesInChroot}"
    ];
  };

  # Флаг для `anon-mode fresh`: у oneshot-юнита нет аргументов, а писать в
  # /run пользователь не может.
  systemd.services.anon-mode-fresh = {
    description = "Arm anon-mode to start disconnected (fresh network)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/touch ${freshFlag}";
    };
  };

  systemd.services.anon-mode = {
    description = "Anonymous mode: Tor-only kill-switch, identity services stopped";
    # Никаких wantedBy: только руками.
    after = ["NetworkManager.service" "anon-mode-fresh.service"];
    # Пересборка не должна дёргать включённый режим: рестарт = секунды без
    # kill-switch.
    restartIfChanged = false;
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
          (action.lookup("unit") == "anon-mode.service" ||
           action.lookup("unit") == "anon-mode-fresh.service") &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [anonMode anonBrowser pkgs.obfs4];
}
