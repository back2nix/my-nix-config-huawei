#!/usr/bin/env bash
set -euo pipefail
# Official manifest, using the dedicated route selected in the tray.
BASE="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
PROXY="${ANTIGRAVITY_UPDATE_PROXY-http://127.0.0.1:1121}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT
curl -fsSL --proxy "$PROXY" --noproxy "" "$BASE/manifests/linux_amd64.json" -o "$manifest"
python3 - "$REPO_ROOT/pkgs/antigravity-cli.nix" "$manifest" <<'PY'
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse
path = Path(sys.argv[1])
manifest = json.loads(Path(sys.argv[2]).read_text())
version, url, sha = (manifest[key] for key in ('version', 'url', 'sha512'))
if not re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][\w.-]+)?', version):
    raise SystemExit('Invalid version')
parsed = urlparse(url)
if parsed.scheme != 'https' or parsed.netloc != 'storage.googleapis.com' or not parsed.path.startswith('/antigravity-public/antigravity-cli/') or not parsed.path.endswith('.tar.gz'):
    raise SystemExit('Unexpected download URL')
if not re.fullmatch(r'[0-9a-f]{128}', sha):
    raise SystemExit('Invalid SHA512 checksum')
text = path.read_text()
for key, value in [('version', version), ('url', url), ('sha512', sha)]:
    text, count = re.subn(rf'\b{key} = "[^"]*";', f'{key} = "{value}";', text)
    if count != 1:
        raise SystemExit(f'Expected exactly one {key} in {path}')
path.write_text(text)
print(f'Antigravity CLI: {version}')
PY
device="${DEVICE:-$(case "$(hostname)" in
  huawei-rlef-x) echo huawei ;;
  yoga14) echo yoga14 ;;
  desktop) echo desktop ;;
  asus*) echo asus ;;
esac)}"
if [ -n "$device" ]; then
  nix build "path:$REPO_ROOT#nixosConfigurations.$device.pkgs.antigravity-cli" --no-link --print-out-paths
fi
echo "Готово. Для применения: just switch"
