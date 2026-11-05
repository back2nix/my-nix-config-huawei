Короткий ответ: менять фингерпринт случайно почти всегда хуже, чем выглядеть как большая однородная толпа. Лучше всего работают готовые браузеры, а патчи ядра почти не помогают против браузерного трекинга. Ниже по слоям.

## 1. Как вас вычисляют (по слоям)

| Слой                     | Что собирают                                                                                                                                                       | Кто                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------- |
| **Сеть**                 | IP, TLS ClientHello (JA3/JA4), HTTP/2 SETTINGS (Akamai fp), TCP/IP-стек: TTL, window size, порядок опций (p0f)                                                     | сайты, CDN, антифрод                                |
| **Браузер JS**           | Canvas, WebGL (renderer, extensions), AudioContext, шрифты, размер экрана/окна, timezone, языки, `navigator.*`, WebGPU, Client Hints, media devices, speech voices | сайты, FingerprintJS, CreepJS                       |
| **Железо через браузер** | тайминги CPU и кэша, `hardwareConcurrency`, `deviceMemory`, батарея, датчики                                                                                       | продвинутый трекинг                                 |
| **Нативные приложения**  | `/etc/machine-id`, DMI (`/sys/class/dmi/id/*`: serial, UUID), MAC-адреса, серийники дисков (`/dev/disk/by-id`), hostname, список пакетов, EDID монитора            | Electron-приложения, Steam, проприетарь, телеметрия |

## 2. Что пишут исследователи

- **Laperdrix et al., "Browser Fingerprinting: A Survey"** (ACM TWEB 2020). Лучший обзор.
- **"FP-Stalker"** (S&P 2018). Отпечатки отслеживаются даже когда меняются, потому что их связывают по эволюции.
- **"FP-Random"** и **"Blink"** (Laperdrix, Baudry). Рандомизация и переключение реальных конфигураций (через ВМ).
- **Vastel et al., "FP-Scanner"** (USENIX Sec 2018). Главный вывод: подмена значений выдаёт сама себя через несогласованность. Например, UA говорит Windows, а шрифты линуксовые, или canvas с шумом не совпадает сам с собой между двумя вызовами. Такой отпечаток уникальнее исходного.
- **Brave "farbling"** (Snyder et al.). Детерминированный шум с сидом на домен и сессию: внутри сайта стабильно, между сайтами отпечатки не связываются.
- **"Rendered private: Making GLSL execution uniform"** (Wu et al., NDSS 2019). Убрать WebGL-фингерпринт через унификацию рендера.
- **Tor Browser design doc**: подход «все выглядят одинаково», letterboxing, uniformity.

Отсюда два рабочих подхода:
1. **Uniformity**: выглядеть как тысячи других (Tor Browser, Mullvad Browser, Firefox с `resistFingerprinting`).
2. **Unlinkability**: правдоподобный шум, свой для каждого сайта и сессии (Brave).

Наивные расширения-«рандомайзеры» (Canvas Blocker в агрессивном режиме, подмена UA) обычно делают хуже.

## 3. Готовые решения (по возрастанию «хардкорности»)

**Браузер:**
- **Mullvad Browser** (это Tor Browser без Tor, есть в nixpkgs как `mullvad-browser`) плюс VPN. Лучший вариант для повседневного использования.
- **Tor Browser** (`tor-browser`), если нужна и сетевая анонимность.
- **LibreWolf** или Firefox с `privacy.resistFingerprinting = true` (или более гибким `privacy.fingerprintingProtection` + overrides). Учтите: RFP подменяет UA на Windows, а timezone ставит UTC.
- **Brave**: farbling включён по умолчанию.
- **Camoufox**: форк Firefox с подменой отпечатка на уровне C++, а не JS, поэтому подмену трудно обнаружить. Генерирует согласованные профили через BrowserForge.
- Антидетект-браузеры (Multilogin, GoLogin, Kameleo): коммерческие, закрытые, но решают ровно задачу «управлять отпечатком».

