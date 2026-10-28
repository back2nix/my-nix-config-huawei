# Переключатель маршрута для портов 1082/1083 (socks-usa/http-usa).
#
# Зачем: 17.06 схема через casino-VPS слегла целиком, и единственным способом
# хоть куда-то попасть оказался docs/no-proxy-access.md — ручная правка
# sing-box-конфига и рестарт юнита. Теперь путь выбирается на лету.
#
# Как устроено: в sing-box (sops/sops.nix) правило для socks-usa/http-usa
# ведёт не на конкретный ssh-outbound, а на outbound типа selector
# (тег usa-select). Selector переключается через Clash-API на 127.0.0.1:9090 —
# без рестарта sing-box и без root: это обычный HTTP на localhost, поэтому
# ни polkit-правила, ни sudo тут не нужны (в отличие от тумблеров VPN,
# которые дёргают systemd).
#
# Выбор запоминается самим sing-box (experimental.cache_file.store_selected),
# так что режим переживает рестарт юнита и ребут.
#
# Управление:
#   proxy-mode                 — показать текущий режим и список
#   proxy-mode seoul|usa-2|usa-2-casino|casino|ps-kz|fra-casino|fra-ru|frankfurt|astana|ru|vpn3|direct
#   proxy-mode status          — машиночитаемо: SEOUL/CASINO/FRANKFURT/VPN3/DIRECT
#   proxy-mode --1088 ...      — то же для 1088/1089 (selector frankfurt-select)
#   proxy-mode --1090 ...      — то же для 1090/1091 (selector astana-select)
#   плитка-список "Прокси 1082" в Quick Settings — расширение
#   gnome-extensions/proxy-mode, собирается здесь же (см. ниже).
#
# vpn3 доступен только из CLI: в меню оставлены четыре пункта, которыми
# пользуются на практике.
{pkgs, ...}: let
  proxyMode = pkgs.writeShellScriptBin "proxy-mode" ''
    set -u
    PATH=${pkgs.lib.makeBinPath [pkgs.curl pkgs.jq pkgs.libnotify]}:$PATH
    API=http://127.0.0.1:9090
    SEL=usa-select
    PORTS=1082/1083
    if [ "''${1:-}" = --1088 ]; then
      SEL=frankfurt-select
      PORTS=1088/1089
      shift
    elif [ "''${1:-}" = --1090 ]; then
      SEL=astana-select
      PORTS=1090/1091
      shift
    fi

    api() { curl -fsS --max-time 3 "$@"; }

    # Имя outbound'а в sing-box <-> короткий псевдоним для человека.
    to_tag() {
      case "$1" in
        seoul)  echo ssh-out1 ;;
        usa-2)  echo ssh-usa-2 ;;
        usa-2-casino) echo ssh-usa-2-via-casino ;;
        casino) echo ssh-out1-via-casino ;;
        ps-kz) echo ssh-ps-kz-via-casino ;;
        fra-casino|fra-ru) echo ssh-frankfurt-via-casino ;;
        frankfurt) echo ssh-frankfurt ;;
        astana) echo ssh-astana ;;
        ru)     echo ssh-ru-beget ;;
        vpn3)   echo ssh-out1-via-vpn3 ;;
        direct) echo direct-out ;;
        *) return 1 ;;
      esac
    }
    to_name() {
      case "$1" in
        ssh-out1)             echo seoul ;;
        ssh-usa-2)            echo usa-2 ;;
        ssh-usa-2-via-casino) echo usa-2-casino ;;
        ssh-out1-via-casino)  echo casino ;;
        ssh-ps-kz-via-casino) echo ps-kz ;;
        ssh-frankfurt)        echo frankfurt ;;
        ssh-frankfurt-via-casino) echo fra-casino ;;
        ssh-out1-via-vpn3)    echo vpn3 ;;
        ssh-astana)           echo astana ;;
        ssh-ru-beget)         echo ru ;;
        direct-out)           echo direct ;;
        *) echo "$1" ;;
      esac
    }

    # Пустой ответ здесь важнее кода возврата: curl в конвейере с jq свой
    # провал не передаёт (статус даёт jq, а он на пустом входе доволен),
    # поэтому недоступный API выглядел бы как пустой режим, а не как ошибка.
    current() {
      cur=$(api "$API/proxies/$SEL" | jq -r '.now // empty')
      [ -n "$cur" ] || return 1
      echo "$cur"
    }

    case "''${1:-show}" in
      status)
        # Для checkcommand в тумблерах: недоступный API — не режим, а поломка,
        # поэтому отдаём UNKNOWN, а не тихо «seoul».
        now=$(current 2>/dev/null) || { echo UNKNOWN; exit 0; }
        to_name "$now" | tr '[:lower:]' '[:upper:]'
        exit 0
        ;;
      show)
        now=$(current) || { echo "sing-box Clash-API недоступен ($API)" >&2; exit 1; }
        echo "текущий: $(to_name "$now")  ($now)"
        echo "доступно: seoul usa-2 usa-2-casino casino ps-kz fra-casino frankfurt astana ru vpn3 direct"
        exit 0
        ;;
      seoul|usa-2|usa-2-casino|casino|ps-kz|fra-casino|fra-ru|frankfurt|astana|ru|vpn3|direct)
        tag=$(to_tag "$1")
        api -X PUT "$API/proxies/$SEL" \
          -H 'Content-Type: application/json' \
          -d "{\"name\":\"$tag\"}" >/dev/null || {
            echo "не удалось переключить: sing-box Clash-API недоступен ($API)" >&2
            exit 1
          }
        notify-send -i network-vpn-symbolic "Прокси $PORTS" "Режим: $1"
        echo "$1"
        exit 0
        ;;
      *)
        echo "usage: proxy-mode [--1088|--1090] [show|status|seoul|usa-2|usa-2-casino|casino|ps-kz|fra-casino|fra-ru|frankfurt|astana|ru|vpn3|direct]" >&2
        exit 2
        ;;
    esac
  '';
  # Dedicated panel menu: application selectors, host VPNs
  # and the legacy shared port selectors for other programs.
  uuid = "proxy-mode@back2nix";

  extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-proxy-mode";
    version = "1.0";
    src = ./gnome-extensions/proxy-mode;

    installPhase = let
      target = "$out/share/gnome-shell/extensions/${uuid}";
    in ''
      runHook preInstall
      install -Dm444 metadata.json -t "${target}"
      install -Dm444 extension.js  -t "${target}"
      runHook postInstall
    '';

    passthru.extensionUuid = uuid;
  };
  # Содержимое меню живёт в /etc, а не в extension.js: расширение перечитывает
  # файл при каждом открытии меню, так что после nixos-rebuild switch изменения
  # видны сразу. Код самого расширения gnome-shell на Wayland подхватывает
  # только после перелогина.
  # Пути до бинарей тоже здесь: PATH у gnome-shell наследуется от сессии,
  # и на systemPackages полагаться нельзя.
  modes = [
    {id = "usa"; label = "USA (Сеул)";}
    {id = "usa-2"; label = "USA 2 (us-central1)";}
    {id = "casino"; label = "USA через Casino";}
    {id = "usa-2-casino"; label = "USA 2 через Casino";}
    {id = "fra-casino"; label = "FRA через RU (Beget)";}
    {id = "ps-kz"; label = "KZ (ps-kz) через Casino";}
    {id = "fra"; label = "FRA (Франкфурт)";}
    {id = "kz"; label = "KZ (Astana)";}
    {id = "ru"; label = "RU (Beget, Personal VPN)";}
    # Только для fra-deploy: seoul-relay пускает лишь фиксированные ssh-цели.
    {id = "beget-relay"; label = "Beget (WinJoy VPN, seoul-relay)";}
  ];
  # Режимы, которые не должны появляться у групп без явного only.
  groupOnlyModes = ["beget-relay"];
  # Группа без only получает все общие режимы — меню остаётся данными в /etc,
  # extension.js не меняется (фильтр only применяется и к Direct/ISP).
  withDefaultOnly = g:
    g
    // {
      only = g.only or (map (m: m.id) (builtins.filter (m: !(builtins.elem m.id groupOnlyModes)) modes) ++ ["direct" "isp-kz"]);
    };
  menu = {
    proxyMode = "${proxyMode}/bin/proxy-mode";
    vpnRoute = "${pkgs.vpn-route}/bin/vpn-route";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    # One Clash API snapshot replaces a shell/curl/jq pipeline per row.
    statusCommand = ["${pkgs.curl}/bin/curl" "--noproxy" "*" "-fsS" "--max-time" "3" "http://127.0.0.1:9090/proxies"];
    outboundModes = {
      ssh-out1 = "usa";
      ssh-usa-2 = "usa-2";
      ssh-usa-2-via-casino = "usa-2-casino";
      ssh-out1-via-casino = "casino";
      ssh-ps-kz-via-casino = "ps-kz";
      ssh-frankfurt = "fra";
      ssh-frankfurt-via-casino = "fra-casino";
      ssh-astana = "kz";
      ssh-ru-beget = "ru";
      ssh-casino-relay = "beget-relay";
      isp-kazakhstan = "isp-kz";
      direct-out = "direct";
    };
    legacyAliases = {usa = "seoul"; fra = "frankfurt"; kz = "astana";};
    legacySelectors = {"1082" = "usa-select"; "1088" = "frankfurt-select"; "1090" = "astana-select";};
    inherit modes;
    vpns = [
      {label = "WinJoy VPN"; unit = "amneziawg-egg.service";}
      {label = "Personal VPN"; unit = "amneziawg-personal.service";}
      {label = "WebRTC: блокировать Google STUN"; unit = "webrtc-google-block.service";}
      {label = "WebRTC: запретить UDP (bg, кроме DNS)"; unit = "webrtc-udp-block.service";}
    ];
    # direct = true добавляет режим Direct, иначе ISP Казахстан.
    # only ограничивает выбор в меню (статус показывается любой).
    # ☢️ Новый пункт/режим/группа меню — ТОЛЬКО данными здесь (modes, groups,
    # only, groupOnlyModes), НЕ правкой extension.js: menu.json перечитывается
    # при открытии меню, а JS требует перелогина. Режим для одной группы —
    # в modes + groupOnlyModes + её only (так сделан beget-relay для fra-deploy).
    # Ошибка 2026-10-20: под fra-deploy добавлялось поле extraModes в JS.
    groups = map withDefaultOnly [
      {id = "antigravity"; label = "Antigravity CLI"; direct = false;}
      {id = "claude"; label = "Claude"; direct = false; only = ["usa-2" "usa-2-casino"];}
      {id = "codex"; label = "Codex"; direct = false;}
      {id = "telegram"; label = "Telegram (SOCKS5: 1106)"; direct = false;}
      {id = "git"; label = "Git"; direct = true;}
      {id = "nix"; label = "Nix / Cachix"; direct = true;}
      {id = "voicestudio"; label = "VoiceStudio (1122/1123)"; direct = true;}
      {id = "browser-usa"; label = "Браузер USA (1110/1111)"; direct = true;}
      {id = "browser-fra"; label = "Браузер FRA (1112/1113)"; direct = true;}
      {id = "browser-kz"; label = "Браузер KZ (1114/1115)"; direct = true;}
      # ssh/деплой Франкфурта: ~/.ssh/config ведёт winjoy-frankfurt через 1124.
      {id = "fra-deploy"; label = "Франкфурт ssh/деплой (1124)"; direct = true; only = ["direct" "beget-relay" "ru" "casino" "usa-2-casino" "ps-kz" "usa" "usa-2" "kz"];}
    ];
    legacyModes = [
      {id = "seoul"; label = "USA (Сеул)";}
      {id = "usa-2"; label = "USA 2 (us-central1)";}
      {id = "frankfurt"; label = "FRA (Франкфурт)";}
      {id = "astana"; label = "KZ (Astana)";}
      {id = "casino"; label = "USA через Casino";}
      {id = "usa-2-casino"; label = "USA 2 через Casino";}
      {id = "fra-casino"; label = "FRA через RU (Beget)";}
      {id = "ps-kz"; label = "KZ (ps-kz) через Casino";}
      {id = "ru"; label = "RU (Beget, Personal VPN)";}
      {id = "direct"; label = "Direct";}
    ];
    legacyPorts = [1082 1088 1090];
  };
in {
  environment.systemPackages = [proxyMode extension];
  environment.etc."proxy-mode/menu.json".text = builtins.toJSON menu;
}
