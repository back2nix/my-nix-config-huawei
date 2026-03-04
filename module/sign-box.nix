{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  systemd.services."sing-box" = {
    enable = true;
    description = "sing-box proxy";
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config.json".path}";
      Restart = "always";
      RestartSec = "5s";
    };
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };

  systemd.services."sing-box2" = {
    enable = true;
    description = "sing-box proxy vpn2";
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config2.json".path}";
      Restart = "always";
      RestartSec = "5s";
    };
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };

  systemd.services."sing-box3" = {
    enable = true;
    description = "sing-box proxy vpn3";
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config3.json".path}";
      Restart = "always";
      RestartSec = "5s";
    };
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };
}
