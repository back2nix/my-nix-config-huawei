{
  config,
  pkgs,
  ...
}: let
  # ☢️ ПАРАМЕТРЫ ОБФУСКАЦИИ — ОБЯЗАНЫ ПОБАЙТОВО СОВПАДАТЬ С СЕРВЕРОМ.
  # Источник истины — casino-vps/modules/wireguard.nix (тот же блок).
  # Расхождение хотя бы в одном числе = рукопожатие не проходит вообще, и в
  # логах это выглядит как тишина, а не как внятная ошибка.
  obfuscation = ''
    Jc = 5
    Jmin = 61
    Jmax = 882
    S1 = 31
    S2 = 63
    H1 = 103733627
    H2 = 1188211264
    H3 = 1851409075
    H4 = 1947645755
  '';

  # ☢️ ПОРТ СЕРВЕРА ДЛЯ ХЕНДШЕЙКА — ПЕРЕКЛЮЧАТЕЛЬ, А НЕ КОНСТАНТА.
  # Сервер слушает 51820 и ДОПОЛНИТЕЛЬНО принимает хендшейк на UDP/443
  # (DNAT → 51820, casino-vps/modules/wireguard.nix, таблица awg0-ingress-dnat).
  # Оба порта на сервере открыты ВСЕГДА; выбор — чисто клиентский, менять тут.
  #
  # ИЗМЕРЕНИЯ (одна машина, разные аплинки, пакеты по 179 байт):
  #   2026-08-30, сотовый:            :51820 — тишина,    :443 — работает.
  #   2026-09-16, раздача с телефона: :51820 — 5/5 дошло, :443 — 1/5
  #     (пакеты по 1000 байт — 0/3). Хендшейк на :443 уходил в пустоту:
  #     awg show показывал 2.16 MiB sent, 0 B received при исправном VPS.
  # Режут ОБА порта, просто в разных сетях разные: 443 ловит QUIC-шейпер
  # оператора, 51820 — портовый фильтр. Обфускация не помогает: режется по
  # порту и размеру, до разбора содержимого. Поэтому переключатель: доступ к
  # узлу из-за смены сети уже теряли (2026-09-16, узел доставали через rescue).
  #
  # КАК ПРОВЕРИТЬ ЖИВОЙ ПОРТ ЗА СЕКУНДУ, БЕЗ РЕБИЛДА:
  #   sudo awg set awg-egg peer MM5HJT6o9NSnCw/exPjo0b9HJOtWQ9cxmi3LV4lHuD0=
  #        endpoint 159.194.224.13:51820      (одной строкой)
  #   sudo awg show awg-egg   — появился latest handshake, значит порт жив.
  # Победивший порт закрепить здесь и пересобрать.
  #
  # ☢️ ЭТОТ КОММЕНТАРИЙ ЖИВЁТ ЗДЕСЬ, А НЕ У Endpoint, НАМЕРЕННО: там он попал бы
  # ВНУТРЬ heredoc в preStart, где оболочка выполняет подстановки. Так уже
  # ломалось (2026-09-16): обратные кавычки вокруг awg show выполнились, вывод
  # команды уехал в конфиг, и awg-quick упал с `Line unrecognized: publickey:...`.
  # Внутри того heredoc не должно быть ни backtick, ни $(...), ни \ в конце строки.
  endpointPort = 443;

  runtimeConf = "/run/amneziawg/awg-egg.conf";
