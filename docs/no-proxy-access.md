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
