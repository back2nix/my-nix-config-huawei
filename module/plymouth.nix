# Красивая тихая загрузка: Plymouth-анимация, пароль LUKS вводится в ней же.
# Посмотреть другие темы: ls $(nix build --no-link --print-out-paths nixpkgs#adi1090x-plymouth-themes)/share/plymouth/themes
# Если что-то сломалось — в меню systemd-boot нажми `e` и убери `quiet splash`.
{pkgs, ...}: {
  boot = {
    plymouth = {
      enable = true;
      theme = "rings";
      themePackages = [
        (pkgs.adi1090x-plymouth-themes.override {selected_themes = ["rings"];})
      ];
    };
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];
  };
}
