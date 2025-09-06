{
pkgs,
config,
...
}:
{
  # autossh -M 0 -N -o "ServerAliveInterval=60" -o "ServerAliveCountMax=3" -o "ExitOnForwardFailure=yes" -i /home/bg/.ssh/id_rsa -R 2222:localhost:22  root@remote-server-ip
  systemd.services.reverse-ssh-tunnel = {
    description = "Persistent Reverse SSH Tunnel using autossh";

    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "bg";

      ExecStart = ''
        ${pkgs.autossh}/bin/autossh \
          -M 0 \
          -N \
          -o "ServerAliveInterval=60" \
          -o "ServerAliveCountMax=3" \
          -o "ExitOnForwardFailure=yes" \
          -i /home/bg/.ssh/id_rsa \
          -R 2222:localhost:22 \
          root@35.193.76.228
      '';

      Restart = "always";
      RestartSec = "15s";
    };
  };
}
