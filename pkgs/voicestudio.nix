{
  lib,
  appimageTools,
  fetchurl,
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
