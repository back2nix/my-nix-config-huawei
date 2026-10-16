{pkgs, ...}: let
  wallpaper = ../../../assets/wallpapers/nix-wallpaper-binary-black-2880x1800.png;
in {
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file://${wallpaper}";
      picture-uri-dark = "file://${wallpaper}";
      picture-options = "zoom";
    };
    "org/gnome/desktop/screensaver" = {
      picture-uri = "file://${wallpaper}";
      picture-options = "zoom";
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
      ];
    };
    "org/gnome/settings-daemon/plugins/power" = {
      ambient-enabled = false;
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Primary><Alt>T";
      command = "kitty";
      name = "Open Terminal";
    };
    # ВНИМАНИЕ: жёсткое выключение через sysrq, без sync и без systemd.
    # Несохранённые данные теряются. См. module/hard-poweroff.nix
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Primary>Escape";
      command = "/run/wrappers/bin/sudo -n /run/current-system/sw/bin/hard-poweroff";
      name = "Hard Power Off (instant)";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Primary><Alt>R";
      command = "toggle-flip";
      name = "Toggle Screen Flip";
    };
    # Режим портфеля: крышку можно закрыть, ноут продолжает работать
    # (инхибитор logind). Тот же тумблер есть в Quick Settings ниже.
    # См. module/bag-mode.nix
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Primary><Alt>B";
      command = "bag-mode";
      name = "Bag Mode (lid closable, no suspend)";
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = true;
      send-events = "enabled";
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };
    "org/gnome/desktop/wm/keybindings" = {
      close = ["<Alt>q"];
      cycle-group = [];
      cycle-group-backward = [];
      cycle-panels = [];
      cycle-panels-backward = [];
      cycle-windows = [];
      cycle-windows-backward = [];
      move-to-monitor-down = [];
      move-to-monitor-left = [];
      move-to-monitor-right = [];
      move-to-monitor-up = [];
      move-to-workspace-1 = [];
      move-to-workspace-last = [];
      move-to-workspace-left = ["<Shift><Control><Alt>Left"];
      move-to-workspace-right = ["<Shift><Control><Alt>Right"];
      switch-panels = [];
      switch-panels-backward = [];
      switch-to-workspace-1 = ["<Alt>1"];
      switch-to-workspace-2 = ["<Alt>2"];
      switch-to-workspace-3 = ["<Alt>3"];
      switch-to-workspace-4 = ["<Alt>4"];
      switch-to-workspace-last = [];
      switch-input-source = ["<Alt>Shift_L"];
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      # В системе один пользователь, и GNOME в этом случае прячет «Выйти» —
      # остаётся только перезагрузка. Расширения подхватываются лишь после
      # ре-логина, так что кнопка нужна.
      always-show-log-out = true;
      enabled-extensions = [
        "dual-clock@back2nix"
        "window-calls@domandoman.xyz"
        "osk-globe-cycle@back2nix"
        "custom-command-toggle@storageb.github.com"
        # Отдельное меню VPN и маршрутов приложений.
        # (module/proxy-mode.nix).
        "proxy-mode@back2nix"
      ];
    };

    # Переключатель admin-VPN находится в отдельном меню VPN Routes.
    # NetworkManager AmneziaWG не понимает (обфусцированный форк WireGuard — см.
    # module/wireguard-eggventure.nix), поэтому штатного VPN-переключателя нет и
    # быть не может; этот дёргает systemd-юнит напрямую. Право на start/stop без
    # пароля даёт polkit-правило, ограниченное РОВНО этим юнитом (там же).
    #
    # Главная польза здесь — не сам переключатель (юнит и так поднимается при
    # загрузке), а ИНДИКАТОР: сейчас об отвале туннеля узнаёшь только по
    # отвалившемуся kubectl.
    #
    # ⚠️ Расширения GNOME ломаются на каждом мажоре шелла. При переезде на
    # GNOME 51 проверь shell-version в metadata.json ДО switch — иначе тумблер
    # тихо исчезнет, и это будет выглядеть как «VPN отвалился».
    # VPN switches live in the dedicated VPN Routes panel menu.
    "org/gnome/shell/extensions/custom-command-toggle" = {
      numbuttons-setting = 2;
      # Кнопка 1: экранная клавиатура GNOME (OSK). Выключенная — не всплывает
      # вообще, включённая — появляется в нужные моменты (ввод с тачскрина).
      # Это ровно тот же ключ a11y, что задан ниже как значение по умолчанию;
      # переключатель меняет его на лету через gsettings.
      entryrow3-setting = "Экранная клавиатура";
      entryrow4-setting = "input-keyboard-symbolic,input-keyboard-symbolic";
      entryrow1-setting = "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true";
      entryrow2-setting = "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false";
      # Состояние читаем из самого gsettings, а не из памяти расширения:
      # ключ могли поменять из Настроек или home-manager'ом при пересборке.
      checkcommand1-setting = "gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled";
      checkregex1-setting = "true";
      checkcommandsync1-setting = true;
      checkcommandinterval1-setting = 10;
      initialtogglestate1-setting = 3; # не трогать ключ при логине
      showindicator1-setting = false;
      runcommandatboot1-setting = false;

      # Кнопка 2: режим портфеля — ноут работает с закрытой крышкой
      # (инхибитор logind, см. module/bag-mode.nix). Индикатор в топ-баре
      # включён намеренно: забытый включённым режим — это разряженная батарея
      # в сумке.
      entryrow32-setting = "Режим портфеля";
      entryrow42-setting = "system-run-symbolic,system-suspend-symbolic";
      entryrow12-setting = "bag-mode on";
      entryrow22-setting = "bag-mode off";
      checkcommand2-setting = "bag-mode status";
      checkregex2-setting = "ON";
      checkcommandsync2-setting = true;
      checkcommandinterval2-setting = 10;
      initialtogglestate2-setting = 3; # не трогать юнит при логине
      showindicator2-setting = true;
      runcommandatboot2-setting = false;
    };
    "org/gnome/desktop/interface" = {
      enable-animations = false;
    };
    # Экранная клавиатура GNOME (всплывает при вводе с тачскрина).
    # Ключ НЕ фиксируем декларативно: им рулит тумблер «Экранная клавиатура»
    # в Quick Settings (см. custom-command-toggle выше). Если прописать здесь
    # значение, любая пересборка home-manager затирала бы выбор пользователя.
    # "org/gnome/desktop/a11y/applications" = {
    #   screen-keyboard-enabled = true;
    # };
    # Настройки масштабирования (если нужны)
    # Раскомментируй и настрой под свои нужды:
    # "org/gnome/desktop/interface" = {
    #   text-scaling-factor = 1.0;  # 1.0, 1.25, 1.5
    # };
    # "org/gnome/mutter" = {
    #   experimental-features = ["scale-monitor-framebuffer"];  # для fractional scaling
    # };
  };
}
