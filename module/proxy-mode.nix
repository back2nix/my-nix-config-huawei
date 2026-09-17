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
#   proxy-mode seoul|casino|frankfurt|vpn3|direct
#   proxy-mode status          — машиночитаемо: SEOUL/CASINO/FRANKFURT/VPN3/DIRECT
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

    api() { curl -fsS --max-time 3 "$@"; }

    # Имя outbound'а в sing-box <-> короткий псевдоним для человека.
    to_tag() {
      case "$1" in
        seoul)  echo ssh-out1 ;;
        casino) echo ssh-out1-via-casino ;;
        frankfurt) echo ssh-frankfurt ;;
        vpn3)   echo ssh-out1-via-vpn3 ;;
        direct) echo direct-out ;;
        *) return 1 ;;
      esac
    }
    to_name() {
      case "$1" in
        ssh-out1)             echo seoul ;;
        ssh-out1-via-casino)  echo casino ;;
        ssh-frankfurt)        echo frankfurt ;;
        ssh-out1-via-vpn3)    echo vpn3 ;;
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
        echo "доступно: seoul casino frankfurt vpn3 direct"
        exit 0
        ;;
      seoul|casino|frankfurt|vpn3|direct)
        tag=$(to_tag "$1")
        api -X PUT "$API/proxies/$SEL" \
          -H 'Content-Type: application/json' \
          -d "{\"name\":\"$tag\"}" >/dev/null || {
            echo "не удалось переключить: sing-box Clash-API недоступен ($API)" >&2
            exit 1
          }
        notify-send -i network-vpn-symbolic "Прокси 1082/1083" "Режим: $1"
        echo "$1"
        exit 0
        ;;
      *)
        echo "usage: proxy-mode [show|status|seoul|casino|frankfurt|vpn3|direct]" >&2
        exit 2
        ;;
    esac
  '';
  # GUI к тому же скрипту: плитка со списком режимов в Quick Settings.
  #
  # Почему отдельное расширение, а не ещё кнопки в custom-command-toggle
  # (которым сделаны WinJoy VPN, Personal VPN и режим портфеля): то
  # расширение умеет только QuickToggle — бинарную плитку, а режимов несколько
  # и они взаимоисключающие. Списком это QuickMenuToggle, которого там нет.
  uuid = "proxy-mode@back2nix";

  extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-proxy-mode";
    version = "1.0";
    src = ./gnome-extensions/proxy-mode;

    # PATH у gnome-shell наследуется от сессии, и на systemPackages там
    # полагаться нельзя — плитка молча перестала бы работать. Прибиваем
    # путь до скрипта гвоздями на сборке.
    buildPhase = ''
      runHook preBuild
      substituteInPlace extension.js \
        --replace-fail "@proxyMode@" "${proxyMode}/bin/proxy-mode"
      runHook postBuild
    '';

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
in {
  environment.systemPackages = [proxyMode extension];
}
