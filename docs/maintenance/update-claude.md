# Обновление Claude Code

> **Важно:** Если в процессе обновления обнаружился flow, которого нет в этой инструкции — обнови или дополни её.

Чтобы обновить `claude-code` до новой версии, выполните следующие шаги:

## 1. Получите хэш исходного кода (src)

Замените `<VERSION>` на нужную версию:
```bash
nix-prefetch-url --unpack https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-<VERSION>.tgz | xargs nix hash convert --to sri --type sha256
```

## 2. Отредактируйте `overlays/default.nix`

Обновите `version` и `src.hash`. Структура должна выглядеть **именно так** (с явным `npmDeps`):

```nix
claude-code = final.unstable.claude-code.overrideAttrs (oldAttrs: rec {
  version = "<VERSION>";
  src = final.fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "<SRC_HASH>";
  };
  npmDeps = prev.fetchNpmDeps {
    name = "claude-code-${version}-npm-deps";
    inherit src;
    postPatch = oldAttrs.postPatch;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
});
```

### Почему именно так, а не `npmDepsHash`

`claude-code` в nixpkgs использует `buildNpmPackage` через `lib.extendMkDerivation`.
При `overrideAttrs` атрибут `npmDeps` **не пересчитывается** — он уже зафиксирован как store path
старой версии. Поэтому нужно явно переопределить `npmDeps`.

Кроме того, `package-lock.json` **не входит в tgz** (там только `bun.lock`). Nixpkgs
хранит `package-lock.json` рядом с рецептом и копирует его через `postPatch`. Поэтому
`postPatch = oldAttrs.postPatch` — обязателен, иначе `fetchNpmDeps` упадёт с
`ERROR: No lock file!`.

**Примечание:** Зависимости `claude-code` (только `@img/sharp-*` опциональные) меняются
редко. Если версия `@img/sharp-*` в `package.json` не изменилась, `npmDepsHash` будет
совпадать со старым. Это нормально.

## 3. Получите правильный `npmDepsHash`

Запустите сборку (хост — `yoga14`):
```bash
nix build .#nixosConfigurations.yoga14.pkgs.claude-code
```

Nix выдаст ошибку `hash mismatch`. Скопируйте хэш из строки `got:` и вставьте его в
`npmDeps.hash`.

## 4. Финальная проверка сборки

```bash
nix build .#nixosConfigurations.yoga14.pkgs.claude-code
```

Нет вывода ошибок — всё готово к `nixos-rebuild switch`.
