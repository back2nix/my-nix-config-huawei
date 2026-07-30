# File: module/osk-globe-cycle.nix
#
# Расширение gnome-shell: кнопка-глобус на экранной клавиатуре сразу
# переключает раскладку вместо открытия меню выбора языка. Меню
# (LanguageSelectionPopup) не реагирует на касания в модальных диалогах
# (Alt+F2, экран блокировки), потому что лежит вне поддерева, захваченного
# Main.pushModal.
{pkgs, ...}: let
  uuid = "osk-globe-cycle@back2nix";

  extension = pkgs.stdenvNoCC.mkDerivation {
    pname = "gnome-shell-extension-osk-globe-cycle";
    version = "1.0";
    src = ./gnome-extensions/osk-globe-cycle;

    nativeBuildInputs = [pkgs.glib];

    buildPhase = ''
      runHook preBuild
      glib-compile-resources \
        --target=osk-layouts.gresource \
        --sourcedir=. \
        osk-layouts.gresource.xml
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm444 metadata.json        -t "$out/share/gnome-shell/extensions/${uuid}"
      install -Dm444 extension.js         -t "$out/share/gnome-shell/extensions/${uuid}"
      install -Dm444 osk-layouts.gresource -t "$out/share/gnome-shell/extensions/${uuid}"
      runHook postInstall
    '';

    passthru.extensionUuid = uuid;
  };
in {
  environment.systemPackages = [extension];
}
