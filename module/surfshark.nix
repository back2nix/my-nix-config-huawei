{
  config,
  lib,
  pkgs,
  ...
}:

# systemctl list-unit-files | grep openvpn | grep us-
# sudo systemctl start openvpn-us-nyc.service
# sudo systemctl restart openvpn-us-nyc.service
# sudo systemctl status openvpn-us-nyc.service

with lib;
let
  configFiles = pkgs.stdenv.mkDerivation {
    name = "surfshark-config";
    src = pkgs.fetchurl {
      url = "https://github.com/charludo/surfshark-configs/raw/main/Surfshark_Config.zip";
      sha256 = "sha256-n2cPHCYxXGzTvPHwCjsHVIj3yM/bnCJw0hwwTNXlcQI";
    };
    phases = [ "installPhase" ];
    buildInputs = [
      pkgs.unzip
      pkgs.rename
    ];
    installPhase = ''
      unzip $src
      find . -type f ! -name '*_udp.ovpn' -delete
      # find . -type f -exec sed -i "s+auth-user-pass+auth-user-pass \"${config.sops.secrets.surfshark.path}\"+" {} +
      # find . -type f -exec sed -i "s+auth-user-pass+auth-user-pass /home/bg/Documents/code/github.com/back2nix/nix/my-nix-config-huawei/surfshark.cred+" {} +
      find . -type f -exec sed -i "s+auth-user-pass+auth-user-pass \"${config.sops.secrets.surfshark.path}\"+" {} +
      rename 's/prod.surfshark.com_udp.//' *
      mkdir -p $out
      mv * $out
    '';

    # not tested
    # installPhase = ''
    #   unzip $src
    #   # Оставляем только нужные файлы и сразу переименовываем их
    #   for f in *_udp.ovpn; do
    #     mv "$f" "$out/''${f#prod.surfshark.com_udp.}"
    #   done
    #   # Удаляем всё остальное
    #   rm -rf !(*.ovpn)

    #   # Заменяем auth-user-pass одной командой
    #   sed -i "s+auth-user-pass+auth-user-pass \"${config.sops.secrets.surfshark.path}\"+" $out/*.ovpn
    # '';
  };

  getConfig = filePath: {
    name = "${builtins.substring 0 (builtins.stringLength filePath - 5) filePath}";
    value = {
      config = ''config ${configFiles}/${filePath} '';
      autoStart = false;
      updateResolvConf = true;
    };
  };
  openVPNConfigs = map getConfig (builtins.attrNames (builtins.readDir configFiles));

  services = "(${
    lib.concatStringsSep " " (lib.mapAttrsToList (name: _: "\"openvpn-${name}.service\"") config.services.openvpn.servers)
  })";

  surfshark-start = pkgs.writeshellapplication {
    name = "surfshark-stop";
    text = ''
      sudo systemctl start openvpn-us-nyc.service
    '';
  };

  surfshark-stop = pkgs.writeshellapplication {
    name = "surfshark-stop";
    text = ''
      services=${services}
      for service in "''${services[@]}"; do
          systemctl stop "$service"
      done
    '';
  };
  surfshark-random = pkgs.writeShellApplication {
    name = "surfshark-random";
    runtimeInputs = [ surfshark-stop ];
    text = ''
      systemctl daemon-reload
      ${surfshark-stop}/bin/surfshark-stop
      services=${services}
      random_service=$(printf "%s\n" "''${services[@]}" | shuf -n1)
      systemctl start "$random_service"
    '';
  };

  cfg = config.surfshark;
in
{
  options.surfshark = {
    enable = lib.mkEnableOption (lib.mdDoc "enable surfshark VPN");

    alwaysOn = mkOption {
      type = types.bool;
      default = false;
      description = "make sure surfshark is always running";
    };

    hopWeekly = mkOption {
      type = types.bool;
      default = cfg.alwaysOn;
      description = "whether the surfshark server should be changed automatically once per week";
    };

    iptables.enable = mkOption {
      type = types.bool;
      default = cfg.alwaysOn;
      description = "whether to enforce surfshark use through iptables extraCommands";
    };

    iptables.enforceForUsers = mkOption {
      type = types.listOf (types.str);
      default = [ ];
      description = "which users to enforce the surfshark iptables rules for";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    ({
      networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

      services.openvpn.servers = builtins.listToAttrs openVPNConfigs;
      environment.systemPackages = [
        surfshark-random
        surfshark-stop
      ];
    })

    (mkIf cfg.alwaysOn {
      systemd.timers."surfshark-ensure-minutely" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "minutely";
          Persistent = true;
          Unit = "surfshark-ensure.service";
        };
      };
      systemd.services."surfshark-ensure" = {
        script = ''
          if ${pkgs.iproute2}/bin/ip a show tun0 &> /dev/null;
          then
          exit 0
          else
          ${surfshark-random}/bin/surfshark-random
          fi
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    })

    (mkIf cfg.hopWeekly {
      systemd.timers."surfshark-hop-weekly" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 03:00";
          Persistent = true;
          Unit = "surfshark-hop-weekly.service";
        };
      };
      systemd.services."surfshark-hop-weekly" = {
        script = ''
          systemctl reboot
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    })

    (mkIf cfg.iptables.enable {
      networking.firewall.extraCommands =
        ''
          iptables -A INPUT -s localhost -j ACCEPT
          iptables -A OUTPUT -d localhost -j ACCEPT
          iptables -A INPUT -i lo -j ACCEPT
          iptables -A OUTPUT -o lo -j ACCEPT

          iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
          iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

          iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
          iptables -A INPUT -p udp --sport 1194 -j ACCEPT
          iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
          iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

          iptables -A OUTPUT -o tun0 -j ACCEPT

        ''
        + lib.concatStringsSep "" (
          map (user: ''
            iptables -A OUTPUT -m owner --gid-owner ${
              builtins.toString config.users.groups."${user}".gid
            } -d 192.168.0.0/16 ! -o tun0 -j ACCEPT
          '') cfg.iptables.enforceForUsers
        )
        + lib.concatStringsSep "" (
          map (user: ''
            iptables -A OUTPUT -m owner --gid-owner ${
              builtins.toString config.users.groups."${user}".gid
            } -d 127.0.0.1 ! -o tun0 -j ACCEPT
          '') cfg.iptables.enforceForUsers
        )
        + lib.concatStringsSep "" (
          map (user: ''
            iptables -A OUTPUT -m owner --gid-owner ${
              builtins.toString config.users.groups."${user}".gid
            } ! -o tun0 -j REJECT
          '') cfg.iptables.enforceForUsers
        )
        + ''

          iptables -P INPUT DROP
          iptables -P FORWARD DROP
          iptables -P OUTPUT DROP
        '';
    })
  ]);
}