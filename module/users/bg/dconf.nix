{pkgs, ...}: {
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
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
        "window-calls@domandoman.xyz"
        "osk-globe-cycle@back2nix"
        "custom-command-toggle@storageb.github.com"
      ];
    };

    # Тумблер admin-VPN до прод-сервера в Quick Settings + индикатор в топ-баре.
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
    "org/gnome/shell/extensions/custom-command-toggle" = {
      numbuttons-setting = 2;
      entryrow3-setting = "WinJoy VPN";
      entryrow4-setting = "network-vpn-symbolic,network-vpn-disabled-symbolic";
      entryrow1-setting = "systemctl start amneziawg-egg.service";
      entryrow2-setting = "systemctl stop amneziawg-egg.service";
      # Состояние берём из systemd, а не из памяти расширения: иначе после
      # ребута или падения юнита тумблер показывал бы неправду.
      # UP/DOWN, а не сырой вывод is-active: сверка внутри расширения — поиск по
      # границе слова, и `active` совпало бы с `inactive`.
      checkcommand1-setting = "systemctl is-active --quiet amneziawg-egg.service && echo UP || echo DOWN";
      checkregex1-setting = "UP";
      checkcommandsync1-setting = true;
      checkcommandinterval1-setting = 10;
      initialtogglestate1-setting = 3; # не трогать юнит при логине
      showindicator1-setting = true;
      runcommandatboot1-setting = false;

      # Кнопка 2: экранная клавиатура GNOME (OSK). Выключенная — не всплывает
      # вообще, включённая — появляется в нужные моменты (ввод с тачскрина).
      # Это ровно тот же ключ a11y, что задан ниже как значение по умолчанию;
      # переключатель меняет его на лету через gsettings.
      entryrow32-setting = "Экранная клавиатура";
      entryrow42-setting = "input-keyboard-symbolic,input-keyboard-symbolic";
      entryrow12-setting = "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true";
      entryrow22-setting = "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false";
      # Состояние читаем из самого gsettings, а не из памяти расширения:
      # ключ могли поменять из Настроек или home-manager'ом при пересборке.
      checkcommand2-setting = "gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled";
      checkregex2-setting = "true";
      checkcommandsync2-setting = true;
      checkcommandinterval2-setting = 10;
      initialtogglestate2-setting = 3; # не трогать ключ при логине
      showindicator2-setting = false;
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
