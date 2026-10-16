# Инцидент 2026-06-17: `nixos-rebuild` виснет на скачивании + слетела тема tmux

## Симптомы

1. После обновления системы `tmux` потерял тему onedark — статус-бар стал
   дефолтным зелёным.
2. `sudo nixos-rebuild switch` намертво виснет на строке вида:
   ```
   copying path '/nix/store/pqj…-source' from 'https://nix-community.cachix.org'...
   [1/0/1 copied (0.0 KiB/116.1 KiB), 18.3/33.0 KiB DL] fetching source from …
   ```
   Загрузка стопорится **всегда на одном и том же байте (~18745)**, мелкие
   запросы (narinfo) проходят, дальше — `0 bytes/sec`.

## Диагностика (что НЕ было причиной)

Долго шли по ложным следам — фиксируем, чтобы не повторять:

- **Прокси демона.** Сначала казалось, что `nix-daemon` стартовал без прокси.
  Меняли socks 1082 ↔ http 1083 ↔ убирали совсем — **не помогало**.
- **`NO_PROXY` / обход прокси для кэшей.** Добавление `.cachix.org` в `NO_PROXY`
  только ухудшало: прямое соединение к cachix у нас **виснет** (маршрут/гео),
  качает лишь через прокси.
- **Диск, inode, права на /nix/store.** В норме (207G свободно).
- **Битый NAR / cachix.** `curl` и `nix store prefetch-file` тот же файл качают
  целиком за 0.6с — сервер исправен.

Ключевое наблюдение: **одиночный `curl`/`nix copy` с клиента качает нормально, а
`nix-daemon` стабильно рвётся на фиксированном offset.**

## Настоящая причина: HTTP/2 в nix

`nix` по умолчанию качает через HTTP/2 (nghttp2). На некоторых путях/через прокси
поток HTTP/2 **залипает на середине** — HTTP 200, обрыв на фиксированном offset,
`Less than 1 byte/sec`. `curl` работает, т.к. использует HTTP/1.1.

