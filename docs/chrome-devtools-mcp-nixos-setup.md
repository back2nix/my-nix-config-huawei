# Chrome DevTools MCP on NixOS — Setup & Recovery Guide

Browser automation MCP server for Claude Code (`chrome-devtools-mcp`), wired to the
system Chrome with GPU/Vulkan acceleration on Intel Lunar Lake.

This doc is the **single source of truth** — if the config is ever lost, recreating the
three files below fully restores it.

---

## What it gives you

`chrome-devtools-mcp` (official, by Google / ChromeDevTools) exposes ~30 tools to Claude:
navigate, click/type/fill forms, screenshots, a11y snapshots, `evaluate_script`, network
inspection, console, Lighthouse audit, and performance traces — all driving a **real**
Chrome via the DevTools Protocol (CDP).

Verified working: navigation, self-signed local sites (`https://casino.local/`), and
performance traces with hardware GPU compositing.

---

## NixOS gotchas (why the config looks the way it does)

1. **Don't let it download Chrome.** `chrome-devtools-mcp`/Puppeteer downloads its own
   "Chrome for Testing" binary by default. Those prebuilt ELF binaries **don't run on
   NixOS** (no `/lib64/ld-linux`). Fix: point `--executablePath` at the system
   `google-chrome-stable` and set `PUPPETEER_SKIP_DOWNLOAD=1`.

2. **Self-signed local certs.** `casino.local` etc. use a self-signed cert →
   `ERR_CERT_AUTHORITY_INVALID`. Fix: `--acceptInsecureCerts`.

3. **GPU flag-order override (the tricky one).** home-manager's
   `programs.google-chrome.commandLineArgs` bakes
   `--enable-features=Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,...` + `--use-angle=vulkan`
   + `--ozone-platform=x11` into the chrome wrapper for HW compositing on Lunar Lake.
   But Puppeteer appends its **own** `--enable-features=PdfOopif` at the *end* of the
   command line, and **Chrome honors only the last `--enable-features` occurrence** →
   Vulkan gets dropped → `chrome://gpu` shows `Compositing: Software only`.

   Fix: a tiny wrapper script that calls the system chrome with `"$@"` and then
   **re-appends the GPU flags last**, so they win over Puppeteer's flags.

---

## File 1 — GPU wrapper

`~/.config/chrome-devtools-mcp/chrome-gpu.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# Враппер для chrome-devtools-mcp: Puppeteer добавляет свой --enable-features
# в КОНЕЦ, а Chrome при дублировании берёт последнее вхождение, затирая
# Vulkan/DefaultANGLEVulkan из home-manager обёртки → software compositing.
# Поэтому дописываем GPU-флаги ПОСЛЕ "$@", чтобы они выигрывали.
exec /etc/profiles/per-user/bg/bin/google-chrome-stable "$@" \
  --ozone-platform=x11 \
  --enable-features=Vulkan,DefaultANGLEVulkan,VulkanFromANGLE,WebRTCPipeWireCapturer,PdfOopif \
  --use-angle=vulkan \
  --ignore-gpu-blocklist \
  --enable-gpu-rasterization \
  --enable-zero-copy
```

> Keep these flags in sync with `programs.google-chrome.commandLineArgs` in the
> home-manager config. `PdfOopif` is included so Puppeteer's feature isn't lost.

## File 2 — MCP server entry

In `~/.claude.json`, under top-level `mcpServers`:

```json
"chrome-devtools": {
  "type": "stdio",
  "command": "npx",
  "args": [
    "-y", "chrome-devtools-mcp@latest",
    "--executablePath", "/home/bg/.config/chrome-devtools-mcp/chrome-gpu.sh",
    "--isolated",
    "--acceptInsecureCerts"
  ],
  "env": { "PUPPETEER_SKIP_DOWNLOAD": "1" }
}
```

Flag meanings:
- `--executablePath` → the GPU wrapper above (NOT chrome directly).
- `--isolated` → fresh temp profile each run; avoids "user data dir already in use"
  crashes if your normal Chrome is open. Sessions/logins are **not** persisted.
- `--acceptInsecureCerts` → allow self-signed local TLS.
- `PUPPETEER_SKIP_DOWNLOAD=1` → never try to download a browser.

