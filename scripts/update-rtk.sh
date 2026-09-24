#!/usr/bin/env bash
# Обновление rtk в pkgs/rtk.nix до последнего релиза с GitHub.
set -euo pipefail

REPO="rtk-ai/rtk"
PROXY="${RTK_UPDATE_PROXY-127.0.0.1:1082}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$REPO_ROOT/pkgs/rtk.nix"

fetch() {
  if [ -n "$PROXY" ]; then
    curl -fsSL --socks5-hostname "$PROXY" "$1"
  else
    curl -fsSL "$1"
  fi
}

# Сравнение семверов: возвращает 0, если $1 > $2
ver_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }

current="$(sed -n 's/^ *version = "\([0-9.]*\)";/\1/p' "$PKG" | head -1)"
[ -n "$current" ] || { echo "Не удалось определить текущую версию в $PKG" >&2; exit 1; }

latest="$(fetch "https://api.github.com/repos/$REPO/releases/latest" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')"
echo "current=$current latest=$latest"

if ! ver_gt "$latest" "$current"; then
  echo "Уже актуальная версия ($current), обновление не требуется."
  exit 0
fi

# Хэш исходников (формат nix32, как в fetchFromGitHub.sha256)
tarball="$(mktemp --suffix=.tar.gz)"
trap 'rm -f "$tarball"' EXIT
fetch "https://github.com/$REPO/archive/refs/tags/v$latest.tar.gz" > "$tarball"
src_hash="$(nix-prefetch-url --unpack --type sha256 "file://$tarball" 2>/dev/null | tail -1)"
[ ${#src_hash} -eq 52 ] || { echo "Некорректный src hash: $src_hash" >&2; exit 1; }

echo "Обновляю $current -> $latest (src sha256=$src_hash)"

cp "$PKG" "$PKG.bak"
restore() { mv "$PKG.bak" "$PKG"; echo "Откат pkgs/rtk.nix" >&2; }

sed -i \
  -e "s|version = \"$current\";|version = \"$latest\";|" \
  -e "s|sha256 = \"[0-9a-z]*\";|sha256 = \"$src_hash\";|" \
  -e "s|cargoHash = \"[^\"]*\";|cargoHash = \"$(printf 'sha256-%s=' AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA)\";|" \
  "$PKG"

# Вычисляем cargoHash: собираем с фейковым хэшем и берём "got:" из ошибки
echo "Вычисляю cargoHash..."
out="$(nix build --impure --no-link --expr \
  "(import <nixpkgs> {}).callPackage $PKG {}" 2>&1 || true)"
cargo_hash="$(printf '%s\n' "$out" | sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | tail -1)"
if [ -z "$cargo_hash" ]; then
  printf '%s\n' "$out" | tail -30 >&2
  restore; exit 1
fi
sed -i "s|cargoHash = \"[^\"]*\";|cargoHash = \"$cargo_hash\";|" "$PKG"
rm -f "$PKG.bak"
echo "cargoHash=$cargo_hash"

device="${DEVICE:-$( \
  case "$(hostname)" in
    huawei-rlef-x) echo huawei ;;
    yoga14)        echo yoga14 ;;
    desktop)       echo desktop ;;
    asus-ux3405m)  echo asus ;;
  esac)}"

if [ -n "$device" ]; then
  echo "Проверочная сборка .#nixosConfigurations.$device.pkgs.rtk"
  nix build "$REPO_ROOT#nixosConfigurations.$device.pkgs.rtk" --no-link --print-out-paths >/dev/null
fi

echo "Готово. Версия $latest записана в pkgs/rtk.nix — можно делать 'just switch'."
