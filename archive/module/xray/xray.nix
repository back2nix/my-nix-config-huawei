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

  networking.firewall.allowedTCPPorts = [
    443
    1081
    3080
    10809
  ];
  networking.firewall.allowedUDPPorts = [
    443
    1081
    3080
    10809
  ];
  sops = {
    templates."xray-server.json" = {
      owner = "${user}";
      content = ''
        {
          "log": {
            "loglevel": "warring",
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
              "port": 443,
              "listen": "0.0.0.0",
              "protocol": "vless",
              "settings": {
                "clients": [
                  {
                    "id": \"${config.sops.placeholder."xray/uuid"}\",
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
                    "www.bing.com",
                    "expresscomcleaning.com",
                    "usa.lg.pq.hosting",
                    "ref-server.com"
                  ],
                  "privateKey": \"${config.sops.placeholder."xray/privateKey"}\",
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
                "handshake": 1,
                "connIdle": 120,
                "uplinkOnly": 1,
                "downlinkOnly": 1,
                "statsUserUplink": true,
                "statsUserDownlink": true,
                "bufferSize": 32
              }
            },
            "system": {
              "statsInboundUplink": true,
              "statsInboundDownlink": true,
              "statsOutboundUplink": true,
              "statsOutboundDownlink": true
            }
          },
          "stats": {},
          "buffer": {
            "size": 16
          }
        }
      '';
    };
    templates."xray-client.json" = {
      owner = "${user}";
      content = ''
        {
          "log": {
            "loglevel": "warring"
          },
          "routing": {
            "domainStrategy": "IPOnDemand",
            "rules": [
                {
                    "type": "field",
                    "ip": [
                        "geoip:private"
                    ],
                    "outboundTag": "direct"
                }
            ]
          },
          "inbounds": [
            {
                "port": 1081,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "settings": {
                    "udp": true
                }
            },
            {
              "port": 10809,
              "listen": "127.0.0.1",
              "protocol": "http"
            }
          ],
          "outbounds": [
          {
            "protocol": "vless",
            "settings": {
              "vnext": [
                {
                  "address": "${config.sops.placeholder."xray/server"}",
                  "port": 443,
                  "users": [
                    {
                      "id": "${config.sops.placeholder."xray/uuid"}",
                      "flow": "xtls-rprx-vision",
                      "encryption": "none"
                    }
                  ]
                }
              ]
            },
            "streamSettings": {
              "network": "tcp",
              "security": "reality",
              "realitySettings": {
                "serverName": "www.microsoft.com",
                "fingerprint": "firefox",
                "shortId": "114514",
                "publicKey": "${config.sops.placeholder."xray/publicKey"}",
                "spiderX": "/"
              }
            }
          },
          {
            "protocol": "freedom",
            "tag": "direct"
          }
        ]
        }
      '';
    };
  };

  services.xray = {
    enable = true;
    package = pkgs-master.xray;
    # package =
    #   pkgs-master.xray.overrideAttrs
    #   (prev: {patches = prev.patches or [] ++ [./disable-splice.patch];});
    # settingsFile = config.sops.templates."xray-server.json".path;
    settingsFile = config.sops.templates."xray-client.json".path;
  };
  systemd.services.xray = {
    wants = ["sops-nix.service"];
    after = ["sops-nix.service"];
    serviceConfig.User = "${user}";
  };
}
