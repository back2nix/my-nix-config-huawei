{ config, pkgs, lib, ... }:

# Вариант B: secure DNS через proxy (обход цензуры/отравления DNS под GFW).
#
# blocky сам через SOCKS/HTTP ходить не умеет, поэтому промежуточным звеном
# ставим dnscrypt-proxy2: он держит DoH к Quad9 и заворачивает его в sing-box.
#
#   blocky (127.0.0.1:53)
#     └─ strict, по порядку:
#        1. 127.0.0.1:5300  → dnscrypt-proxy → socks5 1082 → ssh-out1 (Seoul) → Quad9 DoH
#        2. 9.9.9.9 / 149...  → plain напрямую (твой failover, остаётся как есть)
#
# Петли нет: Quad9 задан static-стампом с зашитым IP 9.9.9.9, поэтому
# bootstrap-резолв hostname'а не нужен (курица/яйцо исключена).
{
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:5300" ];

      # DoH идёт по TCP/443, а SOCKS у sing-box — TCP. UDP через прокси не нужен.
      force_tcp = true;

      # Не тянем публичный список резолверов (его загрузка сама требовала бы
      # bootstrap-DNS). Работаем только по своему static-стампу ниже.
      server_names = [ "quad9-doh-proxied" ];
      ignore_system_dns = true;

      # Весь исходящий трафик dnscrypt-proxy — через sing-box socks-usa (1082),
      # т.е. SSH-тоннель на google-seoul напрямую, выход за GFW одним прыжком.
      proxy = "socks5://127.0.0.1:1082";

      # IP уже зашит в стамп → bootstrap не используется, но поле обязательно.
      bootstrap_resolvers = [ "9.9.9.9:53" "1.1.1.1:53" ];

      static.quad9-doh-proxied.stamp =
        "sdns://AgcAAAAAAAAABzkuOS45LjkADWRucy5xdWFkOS5uZXQKL2Rucy1xdWVyeQ";
    };
  };

  # dnscrypt-proxy бесполезен без тоннеля — стартуем после sing-box.
  systemd.services.dnscrypt-proxy = {
    after = [ "sing-box.service" ];
    wants = [ "sing-box.service" ];
  };
}