Известный баг: <https://github.com/NixOS/nix/issues/11352>
(см. также <https://github.com/NixOS/nix/issues/1181>).

### Фикс

В `cachix.nix` → `nix.settings`:
```nix
http2 = false;
```
Для немедленной разблокировки (без пересборки): `--option http2 false`.

После этого сборка поехала (`3.5/4.0 MiB DL` вместо виса на 33 КБ).

## Сопутствующие изменения

- **garnix убран из `substituters`** (`cachix.nix`): он отдаёт только то, что
  собрал его CI; без подключённого garnix-CI уникальных попаданий почти не даёт,
  лишь дублирует cache.nixos.org/cachix. Пути, что были только на garnix,
  собираются локально.
- **Сеть:** прямое соединение к бинарным кэшам у нас виснет, рабочий путь — через
  sing-box (socks `127.0.0.1:1082` или http `127.0.0.1:1083`). Прокси демона
  задаётся в `cachix.nix` (`systemd.services.nix-daemon.serviceConfig.Environment`).
  ВАЖНО: при смене прокси демон надо реально перезапускать
  (`systemctl restart nix-daemon`), иначе живой процесс работает со старым env.

## Тема tmux (отдельная, не связанная с сетью)

Плагин `tmuxPlugins.onedark-theme` после обновления nixpkgs приехал со старым
шебангом `#!/bin/bash`, которого на NixOS нет → `run-shell` плагина падает с
кодом 126 (`bad interpreter: /bin/bash`) → тема не применяется, tmux откатывается
на дефолт. Плюс плагин (2020 г.) использует опции эпохи tmux 2.x
(`status-bg`, `message-fg`, `*-attr`), удалённые в tmux 2.9.

### Фикс

В `module/users/bg/tmux/tmux.nix`: плагин отключён, тема onedark встроена в
`extraConfig` современным синтаксисом tmux 3.x (`-style` вместо `*-fg/*-bg/*-attr`).
Применить: пересборка + `tmux kill-server`.

## Чеклист на будущее, если `nixos-rebuild` снова виснет на скачивании

1. `curl -o /dev/null -w '%{size_download}\n' <nar-url>` со своей машины — если
   качает, а nix висит → почти наверняка HTTP/2: добавь `--option http2 false`.
2. Прямое соединение к кэшу висит? → ходи через прокси (sing-box 1082/1083) и
   проверь, что `nix-daemon` реально перезапущен с нужным env
   (`sudo cat /proc/$(pgrep -o nix-daemon)/environ | tr '\0' '\n' | grep -i proxy`).

---

# Инцидент 2026-06-27 (desktop): `error: Cannot parse Nix store 'cache.nixos.org'`

## Симптомы

На сервере `desktop` (`ssh bg@192.168.3.78`) `sudo nixos-rebuild switch --flake
…#desktop --option http2 false --option substituters "https://cache.nixos.org"`
падает сразу:
```
building the system configuration...
error: Cannot parse Nix store 'cache.nixos.org'
Try 'nix --help' for more information.
Command 'nix … build … --option http2 false --option substituters https://cache.nixos.org' returned non-zero exit status 1.
```
Подсказка `Try 'nix --help'` ⇒ это `UsageError` на этапе разбора настроек, а не
ошибка вычисления флейка.

## Причина: голый хост (без схемы) в `trusted-substituters` устаревшего `/etc/nix/nix.conf`

Сообщение `Cannot parse Nix store '<X>'` nix выдаёт, когда в настройке типа
«стор» (`substituters`/`trusted-substituters`) лежит **голое имя хоста без
`https://`**. Проверено: `--option substituters "cache.nixos.org"` (без схемы)
даёт ровно эту строку; со схемой — ок.

На `desktop` развёрнутый `/etc/nix/nix.conf` (старое поколение, ещё с garnix и
cuda) содержал:
```
trusted-substituters = cache.nixos.org nix-community.cachix.org   # ← без https://
```
Почему **только под root**: `bg` ходит через `nix-daemon` и `trusted-substituters`
в стор-объекты не разбирает (для него голое имя безразлично — `nix build` как
`bg` собирает десктоп без ошибок). Root же открывает локальный стор напрямую и
парсит `trusted-substituters` в сторы → голое имя кидает `UsageError`.

**Важно — `--option` НЕ помогает.** `--option trusted-substituters ""`
(и `--option substituters ""`) не убирают ошибку: root открывает стор с
**файловым** merged-конфигом и парсит `trusted-substituters` ещё до того, как
применятся CLI-overrides. Проверено на сервере — падает с теми же флагами.
Лечится только правкой самого файла `/etc/nix/nix.conf`.

Курица-и-яйцо: в репозитории `cachix.nix` это **уже исправлено** (схемы есть:
`"https://cache.nixos.org/"`, `"https://nix-community.cachix.org"`), но живая
система старее этого фикса, и пересобраться через сломанный `nix.conf` нельзя.

### Фикс (разовый, чтобы прошла одна пересборка)

`/etc/nix/nix.conf` — симлинк на read-only стор (`/etc/static/...`), писать сквозь
него нельзя. Подменяем симлинк реальным исправленным файлом; успешный `switch`
потом сам перегенерит `/etc/nix/nix.conf` из `cachix.nix`.
```
sudo cp -L /etc/nix/nix.conf /etc/nix/nix.conf.fixed
sudo sed -i \
  -e 's#^substituters = .*#substituters = https://cache.nixos.org/ https://nix-community.cachix.org#' \
  -e 's#^trusted-substituters = .*#trusted-substituters = https://cache.nixos.org/ https://nix-community.cachix.org#' \
  /etc/nix/nix.conf.fixed
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.symlink-bak
sudo mv /etc/nix/nix.conf.fixed /etc/nix/nix.conf

sudo nixos-rebuild switch \
  --flake ~/Documents/code/github.com/back2nix/nix/my-nix-config-huawei#desktop \
  --option http2 false
```
Правок в репозитории не требуется: причина — устаревший развёрнутый `nix.conf`,
а не текущий код.

### Диагностика

- `nix build nixpkgs#hello --dry-run --option substituters "cache.nixos.org"`
  (как `bg`) — голое имя даёт `warning: Cannot parse Nix store 'cache.nixos.org'`,
  подтверждая, что строку рождает голый хост в стор-настройке.
- `sudo nix config show | grep -nE 'substituters'` — видно итоговый merged-конфиг
  root-а; ищем запись без `https://`. ВНИМАНИЕ: `grep -r cache.nixos.org /etc/nix/`
  ничего не найдёт — `nix.conf` там симлинк, а `grep -r` симлинки не разворачивает.
- Быстрая проверка фикса (падает мгновенно на setup, если ошибка осталась):
  `sudo nix build '<flake>#nixosConfigurations."desktop"...toplevel' --dry-run --option http2 false`
