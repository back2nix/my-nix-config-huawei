# Handover: NodeMaven China (Shanghai) proxy in NekoBox on Huawei

**Date:** 2026-07-14
**Device:** Huawei HBP-AL00 (Kirin 9010), Android 12, microG (no Google Play Services)
**App:** NekoBox for Android 1.3.9 (215) OSS (`moe.nb4a`)
**Goal:** Make the phone appear as a residential IP in **Shanghai, China** via a NodeMaven SOCKS5 residential proxy, and make Chinese apps (Taobao) work.
**Physical location of phone:** St. Petersburg, RU (real WiFi `HUAWEI-T1C2K1`). The China exit is purely the proxy.

## Final working result

```json
{
  "ip": "183.194.151.212",
  "city": "Shanghai",
  "region": "Shanghai",
  "country": "CN",
  "org": "AS24400 Shanghai Mobile Communications Co.,Ltd.",
  "timezone": "Asia/Shanghai"
}
```
Taobao app loads the full home feed. ipinfo.io reports Shanghai. Verified over adb (`https://ipinfo.io/json` in Chrome + Taobao launch).

## Proxy provider

**NodeMaven** residential SOCKS5. Gateway `gate.nodemaven.com:1080`.
Auth: username encodes geo-targeting params, password `******`.

Username format (dash-separated params):
```
****
```
- `socks5h://` (remote DNS) from a PC gives the real geo exit.
- `sid-<value>` = **sticky session**. A given sid pins to one exit IP.

## The four independent problems (all had to be fixed)

1. **System Private DNS = `dns.google`** (Android global setting, `opportunistic`
   Intercepts DNS *outside* the tunnel; `dns.google` is unreachable/blocked → Chrome `DNS_PROBE_STARTED`.
   Fix: `adb shell settings put global private_dns_mode off` (or Settings → Private DNS → Off).

2. **Per-app proxy was ON** with a curated app list — Huawei's own browser and some apps were bypassing the tunnel.
   Fix: NekoBox → per-app proxy OFF (route ALL traffic through VPN). Setting `proxyApps=false`.

3. **Stuck/expired sticky `sid`** — old sids (`4325e9dc4f934`, `8996c1d658e04`) had fallen back to **Japan (Vultr 45.76.202.45)** or **US (LA 74.222.14.83)** datacenter exits, ignoring `country-cn`.
   Diagnosis: identical behavior via PC `curl` proved it was NodeMaven-side, not the phone.
   Fix: use a **fresh sid** → real Shanghai residential (China Mobile / China Telecom). Working sid used: `292844f393ec4`.
   Also: over-specific targeting (`isp-china_telecom` + `speed-fast` + city) can empty the pool → datacenter fallback. Keep it lean (`country-cn-region-shanghai`).

4. **Remote DNS = Cloudflare `https://1.1.1.1/dns-query`** — once the exit is genuinely in China, the **GFW resets `1.1.1.1`** → DNS fails inside the tunnel (`DNS_PROBE`, `ERR_CONNECTION_RESET`).
   Fix: Remote DNS = **`223.5.5.5`** (AliDNS, plain UDP — NOT the DoH URL; bare-IP DoH `https://223.5.5.5/dns-query` failed cert/format in NekoBox). AliDNS is reachable and resolves both CN and foreign domains from a China exit.

5. **Taobao (and Alibaba apps) wouldn't load** — they lean on **QUIC (UDP/443)**; NodeMaven residential SOCKS5 is effectively TCP-only, so UDP stalls.
   Fix: NekoBox → Route → enable **Block QUIC** rule (port 443 / udp → Block). Apps fall back to TCP → Taobao works.

## Final working configuration (all applied)

| Setting | Value |
|---|---|
| Profile | `NodeMaven-Shanghai`, SOCKS5 `gate.nodemaven.com:1080` |
| Username | `**********` |
| Password | `*******` |
| Remote DNS | `223.5.5.5` (AliDNS, plain) |
| Direct DNS | `https://1.1.1.1/dns-query` (fine — resolves on the real RU network) |
| System Private DNS | **Off** |
| Per-app proxy | **Off** (all traffic through VPN) |
| Route → Block QUIC | **On** |
| Route → China-bypass rules (`geosite:cn` Bypass, etc.) | Off (want CN traffic through proxy too) |

## Troubleshooting quick reference

- **Exit shows wrong country** → sticky sid stale. Edit profile → Username → change `sid-XXXX` to any new value → OK → save (✓) → reconnect.
- **`DNS_PROBE` with a China exit** → Remote DNS must be `223.5.5.5` (AliDNS), not Cloudflare/Google.
- **Chinese app won't load but browser works** → enable **Block QUIC** (UDP not supported over the residential SOCKS).
- **Foreign sites (Google/Instagram/1.1.1.1) slow or reset** → expected from a CN residential IP behind the GFW, not a fault.
- **Verify exit:** open `https://ipinfo.io/json` or `https://1.1.1.1/cdn-cgi/trace` in Chrome.

## Notes / gotchas discovered

- NekoBox backup (`.json`) stores each profile/setting as base64 of a length-prefixed binary blob; **the last byte of each string has its high bit set** as an end-marker (e.g. `m`=0x6d stored as 0xed), so a decoded string can look truncated but isn't.
- `adb shell ping <hostname>` from the shell uid does NOT go through the app VPN — misleading for DNS tests. Use a real app (Chrome) instead.
- adb was used to drive everything: `settings put global private_dns_mode off`, UI taps (`input tap`/`input text`/`input keyevent`), `screencap`, launching Chrome/Taobao via `am start`/`monkey`.
