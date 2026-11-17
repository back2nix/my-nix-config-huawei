# zapret2 (nfqws2) — обход ТСПУ для ПРЯМОГО трафика, и только для него.
#
# Где это помогает: соединение идёт мимо тоннелей (режим Direct у группы,
# «Весь трафик» = direct, outbound direct-out в sing-box), а ТСПУ режет его по
# первому пакету клиента — SNI в TLS ClientHello или QUIC Initial. nfqws2
# подсовывает DPI фальшивый ClientHello и режет настоящий, сервер при этом
# получает обычный запрос.
#
# Где НЕ помогает и потому не включено:
#   * ssh-outbound'ы sing-box: SSH узнаётся по баннеру, который шлёт и сервер,
#     а nfqws2 на клиенте правит только исходящие пакеты; блокировку по IP и
#     «замирание» потока десинхронизацией не лечат (см. ssh-keepalive.patch);
#   * трафик внутри тоннелей (sbtun0, awg-*): ТСПУ его не видит;
#   * всё, чего нет в списке доменов: десинхронизация «на всё подряд» ломает
#     часть обычных сайтов, а пользы там нет.
#
# Поэтому три фильтра подряд:
#   1. nft: только выход через физический интерфейс, только tcp/443 и udp/443,
#      только первые пакеты соединения, мимо серверов тоннелей и частных сетей;
#   2. nfqws2: только TLS ClientHello / QUIC Initial;
#   3. nfqws2: только домены из module/zapret2/hosts.txt (с поддоменами),
#      разложенные по стратегиям в module/zapret2/profiles.json.
# Соединение без имени хоста (ssh на 443 к Парижу) под профиль не попадает.
#
# Стратегии подбираются под провайдера и со временем перестают работать.
# Если что-то из списка перестало открываться напрямую: `just zapret-tune`,
# затем `just switch`. Методика и разбор случаев — docs/zapret2-tuning.md.
#
# Управление: тумблер «zapret2: обход ТСПУ (прямой трафик)» в меню proxy-mode
# или `systemctl start|stop zapret2`. Включён по умолчанию.
{
  pkgs,
  lib,
  ...
}: let
  zapret = pkgs.zapret2;
  lua = "${zapret}/share/zapret2/lua";
  qnum = 200;
  # Метка пакетов, которые сгенерировал сам nfqws2 (его значение по умолчанию).
  desyncMark = "0x40000000";
  # Полный список доменов: вход для подбора и список для QUIC-профиля.
  hostlist = ./zapret2/hosts.txt;

  # TLS-профили — результат `just zapret-tune` (scripts/zapret2-tune.sh):
  # какой группе доменов какая стратегия подходит на этой сети. Одной стратегии
  # на всех нет: например, кэшам YouTube (googlevideo.com) фальшивый ClientHello
  # ломает TLS, а Discord и X без него не открываются. nfqws2 берёт первый
  # профиль, в чей список попал хост. Домены, которые открываются только без
  # обхода, в профили не попадают вовсе.
  tlsProfiles = (builtins.fromJSON (builtins.readFile ./zapret2/profiles.json)).profiles;

  quicStrategy = [
    "--lua-desync=fake:blob=fake_default_quic:repeats=6"
  ];

  tlsProfileArgs = i: p:
    [
      "${
        if i == 0
        then "--name"
        else "--new"
      }=${p.name}"
      "--hostlist=${pkgs.writeText "zapret2-hosts-${p.name}.txt" (lib.concatLines p.hosts)}"
      "--filter-tcp=443"
      "--filter-l7=tls"
      "--out-range=-d10"
      "--payload=tls_client_hello"
    ]
    ++ p.desync;

  # Файл параметров: nfqws2 читает его как @config.
  nfqwsConf = pkgs.writeText "nfqws2.conf" (lib.concatLines ([
      "--qnum=${toString qnum}"
      "--fwmark=${desyncMark}"
      "--lua-init=@${lua}/zapret-lib.lua"
      "--lua-init=@${lua}/zapret-antidpi.lua"
    ]
    ++ lib.concatLists (lib.imap0 tlsProfileArgs tlsProfiles)
    ++ [
      "--new=quic"
      "--hostlist=${hostlist}"
      "--filter-udp=443"
      "--filter-l7=quic"
      "--payload=quic_initial"
    ]
    ++ quicStrategy));

  # Отдельная таблица переживает перезагрузку основного firewall
  # (flushRuleset=false). Первые две строки делают загрузку идемпотентной.
  rules = pkgs.writeText "zapret2.nft" ''
    table inet zapret2
    delete table inet zapret2
    table inet zapret2 {
      set skip4 {
        type ipv4_addr
        flags interval
        elements = {
          # Серверы тоннелей (тот же список, что route_exclude_address
          # в module/system-vpn.nix): их соединения не трогаем никогда.
          35.212.30.39, 35.208.120.183, 5.252.179.162, 194.180.174.137,
          # Quad9 DoH (dnscrypt-proxy, sing-box dns): DNS всей системы,
          # десинхронизация ему не нужна, а сломать его — значит «нет интернета».
          9.9.9.9, 149.112.112.112,
          10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10,
          169.254.0.0/16, 127.0.0.0/8
        }
      }

      chain queue_out {
        tcp dport 443 ct original packets 1-12 queue num ${toString qnum} bypass
        udp dport 443 ct original packets 1-12 queue num ${toString qnum} bypass
      }

      # 101 = после srcnat: трафик контейнеров уже с адресом хоста.
      chain postnat {
        type filter hook postrouting priority 101; policy accept;
        meta mark and ${desyncMark} != 0 return
        ip daddr @skip4 return
        ip6 daddr { ::1, fc00::/7, fe80::/10 } return
        oifname "wl*" jump queue_out
        oifname "en*" jump queue_out
        oifname "eth*" jump queue_out
        oifname "usb*" jump queue_out
        oifname "ww*" jump queue_out
      }

      # Фальшивки nfqws2 идут мимо conntrack: иначе он счёл бы их INVALID
      # или испортил бы ими состояние настоящего соединения.
      chain predefrag {
        type filter hook output priority -401; policy accept;
        meta mark and ${desyncMark} != 0 notrack
      }
    }
  '';
  nft = "${pkgs.nftables}/bin/nft";
in {
  environment.systemPackages = [zapret];

  systemd.services.zapret2 = {
    description = "zapret2: TSPU bypass for direct traffic (nfqws2)";
    after = ["network.target" "nftables.service"];
    wants = ["nftables.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "notify";
      # `queue ... bypass`: пока nfqws2 не слушает очередь, пакеты идут как есть.
      ExecStartPre = "${nft} -f ${rules}";
      ExecStart = "${zapret}/bin/nfqws2 @${nfqwsConf}";
      ExecStopPost = "-${nft} delete table inet zapret2";
      Restart = "on-failure";
      RestartSec = "5s";

      # nfqws2 сам сбрасывает root после открытия очереди и raw-сокетов.
      CapabilityBoundingSet = ["CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SETUID" "CAP_SETGID" "CAP_SETPCAP"];
      RestrictAddressFamilies = ["AF_NETLINK" "AF_UNIX" "AF_INET" "AF_INET6"];
      LockPersonality = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "full";
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
    };
  };

  # Тумблер в трее дёргает systemd от имени bg.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "zapret2.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.user == "bg" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
}
