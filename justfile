# Загружаем переменные из .env
set dotenv-load

# Основная команда для пересборки системы
default:
    sudo nixos-rebuild switch --flake .#{{env_var('DEVICE')}}

# Пересборка NixOS
nix:
    sudo nixos-rebuild switch --flake .#{{env_var('DEVICE')}}

# Сборка VM для тестирования
build:
    nix build .#nixosConfigurations.{{env_var('DEVICE')}}.config.system.build.vm

# Запуск VM без графики
run-nographic:
    #!/usr/bin/env bash
    QEMU_KERNEL_PARAMS=console=ttyS0 ./result/bin/run-nixos-vm -nographic
    reset

# Обновление nixvim
update-nixvim:
    nix flake lock --update-input nixvim

# Обновление replacer
update-replacer:
    nix flake lock --update-input replacer

# Полное обновление flake
update:
    nix flake update

# Переключение на конкретное устройство (переопределяет .env)
switch-device device:
    sudo nixos-rebuild switch --flake .#{{device}}

# Форматирование кода с помощью alejandra
fmt-alejandra:
    alejandra .

# Проверка форматирования
fmt-check:
    alejandra .

# Показать текущее устройство из .env
show-device:
    @echo "Текущее устройство: {{env_var('DEVICE')}}"