in {
  # Admin-VPN до casino-VPS (eggventure-main, 159.194.224.13).
  #
  # Зачем: плоскость администрирования прода. Через этот туннель и ТОЛЬКО через
  # него доступны kube-API (10.100.0.1:6443) и Grafana (10.100.0.1:3001).
  # На публичном winjoy.games этих сервисов нет — они биндятся на адрес
  # интерфейса admin-VPN сервера, поэтому из интернета до них нет сокета.
  # Серверная сторона: casino-vps/modules/wireguard.nix (пир 10.100.0.2 — это мы)
  # и casino-vps/modules/firewall.nix (6443/3001 только на awg0).
  #
  # ☢️ ПОЧЕМУ AmneziaWG, А НЕ ВАНИЛЬНЫЙ WireGuard, И ПОЧЕМУ НЕ NetworkManager.
  # Измерено 2026-07-31 захватом на сервере: обычные UDP-датаграммы с этого
  # ноутбука долетают на 51820 все (9/9), а WireGuard-поток живёт ~5 секунд
  # после рукопожатия, дальше входящее направление глохнет (33 отправлено,
  # 5 получено). Пересоздание туннеля меняет source-порт и снова даёт короткое
  # окно — блокировка привязывается к потоку ПОСЛЕ классификации. Это DPI
  # провайдера, режущий сигнатуру WG (фиксированный type-байт + длины 148/92).
  # AmneziaWG ломает сигнатуру, не трогая криптографию Noise IK.
  #
  # Цена решения, зафиксирована осознанно: NetworkManager AmneziaWG НЕ понимает,
  # поэтому переключателя VPN в трее нет — интерфейс поднимает systemd.
  # Варианта, который одновременно обходит DPI и живёт в трее, не существует.
  # Включение/выключение вручную:
  #   sudo systemctl start  amneziawg-egg
  #   sudo systemctl stop   amneziawg-egg
  #
  # Приватный ключ НЕ в репозитории: он в sops (secrets/secrets.yaml, путь
  # wireguard/eggventure_private). Публичный ключ этой пары —
  # 4NsgkUMcEoU0zORdZLD90rMZxAQ/QIq8Lc+hvdaCcxU= — прописан пиром на сервере.
  sops.secrets."wireguard/eggventure_private" = {
    mode = "0400";
  };

  # ☢️ USERSPACE-РЕАЛИЗАЦИЯ (amneziawg-go), А НЕ МОДУЛЬ ЯДРА — как и на сервере.
  # Модуль ядра требует ПЕРЕЗАГРУЗКИ после каждого switch (modprobe ищет модули
  # в /run/booted-system, а не в current-system) и ломается при любом обновлении
  # ядра до пересборки. На ноутбуке с `linuxPackages_latest` ядро едет часто,
  # так что это гарантированные грабли. Userspace дороже по CPU, но для
  # kubectl и дашбордов разница неизмерима.
  environment.systemPackages = [pkgs.amneziawg-tools pkgs.amneziawg-go];

  systemd.services.amneziawg-egg = {
    description = "AmneziaWG admin VPN to eggventure-main";
    after = ["network-online.target" "sops-nix.service"];
    wants = ["network-online.target" "sops-nix.service"];
    # Поднимается автоматически при загрузке — по прямому решению владельца:
    # алерт из ntfy может прийти в любой момент, и ручной старт туннеля перед
    # каждым заходом в Grafana обесценивает быстрый доступ.
    # Выключить разово: sudo systemctl stop amneziawg-egg
    wantedBy = ["multi-user.target"];
    path = with pkgs; [amneziawg-tools amneziawg-go iproute2 iptables];

    # awg-quick при отсутствии модуля ядра поднимает интерфейс через userspace-
    # бинарь, указанный этой переменной. Без неё он молча пытается
    # ip link add type amneziawg и падает «Unknown device type».
    environment.WG_QUICK_USERSPACE_IMPLEMENTATION = "amneziawg-go";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.amneziawg-tools}/bin/awg-quick up ${runtimeConf}";
      ExecStop = "${pkgs.amneziawg-tools}/bin/awg-quick down ${runtimeConf}";
    };

    # Конфиг собирается в /run (tmpfs, 0600), а НЕ в nix-store: awg-quick требует
    # PrivateKey инлайном, а всё в store читаемо любым пользователем системы.
    preStart = ''
      set -eu
      umask 077
      mkdir -p /run/amneziawg
      chmod 700 /run/amneziawg
      cat > ${runtimeConf} <<EOF
      [Interface]
      Address = 10.100.0.2/24
      PrivateKey = $(cat ${config.sops.secrets."wireguard/eggventure_private".path})
      ${obfuscation}

      [Peer]
      PublicKey = MM5HJT6o9NSnCw/exPjo0b9HJOtWQ9cxmi3LV4lHuD0=
      # Порт — endpointPort, разбор см. в шапке файла у его объявления.
      Endpoint = 159.194.224.13:${toString endpointPort}
      # ☢️ ТОЛЬКО админ-подсеть, а НЕ 0.0.0.0/0. Split-tunnel: в туннель уходит
      # исключительно трафик к 10.100.0.0/24, остальной интернет идёт напрямую.
      # Полный редирект был бы и лишним (это служебный доступ, не anonymity-VPN),
      # и вредным — утащил бы в туннель трафик к самому winjoy.games.
      AllowedIPs = 10.100.0.0/24
      # Ноутбук почти всегда за NAT: без keepalive серверный conntrack-маппинг
      # протухает и сервер перестаёт мочь достучаться первым.
      PersistentKeepalive = 25
      EOF
      chmod 600 ${runtimeConf}
    '';
  };

  # Переключатель admin-VPN в Quick Settings GNOME (расширение
  # custom-command-toggle, включается в module/users/bg/dconf.nix) дёргает этот
  # юнит напрямую — NetworkManager AmneziaWG не понимает, поэтому иначе никак.
  # ☢️ Правило намеренно УЗКОЕ: проверяются одновременно action.id, ИМЯ ЮНИТА и
  # глагол. Без lookup("unit") пользователь bg получил бы право управлять ЛЮБЫМ
  # системным сервисом, включая sshd и firewall — это не «удобство», а
  # эскалация привилегий. subject.local && subject.active отсекают ssh-сессии и
  # залоченный экран. `systemctl is-active` пароля не требует вовсе (read-only).
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "amneziawg-egg.service" &&
          (action.lookup("verb") == "start" ||
           action.lookup("verb") == "stop"  ||
           action.lookup("verb") == "restart") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';

  # Правило в nftables-ruleset (module/network-configuration.nix) НАМЕРЕННО не
  # добавляется. Исходящие UDP/51820 уже разрешены set'ом system_udp, а ответный
  # трафик проходит по `ct state established accept` — туннель работает как есть.
  # Blanket `iifname "awg-egg" accept` в цепочке input дал бы СЕРВЕРУ возможность
  # самому инициировать соединения в ноутбук: расширение поверхности атаки без
  # единого сценария, который бы это требовал. Мы всегда клиент.
}
