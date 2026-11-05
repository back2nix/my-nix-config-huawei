# Обновление Gemini CLI

> **Важно:** Если в процессе обновления обнаружился flow, которого нет в этой инструкции — обнови или дополни её.

Обновление `gemini-cli` сложнее из-за монорепозитория и нескольких пакетов внутри.

## 1. Найдите версию на GitHub

[Releases google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli/releases)

Теги nightly имеют формат `v0.44.0-nightly.20260518.g5611ff40e` (не просто `v0.44.0-nightly`).
Актуальный список последних релизов:

```bash
curl -s "https://api.github.com/repos/google-gemini/gemini-cli/releases?per_page=10" \
  | python3 -c "import json,sys; [print(r['tag_name']) for r in json.load(sys.stdin)]"
```

## 2. Получите хэш исходного кода (src)

```bash
nix-prefetch-url --unpack https://github.com/google-gemini/gemini-cli/archive/refs/tags/v<VERSION>.tar.gz 2>&1 | tail -1 \
  | xargs nix hash convert --hash-algo sha256 --to sri
```

## 3. Отредактируйте `overlays/default.nix`

Обновите `version` и `src.hash`. В секции `npmDeps` поставьте фейковый хэш:

```nix
gemini-cli = final.unstable.gemini-cli.overrideAttrs (oldAttrs: rec {
  version = "<VERSION>";  # например: "0.44.0-nightly.20260518.g5611ff40e"

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

> **Если ошибка сети (`Failed sending data to the peer`)** — это временная нестабильность
> прокси. Запустите сборку повторно. Прокси (`http://127.0.0.1:1083`) уже прописан
> в окружении `nix-daemon` через `cachix.nix`.

## 5. Финальная проверка сборки

```bash
nix build .#nixosConfigurations.yoga14.pkgs.gemini-cli && result/bin/gemini --version
```

Выводит версию без ошибок — всё готово к `nixos-rebuild switch`.

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
- Теги nightly имеют полный формат с датой и коммитом:
  `v0.44.0-nightly.20260518.g5611ff40e` — именно его нужно указывать в `version`.
