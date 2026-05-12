# module/sing-box.nix
{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  systemd.services."ssh-tunnel-vpn3" = {
    description = "SSH SOCKS tunnel to google-seoul via vpn3 proxy";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "ssh-tunnel-vpn3" ''
        exec ${pkgs.autossh}/bin/autossh \
        -M 0 \
        -4 -N \
        -D 127.0.0.1:1091 \
        -o "ProxyCommand=${pkgs.netcat-openbsd}/bin/nc -X connect -x 192.168.43.1:8080 %h %p" \
        -o ServerAliveInterval=2 \
        -o ServerAliveCountMax=1 \
        -o ConnectTimeout=3 \
        -o ExitOnForwardFailure=yes \
        -o StrictHostKeyChecking=accept-new \
        google-seoul
        '';
      Restart = "always";
      RestartSec = "5s";
      User = "bg";
    };
  };

  systemd.services."sing-box" = {
    enable = true;
    description = "sing-box proxy";
    after = ["network-online.target" "ssh-tunnel-vpn3.service"];
    wants = ["network-online.target" "ssh-tunnel-vpn3.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      ExecStart = "${pkgs-unstable.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box-config.json".path}";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
