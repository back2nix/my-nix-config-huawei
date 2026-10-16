#!/usr/bin/env bash
# Обновление gemini-cli в overlays/default.nix до последнего стабильного релиза.
# Документация: docs/maintenance/update-gemini.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="$REPO_ROOT/overlays/default.nix"

current="$(sed -n 's/^ *version = "\([0-9A-Za-z.+-]*\)";/\1/p' "$OVERLAY" \
  | awk '/^0\./ {print; exit}')"
# ^ overlay содержит несколько блоков с "version = ...";, берём тот, что
# относится к gemini-cli, по разделу файла.
current="$(awk '/gemini-cli = final.unstable.gemini-cli.overrideAttrs/,/КОНЕЦ: Обновление gemini-cli/' "$OVERLAY" \
  | sed -n 's/^ *version = "\([0-9A-Za-z.+-]*\)";/\1/p' | head -1)"
[ -n "$current" ] || { echo "Не удалось определить текущую версию gemini-cli в $OVERLAY" >&2; exit 1; }

latest="$(curl -fsS https://api.github.com/repos/google-gemini/gemini-cli/releases/latest \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')"
echo "current=$current latest=$latest"

if [ "$latest" = "$current" ]; then
  echo "Уже актуальная версия ($current), обновление не требуется."
  exit 0
fi

echo "Получаю src hash для тега v$latest..."
src_json="$(nix run nixpkgs#nix-prefetch-github -- google-gemini gemini-cli --rev "v$latest")"
src_hash="$(echo "$src_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"])')"
rev="$(echo "$src_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["rev"])')"
echo "src hash=$src_hash (rev=$rev)"

device_probe="${DEVICE:-$( \
  case "$(hostname)" in
    huawei-rlef-x) echo huawei ;;
    yoga14)        echo yoga14 ;;
    desktop)       echo desktop ;;
    asus-ux3405m)  echo asus ;;
  esac)}"
[ -n "$device_probe" ] || { echo "Не удалось определить устройство (DEVICE или hostname)" >&2; exit 1; }

# npmDeps считается внутри buildNpmPackage через fetchNpmDeps с
# NIX_NPM_FETCHER_VERSION=2 (см. комментарий в overlay) — общий
# prefetch-npm-deps по умолчанию использует другой формат кэша и даёт
# хэш, не совпадающий с тем, что реально запросит сборка. Поэтому
# ставим заведомо фейковый хэш и вытаскиваем правильный из ошибки
# hash mismatch — так же, как описано в docs/maintenance/update-gemini.md.
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

python3 - "$OVERLAY" "$current" "$latest" "$src_hash" "$fake_hash" <<'PY'
import sys, re
path, cur, new, src_hash, npmdeps_hash = sys.argv[1:6]
s = open(path).read()
start = s.index("# --- НАЧАЛО: Обновление gemini-cli")
end = s.index("# --- КОНЕЦ: Обновление gemini-cli")
end = s.index("\n", end) + 1
block = s[start:end]
block = block.replace(f'version = "{cur}"', f'version = "{new}"')
block = re.sub(r'(src = prev\.fetchFromGitHub \{.*?hash = ")[^"]*(";)', rf'\g<1>{src_hash}\g<2>', block, count=1, flags=re.S)
block = re.sub(r'(npmDeps = final\.unstable\.fetchNpmDeps \{.*?hash = ")[^"]*(";)', rf'\g<1>{npmdeps_hash}\g<2>', block, count=1, flags=re.S)
open(path, "w").write(s[:start] + block + s[end:])
PY

# Заголовок блока-комментария "--- НАЧАЛО: Обновление gemini-cli до X.Y.Z ---"
sed -i "0,/# --- НАЧАЛО: Обновление gemini-cli до ${current//./\\.}/s//# --- НАЧАЛО: Обновление gemini-cli до ${latest}/" "$OVERLAY"
sed -i "0,/# --- КОНЕЦ: Обновление gemini-cli до ${current//./\\.}/s//# --- КОНЕЦ: Обновление gemini-cli до ${latest}/" "$OVERLAY"

echo "Пробная сборка с фейковым npmDeps hash, чтобы узнать настоящий..."
build_out="$(nix build "$REPO_ROOT#nixosConfigurations.$device_probe.pkgs.gemini-cli" --no-link 2>&1 || true)"
npmdeps_hash="$(echo "$build_out" | sed -n 's/^ *got: *//p' | head -1)"
if [ -z "$npmdeps_hash" ]; then
  echo "Не удалось получить npmDeps hash из вывода сборки:" >&2
  echo "$build_out" >&2
  exit 1
fi
echo "npmDeps hash=$npmdeps_hash"

python3 - "$OVERLAY" "$npmdeps_hash" <<'PY'
import sys, re
path, npmdeps_hash = sys.argv[1:3]
s = open(path).read()
start = s.index("# --- НАЧАЛО: Обновление gemini-cli")
end = s.index("# --- КОНЕЦ: Обновление gemini-cli")
end = s.index("\n", end) + 1
block = s[start:end]
block = re.sub(r'(npmDeps = final\.unstable\.fetchNpmDeps \{.*?hash = ")[^"]*(";)', rf'\g<1>{npmdeps_hash}\g<2>', block, count=1, flags=re.S)
open(path, "w").write(s[:start] + block + s[end:])
PY

echo "Обновил $current -> $latest в overlays/default.nix"

echo "Финальная проверочная сборка .#nixosConfigurations.$device_probe.pkgs.gemini-cli"
nix build "$REPO_ROOT#nixosConfigurations.$device_probe.pkgs.gemini-cli" --no-link --print-out-paths

echo "Готово. Версия $latest записана в overlays/default.nix — можно делать 'just switch'."
