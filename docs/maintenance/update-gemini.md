# Обновление Gemini CLI

Обновление `gemini-cli` сложнее из-за монорепозитория и нескольких пакетов внутри.

1. **Найдите версию на GitHub** в [репозитории google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli/releases).

2. **Получите хэш исходного кода (src):**
   ```bash
   nix-prefetch-url --unpack https://github.com/google-gemini/gemini-cli/archive/refs/tags/v<VERSION>.tar.gz | xargs nix hash convert --to sri --type sha256
   ```

3. **Обновите хэш и версию в `overlays/default.nix`** в секции `gemini-cli`:
   - `version = "...";`
   - `src.hash = "...";`

4. **Получите хэш NPM-зависимостей:**
   Самый простой способ — очистить `npmDeps.hash` в файле:
   ```nix
   npmDeps = prev.fetchNpmDeps {
     inherit (oldAttrs) pname;
     inherit version src;
     hash = ""; # Очистите это поле (или используйте lib.fakeHash)
   };
   ```
   И запустить сборку через NixOS конфигурацию (т.к. пакет в оверлее):
   ```bash
   # Например, для хоста huawei:
   nix build .#nixosConfigurations.huawei.pkgs.gemini-cli
   ```
   Nix выдаст `hash mismatch`. Скопируйте правильный хэш из поля `got:` и вставьте его в `npmDeps.hash`.

   **Если установлена утилита `prefetch-npm-deps`**, можно попробовать так (без скачивания всего репозитория вручную):
   ```bash
   # Нужно иметь исходники локально, чтобы запустить это
   nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json"
   ```
   Но способ с `hash = "";` в конфиге через `nix build` — самый надежный.

5. **Проверьте сборку:**
   ```bash
   nix build .#nixosConfigurations.huawei.pkgs.gemini-cli
   ```
