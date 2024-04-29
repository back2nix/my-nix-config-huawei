REPO_URL := https://github.com/back2nix/my-astronvim-config
REPO_DIR := my-astronvim-config

home:
	home-manager switch

nix:
	sudo nixos-rebuild switch

flake:
	home-manager switch --flake .

sync:
	rsync -avP \
		--exclude='private' \
		--exclude='presharedKeyFile' \
		/etc/nixos/* nixos
	rsync -avP ~/.config/home-manager/* .
	cd $(REPO_DIR) && make sync

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
	rsync -avP $(REPO_DIR)/user ~/.config/nvim/lua/
