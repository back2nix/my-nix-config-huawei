{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper, # Добавлено для создания обертки
  flac,
  gnome2,
  harfbuzzFull,
  nss,
  snappy,
  xdg-utils,
  xorg,
  alsa-lib,
  atk,
  cairo,
  cups,
  curl,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libX11,
  libxcb,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libdrm,
  libnotify,
  libopus,
  libpulseaudio,
  libuuid,
  libxshmfence,
  mesa,
  nspr,
  pango,
  systemd,
  at-spi2-atk,
  at-spi2-core,
  libsForQt5,
  qt6,
  ffmpeg-full,
  libGL,
  vivaldi-ffmpeg-codecs,
  edition ? "stable",
}: let
  version =
    {
      corporate = "";
      beta = "";
      stable = "25.10.1.1173-1";
    }
    .${
      edition
    };

  hash =
    {
      corporate = "";
      beta = "";
      stable = "sha256-MewVX1C6DsnE1IQTIurZsZZCmSbt7a7gxMm0yqk3qmQ=";
    }
    .${
      edition
    };

  app =
    {
      corporate = "";
      beta = "-beta";
      stable = "";
    }
    .${
      edition
    };
in
  stdenv.mkDerivation rec {
    pname = "my-yandex-browser-${edition}";
    inherit version;

    src = fetchurl {
      url = "http://repo.yandex.ru/yandex-browser/deb/pool/main/y/yandex-browser-${edition}/yandex-browser-${edition}_${version}_amd64.deb";
      inherit hash;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      qt6.wrapQtAppsHook
      wrapGAppsHook3
      makeWrapper # Добавлено в зависимости сборки
    ];

    buildInputs = [
      flac
      harfbuzzFull
      nss
      snappy
      xdg-utils
      xorg.libxkbfile
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      curl
      dbus
      expat
      fontconfig.lib
      freetype
      gdk-pixbuf
      glib
      gnome2.GConf
      gtk3
      libX11
      libXScrnSaver
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXrandr
      libXrender
      libXtst
      libdrm
      libnotify
      libopus
      libuuid
      libxcb
      libxshmfence
      mesa
      nspr
      nss
      pango
      (lib.getLib stdenv.cc.cc)
      libsForQt5.libqtpas
      qt6.qtbase
      libGL
    ];

    unpackPhase = ''
      mkdir $TMP/ya/ $out/bin/ -p
      ar vx $src
      tar --no-overwrite-dir -xvf data.tar.xz -C $TMP/ya/
    '';

    installPhase = ''
      cp $TMP/ya/{usr/share,opt} $out/ -R
      cp $out/share/applications/yandex-browser${app}.desktop $out/share/applications/${pname}.desktop || true
      rm -f $out/share/applications/yandex-browser.desktop
      substituteInPlace $out/share/applications/${pname}.desktop --replace /usr/ $out/
      substituteInPlace $out/share/menu/yandex-browser${app}.menu --replace /opt/ $out/opt/
      substituteInPlace $out/share/gnome-control-center/default-apps/yandex-browser${app}.xml --replace /opt/ $out/opt/

      ln -sf ${vivaldi-ffmpeg-codecs}/lib/libffmpeg.so $out/opt/yandex/browser${app}/libffmpeg.so

      cat > $out/bin/${pname} <<EOF
      #!/usr/bin/env bash
      export LD_LIBRARY_PATH="${lib.getLib libGL}/lib:/run/opengl-driver/lib:\$LD_LIBRARY_PATH"
      exec $out/opt/yandex/browser${app}/yandex-browser${app} \\
        # --disable-gpu-sandbox \\
        # --flag-switches-begin \\
        # --enable-gpu-rasterization \\
        # --enable-zero-copy \\
        # --ignore-gpu-blocklist \\
        # --use-gl=angle \\
        # --use-angle=gl \\
        # --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder,Vulkan \\
        # --enable-hardware-overlays \\
        # --disable-software-rasterizer \\
        # --flag-switches-end \\
      # 2222222222222222222
        # --ozone-platform=x11 \\
        # --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer \\
        # --enable-wayland-ime \\
        # --use-gl=angle \\
        # --use-angle=gl \\
        # --enable-gpu-rasterization \\
        # --enable-zero-copy \\
        # --enable-features=ExperimentalWebMachineLearningNeuralNetwork,WebMachineLearningNeuralNetwork,VaapiVideoDecodeLinuxGL,VaapiVideoEncoder" \\
        # --force-webrtc-ip-handling-policy=default_public_interface_only \\
        # --enforce-webrtc-ip-permission-check \\
        # --remote-debugging-port=9222 \\
        --ozone-platform=wayland \\
        --enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer,Vulkan,DefaultANGLEVulkan,VulkanFromANGLE \\
        --enable-gpu-rasterization \\
        --enable-zero-copy \\
        --ignore-gpu-blocklist \\
        --use-angle=vulkan \\
        --disable-gpu-video-decode \\
        "\$@"
      EOF

      chmod +x $out/bin/${pname}

      for lib in $out/opt/yandex/browser${app}/lib*GL* $out/opt/yandex/browser${app}/lib*EGL*; do
        if [ -f "$lib" ]; then
          patchelf --set-rpath ${lib.makeLibraryPath runtimeDependencies} "$lib" || true
        fi
      done
    '';

    runtimeDependencies =
      map lib.getLib [
        libpulseaudio
        curl
        systemd
        vivaldi-ffmpeg-codecs
        ffmpeg-full
        libGL
      ]
      ++ buildInputs;

    meta = with lib; {
      description = "Yandex Web Browser";
      homepage = "https://browser.yandex.ru/";
      license = licenses.unfree;
      sourceProvenance = with sourceTypes; [binaryNativeCode];
      maintainers = with maintainers; [
        dan4ik605743
        ionutnechita
      ];
      platforms = ["x86_64-linux"];

      knownVulnerabilities = [
        ''
          Trusts a Russian government issued CA certificate for some websites.
          See https://habr.com/en/company/yandex/blog/655185/ (Russian) for details.
        ''
      ];
    };
  }
