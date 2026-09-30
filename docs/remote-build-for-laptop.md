# Сборка обновления ноутбука на мощной машине

Цель: не компилировать обновление на слабом ноутбуке (`yoga14`), а собрать его на `desktop` и скопировать готовое.

`just switch` на desktop собирает только `.#desktop`. Конфиг ноутбука отличается (модули, ядро, mutter), поэтому его нужно собрать отдельно.

## 1. На desktop

```bash
just update
nix build .#nixosConfigurations.yoga14.config.system.build.toplevel
git commit -am "update flake.lock" && git push   # ноутбуку нужен тот же flake.lock
```

## 2. На ноутбуке

```bash
git pull   # flake.lock должен совпадать до байта
nix copy --from ssh-ng://desktop \
  $(nix eval --raw .#nixosConfigurations.yoga14.config.system.build.toplevel.outPath)
just switch   # всё уже в store, компиляции нет
```

## Условия

- Одинаковый `flake.lock` на обеих машинах, иначе хеши разойдутся и начнётся локальная сборка.
- Для `nix copy --from` пользователь ноутбука должен быть в `nix.settings.trusted-users`, или пути должны быть подписаны ключом desktop.
- Обе машины x86_64-linux.

## Альтернатива: desktop как постоянный кеш

На desktop поднять `nix-serve` или `harmonia` с ключом подписи. На ноутбуке добавить его в `substituters` и `trusted-public-keys`. Внимание: `just switch` сейчас явно задаёт `--option substituters "https://cache.nixos.org"`, так что desktop-кеш придётся дописать и туда.
