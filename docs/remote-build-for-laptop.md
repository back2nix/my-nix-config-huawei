# Сборка обновления ноутбука на мощной машине

Цель: не компилировать обновление на слабом ноутбуке (`yoga14`), а собрать его на `desktop` и скопировать готовое.

`just switch` на desktop собирает только `.#desktop`. Конфиг ноутбука отличается (модули, ядро, mutter), поэтому его нужно собрать отдельно.

## 1. На desktop

```bash
just update
git commit -am "update flake.lock" && git push
nix build --no-link .#nixosConfigurations.yoga14.config.system.build.toplevel
```

Собирать нужно **после** того, как репо на desktop приведено в итоговое состояние (последний коммит, никаких незакоммиченных правок). Любое изменение в конфиге, даже в не связанном с ноутбуком месте, меняет хеш системы. Тогда готовой системы на desktop не окажется, а `nix copy` упадёт с ошибкой:

```
error: path '/nix/store/…-nixos-system-yoga14-…' is required, but there is no substituter that can build it
```

Проверить, что хеши совпадают, можно так: выполни эту команду на обеих машинах, вывод должен быть одинаковым.

```bash
nix eval --raw .#nixosConfigurations.yoga14.config.system.build.toplevel.outPath
```

## 2. На ноутбуке

```bash
git pull   # тот же коммит и flake.lock, что на desktop
nix copy -s --no-check-sigs --from ssh-ng://desktop \
  $(nix eval --raw .#nixosConfigurations.yoga14.config.system.build.toplevel.outPath)
just switch   # всё уже в store, компиляции нет
```

Флаги:
- `-s` (`--substitute-on-destination`): всё, что есть в cache.nixos.org, ноутбук скачивает оттуда, а с desktop копирует только собранное локально. Без флага весь closure (~35 GiB) идёт с desktop.
- `--no-check-sigs`: пути, собранные на desktop, не подписаны, и без этого флага будет ошибка `lacks a signature by a trusted key`. Флаг работает только для trusted-пользователя (`nix.settings.trusted-users`) или через `sudo`.
- Прогресс `[N/M copied (X/Y GiB)]` выводится сам, если запускать в терминале без pipe. `-v` печатает каждый путь. По ssh-ng счётчик байт обновляется только после того, как путь скопирован целиком, поэтому на больших пакетах (openusd и т.п.) он подолгу стоит на месте. Это нормально.

Если `nix copy` не дошёл до конца, `just switch` всё равно можно запускать. Уже скопированное он возьмёт из store, остальное скачает из cache.nixos.org, а собранное только на desktop, но не скопированное, будет компилировать локально.

## Альтернатива: desktop как постоянный кеш

На desktop поднять `nix-serve` или `harmonia` и подписывать пути ключом. На ноутбуке добавить его в `substituters` и `trusted-public-keys`. Внимание: `just switch` сейчас явно задаёт `--option substituters "https://cache.nixos.org"`, так что desktop-кеш придётся дописать и туда.
