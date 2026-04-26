# Обновление Claude Code

> **Важно:** Если в процессе обновления обнаружился flow, которого нет в этой инструкции — обнови или дополни её.

Чтобы обновить `claude-code` до новой версии, выполните следующие шаги:

## 1. Получите хэши

Замените `<VERSION>` на нужную версию:

```bash
# Хэш основного tgz (src)
nix-prefetch-url --unpack https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-<VERSION>.tgz \
  | xargs -I{} nix hash to-sri --type sha256 {}

# Хэш нативного бинарника linux-x64
nix-prefetch-url --unpack https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-<VERSION>.tgz \
  | xargs -I{} nix hash to-sri --type sha256 {}
```

## 2. Подготовьте `package-lock.json` и `package.json`

Начиная с версий после 2.1.81, `optionalDependencies` в `package.json` изменились с
`@img/sharp-*` на `@anthropic-ai/claude-code-<platform>`. Нативный бинарник мы поставляем
сами через `claude-code-native-linux-x64`, поэтому нужны stripped-файлы без `optionalDependencies`:

```bash
# Распакуйте tgz
mkdir -p /tmp/cc-update && cd /tmp/cc-update
curl -sL https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-<VERSION>.tgz | tar -xz

# Удалите optionalDependencies из package.json
python3 -c "
import json
with open('package/package.json') as f: d = json.load(f)
d.pop('optionalDependencies', None)
with open('package/package.json', 'w') as f: json.dump(d, f, indent=2)
"

# Сгенерируйте package-lock.json (без optional deps)
cd package && npm install --package-lock-only --ignore-scripts

# Скопируйте оба файла в pkgs/
cp package.json /path/to/repo/pkgs/claude-code-<VERSION>-package.json
cp package-lock.json /path/to/repo/pkgs/claude-code-<VERSION>-package-lock.json

# Добавьте оба файла в git (Nix flake не видит незакоммиченные файлы)
git add pkgs/claude-code-<VERSION>-package.json pkgs/claude-code-<VERSION>-package-lock.json
```

## 3. Отредактируйте `overlays/default.nix`

Структура должна выглядеть **именно так**:

```nix
# --- НАЧАЛО: Обновление claude-code до <VERSION> ---
claude-code-native-linux-x64 = prev.stdenv.mkDerivation {
  name = "claude-code-native-linux-x64-<VERSION>";
  src = prev.fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-<VERSION>.tgz";
    hash = "<NATIVE_HASH>";
  };
  # бинарник — это bun SFE; strip/autoPatchelfHook повреждают trailer
  nativeBuildInputs = [ prev.patchelf ];
  dontStrip = true;
  unpackPhase = "tar -xzf $src";
  installPhase = ''
    install -Dm755 package/claude $out/bin/claude
    patchelf --set-interpreter ${prev.glibc}/lib/ld-linux-x86-64.so.2 $out/bin/claude
  '';
};

claude-code = final.unstable.claude-code.overrideAttrs (oldAttrs: rec {
  version = "<VERSION>";
  src = final.fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "<SRC_HASH>";
  };
  postPatch = ''
    cp ${../pkgs/claude-code-<VERSION>-package-lock.json} package-lock.json
    cp ${../pkgs/claude-code-<VERSION>-package.json} package.json
  '';
  npmDeps = prev.fetchNpmDeps {
    name = "claude-code-${version}-npm-deps";
    inherit src;
    postPatch = postPatch;
    forceEmptyCache = true;  # нет зависимостей для кэширования
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  preInstall = "mkdir -p node_modules";  # npmInstallHook делает find node_modules
  postInstall = (oldAttrs.postInstall or "") + ''
    chmod +w $out/bin
    rm -f $out/bin/claude
    ln -s ${final.claude-code-native-linux-x64}/bin/claude $out/bin/claude
  '';
  doInstallCheck = false;
});
# --- КОНЕЦ: Обновление claude-code ---
```

### Почему именно так

- `npmDeps` при `overrideAttrs` **не пересчитывается** автоматически — нужно явно переопределить.
- `package-lock.json` **не входит в tgz** — используем свой stripped вариант.
- `package.json` без `optionalDependencies` — иначе `npm ci` падает, т.к. lock-файл не совпадает.
- `forceEmptyCache = true` — у пакета нет npm-зависимостей, fetchNpmDeps требует явного флага.
- `preInstall = "mkdir -p node_modules"` — `npmInstallHook` делает `find node_modules`, которая
  падает если директории нет.
- `postInstall` заменяет `$out/bin/claude` симлинком на нативный бинарник.

## 4. Получите правильный `npmDepsHash`

```bash
nix build .#nixosConfigurations.yoga14.pkgs.claude-code
```

Nix выдаст `hash mismatch`. Скопируйте хэш из строки `got:` и вставьте в `npmDeps.hash`.

## 5. Финальная проверка сборки

```bash
nix build .#nixosConfigurations.yoga14.pkgs.claude-code
result/bin/claude --version
```

Нет вывода ошибок, версия совпадает — всё готово к `nixos-rebuild switch`.
