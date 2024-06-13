#!/usr/bin/env nix-shell
#!nix-shell -i bash -p patchelf

ss-local -v -c /etc/nixos/module/shadowsocks.json
