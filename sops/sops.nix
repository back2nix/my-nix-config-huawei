{config, ...}: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/bg/.config/sops/age/keys.txt";
    age.generateKey = true;

    secrets = {
      "vpn/ip" = {};
      "vpn/user" = {};
      "vpn/private_key_path" = {};

      "vpn-directuser/ip" = {};
      "vpn-directuser/user" = {};
      "vpn-directuser/private_key_path" = {};

      "vpn-proxyuser/ip" = {};
      "vpn-proxyuser/user" = {};
      "vpn-proxyuser/private_key_path" = {};

      "vault/root_token" = {};
      # "vault/unseal_Key" = {};
      "autossh/ip" = {};

      # "vault_root_token" = {};

      "mutter/hide_keywords_list" = {
        owner = config.users.users.bg.name;
        mode = "0400";
      };

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
      "attic/env" = {
        restartUnits = [ "atticd.service" ];
      };
    };

    # templates."autossh_ip" = {
    #   # Плейсхолдер будет заменен на содержимое секрета "autossh/ip"
    #   content = "${config.sops.placeholder."autossh/ip"}";
    # };

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

    templates."sing-box-config2.json" = {
      content = builtins.toJSON {
        log.level = "info";

        inbounds = [
          {
            type = "http";
            tag = "http-proxy2";
            listen = "127.0.0.1";
            listen_port = 1085;
          }
          {
            type = "socks";
            tag = "socks-proxy2";
            listen = "127.0.0.1";
            listen_port = 1084;
          }
        ];
        outbounds = [
          {
            type = "ssh";
            tag = "ssh-out2";
            server = "${config.sops.placeholder."vpn-proxyuser/ip"}";
            server_port = 22;
            user = "${config.sops.placeholder."vpn-proxyuser/user"}";
            private_key_path = "${config.sops.placeholder."vpn-proxyuser/private_key_path"}";
          }
        ];
        route.rules = [
          {
            inbound = ["http-proxy2" "socks-proxy2"];
            outbound = "ssh-out2";
          }
        ];
      };
    };

    templates."sing-box-config3.json" = {
      content = builtins.toJSON {
        log.level = "info";

        inbounds = [
          {
            type = "http";
            tag = "http-proxy3";
            listen = "127.0.0.1";
            listen_port = 1087;
          }
          {
            type = "socks";
            tag = "socks-proxy3";
            listen = "127.0.0.1";
            listen_port = 1086;
          }
        ];
        outbounds = [
          {
            type = "ssh";
            tag = "ssh-out3";
            server = "${config.sops.placeholder."vpn-directuser/ip"}";
            server_port = 22;
            user = "${config.sops.placeholder."vpn-directuser/user"}";
            private_key_path = "${config.sops.placeholder."vpn-directuser/private_key_path"}";
          }
        ];
        route.rules = [
          {
            inbound = ["http-proxy3" "socks-proxy3"];
            outbound = "ssh-out3";
          }
        ];
      };
    };
  };
}
