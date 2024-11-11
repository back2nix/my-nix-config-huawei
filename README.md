### switch

```bash
git clone https://github.com/back2nix/my-nix-config-huawei
ln -s /home/bg/Documents/code/github.com/back2nix/nix/my-nix-config-huawei /etc/nixos
# recover secrets
cp -r /backup/.config/sops /home/$USER/.config/sops

sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

### update nixvim only

```bash
make update/nixvim
```
