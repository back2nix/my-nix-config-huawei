#!/usr/bin/env bash
# Обновление OpenAI Codex CLI в pkgs/codex.nix до последнего стабильного релиза.
set -euo pipefail

API="https://api.github.com/repos/openai/codex/releases/latest"
PROXY="${CODEX_UPDATE_PROXY-127.0.0.1:1082}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$REPO_ROOT/pkgs/codex.nix"

TARGET="x86_64-unknown-linux-musl"

fetch() {
  if [ -n "$PROXY" ]; then
    curl -fsSL \
      --socks5-hostname "$PROXY" \
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

tag="$(
  fetch "$API" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])'
)"

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

if ! ver_gt "$target" "$current"; then
  echo "Уже актуальная версия ($current), обновление не требуется."
  exit 0
fi

url="https://github.com/openai/codex/releases/download/$tag/codex-$TARGET.tar.gz"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
archive="$tmp_dir/codex.tar.gz"

echo "Скачиваю $url"
fetch "$url" -o "$archive"

expected_file="codex-$TARGET"
if ! tar -tzf "$archive" | sed 's#^\./##' | grep -Fxq "$expected_file"; then
  echo "В архиве отсутствует ожидаемый файл: $expected_file" >&2
  exit 1
fi

hash="$(nix hash file --type sha256 "$archive")"

[[ "$hash" == sha256-* ]] || {
  echo "Некорректный хеш: $hash" >&2
  exit 1
}

echo "Обновляю $current -> $target"
echo "hash=$hash"

python3 - "$PACKAGE" "$current" "$target" "$hash" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
current, target, new_hash = sys.argv[2:5]
text = path.read_text()

text, version_count = re.subn(
    rf'(?m)^  version = "{re.escape(current)}";$',
    f'  version = "{target}";',
    text,
    count=1,
)

hash_pattern = re.compile(
    r'(x86_64-linux\s*=\s*\{.*?^\s+hash\s*=\s*")[^"]+(";\s*$)',
    re.MULTILINE | re.DOTALL,
)
text, hash_count = hash_pattern.subn(
    lambda match: match.group(1) + new_hash + match.group(2),
    text,
    count=1,
)

if version_count != 1:
    raise SystemExit("Не удалось однозначно заменить version")

if hash_count != 1:
    raise SystemExit("Не удалось однозначно заменить hash для x86_64-linux")

path.write_text(text)
PY

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
