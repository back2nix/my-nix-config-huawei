# "Режим портфеля": ноут продолжает работать с закрытой крышкой.
#
# Включённый режим держит block-инхибитор logind на handle-lid-switch:sleep,
# поэтому закрытие крышки не усыпляет машину. Современный GNOME (>=3.28)
# обработку крышки полностью делегирует logind, так что
# services.logind HandleLidSwitch = "suspend" (configuration.nix) на время
# режима не срабатывает.
#
# ВАЖНО: в --what НЕТ класса idle, хотя блокировать засыпание по простою вроде
# бы напрашивается. idle — это ровно тот класс, которым GNOME гасит экран: с ним
# сессия считается активной вечно, и подсветка в сумке горит до разряда (именно
# так вёл себя первый вариант модуля). Засыпание по простою и без него не
# пройдёт: gsd-power зовёт logind Suspend(false), а неинтерактивный вызов
# упирается в наш block-инхибитор sleep.
#
# Гашение экрана: закрытая крышка сама по себе панель не тушит, а штатного
# idle-blank ждать 5 минут. Поэтому режим следит за крышкой и при закрытии сразу
# блокирует сессию — на блокировке GNOME выключает панель.
#
# Управление:
#   * тумблер "Режим портфеля" в Quick Settings (custom-command-toggle,
#     см. module/users/bg/dconf.nix)
#   * Ctrl+Alt+B — то же самое переключение с клавиатуры
#
# Состояние живёт в user-юните, а не в фоновом процессе скрипта: тумблер и
# хоткей тогда видят одно и то же состояние, и оно переживает закрытие
# терминала, из которого режим включили.
{pkgs, ...}: let
  bagMode = pkgs.writeShellScriptBin "bag-mode" ''
    set -u
    PATH=${pkgs.lib.makeBinPath [pkgs.systemd pkgs.libnotify]}:$PATH
    UNIT=bag-mode.service

    active() { systemctl --user is-active --quiet "$UNIT"; }

    case "''${1:-toggle}" in
      on)  systemctl --user start "$UNIT" ;;
      off) systemctl --user stop "$UNIT" ;;
      status)
        if active; then echo ON; else echo OFF; fi
        exit 0
        ;;
      toggle)
        if active; then
          systemctl --user stop "$UNIT"
          notify-send -i system-suspend "Режим портфеля выключен" \
            "Крышка снова усыпляет ноутбук."
        else
          systemctl --user start "$UNIT"
          notify-send -i system-run "Режим портфеля включён" \
            "Крышку можно закрыть — задача продолжит работать, экран погаснет."
        fi
        exit 0
        ;;
      *) echo "usage: bag-mode [on|off|toggle|status]" >&2; exit 2 ;;
    esac
  '';

  # Наблюдатель за крышкой. Опрос /proc раз в 2 с, а не подписка на события:
  # с активным инхибитором logind сигнал о крышке всё равно не разослать,
  # а цена опроса — доли процента CPU.
  lidWatch = pkgs.writeShellScript "bag-mode-lid-watch" ''
    PATH=${pkgs.lib.makeBinPath [pkgs.coreutils pkgs.glib]}:$PATH
    prev=open
    while :; do
      if cat /proc/acpi/button/lid/*/state 2>/dev/null | grep -q closed; then
        cur=closed
      else
        cur=open
      fi
      if [ "$cur" = closed ] && [ "$prev" != closed ]; then
        # Блокировка сессии = гашение панели. Пароль при открытии крышки —
        # осознанная плата: иначе ноут едет в сумке разблокированным.
        gdbus call --session -d org.gnome.ScreenSaver -o /org/gnome/ScreenSaver \
          -m org.gnome.ScreenSaver.SetActive true >/dev/null 2>&1 || true
      fi
      prev=$cur
      sleep 2
    done
  '';
in {
  environment.systemPackages = [bagMode];

  systemd.user.services.bag-mode = {
    description = "Bag mode: keep working with the lid closed (inhibit suspend)";
    # Никаких wantedBy: юнит запускается только руками (тумблер/хоткей),
    # иначе ноут перестал бы засыпать вообще.
    path = [pkgs.gnugrep];
    serviceConfig = {
      Type = "simple";
      # Инхибитор живёт ровно столько, сколько работает наблюдатель за крышкой;
      # снимается при остановке юнита.
      #
      # --why в кавычках обязательно: systemd режет ExecStart по пробелам, и без
      # них "with" из фразы стало бы командой запуска (юнит падал с status=1).
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=handle-lid-switch:sleep --who=bag-mode --why=\"Working with the lid closed\" --mode=block ${lidWatch}";
    };
  };
}
