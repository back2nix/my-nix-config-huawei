# Когда прокси лёг

Сначала переключи маршрут 1082/1083, а не правь конфиг руками:

```bash
proxy-mode            # что сейчас
proxy-mode casino     # google-seoul через casino-VPS
proxy-mode seoul      # прямой ssh до google-seoul (режим по умолчанию)
proxy-mode frankfurt  # выход через Frankfurt (ssh-frankfurt)
proxy-mode direct     # без проксирования, выход с самого ноутбука
```

То же самое мышью — плитка «Прокси 1082» в Quick Settings, рядом с WinJoy VPN:
клик раскрывает список «Через USA / Через Casino / Через Frankfurt / Без VPN». sing-box при этом
не перезапускается, выбор переживает ребут. Устройство: module/proxy-mode.nix
(скрипт + расширение gnome-shell), selector `usa-select` в sops/sops.nix.

Ниже — ручные обходные пути, если не помогло и это.

```bash
sudo tee /run/systemd/system/nix-daemon.service.d/proxy.conf >/dev/null <<'EOF'
[Service]
Environment=HTTP_PROXY=socks5h://127.0.0.1:1086
Environment=HTTPS_PROXY=socks5h://127.0.0.1:1086
Environment=ALL_PROXY=socks5h://127.0.0.1:1086
Environment=NO_PROXY=localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8
EOF
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon
systemctl show nix-daemon -p Environment
```

```bash
sudo tee /run/systemd/system/nix-daemon.service.d/proxy.conf >/dev/null <<'EOF'
[Service]
Environment=HTTP_PROXY=socks5h://127.0.0.1:1082
Environment=HTTPS_PROXY=socks5h://127.0.0.1:1082
Environment=ALL_PROXY=socks5h://127.0.0.1:1082
Environment=NO_PROXY=localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8
EOF
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon
systemctl show nix-daemon -p Environment
```
