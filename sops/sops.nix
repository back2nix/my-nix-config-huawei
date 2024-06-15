{config, ...}: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/bg/.config/sops/age/keys.txt";
    age.generateKey = true;
    secrets.example-key = {};
    secrets."myservice/my_subdir/my_secret" = {};
    secrets.example-key.mode = "0440";
    secrets.example-key.owner = config.users.users.nobody.name;
    secrets.example-key.group = config.users.users.nobody.group;

    secrets."shadowsocks/password" = {};
    secrets."shadowsocks/server" = {};

    templates."shadowsocks.json".content = ''
      {
          "server": [
              "::1",
              "${config.sops.placeholder."shadowsocks/server"}"
          ],
          "mode": "tcp_and_udp",
          "server_port": 8388,
          "local_port": 1080,
          "password": "${config.sops.placeholder."shadowsocks/password"}",
          "timeout": 60,
          "method": "rc4-md5",
          "fast_open": true
      }
    '';
  };
}
