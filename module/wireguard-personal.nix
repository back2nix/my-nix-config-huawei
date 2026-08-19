{
  config,
  pkgs,
  ...
}: let
  # ☢️ ЭТОТ ТУННЕЛЬ НЕ ИМЕЕТ ОТНОШЕНИЯ К КАЗИНО и намеренно отделён от
  # admin-VPN (module/wireguard-eggventure.nix) по всем осям сразу:
  #
  #   ось          admin-VPN (казино)   личный VPN (этот файл)
  #   интерфейс    awg-egg              awg-pers
  #   адрес        10.100.0.2           10.101.0.2
  #   порт сервера 51820                51821
  #   ключ         sops wireguard/      sops wireguard/
  #                eggventure_private   personal_private
  #   обфускация   свой набор           ДРУГОЙ набор
  #
  # Общий ключ или общая подсеть означали бы, что компрометация личного контура
  # даёт доступ в админ-плоскость прода. Разделение подсетей без разделения
  # ключей эту связь не разрывает, поэтому пара ключей здесь отдельная, хотя
  # машина физически та же самая.
  #
  # Назначение: ssh на Windows-машину (10.101.0.3) через сервер как рандеву-узел.
  # У Windows своего внешнего IP нет и она может быть в другой стране за NAT.
  # Серверная сторона — casino-vps/modules/vpn-personal.nix.

  # ☢️ ОБЯЗАНЫ ПОБАЙТОВО СОВПАДАТЬ С СЕРВЕРОМ И С WINDOWS-КОНФИГОМ.
  # Источник истины — casino-vps/modules/vpn-personal.nix. Расхождение хотя бы
  # в одном числе = рукопожатие не проходит ВООБЩЕ, и в логах это выглядит как
  # тишина, а не как внятная ошибка.
  # Значения ОТЛИЧАЮТСЯ от admin-VPN осознанно: одинаковый профиль длин и
  # type-полей на двух портах одного IP сам стал бы сигнатурой, связывающей
  # два контура для наблюдателя.
  obfuscation = ''
    Jc = 7
    Jmin = 53
    Jmax = 1147
    S1 = 47
    S2 = 91
    H1 = 421779113
    H2 = 998244353
    H3 = 1610612741
    H4 = 2038074743
  '';

  runtimeConf = "/run/amneziawg/awg-pers.conf";
in {
  # ☢️ ПОЧЕМУ AmneziaWG, А НЕ ВАНИЛЬНЫЙ WireGuard: та же измеренная причина, что
  # и у admin-VPN (разбор в module/wireguard-eggventure.nix) — DPI провайдера
  # убивает WG-поток через ~5 секунд после рукопожатия по сигнатуре протокола.
  # Криптография Noise IK при этом не тронута.
  sops.secrets."wireguard/personal_private" = {
    mode = "0400";
  };

  environment.systemPackages = [pkgs.amneziawg-tools pkgs.amneziawg-go];

  systemd.services.amneziawg-personal = {
    description = "AmneziaWG personal VPN (ssh к Windows, к казино не относится)";
    after = ["network-online.target" "sops-nix.service"];
    wants = ["network-online.target" "sops-nix.service"];

    # ☢️ АВТОСТАРТА НЕТ — в отличие от admin-VPN. Это побочный проект, а не
    # канал реагирования на алерты: держать лишний туннель поднятым постоянно
    # незачем. Поднять перед заходом на Windows:
    #   sudo systemctl start amneziawg-personal
    #   ssh bagau
    #   sudo systemctl stop amneziawg-personal
    # Если понадобится постоянно — добавить wantedBy = ["multi-user.target"].
    wantedBy = [];

    path = with pkgs; [amneziawg-tools amneziawg-go iproute2 iptables];

    # Без переменной awg-quick молча делает `ip link add type amneziawg`
    # и падает «Unknown device type» — модуля ядра здесь нет намеренно.
    environment.WG_QUICK_USERSPACE_IMPLEMENTATION = "amneziawg-go";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.amneziawg-tools}/bin/awg-quick up ${runtimeConf}";
      ExecStop = "${pkgs.amneziawg-tools}/bin/awg-quick down ${runtimeConf}";
    };

    # Конфиг в /run (tmpfs, 0600), а НЕ в nix-store: awg-quick требует PrivateKey
    # инлайном, а всё в store читаемо любым пользователем системы.
    preStart = ''
      set -eu
      umask 077
      mkdir -p /run/amneziawg
      chmod 700 /run/amneziawg
      cat > ${runtimeConf} <<EOF
      [Interface]
      Address = 10.101.0.2/24
      PrivateKey = $(cat ${config.sops.secrets."wireguard/personal_private".path})
      ${obfuscation}

      [Peer]
      PublicKey = yhtMBkc8Ix+0LPsYf26Ad/0pLsumVnUqqqftpZU/ZB8=
      Endpoint = 159.194.224.13:51821
      # ☢️ ТОЛЬКО 10.101.0.0/24, а НЕ 0.0.0.0/0. Split-tunnel: в туннель уходит
      # исключительно трафик к личной подсети, весь остальной интернет идёт
      # напрямую. Полный редирект утащил бы туда и обычный трафик ноутбука.
      # 10.100.0.0/24 (admin-VPN) сюда НЕ входит — контуры не пересекаются даже
      # маршрутами, и порядок подъёма двух туннелей не имеет значения.
      AllowedIPs = 10.101.0.0/24
      # Ноутбук почти всегда за NAT: без keepalive маппинг протухает и сервер
      # не может достучаться первым.
      PersistentKeepalive = 25
      EOF
      chmod 600 ${runtimeConf}
    '';
  };

  # Старт/стоп этого туннеля без пароля — иначе автостарта нет И каждый подъём
  # требует sudo, что делает сценарий «поднял, зашёл, опустил» неоправданно
  # тяжёлым.
  # ☢ Правило НАМЕРЕННО УЗКОЕ, тот же приём, что в wireguard-eggventure.nix:
  # проверяются одновременно action.id, ИМЯ ЮНИТА и глагол. Без lookup("unit")
  # пользователь bg получил бы право управлять ЛЮБЫМ системным сервисом,
  # включая sshd и firewall — это не «удобство», а эскалация привилегий.
  # subject.local && subject.active отсекают ssh-сессии и залоченный экран.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "amneziawg-personal.service" &&
          (action.lookup("verb") == "start" ||
           action.lookup("verb") == "stop"  ||
           action.lookup("verb") == "restart") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
}
