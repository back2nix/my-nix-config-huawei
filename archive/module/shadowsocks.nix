{
  pkgs,
  config,
  ...
}: let
in {
  # before 192.168.100.3 1080
  # after  127.0.0.1 1080
  systemd.services."shadowsocks-client" = {
    enable = true;
    description = "shadowsocks-client";
    unitConfig = {
      Type = "simple";
    };
    path = [pkgs.nix];
    serviceConfig = {
      ExecStart = "${pkgs.shadowsocks-libev}/bin/ss-local -v -c ${
        config.sops.templates."shadowsocks.json".path
      }";
    };
    wantedBy = ["multi-user.target"];
  };
}
