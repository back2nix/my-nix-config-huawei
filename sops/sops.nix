{config, ...}: {
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/bg/.config/sops/age/keys.txt";
    age.generateKey = true;

    secrets = {
      # vpn1 = google-seoul-proxy (35.212.30.39)
      "vpn1/ip" = {};
      "vpn1/user" = {};
      "vpn1/private_key_path" = {};

      # vpn2 = germany-1 (178.215.236.246)
      "vpn2/ip" = {};
      "vpn2/user" = {};
      "vpn2/private_key_path" = {};

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
          # auto (urltest)
          {
            type = "socks";
            tag = "socks-auto";
            listen = "0.0.0.0";
            listen_port = 1082;
          }
          {
            type = "http";
            tag = "http-auto";
            listen = "0.0.0.0";
            listen_port = 1083;
          }
          # usa (vpn1)
          {
            type = "socks";
            tag = "socks-usa";
            listen = "0.0.0.0";
            listen_port = 1084;
          }
          {
            type = "http";
            tag = "http-usa";
            listen = "0.0.0.0";
            listen_port = 1085;
          }
          # germany (vpn2)
          {
            type = "socks";
            tag = "socks-de";
            listen = "0.0.0.0";
            listen_port = 1086;
          }
          {
            type = "http";
            tag = "http-de";
            listen = "0.0.0.0";
            listen_port = 1087;
          }
        ];
        outbounds = [
          {
            type = "urltest";
            tag = "auto";
            outbounds = ["ssh-out1" "ssh-out2"];
            url = "http://www.gstatic.com/generate_204";
            interval = "5s";
            tolerance = 50;
            idle_timeout = "30m";
          }
          {
            type = "ssh";
            tag = "ssh-out1";
            server = "${config.sops.placeholder."vpn1/ip"}";
            server_port = 22;
            user = "${config.sops.placeholder."vpn1/user"}";
            private_key_path = "${config.sops.placeholder."vpn1/private_key_path"}";
          }
          {
            type = "ssh";
            tag = "ssh-out2";
            server = "${config.sops.placeholder."vpn2/ip"}";
            server_port = 2222;
            user = "${config.sops.placeholder."vpn2/user"}";
            private_key_path = "${config.sops.placeholder."vpn2/private_key_path"}";
          }
        ];
        route.rules = [
          {
            inbound = ["socks-auto" "http-auto"];
            outbound = "auto";
          }
          {
            inbound = ["socks-usa" "http-usa"];
            outbound = "ssh-out1";
          }
          {
            inbound = ["socks-de" "http-de"];
            outbound = "ssh-out2";
          }
        ];
      };
    };
  };
}
