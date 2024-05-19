{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.change-mac;
in
{
  options.services.change-mac = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the change MAC service.
      '';
    };

    interface = mkOption {
      type = types.str;
      default = "wlp0s20f3";
      description = ''
        The network interface to change the MAC address for.
      '';
    };

    macAddress = mkOption {
      type = types.str;
      default = "00:11:22:33:44:55";
      description = ''
        The MAC address to set.
      '';
    };
  };

  config = mkMerge [ 
  (mkIf cfg.enable {
    systemd.services.change-mac = {
      description = "Change MAC Address Service";
      after = [ "network-pre.target" ];
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        Environment = "PATH=${pkgs.iproute2}/bin";
        ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/module/change-mac.sh ${cfg.interface} ${cfg.macAddress}";
        ExecStop = "${pkgs.bash}/bin/bash /etc/nixos/module/restore-mac.sh ${cfg.interface}";
        RemainAfterExit = true;
      };
    };
  })
  (mkIf (!cfg.enable) { 
    systemd.services.restore-mac = {
      description = "Restore MAC Address Service";
      before = [ "shutdown.target" ];
      wantedBy = [ "shutdown.target" ];

      serviceConfig = {
        Type = "oneshot";
        Environment = "PATH=${pkgs.iproute2}/bin:${pkgs.ethtool}/bin:${pkgs.gawk}/bin";
        ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/module/restore-mac.sh ${cfg.interface}";
        RemainAfterExit = true;
      };
    };
  })
  ];
}
