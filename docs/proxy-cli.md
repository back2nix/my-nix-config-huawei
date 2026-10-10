# Маршруты по приложениям

Claude, Codex, Telegram, Git, браузеры и Nix/Cachix используют отдельные входы sing-box.
Изменение маршрута одной программы не меняет остальные и не переключает
общие порты 1082/1088/1090.

В верхней панели GNOME есть отдельный значок **VPN Routes**. В его меню:

- WinJoy VPN и Personal VPN — состояние и включение/выключение;
- Claude, Codex и Telegram — независимый выбор USA, USA через Casino, KZ (ps-kz) через Casino, FRA, KZ или ISP Казахстан;
- Git, Nix / Cachix и три браузерных прокси (USA, FRA, KZ) — USA, Casino, ps-kz через Casino, FRA, KZ и Direct;
- общие прокси для других программ — три пункта в основном меню, без вложенных подменю.

Выбор маршрута хранится в sing-box и переживает перезапуск службы/компьютера.
Меню и команды управления читают одно состояние. Смена маршрута может
оборвать текущие соединения соответствующей группы; новое соединение
использует выбранный выход.

USA и ps-kz через Casino требуют включённого WinJoy VPN: это транспорт до
промежуточного сервера. Выключение этого VPN делает Casino-маршрут недоступным
для всех выбравших его программ, но не меняет их сохранённый выбор.

ISP Казахстан использует постоянную цепочку `sing-box → SSH kz-astana →
SOCKS5 ISP`. Соединение с ISP открывается с сервера kz-astana: прямого
подключения к ISP с ноутбука нет. SSH управляется самим sing-box, отдельный
ручной `ssh -L` не нужен; служба запускается при загрузке и перезапускается
systemd при падении. Выбор ISP сохраняется при перезапуске. При недоступности
SSH/ISP запрос завершается ошибкой, без переключения на другой выход.

## Claude и Codex

Команды `claude` и `codex` запускают `claude-safe` и `codex-safe` с изолированной
сетью. По умолчанию Claude использует KZ, Codex — USA (Сеул).
У селекторов агентов нет режима Direct или автоматического fallback в Direct.
Локальные веб-сервисы на `10.0.0.1` и его алиасах из `networking.extraHosts`
(включая `casino.local`) доступны через HTTP-прокси агента: sing-box направляет
их с хоста на локальный IP без VPN. Остальные запросы используют selector.
Codex автоматически получает `--no-daemon`, чтобы не использовать общий
сервер вне изоляции. Подробности и граница защиты: [claude-safe.md](claude-safe.md).

```fish
claude-proxy                 # текущий маршрут Claude
claude-proxy usa
claude-proxy casino          # USA через Casino
codex-proxy fra              # изменяет только Codex
claude --check
codex --check
codex --yolo
```

CLI из любой оболочки:

```sh
vpn-route claude kz
vpn-route codex usa-casino
vpn-route codex ps-kz        # 91.147.105.59:22 через Casino
vpn-route claude isp-kz       # ISP Казахстан, SOCKS5-прокси с авторизацией
vpn-route telegram fra
vpn-route nix direct
vpn-route nix status
```

Также принимаются старые значения 1082/1083, 1088/1089, 1090/1091 как
псевдонимы USA, FRA и KZ. Старые универсальные переменные fish
`claude_proxy_port` и `codex_proxy_port` больше не используются.

Команды `claude-1082-safe`, `claude-1088-safe`, `claude-1090-safe` и аналогичные
Codex сохранены как явные **фиксированные** маршруты. Они не следуют
переключателям приложений. Все safe-команды поддерживают `--check`.
Обычные `claude-1082`, `codex-1090` и другие команды без `safe` используют
только proxy-переменные и допускают обход через `--noproxy`.

## Telegram

В настройках Telegram добавь и включи SOCKS5-прокси: сервер `127.0.0.1`,
порт `1106`, без логина и пароля. После этого пункт **Telegram** в меню VPN
переключает только его маршрут. По умолчанию используется KZ (Astana);
доступны те же выходы, что у Claude, включая ISP Казахстан.
Из терминала: `vpn-route telegram fra` или `vpn-route telegram status`.
Если Telegram настроен на старый порт 1082/1088/1090, замени его на 1106.

## Git

Пункт **Git** независимо переключает USA, Casino, FRA, KZ и Direct.
Git по SSH использует SOCKS5 на `127.0.0.1:1118`, Git по HTTP/HTTPS —
HTTP-прокси на `127.0.0.1:1119`. Настройки задаются глобально через Home Manager.
По умолчанию выбран USA (Сеул). CLI: `vpn-route git fra` или `vpn-route git status`.