**Сеть:**
- VPN или Tor. Важно, чтобы timezone и язык совпадали с выходным IP.
- TLS/JA4: у настоящего браузера он и так совпадает с миллионами пользователей, это не проблема. Проблема возникает у curl и скриптов, тут помогают `curl-impersonate` и `utls` (Go).
- TCP-фингерпринт (p0f): выдаёт «Linux» при UA «Windows». Лечится через sysctl (`net.ipv4.ip_default_ttl=128`, отключение timestamps `net.ipv4.tcp_timestamps=0`) или nftables/eBPF-нормализатором. **Это единственное место, где реально пригодится уровень ядра.** Но если вы не подменяете ОС в UA, трогать не нужно.

**Система (против нативных приложений):**
- `machine-id`: генерировать на каждую загрузку или подменять для конкретного приложения через bind-mount.
- MAC: `networking.networkmanager.wifi.macAddress = "random"` и `ethernet.macAddress = "random"` в NixOS.
- Hostname: generic (`localhost`) или `networking.hostName` вида `pc`.
- Подозрительные приложения запускать в песочнице: **bubblewrap/firejail/Flatpak** с поддельными `/etc/machine-id`, `/sys/class/dmi`, `/proc/cpuinfo` (tmpfs + bind), без `/dev/disk/by-id`, отдельный network namespace.
- Максимальный уровень: **ВМ (QEMU) или Whonix/Qubes-подход**. Гость видит виртуальное «железо», которое можно задать любым (SMBIOS через `-smbios type=1,serial=...`, свой MAC, свой диск). Это и есть «Blink»-подход из научной работы: отпечаток можно менять целиком и согласованно.

## 4. Про патчи ядра

Браузерный JS-фингерпринт формируется в userspace (Skia, ANGLE/Mesa, FreeType, шрифты), ядро его почти не видит. Что разумно делать на этом уровне:
- **eBPF/LSM (или seccomp-notify)**, чтобы перехватывать `open()` к `/sys/class/dmi`, `/etc/machine-id`, `/sys/class/net/*/address` для выбранных процессов и отдавать фейк. Это реализуемо, хотя bwrap+bind решает то же проще.
- **Нормализация TCP/IP** через nftables/eBPF TC.
- Тайминги: процессу можно огрубить `CLOCK_MONOTONIC`, но браузеры и так огрубляют `performance.now()`.

## 5. Что можно закодить (если готовое не устроит)

Реалистичный проект на NixOS, «профили личностей»:

1. **Генератор согласованного профиля**: ОС, UA, экран, timezone, локаль, шрифты, GPU, MAC, machine-id, DMI. Значения берутся из реальных распределений (как в BrowserForge), а не случайно.
2. **Обёртка-запускатор**: `bwrap` или ВМ плюс Camoufox (принимает профиль в конфиге) плюс network namespace с отдельным VPN или WireGuard-выходом, геолокация которого совпадает с timezone.
3. **Модуль NixOS** с рандомизацией MAC, hostname и machine-id и sysctl TCP-нормализацией.
4. **Проверка**: CreepJS (abrahamjuliot.github.io/creepjs), amiunique.org, coveryourtracks.eff.org, browserleaks.com. Особенно смотреть на «lies» и несогласованности в CreepJS.

Мой совет на практике: **Mullvad Browser для обычного сёрфинга, отдельный Firefox-профиль для аккаунтов, где вы и так залогинены (там фингерпринт не важен), и bwrap-песочница для проприетарных приложений**, плюс рандомизация MAC и hostname в NixOS-конфиге. Всё это займёт несколько десятков строк в вашем репозитории.

Хотите, добавлю это в конфиг (MAC/hostname, Mullvad Browser, sysctl, bwrap-обёртку с поддельными machine-id и DMI)? Или соберу прототип генератора профилей под Camoufox?
