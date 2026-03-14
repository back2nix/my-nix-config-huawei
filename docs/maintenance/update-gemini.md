# Обновление Gemini CLI

> **Важно:** Если в процессе обновления обнаружился flow, которого нет в этой инструкции — обнови или дополни её.

Обновление `gemini-cli` сложнее из-за монорепозитория и нескольких пакетов внутри.

## 1. Найдите версию на GitHub

[Releases google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli/releases)

## 2. Получите хэш исходного кода (src)

```bash
nix-prefetch-url --unpack https://github.com/google-gemini/gemini-cli/archive/refs/tags/v<VERSION>.tar.gz | xargs nix hash convert --to sri --type sha256
```

## 3. Отредактируйте `overlays/default.nix`

Обновите `version` и `src.hash`. В секции `npmDeps` поставьте фейковый хэш:

```nix
gemini-cli = final.unstable.gemini-cli.overrideAttrs (oldAttrs: rec {
  version = "<VERSION>";

  src = prev.fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${version}";
    hash = "<SRC_HASH>";
  };

  npmDeps = prev.fetchNpmDeps {
    inherit (oldAttrs) pname;
    inherit version src;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # postPatch и postInstall оставить как есть
  ...
});
```

## 4. Получите правильный `npmDepsHash`

Запустите сборку (хост — `yoga14`):
```bash
nix build .#nixosConfigurations.yoga14.pkgs.gemini-cli
```

Nix выдаст ошибку `hash mismatch`. Скопируйте хэш из строки `got:` и вставьте его в
`npmDeps.hash`.

## 5. Финальная проверка сборки

```bash
nix build .#nixosConfigurations.yoga14.pkgs.gemini-cli
```

Нет вывода ошибок — всё готово к `nixos-rebuild switch`.

---

## Особенности структуры

- `gemini-cli` — монорепозиторий с пакетами `packages/sdk`, `packages/devtools`,
  `packages/core`, `packages/cli`.
- `postPatch` отключает сборку `vscode-ide-companion` и `test-utils`, а также
  переводит параллельный билд в последовательный (иначе падает в sandbox).
- `postInstall` копирует `packages/sdk` и `packages/devtools` в `node_modules`,
  т.к. они появились в монорепо и nixpkgs их не симлинкует автоматически.
- В отличие от `claude-code`, здесь `package-lock.json` **есть в исходниках** (GitHub),
  поэтому `postPatch` к `fetchNpmDeps` передавать не нужно.
