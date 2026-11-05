{
  config,
  lib,
  pkgs,
  ...
}: let
  # Полнотуннельный VPN: ВЕСЬ трафик системы через Париж или через Франкфурт.
  # Тумблеры в трее (module/proxy-mode.nix → vpns). Юниты взаимоисключающие.
  #
  #   amneziawg-personal-full  — тот же ключ/адрес/пир, что split-туннель
  #     amneziawg-personal (awg1 на Paris, 10.101.0.0/24), но AllowedIPs = 0/0.
  #     Пока он поднят, split-юнит остановлен (Conflicts), после остановки
  #     split возвращается сам. Сервер: casino-vps vpnPersonal.directEgress.
  #   amneziawg-fra-full — отдельный туннель awg-fra на Франкфурт
  #     (10.103.0.0/24, :51822), свой ключ, сгенерированный здесь же.
  #     Сервер: casino-vps/modules/vpn-fra-full.nix.
  #
  # Утечки: awg-quick с 0/0 ставит policy routing по fwmark — весь трафик,
  # кроме шифрованного конверта самого туннеля, уходит в интерфейс. IPv6 тоже
  # заворачивается (::/0) и на сервере дропается: v6 мимо туннеля не утекает.
  # DNS у ноутбука локальный (127.0.0.1 → dnscrypt), наружу он идёт уже в туннеле.
  # Исключение — сам Париж (casino_ip): admin-VPN awg-egg и split-туннель
  # должны ходить к нему напрямую, а не петлёй через awg1 в его же input.
  pcfg = config.my.fullTunnel.paris;
  fcfg = config.my.fullTunnel.fra;

  parisObfuscation = ''
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
  # ☢️ Побайтово = casino-vps/modules/vpn-fra-full.nix.
  fraObfuscation = ''
    Jc = 6
    Jmin = 47
    Jmax = 1013
    S1 = 29
    S2 = 113
    H1 = 1328759113
    H2 = 2110421771
    H3 = 734521873
    H4 = 1689032299
  '';

  casinoIp = config.sops.secrets."hosts/casino_ip".path;
  fraIp = config.sops.secrets."hosts/frankfurt_ip".path;
  fraKeyDir = "/var/lib/personal-vpn-fra";

  mkUnit = {
    description,
    conf,
    conflicts,
    preStart,
    extra ? {},
  }:
    lib.recursiveUpdate {
      inherit description preStart;
      after = ["network-online.target" "sops-nix.service"];
      wants = ["network-online.target" "sops-nix.service"];
      conflicts = conflicts;
      # Без автостарта: включается только тумблером.
      path = with pkgs; [amneziawg-tools amneziawg-go iproute2 iptables nftables procps];
      environment.WG_QUICK_USERSPACE_IMPLEMENTATION = "amneziawg-go";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.amneziawg-tools}/bin/awg-quick up ${conf}";
        ExecStop = "${pkgs.amneziawg-tools}/bin/awg-quick down ${conf}";
      };
    }
    extra;

  units = ["amneziawg-personal-full.service" "amneziawg-fra-full.service"];
in {
  options.my.fullTunnel = {
    paris = {
      address = lib.mkOption {
        type = lib.types.str;
        description = "Адрес в 10.101.0.0/24 (тот же, что у split-туннеля).";
      };
      privateKeyFile = lib.mkOption {
        type = lib.types.str;
        description = "Приватный ключ awg-pers (тот же, что у split-туннеля).";
      };
    };
    fra = {
      address = lib.mkOption {
        type = lib.types.str;
        example = "10.103.0.7";
        description = "Адрес в 10.103.0.0/24; должен совпадать с casino.vpnFraFull.peers.";
      };
      serverPublicKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "awg pubkey сервера (/var/lib/wireguard/awg-fra.key на Франкфурте). Пусто — юнит не стартует.";
      };
    };
  };

  config = {
    systemd.services.amneziawg-personal-full = mkUnit {
      description = "AmneziaWG: весь трафик через Париж (awg1)";
      conf = "/run/amneziawg/awg-pfull.conf";
      conflicts = ["amneziawg-personal.service" "amneziawg-fra-full.service"];
      extra.serviceConfig.ExecStopPost = "-${pkgs.systemd}/bin/systemctl --no-block start amneziawg-personal.service";
      preStart = ''
        set -eu
        umask 077
        mkdir -p /run/amneziawg
        chmod 700 /run/amneziawg
        cat > /run/amneziawg/awg-pfull.conf <<EOF
        [Interface]
        Address = ${pcfg.address}/24
        PrivateKey = $(cat ${pcfg.privateKeyFile})
        ${parisObfuscation}
        PostUp = ip rule add to $(cat ${casinoIp})/32 lookup main pref 100
        PreDown = ip rule del to $(cat ${casinoIp})/32 lookup main pref 100 || true

        [Peer]
        PublicKey = $(cat ${config.sops.secrets."wireguard/personal_server_public".path})
        Endpoint = $(cat ${casinoIp}):51821
        AllowedIPs = 0.0.0.0/0, ::/0
        PersistentKeepalive = 25
        EOF
        chmod 600 /run/amneziawg/awg-pfull.conf
      '';
    };

    systemd.services.amneziawg-fra-full = mkUnit {
      description = "AmneziaWG: весь трафик через Франкфурт (awg-fra)";
      conf = "/run/amneziawg/awg-fra.conf";
      conflicts = ["amneziawg-personal-full.service"];
      preStart = ''
        set -eu
        umask 077
        mkdir -p /run/amneziawg ${fraKeyDir}
        chmod 700 /run/amneziawg ${fraKeyDir}
        # Ключ генерируется на этой машине и не покидает её; публичную часть
        # вписать в casino.vpnFraFull.peers на Франкфурте.
        if [ ! -s ${fraKeyDir}/awg-fra.key ]; then
          awg genkey > ${fraKeyDir}/awg-fra.key
        fi
        awg pubkey < ${fraKeyDir}/awg-fra.key > ${fraKeyDir}/awg-fra.pub
        chmod 644 ${fraKeyDir}/awg-fra.pub
        ${lib.optionalString (fcfg.serverPublicKey == "") ''
          echo "my.fullTunnel.fra.serverPublicKey не задан; pubkey клиента: $(cat ${fraKeyDir}/awg-fra.pub)" >&2
          exit 1
        ''}
        cat > /run/amneziawg/awg-fra.conf <<EOF
        [Interface]
        Address = ${fcfg.address}/24
        PrivateKey = $(cat ${fraKeyDir}/awg-fra.key)
        ${fraObfuscation}

        [Peer]
        PublicKey = ${fcfg.serverPublicKey}
        Endpoint = $(cat ${fraIp}):51822
        AllowedIPs = 0.0.0.0/0, ::/0
        PersistentKeepalive = 25
        EOF
        chmod 600 /run/amneziawg/awg-fra.conf
      '';
    };

    # Узкое правило: только эти два юнита, только start/stop/restart,
    # только локальная активная сессия bg (как в wireguard-eggventure.nix).
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var units = ${builtins.toJSON units};
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            units.indexOf(action.lookup("unit")) >= 0 &&
            (action.lookup("verb") == "start" ||
             action.lookup("verb") == "stop"  ||
             action.lookup("verb") == "restart") &&
            subject.user == "bg" && subject.local && subject.active) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
