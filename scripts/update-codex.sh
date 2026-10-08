#!/usr/bin/env bash
# Обновление OpenAI Codex CLI в pkgs/codex.nix до последнего стабильного релиза.
set -euo pipefail

API="https://api.github.com/repos/openai/codex/releases/latest"
# Используем тот же HTTP-прокси и маршрут VPN Routes, что и Codex.
PROXY="${CODEX_UPDATE_PROXY-http://127.0.0.1:1103}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$REPO_ROOT/pkgs/codex.nix"

TARGET="x86_64-unknown-linux-musl"

fetch() {
  if [ -n "$PROXY" ]; then
    curl -fsSL \
      --proxy "$PROXY" \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: update-codex.sh" \
      "$@"
  else
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: update-codex.sh" \
      "$@"
  fi
}

# Возвращает 0, если $1 > $2.
ver_gt() {
  [ "$1" != "$2" ] &&
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]
}

current="$(
  sed -n 's/^  version = "\([^"]*\)";/\1/p' "$PACKAGE" |
    head -n1
)"

[ -n "$current" ] || {
  echo "Не удалось определить текущую версию в $PACKAGE" >&2
  exit 1
}

release_json="$(fetch "$API")"
tag="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])' <<< "$release_json")"

case "$tag" in
  rust-v*) target="${tag#rust-v}" ;;
  *)
    echo "Неожиданный GitHub-тег: $tag" >&2
    exit 1
    ;;
esac

[[ "$target" =~ ^[0-9]+(\.[0-9]+)+$ ]] || {
  echo "Некорректная версия: $target" >&2
  exit 1
}

echo "current=$current latest=$target"

if ver_gt "$current" "$target"; then
  echo "Локальная версия ($current) новее последнего релиза ($target)."
  exit 0
fi

tmp_dir="$(mktemp -d)"
package_changed=0
cleanup() {
  status=$?
  if [ "$status" -ne 0 ] && [ "$package_changed" -eq 1 ]; then
    cp "$tmp_dir/codex.nix" "$PACKAGE"
    echo "Обновление не прошло проверку; прежний pkgs/codex.nix восстановлен." >&2
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

archive_hash() {
  local name="$1" archive="$tmp_dir/$1.tar.gz"
  local url="https://github.com/openai/codex/releases/download/$tag/$name.tar.gz"
  echo "Скачиваю $url" >&2
  fetch "$url" -o "$archive" || return 1
  tar -tzf "$archive" > "$tmp_dir/contents" || return 1
  if ! sed 's#^\./##' "$tmp_dir/contents" | grep -Fxq "$name"; then
    echo "В архиве отсутствует ожидаемый файл: $name" >&2
    return 1
  fi
  nix hash file --type sha256 "$archive"
}

hash="$(archive_hash "codex-$TARGET")"
code_mode_host_hash="$(archive_hash "codex-code-mode-host-$TARGET")"

for value in "$hash" "$code_mode_host_hash"; do
  [[ "$value" == sha256-* ]] || {
    echo "Некорректный хеш: $value" >&2
    exit 1
  }
done

echo "Проверяю обновление $current -> $target"
echo "hash=$hash"
echo "codeModeHostHash=$code_mode_host_hash"
cp "$PACKAGE" "$tmp_dir/codex.nix"

python3 - "$PACKAGE" "$current" "$target" "$hash" "$code_mode_host_hash" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
current, target, new_hash, host_hash = sys.argv[2:6]
text = path.read_text()

text, version_count = re.subn(
    rf'(?m)^  version = "{re.escape(current)}";$',
    f'  version = "{target}";',
    text,
    count=1,
)

for field, value in (("hash", new_hash), ("codeModeHostHash", host_hash)):
    pattern = re.compile(
        rf'(x86_64-linux\s*=\s*\{{[^}}]*?^\s+{field}\s*=\s*")[^"]+(";\s*$)',
        re.MULTILINE | re.DOTALL,
    )
    text, count = pattern.subn(
        lambda match: match.group(1) + value + match.group(2), text, count=1
    )
    if count != 1:
        raise SystemExit(f"Не удалось однозначно заменить {field} для x86_64-linux")

if version_count != 1:
    raise SystemExit("Не удалось однозначно заменить version")

path.write_text(text)
PY
package_changed=1

device="${DEVICE:-$(
  case "$(hostname)" in
    huawei-rlef-x) echo huawei ;;
    yoga14) echo yoga14 ;;
    desktop) echo desktop ;;
    asus-ux3405m) echo asus ;;
  esac
)}"

if [ -n "$device" ]; then
  echo "Проверочная сборка .#nixosConfigurations.$device.pkgs.codex"
  nix build \
    "$REPO_ROOT#nixosConfigurations.$device.pkgs.codex" \
    --no-link \
    --print-out-paths >/dev/null
fi

echo "Готово. Версия $target записана в pkgs/codex.nix."
