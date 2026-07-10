# Chrome DevTools MCP on NixOS — Setup & Recovery Guide

Browser automation MCP server for Claude Code (`chrome-devtools-mcp`), wired to the
system Chrome with GPU/Vulkan acceleration on Intel Lunar Lake, with auto-detect
connect-to-existing-browser support.

This doc is the **single source of truth** — if the config is ever lost, recreating the
files below fully restores it.

> **2026-07-10 update:** added `mcp-launch.sh` (File 2) so the MCP server can attach to
> an already-running Chrome (e.g. one the user started manually with
> `--remote-debugging-port=9333`) instead of always spawning its own isolated instance.
> See [Connect vs. launch (auto-detect)](#connect-vs-launch-auto-detect) below.

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

4. **Sometimes you want to attach to an already-open browser, not launch a new one.**
   If the user is already running Chrome with `--remote-debugging-port=9333` (their daily
   driver, with real logins/cookies/tabs), a fresh `--isolated` launch is the wrong tool —
   it opens a second, empty, logged-out browser. But hardcoding `--browserUrl` breaks the
   common case (no such Chrome running) with a hard connection error and no fallback.
   `chrome-devtools-mcp` itself has no auto-fallback between connect and launch (see
   `browser.js`: it's `serverArgs.browserUrl ? ensureBrowserConnected(...) :
   ensureBrowserLaunched(...)`, strictly either/or).

   Fix: a launcher wrapper (`mcp-launch.sh`) in front of `npx chrome-devtools-mcp`, run at
   MCP-server-startup, that probes the port with `curl` and picks the flag set. Full
   detail: [Connect vs. launch (auto-detect)](#connect-vs-launch-auto-detect).

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

## Connect vs. launch (auto-detect)

`chrome-devtools-mcp` (npm package, `build/src/browser.js`) picks connect-vs-launch purely
from which CLI flags are present — there's no runtime fallback:

```js
const browser = serverArgs.browserUrl || serverArgs.wsEndpoint || serverArgs.autoConnect
  ? await ensureBrowserConnected({ browserURL: serverArgs.browserUrl, ... })
  : await ensureBrowserLaunched({ executablePath: serverArgs.executablePath, ... });
```

So `--browserUrl http://127.0.0.1:9333` connects Puppeteer to an already-running Chrome
(started with `--remote-debugging-port=9333`, e.g. by the user manually) — real profile,
real logins, real tabs. Omit it and pass `--executablePath`/`--isolated` instead, and it
launches its own throwaway Chrome (File 1's GPU wrapper).

`mcp-launch.sh` (File 2) sits in front of `npx chrome-devtools-mcp` and chooses at
MCP-server-startup time: `curl` the CDP endpoint; if it answers, connect; otherwise launch
isolated. This is a **local decision made once per MCP server process start** — if you
start the user's Chrome with remote debugging *after* Claude Code already launched the
MCP server, you must restart the MCP connection (see Troubleshooting) for the wrapper to
notice.

## File 2 — MCP launcher wrapper

`~/.config/chrome-devtools-mcp/mcp-launch.sh` (chmod +x):

```bash
#!/usr/bin/env bash
# Враппер для запуска chrome-devtools-mcp: если на CHROME_DEVTOOLS_MCP_PORT
# (по умолчанию 9333) уже отвечает Chrome с remote-debugging — подключаемся
# к нему (--browserUrl), иначе запускаем свой изолированный Chrome через
# chrome-gpu.sh (GPU/Vulkan фикс), как раньше.
set -euo pipefail

PORT="${CHROME_DEVTOOLS_MCP_PORT:-9333}"

if curl -s -m 1 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  exec npx -y chrome-devtools-mcp@latest \
    --browserUrl "http://127.0.0.1:${PORT}" \
    --acceptInsecureCerts
else
  exec npx -y chrome-devtools-mcp@latest \
    --executablePath "$HOME/.config/chrome-devtools-mcp/chrome-gpu.sh" \
    --isolated \
    --acceptInsecureCerts
fi
```

> Override the port per-invocation with `CHROME_DEVTOOLS_MCP_PORT` in the MCP server's
> `env` block if 9333 isn't the port the user's Chrome uses.

## File 3 — MCP server entry

In `~/.claude.json`, under top-level `mcpServers`:

```json
"chrome-devtools": {
  "type": "stdio",
  "command": "/home/bg/.config/chrome-devtools-mcp/mcp-launch.sh",
  "args": [],
  "env": { "PUPPETEER_SKIP_DOWNLOAD": "1" }
}
```

`command` points at the launcher wrapper (File 2), not `npx` directly — the wrapper picks
the real `npx chrome-devtools-mcp@latest ...` invocation (connect or launch) itself.

Flag meanings (chosen inside `mcp-launch.sh`, not here):
- `--executablePath` (launch path) → the GPU wrapper, File 1 (NOT chrome directly).
- `--isolated` (launch path) → fresh temp profile each run; avoids "user data dir already
  in use" crashes if your normal Chrome is open. Sessions/logins are **not** persisted.
- `--browserUrl` (connect path) → attach to the user's already-running Chrome instead;
  sessions/logins/tabs are the real ones.
- `--acceptInsecureCerts` → allow self-signed local TLS (both paths).
- `PUPPETEER_SKIP_DOWNLOAD=1` → never try to download a browser.

## File 4 — (you already have this) home-manager Chrome

`programs.google-chrome` with `commandLineArgs` providing the Vulkan/XWayland flags.
That's what makes the *desktop* Chrome accelerated; the wrapper just propagates the same
flags into the MCP-launched instance. See commit `5a90d96`
("fix: chrome GPU compositing on Lunar Lake").

---

## Recreate from scratch (recovery steps)

```bash
# 1. GPU wrapper
mkdir -p ~/.config/chrome-devtools-mcp
$EDITOR ~/.config/chrome-devtools-mcp/chrome-gpu.sh   # paste File 1
chmod +x ~/.config/chrome-devtools-mcp/chrome-gpu.sh

# 2. launcher wrapper (connect-vs-launch auto-detect)
$EDITOR ~/.config/chrome-devtools-mcp/mcp-launch.sh   # paste File 2
chmod +x ~/.config/chrome-devtools-mcp/mcp-launch.sh

# 3. register MCP server (paste File 3 into ~/.claude.json mcpServers)
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude.json"); d = json.load(open(p))
d.setdefault("mcpServers", {})["chrome-devtools"] = {
    "type": "stdio",
    "command": os.path.expanduser("~/.config/chrome-devtools-mcp/mcp-launch.sh"),
    "args": [],
    "env": {"PUPPETEER_SKIP_DOWNLOAD": "1"},
}
json.dump(d, open(p, "w"), indent=2)
print("done")
PY

# 4. restart Claude Code so the MCP server picks up the config
```

---

## Verify it works

**Which path did it take?** Before checking GPU status, confirm connect-vs-launch matched
intent:
- Ask Claude to `list_pages` — if it shows your real tabs (Gmail, GitHub, etc.), it
  connected to the existing browser. If it shows a single blank/new tab, it launched an
  isolated one.
- Or check directly: `curl -s http://127.0.0.1:9333/json/version` — if this succeeds, a
  fresh MCP server start will take the `--browserUrl` path.

The GPU checks below only apply to the **launch** path — a connected existing browser's
GPU state depends on how *that* Chrome was started (e.g. `programs.google-chrome`'s
home-manager flags), not on `mcp-launch.sh`.

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
| `Compositing: Software only` / `Vulkan: Disabled` | MCP launched chrome directly, or wrapper flags not last | Ensure `executablePath` points to `chrome-gpu.sh`, GPU flags after `"$@"`. Restart Claude Code. Note: only applies on the **launch** path — a connected browser's GPU state is outside `mcp-launch.sh`'s control. |
| `ERR_CERT_AUTHORITY_INVALID` | self-signed local site | confirm `--acceptInsecureCerts` is in args; restart |
| Server hangs / downloads forever | tried to fetch Chrome-for-Testing | `PUPPETEER_SKIP_DOWNLOAD=1` + valid `--executablePath` |
| "user data dir already in use" | shared profile with running Chrome | keep `--isolated` |
| Config edits don't apply / still launches an isolated browser even though your Chrome is open | MCP server process already running — it decided connect-vs-launch once at startup, before you started your Chrome or before you edited `~/.claude.json`/`mcp-launch.sh` | **restart Claude Code** (or `/mcp` → reconnect) so a fresh MCP process re-probes the port |
| `google-chrome-stable` path changed | nix profile path differs | update path in wrapper: `readlink -f $(which google-chrome-stable)` for reference; profile path is `/etc/profiles/per-user/bg/bin/google-chrome-stable` |
| Connects to isolated browser instead of the user's real one, even though their Chrome is running | user's Chrome not started with `--remote-debugging-port=9333` (or a different port), or `mcp-launch.sh`/`chmod +x` missing, or `curl` not on `PATH` for the MCP process | confirm `curl -s http://127.0.0.1:9333/json/version` succeeds in a plain shell; confirm the port the user's Chrome was launched with matches `CHROME_DEVTOOLS_MCP_PORT` (default 9333) |
| Wrong tab/site shows up unexpectedly, or actions land in someone else's tab | connected to the user's daily-driver Chrome (`--browserUrl` path) — it has all their normal tabs (email, banking, etc.), not a clean sandbox | expected on the connect path; use `list_pages` to see the real tab list before acting, or force isolated launch by stopping remote debugging on that port |

---

## Tuning options

- **Different remote-debugging port:** set `"env": {"CHROME_DEVTOOLS_MCP_PORT": "1234"}`
  in the `chrome-devtools` MCP entry (alongside `PUPPETEER_SKIP_DOWNLOAD`).
- **Always launch isolated, never connect:** temporarily rename/remove
  `mcp-launch.sh`'s curl check, or just point `command`/`args` back at File 3's old form
  (`npx` + `--executablePath`/`--isolated` directly, no wrapper).
- **Persistent logins on the launch path:** drop `--isolated` in `mcp-launch.sh`'s else
  branch (but then don't run a separate Chrome with the same profile simultaneously).
- **Headless:** add `--headless` to the relevant `npx` call inside `mcp-launch.sh`
  (default is headful — needs your GUI session, which is fine on the desktop; irrelevant
  on the connect path since the browser is already running).
- **Block/allow URLs, proxy:** see `npx chrome-devtools-mcp@latest --help`
  (`--blockedUrlPattern`, `--allowedUrlPattern`, `--proxyServer`).

---

## Notes

- Config lives in `~/.config` + `~/.claude.json` — **not** nix-managed yet. A reproducible
  nix version (wrapper as a package + committed `.mcp.json`) is a possible future step.
- Backups of `~/.claude.json` are saved as `~/.claude.json.bak.<timestamp>` whenever the
  setup script ran.
- The connect-vs-launch decision in `mcp-launch.sh` is a **one-shot probe at MCP server
  startup**, not a live fallback — if the port state changes after the MCP process has
  started (Chrome closes, or opens later), you must restart/reconnect the MCP server for
  it to re-decide. This is a property of `chrome-devtools-mcp`'s own design
  (`ensureBrowserConnected`/`ensureBrowserLaunched` are chosen once and cached in a
  module-level `browser` variable — see `build/src/browser.js`), not something
  `mcp-launch.sh` can work around from outside the process.