Локальный `core.sshCommand` в `.git/config` перекрывает глобальный маршрут.
Для этого репозитория временную настройку на порт 1082 нужно удалить после
применения конфигурации: `git config --local --unset core.sshCommand`.
Переменные `GIT_SSH_COMMAND` и собственные настройки отдельных репозиториев
также имеют приоритет. Direct означает прямой выход через sing-box.

## Браузеры

Для браузера выделены отдельные порты на `127.0.0.1`.
Пары USA (1110/1111), FRA (1112/1113) и KZ (1114/1115) имеют собственные
переключатели в трее: можно независимо выбрать USA, Casino, FRA, KZ или Direct.
Названия обозначают исходный профиль; текущий выход показан после двоеточия.
CLI: `vpn-route browser-usa fra`, `vpn-route browser-fra kz`,
`vpn-route browser-kz direct`. Пара Casino (1116/1117) остаётся фиксированной.
Укажи нужный SOCKS или HTTP-порт в настройках своего браузера/расширения
управления прокси; адреса приведены в таблице ниже. Новые профили браузера,
команды запуска и desktop entries не создаются.

Для SOCKS нужен удалённый DNS (в curl — `socks5h`; в браузере настройка
зависит от используемого клиента). Сам факт выделенного порта не запрещает
браузеру обходить прокси или использовать локальный DNS.

## Nix/Cachix

`cachix.nix` направляет nix-daemon на собственный SOCKS5h-вход 1104.
`nix-proxy direct|usa|casino|fra|kz` или `vpn-route nix ...` переключает его
selector без перезапуска nix-daemon. Direct означает прямой выход sing-box,
а не изменение списка кешей или ключей доверия.

Это маршрут загрузок nix-daemon, включая бинарные кеши. Отдельные сетевые
операции клиентского `nix` (например, некоторые загрузки входов flakes),
произвольных build-скриптов и других программ не получают эту настройку
автоматически. Локальные адреса из NO_PROXY продолжают обращаться напрямую.

## Входы

Все новые входы слушают только `127.0.0.1` и не требуют внешних firewall-портов.
DNS каждой группы идёт по DoH через тот же selector или фиксированный выход.
Это относится и к старым входам: 1084/1085 используют `ssh-out1-via-vpn3`
для DNS и трафика, 1086/1087 — `ssh-out1-via-casino`. Проверка в
`tests/proxy-consumers.py` охватывает каждый вход из конфигурации sing-box.
DNS-запрос ограничен 5 секундами. В сборке sing-box исправлено открытие
SSH-канала: оно учитывает отмену запроса, вместо ожидания TCP-таймаута sshd
на недоступном выходе.
DNS-ответы кэшируются по DNS-серверу до истечения TTL. При смене любого
selector через CLI, меню или Clash API сборка sing-box сбрасывает DNS-кэш;
повторный выбор того же выхода кэш сохраняет. Тест проверяет число реальных
DNS-запросов и сброс кэша при переключении выхода.
После подключения Wi-Fi или Ethernet NetworkManager пересоздаёт соединения
sing-box; сохранённые selector остаются выбранными. Энергосбережение Wi-Fi
отключено декларативно.
Если выбранный выход недоступен, запрос завершится ошибкой; рабочий выход
можно выбрать через `vpn-route browser-kz kz`. Автоматической смены страны нет.

| Потребитель | SOCKS | HTTP | Выход по умолчанию |
| --- | --- | --- | --- |
| Antigravity CLI safe | — | 1121 | USA, свой selector |
| Claude safe | — | 1101 | KZ, свой selector |
| Codex safe | — | 1103 | USA, свой selector |
| Telegram | 1106 | 1107 | KZ, свой selector |
| Git | 1118 | 1119 | USA, свой selector |
| Nix/Cachix | 1104 | 1105 | USA, свой selector |
| Браузер USA | 1110 | 1111 | USA, свой selector |
| Браузер FRA | 1112 | 1113 | FRA, свой selector |
| Браузер KZ | 1114 | 1115 | KZ, свой selector |
| Браузер USA через Casino | 1116 | 1117 | фиксированный Сеул через Casino |

USA — существующее название выхода `ssh-out1` в этом репозитории; фактический
сервер находится в Сеуле. Casino — промежуточный хоп до того же сервера.
Общие пары 1082/1083, 1088/1089, 1090/1091 и фиксированные safe-входы
1093/1095/1097 сохранены для совместимости.

