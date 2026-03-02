# Обновление Claude Code

Чтобы обновить `claude-code` до новой версии, выполните следующие шаги:

1. **Узнайте новую версию** на [npm](https://www.npmjs.com/package/@anthropic-ai/claude-code).

2. **Получите хэш исходного кода (src):**
   Замените `<VERSION>` на нужную версию:
   ```bash
   nix-prefetch-url --unpack https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-<VERSION>.tgz | xargs nix hash convert --to sri --type sha256
   ```

3. **Отредактируйте `overlays/default.nix`:**
   - Обновите `version`.
   - Вставьте полученный хэш в `src.hash`.
   - Установите `npmDepsHash = "";` (пустая строка заставит Nix выдать ошибку с правильным хэшем).

4. **Запустите сборку для получения хэша зависимостей:**
   ```bash
   nix build .#claude-code
   ```
   Nix выдаст ошибку `hash mismatch`. Скопируйте хэш из строки `got:` и вставьте его в `npmDepsHash`.

5. **Проверьте финальную сборку:**
   ```bash
   nix build .#claude-code
   ```
