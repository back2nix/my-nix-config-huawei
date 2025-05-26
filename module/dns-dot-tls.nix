{pkgs, ...}: {
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = ["~."];
    llmnr = "true";
    dnsovertls = "true";  # Принудительный DoT
    fallbackDns = [
      "1.1.1.1#cloudflare-dns.com"
      "8.8.8.8#dns.google"
      "1.0.0.1#cloudflare-dns.com"
      "8.8.4.4#dns.google"
      "2606:4700:4700::1111#cloudflare-dns.com"
      "2001:4860:4860::8888#dns.google"
      "2606:4700:4700::1001#cloudflare-dns.com"
      "2001:4860:4860::8844#dns.google"
    ];
    extraConfig = ''
      MulticastDNS=resolve
    '';
  };

  # Глобальные DNS серверы (только DoT)
  networking.nameservers = [
    "1.1.1.1#cloudflare-dns.com"
    "8.8.8.8#dns.google"
    "1.0.0.1#cloudflare-dns.com"
    "8.8.4.4#dns.google"
    "2606:4700:4700::1111#cloudflare-dns.com"
    "2001:4860:4860::8888#dns.google"
    "2606:4700:4700::1001#cloudflare-dns.com"
    "2001:4860:4860::8844#dns.google"
  ];
}
