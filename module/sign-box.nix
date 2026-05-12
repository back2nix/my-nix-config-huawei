{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  pkgs-unstable,  # <-- добавить
  ...
}: {
  systemd.services."sing-box" = {
    enable = true;
    description = "sing-box proxy";
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "${pkgs-unstable.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config.json".path}";  # <-- pkgs-unstable
      Restart = "always";
      RestartSec = "5s";
    };
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
  };
}
