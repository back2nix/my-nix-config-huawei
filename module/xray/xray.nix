{
  config,
  pkgs-master,
  ...
}: let
  user = "xray";
in {
  users.users."${user}" = {
    isSystemUser = true;
    group = "${user}";
  };
  users.groups."${user}" = {};

  networking.firewall.allowedTCPPorts = [443 10086];
  networking.firewall.allowedUDPPorts = [443 10086];
  sops = {
    secrets = {
      uuid = {};
      privateKey = {};
      publicKey = {};
    };
    templates."xray.json" = {
      owner = "${user}";
      content = ''
        {
          "log": {
            "loglevel": "debug",
            "access": "/tmp/access.log",
            "error": "/tmp/error.log"
          },
          "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
              {
                "type": "field",
                "outboundTag": "block",
                "ip": ["geoip:private"]
              },
              {
                "type": "field",
                "outboundTag": "block",
                "domain": ["geosite:category-ads-all"]
              }
              {
                "type": "field",
                "outboundTag": "direct",
                "domain": ["regexp:\\.ru$"]
              }
            ]
          },
          "inbounds": [
            {
              "port": 10086,
              "listen": "0.0.0.0",
              "protocol": "vless",
              "settings": {
                "clients": [
                  {
                    "id": "${config.sops.placeholder.uuid}",
                    "flow": "xtls-rprx-vision"
                  }
                ],
                "decryption": "none"
              },
              "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                  "show": false,
                  "dest": "www.microsoft.com:443",
                  "serverNames": [
                    "www.google.com",
                    "www.microsoft.com",
                    "www.bing.com"
                  ],
                  "privateKey": "${config.sops.placeholder.privateKey}",
                  "shortIds": [
                    "",
                    "114514"
                  ],
                  "maxTimeDiff": 0,
                  "fingerprint": "chrome"
                }
              },
              "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls"]
              }
            }
          ],
          "outbounds": [
            {
              "protocol": "freedom",
              "tag": "direct",
              "settings": {
                "domainStrategy": "UseIPv4"
              }
            },
            {
              "protocol": "blackhole",
              "tag": "block"
            }
          ],
          "policy": {
            "levels": {
              "0": {
                "handshake": 4,
                "connIdle": 300,
                "uplinkOnly": 2,
                "downlinkOnly": 5,
                "statsUserUplink": true,
                "statsUserDownlink": true,
                "bufferSize": 4
              }
            },
            "system": {
              "statsInboundUplink": true,
              "statsInboundDownlink": true,
              "statsOutboundUplink": true,
              "statsOutboundDownlink": true
            }
          },
          "stats": {}
        }
      '';
    };
  };

  services.xray = {
    enable = true;
    # package = pkgs-master.xray;
    package =
      pkgs-master.xray.overrideAttrs
      (prev: {patches = prev.patches or [] ++ [./disable-splice.patch];});
    settingsFile = config.sops.templates."xray.json".path;
  };
  systemd.services.xray = {
    wants = ["sops-nix.service"];
    after = ["sops-nix.service"];
    serviceConfig.User = "${user}";
  };
}
