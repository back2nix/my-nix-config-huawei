{config, ...}: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/bg/.config/sops/age/keys.txt";
    age.generateKey = true;

    secrets = {
      "vpn/ip" = {};
      "vpn/user" = {};
      "vpn/private_key_path" = {};

      # Остальные секреты...
      "surfshark" = {
        mode = "0440";
        owner = config.users.users.nobody.name;
        group = config.users.users.nobody.group;
      };
      example-key = {
        mode = "0440";
        owner = config.users.users.nobody.name;
        group = config.users.users.nobody.group;
      };
      "myservice/my_subdir/my_secret" = {};
      "xray/server" = {};
      "xray/privateKey" = {};
      "xray/publicKey" = {};
      "xray/uuid" = {};
    };

    templates."sing-box-config.json" = {
      content = builtins.toJSON {
        log.level = "info";
        inbounds = [
          {
            type = "http";
            tag = "http-proxy";
            listen = "127.0.0.1";
            listen_port = 1083;
          }
          {
            type = "socks";
            tag = "socks-proxy";
            listen = "127.0.0.1";
            listen_port = 1082;
          }
        ];
        outbounds = [
          {
            type = "ssh";
            tag = "ssh-out";
            server = "${config.sops.placeholder."vpn/ip"}";
            server_port = 22;
            user = "${config.sops.placeholder."vpn/user"}";
            private_key_path = "${config.sops.placeholder."vpn/private_key_path"}";
          }
        ];
        route.rules = [
          {
            inbound = ["http-proxy" "socks-proxy"];
            outbound = "ssh-out";
          }
        ];
      };
    };
  };
}
