{
  lib,
  appimageTools,
  fetchurl,
  runCommand,
  asar,
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

  # stageRuntimeSources копирует backend/omnivoice из /nix/store через fs.cp,
  # копии наследуют r-x, и следующий rm (в том числе сразу после установки)
  # падает с EACCES. Перед каждым шагом возвращаем права на запись всему project.
  patched = runCommand "${pname}-${version}-patched" {nativeBuildInputs = [asar];} ''
    cp -r --no-preserve=mode ${appimageContents} $out
    chmod +x $out/AppRun $out/voicestudio-electron $out/chrome_crashpad_handler \
      $out/resources/tools/* $out/resources/native/voicestudio-desktop-bridge
    asar extract ${appimageContents}/resources/app.asar app
    chmodTree='process.getBuiltinModule("node:child_process").spawnSync("chmod", ["-R", "u+w", project]);'
    substituteInPlace app/out/main/index.js \
      --replace-fail '	for (const name of SOURCES) {' "	for (const name of SOURCES) { $chmodTree"
    # create_voice_clone_prompt, в отличие от generate, не под inference_mode,
    # а бэкенд вызывает его отдельно (предрасчёт промпта). Кодирование
    # референса с autograd съедает >5 ГБ и на 8 ГБ GPU падает с CUDA OOM.
    substituteInPlace $out/resources/omnivoice/models/omnivoice.py \
      --replace-fail '    def create_voice_clone_prompt(' '    @torch.inference_mode()
        def create_voice_clone_prompt('
    rm $out/resources/app.asar
    asar pack app $out/resources/app.asar
  '';
in
  # FHS-обёртка: встроенный uv при первом запуске сам качает Python и колёса
  # (torch и т.п.), им нужны обычные /lib-библиотеки.
  appimageTools.wrapAppImage {
    inherit pname version;
    src = patched;

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
      # Режим auto освобождает VRAM перед генерацией только при нехватке RAM,
      # на 8 ГБ GPU (RTX 2060 SUPER) Whisper/NLLB остаются в памяти рядом с TTS
      # и генерация падает с CUDA OOM.
      export OMNIVOICE_FREE_VRAM_BEFORE_GENERATE=always
      export OMNIVOICE_UNLOAD_NLLB=1
      export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
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

      install -Dm644 ${patched}/VoiceStudio.desktop \
        $out/share/applications/voicestudio.desktop
      substituteInPlace $out/share/applications/voicestudio.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      install -Dm644 ${patched}/usr/share/icons/hicolor/512x512/apps/voicestudio-electron.png \
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
