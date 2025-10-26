# Загружаем переменные из .env
include .env
export

REPO_URL := https://github.com/back2nix/my-astronvim-config
REPO_DIR := my-astronvim-config

### flake
switch:
	sudo nixos-rebuild switch --flake .#$(DEVICE)

nix:
	sudo nixos-rebuild switch --flake .#$(DEVICE)

# home:
# 	home-manager switch
#
# flake:
# 	home-manager switch --flake .

sync:
	rsync -avP \
		--exclude='private' \
		--exclude='presharedKeyFile' \
		--exclude='Makefile' \
		--exclude='.env' \
		/etc/nixos/* .
	cd $(REPO_DIR) && make sync
# --exclude='hardware-configuration.nix' \

push:
	git add -u && git commit -m "make push" && git push || (git pull --rebase && git push)
	cd $(REPO_DIR) && git add -u && git commit -m "make push" && git push || (git pull --rebase && git push)

pull:
	@if [ -d "$(REPO_DIR)" ]; then \
		echo "Обновление репозитория..."; \
		cd $(REPO_DIR) && git pull; \
		echo "Репозиторий обновлен."; \
	else \
		git clone $(REPO_URL) $(REPO_DIR); \
	fi

setup: pull
	rsync -avP $(REPO_DIR)/plugins ~/.config/nvim/lua/

### testing on vm
build:
	nix build .#nixosConfigurations.$(DEVICE).config.system.build.vm

run/nographic:
	QEMU_KERNEL_PARAMS=console=ttyS0 ./result/bin/run-nixos-vm -nographic; reset

update/nixvim:
	nix flake lock --update-input nixvim

update/replacer:
	nix flake lock --update-input replacer

update:
	nix flake update

update/mutter:
	nix flake lock --update-input mutter-src

# Переключение на конкретное устройство (переопределяет .env)
switch/device:
	@read -p "Введите имя устройства (asus/huawei/yoga14): " device; \
	sudo nixos-rebuild switch --flake .#$$device

fmt/alejandra:
	alejandra .

fmt/check:
	alejandra .

# Показать текущее устройство
show/device:
	@echo "Текущее устройство: $(DEVICE)"
