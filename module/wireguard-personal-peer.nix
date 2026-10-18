{
  config,
  lib,
  pkgs,
  ...
}: let
  # Личный VPN (awg1) для машин bg, которые не yoga14. Серверная сторона —
  # casino-vps/modules/vpn-personal.nix, там же источник истины для всех чисел.
  # Обфускация и порт совпадают с module/wireguard-personal.nix (yoga14).
  #
  # Отличие от yoga14: приватный ключ лежит файлом на машине
  # (~/.config/personal-vpn/awg-pers.key, сгенерирован на ней же), а не в sops.
  # Публичная часть зарегистрирована на сервере отдельным пиром.
  cfg = config.my.personalVpn;

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
  options.my.personalVpn = {
    address = lib.mkOption {
      type = lib.types.str;
      example = "10.101.0.7";
      description = "Адрес этой машины в личной подсети 10.101.0.0/24 (без маски).";
    };
    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/bg/.config/personal-vpn/awg-pers.key";
      description = "Файл с приватным ключом AmneziaWG (base64, 0600).";
    };
  };

  config = {
    environment.systemPackages = [pkgs.amneziawg-tools pkgs.amneziawg-go];

    systemd.services.amneziawg-personal = {
      description = "AmneziaWG personal VPN (ssh между машинами bg, к казино не относится)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      path = with pkgs; [amneziawg-tools amneziawg-go iproute2 iptables];

      environment.WG_QUICK_USERSPACE_IMPLEMENTATION = "amneziawg-go";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.amneziawg-tools}/bin/awg-quick up ${runtimeConf}";
        ExecStop = "${pkgs.amneziawg-tools}/bin/awg-quick down ${runtimeConf}";
      };

      # Конфиг в /run (tmpfs, 0600), а не в nix-store: там PrivateKey читаем всем.
      preStart = ''
        set -eu
        umask 077
        mkdir -p /run/amneziawg
        chmod 700 /run/amneziawg
        cat > ${runtimeConf} <<EOF
        [Interface]
        Address = ${cfg.address}/24
        PrivateKey = $(cat ${cfg.keyFile})
        ${obfuscation}

        [Peer]
        PublicKey = yhtMBkc8Ix+0LPsYf26Ad/0pLsumVnUqqqftpZU/ZB8=
        Endpoint = 159.194.224.13:51821
        # Только личная подсеть: интернет-трафик идёт напрямую, а не через туннель.
        AllowedIPs = 10.101.0.0/24
        PersistentKeepalive = 25
        EOF
        chmod 600 ${runtimeConf}
      '';
    };

    # Старт/стоп туннеля без пароля для bg, узко: один юнит и три глагола.
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
  };
}
