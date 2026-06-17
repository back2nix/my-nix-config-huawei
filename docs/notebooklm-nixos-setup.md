# NixOS Setup Guide for NotebookLM Skill

## Problem Summary

Two things break on NixOS out of the box:

1. **patchright `node` binary doesn't execute** — NixOS routes `/lib64/ld-linux-x86-64.so.2` through `nix-ld`, which fails to load the bundled node binary at runtime
2. **`channel="chrome"` in browser_utils.py fails** — patchright can't locate Chrome without an explicit path on NixOS
3. **NotebookLM is geo-blocked in Russia** — VPN required

---

## Fix 1: patchelf the patchright node binary

Must be re-applied after every `.venv` rebuild.

```bash
# Find your glibc hash
ls /nix/store/ | grep "^.*-glibc-2\." | grep -v "\.drv\|locales\|iconv\|simple\|getent" | head -5

# Apply patchelf (replace hash with yours)
GLIBC=/nix/store/xx7cm72qy2c0643cm1ipngd87aqwkcdp-glibc-2.40-66
NODE=~/.claude/skills/notebooklm/.venv/lib/python3.13/site-packages/patchright/driver/node

patchelf \
  --set-interpreter $GLIBC/lib64/ld-linux-x86-64.so.2 \
  --set-rpath $GLIBC/lib:/run/current-system/sw/lib \
  $NODE

# Verify
$NODE --version   # should print v22.x.x
```

**When to re-apply:**
- After `rm -rf .venv`
- After `pip install --upgrade patchright`
- After `python scripts/run.py cleanup_manager.py` (if it recreates venv)

---

## Fix 2: Use executable_path instead of channel="chrome"

File: `scripts/browser_utils.py`, method `launch_persistent_context`

Replace:
```python
context = playwright.chromium.launch_persistent_context(
    user_data_dir=user_data_dir,
    channel="chrome",
    headless=headless,
    ...
)
```

With:
```python
import shutil
chrome_path = shutil.which("google-chrome-stable") or shutil.which("google-chrome") or shutil.which("chromium")
context = playwright.chromium.launch_persistent_context(
    user_data_dir=user_data_dir,
    executable_path=chrome_path,
    headless=headless,
    ...
)
```

Chrome binary on this system: `/etc/profiles/per-user/bg/bin/google-chrome-stable`

---

## Fix 3: VPN required

NotebookLM redirects to `https://notebooklm.google/?location=unsupported` in Russia.

**Always enable VPN before running any notebooklm command.**

Symptom without VPN:
```
❌ Authentication timeout: Target page, context or browser has been closed
navigated to "https://notebooklm.google/?location=unsupported"
```

---

## Verification

After applying all fixes:
```bash
# Check node works
~/.claude/skills/notebooklm/.venv/lib/python3.13/site-packages/patchright/driver/node --version

# Run auth (with VPN on)
DISPLAY=:0 python scripts/run.py auth_manager.py setup
```
