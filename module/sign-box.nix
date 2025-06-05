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
}
