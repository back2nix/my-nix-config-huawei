# module/sing-box.nix
{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  systemd.services."sing-box" = {
    enable = true;
    description = "sing-box proxy";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      ExecStart = "${pkgs-unstable.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config.json".path}";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
