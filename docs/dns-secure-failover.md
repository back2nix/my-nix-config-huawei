# Secure DNS, failover и откат без перезагрузки

Дата: 2026-06-18

Документ описывает: как устроен DNS в этой конфигурации, какое изменение
(Вариант A) предложено для надёжного secure-first + failover, почему завернуть
DNS в proxy безопасно (нет петли), и **как откатиться без перезагрузки**, если
после применения пропал интернет.

## Текущая архитектура DNS

- `module/blocky/default.nix` — blocky слушает `127.0.0.1:53` (активный конфиг).
- `module/network-configuration.nix` — `/etc/resolv.conf` пишется вручную:
  ```
  nameserver 127.0.0.1      # blocky
  nameserver 8.8.8.8        # plain fallback
  nameserver 1.1.1.1        # plain fallback
  options edns0 trust-ad timeout:1 attempts:1
  ```
- `module/sign-box.nix` + `sops/sops.nix` — sing-box, socks/http inbounds на
  портах 1082–1085. **Серверы прокси заданы по IP** (`vpn1/ip`, `192.168.3.6`),
  не по hostname.
- systemd-resolved выключен; `/etc/resolv.conf` — единственный источник истины.
- `module/blocky/settings.nix` — мёртвый файл, нигде не импортируется.

## Найденные проблемы

1. **«Секьюрный» DNS не гарантирован.** В `default.nix` группа `default`
   смешивает plain (`8.8.8.8`, `9.9.9.9`, `1.1.1.1`) и DoH (`dns.quad9.net`) в
   одном списке. Дефолтная стратегия blocky — `parallel_best`: берётся 2
   случайных резолвера из четырёх → примерно половина запросов уходит
   **открытым текстом**.
2. **Нет осмысленного failover secure→plain внутри blocky.** Если blocky жив, но
   все upstream'ы недоступны (например, GFW режет 443/853), resolv.conf не
   помогает — blocky отвечает SERVFAIL, на fallback не переключаемся.

Базовая защита «blocky совсем умер» уже работает: glibc по resolv.conf уходит на
plain `8.8.8.8`/`1.1.1.1`.

## Предложенное изменение — Вариант A (secure-first + failover)

> Статус: предложено. На момент написания в `module/blocky/default.nix` ещё НЕ
> применено (правка была откачена для ручной проверки через `nixos-rebuild test`).

В `module/blocky/default.nix`, блок `settings`:

```nix
# bootstrapDns: только plain IP и напрямую (без прокси) — для резолва
# hostname'ов DoH/DoT. Иначе курица/яйцо.
bootstrapDns = [
  "9.9.9.9"
  "1.1.1.1"
];

upstreams = {
  # strict = строгий порядок с откатом: сначала защищённый DNS (DoH→DoT),
  # и только если оба недоступны — plain.
  strategy = "strict";
  # blocky всегда стартует, даже если upstream'ы недоступны (init в фоне).
  # ВАЖНО: в blocky v0.26 ключ — upstreams.init.strategy, а НЕ
  # верхнеуровневый startStrategy (тот вызовет ошибку check-blocky-config:
  # "field startStrategy not found in type config.Config").
  init.strategy = "fast";
  groups = {
    default = [
      "https://dns.quad9.net/dns-query"
      "tcp-tls:dns.quad9.net"
      "9.9.9.9"
      "149.112.112.112"
    ];
  };
};
```

Двухуровневый failover после применения:
1. secure отвалился, blocky жив → strict-откат на plain внутри blocky;
2. blocky целиком мёртв → glibc уходит на plain из `/etc/resolv.conf`.

## DNS через proxy: петли нет

Петля DNS↔proxy возникает, когда прокси для подключения к серверу должен
зарезолвить hostname, а резолвер завёрнут в этот же прокси. Здесь sing-box
подключается к серверам **по IP**, то есть DNS ему для туннелей не нужен.
Поэтому завернуть secure DNS в proxy (для обхода цензуры/отравления DNS под GFW)
безопасно. blocky сам через SOCKS/HTTP не ходит — потребуется промежуточный
`dnscrypt-proxy` (`proxy = socks5://127.0.0.1:1084`) с **plain IP bootstrap'ом**.
Это отдельный Вариант B, здесь не реализован.

## Как откатиться без перезагрузки

Откат на NixOS **не требует интернета**: предыдущая generation уже собрана и
лежит в `/nix/store`.

### 0. Деплоить безопасно
Применять через `test`, не `switch`:
```
sudo nixos-rebuild test --flake .
```
`test` активирует конфиг, но не делает его загрузочным по умолчанию — reboot
вернёт старое. Держите **отдельный root-терминал открытым** на время теста.

### 1. Мгновенно, без nix (самый частый случай)
Если интернет пропал из-за blocky:
```
sudo systemctl stop blocky
```
`127.0.0.1:53` → connection refused → glibc уходит на `8.8.8.8`/`1.1.1.1` из
resolv.conf. Вернуть: `sudo systemctl start blocky`.

> `/etc/resolv.conf` напрямую не редактируется — это symlink в read-only
> `/nix/store`. Поэтому `stop blocky` — самый быстрый ручной откат DNS.

### 2. Откат всей generation без перезагрузки
```
sudo nixos-rebuild switch --rollback
```
Активирует прошлую generation сразу, без reboot и без сети. Вручную:
```
ls -v /nix/var/nix/profiles/           # найти предыдущий system-<N>-link
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```

### 3. Крайний случай
Reboot и выбор предыдущей generation в загрузчике (systemd-boot/GRUB).

### Порядок действий при пропаже интернета
1. `sudo systemctl stop blocky` → проверить интернет (чаще всего хватает).
2. Не помогло → `sudo nixos-rebuild switch --rollback`.
3. Не помогло → reboot и старая generation в загрузчике.

## Проверка после применения
```
dig @127.0.0.1 example.com     # отвечает blocky
journalctl -u blocky -f        # видно выбранный upstream
```
