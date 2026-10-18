{
  lib,
  appimageTools,
  fetchurl,
  # Порт HTTP-входа sing-box (группа voicestudio в module/proxy-routes-data.nix).
  # null — без прокси.
  proxyPort ? null,
}: let
  pname = "voicestudio";
  version = "0.5.6";

  src = fetchurl {
    url = "https://github.com/debpalash/VoiceStudio/releases/download/v${version}/VoiceStudio-Electron-${version}-linux-x64.AppImage";
    hash = "sha256-tE0oaqhiplg3SEZZn5aSo6Hr5W8T5L/KbZSIWqsoqQ8=";
  };

  appimageContents = appimageTools.extract {inherit pname version src;};
in
  # FHS-обёртка: встроенный uv при первом запуске сам качает Python и колёса
  # (torch и т.п.), им нужны обычные /lib-библиотеки.
  appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = pkgs:
      with pkgs; [
        ffmpeg
        libsndfile
        portaudio
        alsa-lib
        libpulseaudio
        zlib
        stdenv.cc.cc.lib
        espeak-ng
        sox
      ];

    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/.${pname}-unwrapped
      cat > $out/bin/${pname} <<EOF
      #!/bin/sh
      # При каждом старте приложение копирует backend/omnivoice из /nix/store
      # в runtime/project и удаляет прошлую копию; копии наследуют r-x из
      # store, и rm падает с EACCES. Возвращаем права на запись.
      chmod -R u+w "\''${XDG_CONFIG_HOME:-\$HOME/.config}/VoiceStudio/runtime/project" 2>/dev/null
    ''
    + lib.optionalString (proxyPort != null) ''
      # Electron берёт прокси из флага, Python-бэкенд (uv, huggingface) — из env.
      export HTTP_PROXY=http://127.0.0.1:${toString proxyPort}
      export HTTPS_PROXY=\$HTTP_PROXY http_proxy=\$HTTP_PROXY https_proxy=\$HTTP_PROXY
      export NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1
      set -- --proxy-server=\$HTTP_PROXY "\$@"
    ''
    + ''
      exec $out/bin/.${pname}-unwrapped "\$@"
      EOF
      chmod +x $out/bin/${pname}

      install -Dm644 ${appimageContents}/VoiceStudio.desktop \
        $out/share/applications/voicestudio.desktop
      substituteInPlace $out/share/applications/voicestudio.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      install -Dm644 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/voicestudio-electron.png \
        $out/share/icons/hicolor/512x512/apps/voicestudio-electron.png
    '';

    meta = {
      description = "Local ElevenLabs alternative: voice cloning, dubbing, transcription";
      homepage = "https://github.com/debpalash/VoiceStudio";
      license = lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
