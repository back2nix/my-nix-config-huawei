{
  stdenv,
  lib,
  appimageTools,
}: let
  pname = "dolphin-anty";
  version = "latest";

  # Используем локальный файл вместо fetchurl
  src = ./dolphin-anty-linux-x86_64-latest.AppImage;

  appimageContents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      mv $out/bin/${pname}-${version} $out/bin/${pname}

      # Попробуем найти desktop файл и иконку
      if [ -f ${appimageContents}/*.desktop ]; then
        install -m 444 -D ${appimageContents}/*.desktop $out/share/applications/dolphin-anty.desktop
        substituteInPlace $out/share/applications/dolphin-anty.desktop \
          --replace 'Exec=AppRun' 'Exec=${pname}' || true
      fi

      # Поищем иконку
      find ${appimageContents} -name "*.png" -o -name "*.svg" | head -1 | while read icon; do
        if [ -f "$icon" ]; then
          install -m 444 -D "$icon" $out/share/pixmaps/dolphin-anty.png
        fi
      done
    '';

    meta = with lib; {
      description = "Dolphin Anty browser for managing multiple accounts";
      homepage = "https://dolphin-anty.com/";
      license = licenses.unfree;
      maintainers = [];
      platforms = ["x86_64-linux"];
    };
  }