## File 3 — (you already have this) home-manager Chrome

`programs.google-chrome` with `commandLineArgs` providing the Vulkan/XWayland flags.
That's what makes the *desktop* Chrome accelerated; the wrapper just propagates the same
flags into the MCP-launched instance. See commit `5a90d96`
("fix: chrome GPU compositing on Lunar Lake").

---

## Recreate from scratch (recovery steps)

```bash
# 1. wrapper
mkdir -p ~/.config/chrome-devtools-mcp
$EDITOR ~/.config/chrome-devtools-mcp/chrome-gpu.sh   # paste File 1
chmod +x ~/.config/chrome-devtools-mcp/chrome-gpu.sh

# 2. register MCP server (paste File 2 into ~/.claude.json mcpServers)
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude.json"); d = json.load(open(p))
d.setdefault("mcpServers", {})["chrome-devtools"] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "chrome-devtools-mcp@latest",
             "--executablePath", os.path.expanduser("~/.config/chrome-devtools-mcp/chrome-gpu.sh"),
             "--isolated", "--acceptInsecureCerts"],
    "env": {"PUPPETEER_SKIP_DOWNLOAD": "1"},
}
json.dump(d, open(p, "w"), indent=2)
print("done")
PY

# 3. restart Claude Code so the MCP server picks up the config
```

---

## Verify it works

After restarting Claude Code, ask Claude to drive the browser, or check manually:

**GPU status** — navigate to `chrome://gpu`, expect:
- `Compositing: Hardware accelerated`
- `Vulkan: Enabled`
- `WebGL: Hardware accelerated` (no "reduced performance")
- active backend: `Vulkan — Intel(R) Graphics (LNL)`

**WebGL renderer on any page** (`evaluate_script`):
```js
const gl = document.createElement('canvas').getContext('webgl2');
const d = gl.getExtension('WEBGL_debug_renderer_info');
gl.getParameter(d.UNMASKED_RENDERER_WEBGL);
// → "ANGLE (Intel, Vulkan 1.4.x (Intel(R) Graphics (LNL)), Intel open-source Mesa driver)"
```

**Smoke test from a shell** (no MCP needed):
```bash
{ printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"navigate_page","arguments":{"url":"https://example.com"}}}'; \
  sleep 35; } \
| npx -y chrome-devtools-mcp@latest \
    --executablePath ~/.config/chrome-devtools-mcp/chrome-gpu.sh \
    --isolated --acceptInsecureCerts 2>/dev/null | grep '"id":2'
# expect: "Successfully navigated to https://example.com."
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Compositing: Software only` / `Vulkan: Disabled` | MCP launched chrome directly, or wrapper flags not last | Ensure `executablePath` points to `chrome-gpu.sh`, GPU flags after `"$@"`. Restart Claude Code. |
| `ERR_CERT_AUTHORITY_INVALID` | self-signed local site | confirm `--acceptInsecureCerts` is in args; restart |
| Server hangs / downloads forever | tried to fetch Chrome-for-Testing | `PUPPETEER_SKIP_DOWNLOAD=1` + valid `--executablePath` |
| "user data dir already in use" | shared profile with running Chrome | keep `--isolated` |
| Config edits don't apply | MCP server already running with old args | **restart Claude Code** (or `/mcp` → reconnect) |
| `google-chrome-stable` path changed | nix profile path differs | update path in wrapper: `readlink -f $(which google-chrome-stable)` for reference; profile path is `/etc/profiles/per-user/bg/bin/google-chrome-stable` |

---

## Tuning options

- **Persistent logins:** drop `--isolated` (but then don't run a separate Chrome with the
  same profile simultaneously).
- **Headless:** add `--headless` to the MCP args (default is headful — needs your GUI
  session, which is fine on the desktop).
- **Block/allow URLs, proxy:** see `npx chrome-devtools-mcp@latest --help`
  (`--blockedUrlPattern`, `--allowedUrlPattern`, `--proxyServer`).

---

## Notes

- Config lives in `~/.config` + `~/.claude.json` — **not** nix-managed yet. A reproducible
  nix version (wrapper as a package + committed `.mcp.json`) is a possible future step.
- Backups of `~/.claude.json` are saved as `~/.claude.json.bak.<timestamp>` whenever the
  setup script ran.
