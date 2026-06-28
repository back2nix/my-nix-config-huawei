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
      "autossh/ip" = {};

      "mutter/hide_keywords_list" = {
        owner = config.users.users.bg.name;
        mode = "0400";
      };

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
        restartUnits = ["atticd.service"];
      };
    };

    # sops/sops.nix - templates."sing-box-config.json"
    templates."sing-box-config.json" = {
      content = builtins.toJSON {
        log.level = "info";

        inbounds = [
          {
            type = "socks";
            tag = "socks-usa";
            listen = "0.0.0.0";
            listen_port = 1082;
          }
          {
            type = "http";
            tag = "http-usa";
            listen = "0.0.0.0";
            listen_port = 1083;
          }
          {
            type = "socks";
            tag = "socks-china";
            listen = "0.0.0.0";
            listen_port = 1084;
          }
          {
            type = "http";
            tag = "http-china";
            listen = "0.0.0.0";
            listen_port = 1085;
          }
        ];

        outbounds = [
          {
            type = "ssh";
            tag = "ssh-out1";
            server = "${config.sops.placeholder."vpn1/ip"}";
            server_port = 22;
            user = "${config.sops.placeholder."vpn1/user"}";
            private_key_path = "${config.sops.placeholder."vpn1/private_key_path"}";
          }
          {
            type = "http";
            tag = "vpn3-proxy";
            # server = "192.168.43.1"; # mobile-china
            # server = "192.168.1.5"; # wifi-china
            server = "192.168.3.6"; # wifi-home
            server_port = 8080;
          }
          {
            type = "ssh";
            tag = "ssh-out1-via-vpn3";
            server = "${config.sops.placeholder."vpn1/ip"}";
            server_port = 22;
            user = "${config.sops.placeholder."vpn1/user"}";
            private_key_path = "${config.sops.placeholder."vpn1/private_key_path"}";
            detour = "vpn3-proxy";
          }
        ];

        route.rules = [
          {
            inbound = ["socks-usa" "http-usa"];
            outbound = "ssh-out1";
          }
          {
            inbound = ["socks-china" "http-china"];
            outbound = "ssh-out1-via-vpn3";
          }
        ];
      };
    };
  };
}
