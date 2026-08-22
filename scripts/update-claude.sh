#!/usr/bin/env bash
# Обновление claude-code в overlays/default.nix до последней версии.
# Документация: docs/maintenance/update-claude.md
set -euo pipefail

BASE="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
PROXY="${CLAUDE_UPDATE_PROXY-127.0.0.1:1082}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="$REPO_ROOT/overlays/default.nix"

fetch() {
  if [ -n "$PROXY" ]; then
    curl -fsS --socks5-hostname "$PROXY" "$1"
  else
    curl -fsS "$1"
  fi
}

# Сравнение семверов: возвращает 0, если $1 > $2
ver_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

current="$(sed -n 's/^ *version = "\([0-9.]*\)";/\1/p' "$OVERLAY" | head -1)"
[ -n "$current" ] || { echo "Не удалось определить текущую версию в $OVERLAY" >&2; exit 1; }

stable="$(fetch "$BASE/stable" | tr -d '[:space:]')"
latest="$(fetch "$BASE/latest" | tr -d '[:space:]')"
echo "current=$current stable=$stable latest=$latest"

target="$stable"
ver_gt "$latest" "$target" && target="$latest"

if ! ver_gt "$target" "$current"; then
  echo "Уже актуальная версия ($current), обновление не требуется."
  exit 0
fi

checksum="$(fetch "$BASE/$target/manifest.json" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["platforms"]["linux-x64"]["checksum"])')"
[ ${#checksum} -eq 64 ] || { echo "Некорректный checksum: $checksum" >&2; exit 1; }

echo "Обновляю $current -> $target (sha256=$checksum)"

python3 - "$OVERLAY" "$current" "$target" "$checksum" <<'PY'
import sys, re
path, cur, new, sha = sys.argv[1:5]
s = open(path).read()
start = s.index("# --- НАЧАЛО: Обновление claude-code")
end = s.index("# --- КОНЕЦ: Обновление claude-code")
end = s.index("\n", end) + 1
block = s[start:end]
block = block.replace(cur, new)
block = re.sub(r'sha256 = "[0-9a-f]*";', f'sha256 = "{sha}";', block)
open(path, "w").write(s[:start] + block + s[end:])
PY

device="${DEVICE:-$( \
  case "$(hostname)" in
    huawei-rlef-x) echo huawei ;;
    yoga14)        echo yoga14 ;;
    desktop)       echo desktop ;;
    asus-ux3405m)  echo asus ;;
  esac)}"

if [ -n "$device" ]; then
  echo "Проверочная сборка .#nixosConfigurations.$device.pkgs.claude-code"
  nix build "$REPO_ROOT#nixosConfigurations.$device.pkgs.claude-code" --no-link --print-out-paths >/dev/null
fi

echo "Готово. Версия $target записана в overlays/default.nix — можно делать 'just switch'."
