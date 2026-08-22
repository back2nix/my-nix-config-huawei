# Обновление Claude Code

> **Важно:** Если в процессе обновления обнаружился flow, которого нет в этой инструкции — обнови или дополни её.

Начиная с версии 2.1.154 используем новый подход: один бинарник напрямую с Google Storage.
Никакого npm, package-lock.json, нативных tgz — просто `fetchurl` + `autoPatchelfHook`.
Бинарник обычно уже есть в кэше [garnix.io](https://garnix.io), поэтому сборка занимает секунды.

## 0. Автоматическое обновление (обычный путь)

```bash
just update-claude
```

Скрипт `scripts/update-claude.sh` сам делает всё, что описано ниже вручную:
берёт максимум из `stable`/`latest`, сравнивает с версией в `overlays/default.nix`,
достаёт `checksum` для `linux-x64` из манифеста, правит версию/url/sha256 в блоке
`claude-code` и делает проверочную сборку `nixosConfigurations.<device>.pkgs.claude-code`.
Если версия уже актуальная — выходит без изменений.

Переменные:
- `CLAUDE_UPDATE_PROXY` — socks5-прокси для curl (по умолчанию `127.0.0.1:1082`,
  пустое значение = без прокси).
- `DEVICE` — цель для проверочной сборки (по умолчанию определяется по hostname).

Ручной flow ниже нужен только для отладки, если скрипт сломался.

## 1. Узнайте актуальную версию — ОБЯЗАТЕЛЬНО, не полагайтесь на память/предположения

`stable` — не всегда самая свежая версия, есть ещё `latest`. Проверяйте оба и берите
максимальный из них, сравнив с версией, установленной в `overlays/default.nix` сейчас:

```bash
curl -s --socks5-hostname 127.0.0.1:1082 \
  "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/stable"
curl -s --socks5-hostname 127.0.0.1:1082 \
  "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/latest"
```

Никогда не говорите пользователю "уже последняя версия", не сверив оба этих значения
с версией в `overlays/default.nix`. Если `latest`/`stable` больше текущей — версия
устарела, нужно обновлять.

## 2. Получите манифест с хэшами

Замените `<VERSION>` на версию, полученную на шаге 1:

```bash
curl -s --socks5-hostname 127.0.0.1:1082 \
  "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/<VERSION>/manifest.json" \
  | python3 -m json.tool
```

Из вывода берём поле `checksum` для `linux-x64`.

## 3. Отредактируйте `overlays/default.nix`

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

## 4. Соберите и проверьте

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
