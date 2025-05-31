{
  pkgs,
  config,
  lib,
  ...
}: {
  services.resolved.enable = false;

  systemd.services.cloudflared-doh = {
    enable = true;
    description = "DNS over HTTPS (DoH) proxy client";
    wants = [
      "network-online.target"
      "nss-lookup.target"
    ];
    before = ["nss-lookup.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      DynamicUser = "yes";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared proxy-dns";
    };
  };

  # Явно управляем resolv.conf
  networking = {
    resolvconf.useLocalResolver = true;
    networkmanager.dns = lib.mkForce "none";
    nameservers = ["127.0.0.1"];
    dhcpcd.extraConfig = "nohook resolv.conf";
  };

  # Или принудительно создаём resolv.conf
  environment.etc."resolv.conf".text = lib.mkForce ''
    nameserver 127.0.0.1
    options edns0 trust-ad
  '';
}
