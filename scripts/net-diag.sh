#!/usr/bin/env bash
# Снимок состояния сети, когда "нет интернета". Пишет всё в один файл и печатает путь.
# Цепочка DNS: app → blocky :53 → dnscrypt-proxy :5300 → sing-box socks :1082 → тоннель → Quad9 DoH.
# Запуск: just net-diag   (sudo спросит пароль для nft; без него просто пропустит)
set -u
out="${1:-$HOME/net-diag-$(date +%Y%m%d-%H%M%S).log}"
exec > >(tee "$out") 2>&1
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

sec() { printf '\n===== %s =====\n' "$*"; }
run() { printf '\n$ %s\n' "$*"; timeout 20 "$@" 2>&1; echo "[exit $?]"; }
sudo -v 2>/dev/null; S() { sudo -n "$@" 2>&1 || echo "(sudo недоступен)"; }

sec "время / хост"; date -Is; uname -r; uptime
sec "сервисы"
for s in sing-box zapret2 blocky dnscrypt-proxy NetworkManager systemd-resolved; do
  printf '%-18s %s\n' "$s" "$(systemctl is-active "$s" 2>&1)"; done
run systemctl --failed --no-pager

sec "сеть"
run ip -br addr; run ip route; run ip -6 route; run ip rule
run nmcli -t dev status; run cat /etc/resolv.conf
run ss -lntup

sec "прямая связность (мимо прокси)"
run ping -c2 -W2 1.1.1.1
run curl -sS -m8 -o /dev/null -w '%{http_code} %{time_total}s\n' https://1.1.1.1
run curl -sS -m8 -o /dev/null -w '%{http_code} %{time_total}s\n' https://9.9.9.9
for h in www.google.com ssl.gstatic.com www.youtube.com github.com api.anthropic.com; do
  run curl -sS -m10 -o /dev/null -w "$h %{http_code} dns=%{time_namelookup}s conn=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s\n" "https://$h"
done

sec "DNS по звеньям цепочки"
for h in ssl.gstatic.com www.google.com api.anthropic.com; do
  run dig +time=5 +tries=1 +short "$h" @127.0.0.1 -p 53      # blocky
  run dig +time=5 +tries=1 +short "$h" @127.0.0.1 -p 5300    # dnscrypt-proxy
  run dig +time=5 +tries=1 +short "$h" @1.1.1.1              # напрямую (может быть отклонено nft)
done

sec "через sing-box socks"
for p in 1082 1083 1080 1081 1084 1085; do
  ss -lnt "sport = :$p" | grep -q LISTEN || continue
  run curl -sS -m12 -o /dev/null -w "socks:$p google %{http_code} total=%{time_total}s\n" --socks5-hostname 127.0.0.1:$p https://www.google.com
  run curl -sS -m12 -o /dev/null -w "socks:$p quad9 %{http_code} total=%{time_total}s\n" --socks5-hostname 127.0.0.1:$p https://9.9.9.9
done

sec "nftables (zapret2 и прочее)"
S nft list ruleset
sec "nfqueue"; run cat /proc/net/netfilter/nfnetlink_queue

sec "логи sing-box: ошибки/предупреждения за 30 мин"
journalctl -u sing-box --since -30min --no-pager | grep -vE 'inbound connection (from|to)' | tail -300
sec "логи sing-box: последние 150 строк целиком"
journalctl -u sing-box -n 150 --no-pager
for s in zapret2 dnscrypt-proxy blocky NetworkManager; do
  sec "логи $s за 30 мин"; journalctl -u "$s" --since -30min --no-pager | tail -120; done
sec "ядро за 30 мин"; journalctl -k --since -30min --no-pager | tail -60

echo; echo ">>> сохранено в: $out"
