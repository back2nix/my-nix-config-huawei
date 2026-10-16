#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$REPO_ROOT/pkgs/dolphin-anty.nix"
# Пустое значение DOLPHIN_UPDATE_PROXY отключает прокси.
PROXY="${DOLPHIN_UPDATE_PROXY-127.0.0.1:1088}"
URL="$(sed -n 's/^ *url = "\([^"]*\)";/\1/p' "$PKG")"
[[ "$URL" == https://* ]] || { echo "Не найден HTTPS URL в $PKG" >&2; exit 1; }

download="$(mktemp --suffix=.AppImage)"
trap 'rm -f "$download"' EXIT
echo "Скачиваю последнюю версию Dolphin Anty..."
curl_args=(--fail --location --retry 3 --connect-timeout 30)
if [[ -n "$PROXY" ]]; then
  curl_args+=(--socks5-hostname "$PROXY")
fi
curl "${curl_args[@]}" "$URL" --output "$download"

# Не записываем хэш страницы ошибки вместо AppImage (ELF + сигнатура Type 2).
python3 - "$download" <<'PY'
import sys
with open(sys.argv[1], "rb") as stream:
    header = stream.read(11)
if header[:4] != b"\x7fELF" or header[8:11] != b"AI\x02":
    sys.exit("Скачанный файл не является AppImage Type 2")
PY

hash="$(nix hash file --type sha256 --sri "$download")"
# Кладём файл в кеш fetchurl, чтобы пересборка не скачивала его снова.
nix-prefetch-url --type sha256 --name "${URL##*/}" "file://$download" >/dev/null
python3 - "$PKG" "$hash" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
updated, count = re.subn(r'    hash = (?:lib\.fakeHash|"[^"]*");',
                         f'    hash = "{sys.argv[2]}";', text)
if count != 1:
    sys.exit("Не удалось найти единственный hash в пакете; файл не изменён")
if updated == text:
    print("Уже актуальная версия Dolphin Anty.")
else:
    path.write_text(updated)
    print("Хэш Dolphin Anty обновлён. Для установки выполните: just switch")
PY
