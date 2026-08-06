# File: module/hard-poweroff.nix
#
# Мгновенное (жёсткое) выключение по Ctrl+Esc.
#
# ВНИМАНИЕ: это НЕ штатное выключение. Данные, ещё не записанные на диск,
# будут потеряны, файловые системы останутся "грязными" (при загрузке
# возможен fsck / журнальное восстановление). Работает через kernel sysrq,
# то есть питание снимается за миллисекунды, минуя systemd и юзерспейс.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # sysrq 'o' = power off immediately.
  # 's' (sync) НЕ делаем — это добавило бы задержку. Если хочешь чуть
  # безопаснее, раскомментируй строку sync ниже.
  hard-poweroff = pkgs.writeShellScriptBin "hard-poweroff" ''
    # echo s > /proc/sysrq-trigger   # sync (добавляет задержку)
    echo o > /proc/sysrq-trigger
  '';
in {
  # Разрешаем sysrq-триггеры (бит 128 = allow reboot/poweroff).
  # 1 = разрешить всё; так же работает Alt+SysRq+O как аппаратный запасной вариант.
  boot.kernel.sysctl."kernel.sysrq" = 1;

  environment.systemPackages = [hard-poweroff];

  # Главный механизм: actkbd — root-демон, читающий /dev/input напрямую.
  # Не зависит от сессии, поэтому работает на экране входа GDM, в TTY,
  # и даже когда GNOME завис. dconf-биндинг ниже покрывает только
  # залогиненную сессию пользователя bg.
  #
  # keycodes: 29 = KEY_LEFTCTRL, 97 = KEY_RIGHTCTRL, 1 = KEY_ESC
  services.actkbd = {
    enable = true;
    bindings = [
      {
        keys = [29 1];
        events = ["key"];
        command = "${hard-poweroff}/bin/hard-poweroff";
      }
      {
        keys = [97 1];
        events = ["key"];
        command = "${hard-poweroff}/bin/hard-poweroff";
      }
    ];
  };

  # Запуск без пароля — иначе горячая клавиша просто зависнет на промпте.
  security.sudo.extraRules = [
    {
      users = ["bg"];
      commands = [
        {
          # Путь-симлинк, а не store-путь: не меняется между поколениями,
          # и совпадает с тем, что вызывает горячая клавиша.
          command = "/run/current-system/sw/bin/hard-poweroff";
          options = ["NOPASSWD" "SETENV"];
        }
      ];
    }
  ];
}
