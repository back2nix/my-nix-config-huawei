# Обновление Claude Code

> **Важно:** Если в процессе обновления обнаружился flow, которого нет в этой инструкции — обнови или дополни её.

Начиная с версии 2.1.154 используем новый подход: один бинарник напрямую с Google Storage.
Никакого npm, package-lock.json, нативных tgz — просто `fetchurl` + `autoPatchelfHook`.
Бинарник обычно уже есть в кэше [garnix.io](https://garnix.io), поэтому сборка занимает секунды.

## 1. Получите манифест с хэшами

Замените `<VERSION>` на нужную версию:

```bash
curl -s --socks5-hostname 127.0.0.1:1084 \
  "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/<VERSION>/manifest.json" \
  | python3 -m json.tool
```

Из вывода берём поле `checksum` для `linux-x64`.

## 2. Отредактируйте `overlays/default.nix`

Структура:

```nix
# --- НАЧАЛО: Обновление claude-code до <VERSION> ---
      claude-code = prev.stdenvNoCC.mkDerivation {
        pname = "claude-code";
        version = "<VERSION>";
        src = prev.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/<VERSION>/linux-x64/claude";
          sha256 = "<CHECKSUM_FROM_MANIFEST>";
        };
        dontUnpack = true;
        dontBuild = true;
        dontStrip = true;
        nativeBuildInputs = [ prev.autoPatchelfHook prev.makeBinaryWrapper ];
        buildInputs = [ prev.alsa-lib ];
        installPhase = ''
          runHook preInstall
          install -Dm755 $src $out/bin/claude
          wrapProgram $out/bin/claude \
            --set DISABLE_AUTOUPDATER 1 \
            --set DISABLE_INSTALLATION_CHECKS 1 \
            --set USE_BUILTIN_RIPGREP 0 \
            --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.alsa-lib ]} \
            --prefix PATH : ${prev.lib.makeBinPath [ prev.procps prev.ripgrep prev.bubblewrap prev.socat ]}
          runHook postInstall
        '';
        meta.mainProgram = "claude";
      };
# --- КОНЕЦ: Обновление claude-code до <VERSION> ---
```

## 3. Соберите и проверьте

```bash
nix build .#nixosConfigurations.yoga14.pkgs.claude-code
result/bin/claude --version
```

Версия совпадает — готово к `nixos-rebuild switch`.

---

## Старый подход (до 2.1.154, через npm — устарел)

До версии 2.1.154 пакет собирался через npm из tgz с registry.npmjs.org.
Это требовало stripped `package.json`/`package-lock.json` и было медленным.
Файлы старых версий лежат в `pkgs/claude-code-<VERSION>-package*.json` — можно удалить.