## Применение

Используй flake-профиль своего устройства, например на yoga14:

```sh
sudo nixos-rebuild switch --flake .#yoga14
```

Шаблон sing-box запрашивает перезапуск службы при изменении содержимого.
Для загрузки нового кода GNOME-расширения выйди из графической сессии и войди
снова. После этого проверь `claude --check`, `codex --check` и меню VPN.

## Проверки реализации

```sh
nix eval --raw '.#nixosConfigurations.yoga14.config.sops.templates."sing-box-config.json".content' > /tmp/routes.json
python3 tests/proxy-consumers.py /tmp/routes.json /path/to/sing-box /path/to/vpn-route
node tests/proxy-menu.mjs
```

Тест маршрутов использует только локальные proxy-fixtures, проверяет
независимость потребителей, запрет Direct для агентов и сохранение выбора.
Тест меню использует mock-объекты GNOME и проверяет действия, ошибки и cleanup;
он не заменяет визуальную проверку в живой графической сессии.

Скрипты `just update-codex` и `just update-claude` используют те же HTTP-прокси,
что и приложения: Codex — `http://127.0.0.1:1103`, Claude — `http://127.0.0.1:1101`.
Маршрут выбирается в пунктах **Codex** и **Claude** меню VPN Routes;
CLI: `vpn-route codex fra`, `vpn-route claude usa`.
Переопределение: `CODEX_UPDATE_PROXY` / `CLAUDE_UPDATE_PROXY` (URL прокси,
например `socks5h://127.0.0.1:1082`); пустое значение отключает явный прокси.

## Новый сервер ps-kz через Casino

Маршрут `ps-kz` (`kz-casino`) использует цепочку
`ноутбук → SSH seoul-relay@10.100.0.1 → SSH ubuntu@91.147.105.59:22`.
Ключ назначения `/home/bg/.ssh/id_ed25519_kz_astana` остаётся на ноутбуке.
На Casino разрешены обе пары USA и ps-kz в `PermitOpen`, `authorized_keys`
и `host-egress`; новые публичные порты не открываются.

После применения конфигурации VPS и `just switch` на ноутбуке включи
WinJoy VPN и выбери **KZ (ps-kz) через Casino** в меню нужного приложения.
Для общих портов: `proxy-mode ps-kz`, `proxy-mode --1088 ps-kz`
или `proxy-mode --1090 ps-kz`.

Для обычного SSH добавь блок **перед** общим `Host *`, если в нём задан
`ProxyCommand none` (SSH использует первое значение):

```sshconfig
Host ps-kz
    HostName 91.147.105.59
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519_kz_astana
    IdentitiesOnly yes
    ProxyCommand ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519_seoul_relay -W %h:%p seoul-relay@10.100.0.1
```

На ps-kz образ Ubuntu запрещает пересылку для root-ключа и требует вход
под `ubuntu`; поэтому outbound и SSH-алиас используют `ubuntu`.

## Antigravity CLI

Официальный CLI запускается через `agy` или `antigravity-cli`. Обе команды
используют изолированную сеть и прокси `127.0.0.1:1121`. Маршрут выбирается
в меню VPN → Antigravity CLI независимо от Claude и Codex, либо командой
`antigravity-proxy fra` / `vpn-route antigravity fra`.

`agy --check` проверяет доступность прокси и локальных сервисов.
`just update-antigravity` обновляет версию, URL и SHA512 официального архива
в `pkgs/antigravity-cli.nix` и проверяет сборку для текущего устройства.
После обновления выполни `just switch`. До первого применения можно обновить
через существующий прокси: `ANTIGRAVITY_UPDATE_PROXY=http://127.0.0.1:1101 just update-antigravity`.
`ANTIGRAVITY_UPDATE_PROXY=''` разрешает прямую загрузку обновления.
Исходный установщик: https://antigravity.google/cli/install.sh.

## FRA через RU (Beget)

В меню VPN доступен «FRA через RU (Beget)». Маршрут: ноутбук → admin-VPN
awg-egg → seoul-relay@10.100.0.1 → SSH 5.252.179.162:22 → интернет.
WinJoy VPN должен быть включён. Ключ FRA остаётся на ноутбуке.

```bash
vpn-route browser-fra fra-casino
vpn-route telegram fra-casino
proxy-mode --1088 fra-casino
```

Outbound: `ssh-frankfurt-via-casino`, detour: `ssh-casino-relay`.
До использования применить изменения casino-vps на Beget (`just deploy`),
затем пересобрать ноутбук из этой конфигурации.
