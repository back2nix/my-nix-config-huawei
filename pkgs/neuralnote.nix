{
  lib,
  clangStdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  python3,
  makeWrapper,
  symlinkJoin,
  makeDesktopItem,
  alsa-lib,
  libjack2,
  freetype,
  fontconfig,
  curl,
  libX11,
  libXext,
  libXinerama,
  libXrandr,
  libXcursor,
  libXcomposite,
  libXrender,
  vulkan-headers,
  vulkan-loader,
  shaderc,
}: let
  version = "2.1.0";

  # muscriptor.cpp тянет ggml через FetchContent (MUSCRIPTOR_GGML_COMMIT, v0.23.0).
  ggml = fetchFromGitHub {
    owner = "ggml-org";
    repo = "ggml";
    rev = "e91ded11bdcd78c42f9c8d3978ff6686eb4c1226";
    hash = "sha256-QArqnQ5//Ft9Knm1Caqz68t4ikNQnk+O+OZUTfZlVCk=";
  };

  # Tools/fetch_soundfont.py качает это при configure; кладём заранее,
  # скрипт видит совпавший sha256 и только собирает NeuralNote_GM.sf3.
  musescoreUrl = "https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General";
  fluidUrl = "https://raw.githubusercontent.com/musescore/MuseScore/45924076871483cb96b859cc374c5fbdbf76ba53/share/sound";
  soundfontFiles = [
    (fetchurl {
      url = "${musescoreUrl}/MuseScore_General.sf3";
      sha256 = "5b85b6c2c61d10b2b91cddd41efcce7b25cd31c8271d511c73afafbef20b6fa3";
    })
    (fetchurl {
      url = "${musescoreUrl}/MuseScore_General_License.md";
      sha256 = "5ad8d737e13c7f01f5b9674872a82a92b4ba253603e8ed14b9db12293550b4b9";
    })
    (fetchurl {
      url = "${fluidUrl}/FluidR3Mono_GM.sf3";
      sha256 = "cfcd66d89e8386823400eca64934b14fbea7bf48ba1f00d21189af1262794ec2";
    })
    (fetchurl {
      url = "${fluidUrl}/FluidR3Mono_License.md";
      sha256 = "09926f9451f751408abd65162c99343f840234d2a708584808fd46427633063f";
    })
  ];

  # Модель MuScriptor large (~2.7 ГБ), ревизия и sha256 из Lib/Model/ModelManifest.h.
  # NeuralNote ищет её в ~/.config/NeuralNote/models под этим же именем.
  modelLarge = fetchurl {
    name = "muscriptor-large-f16.gguf";
    url = "https://huggingface.co/DamRsn/muscriptor-gguf/resolve/d7045f94e8b19427f4ff9542975035e66596e51c/v1/muscriptor-large-f16.gguf";
    sha256 = "35a750fb1ab1e77195cdc2c0b9b4aeea2f4d59f11f729f02af9920c4854ef72e";
  };

  # Только компиляция: пересобирается лишь при смене версии или флагов.
  unwrapped = clangStdenv.mkDerivation {
    pname = "neuralnote-unwrapped";
    inherit version;

    src = fetchFromGitHub {
      owner = "DamRsn";
      repo = "NeuralNote";
      rev = "v${version}";
      fetchSubmodules = true;
      hash = "sha256-5r+MxLof+hKZf+koMJG+qdOBdHsv8AI0l/+WJTTISVM=";
    };

    nativeBuildInputs = [cmake ninja pkg-config python3 shaderc];

    buildInputs = [
      alsa-lib
      libjack2
      freetype
      fontconfig
      curl
      libX11
      libXext
      libXinerama
      libXrandr
      libXcursor
      libXcomposite
      vulkan-headers
      vulkan-loader
    ];

    postPatch = ''
      mkdir -p NeuralNote/Assets/SoundFont
      ${lib.concatMapStrings (f: ''
          cp ${f} NeuralNote/Assets/SoundFont/${lib.removePrefix "${builtins.dirOf f.url}/" f.url}
        '')
        soundfontFiles}
    '';

    cmakeFlags = [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
      "-DMUSCRIPTOR_VULKAN=ON"
      "-DNEURALNOTE_SYMBOLS=OFF"
      # LTO у clang даёт bitcode в .a, ld.bfd его не линкует.
      "-DLTO=OFF"
    ];

    # FetchContent копирует ggml из store, он read-only.
    preConfigure = ''
      cp -r --no-preserve=mode ${ggml} ggml-src
      appendToVar cmakeFlags "-DFETCHCONTENT_SOURCE_DIR_GGML=$PWD/ggml-src"
    '';

    installPhase = ''
      runHook preInstall
      art=NeuralNote_artefacts/Release
      install -Dm755 $art/Standalone/NeuralNote $out/bin/NeuralNote
      mkdir -p $out/lib/vst3
      cp -r $art/VST3/NeuralNote.vst3 $out/lib/vst3/
      install -Dm644 ../NeuralNote/Assets/Logo/neuralnote-1024.png \
        $out/share/icons/hicolor/1024x1024/apps/neuralnote.png
      runHook postInstall
    '';

    meta.platforms = ["x86_64-linux"];
  };

  desktopItem = makeDesktopItem {
    name = "neuralnote";
    desktopName = "NeuralNote";
    exec = "NeuralNote";
    icon = "neuralnote";
    comment = "Audio to MIDI transcription";
    categories = ["Audio" "AudioVideo"];
  };
in
  # Тонкая обёртка: правки здесь не пересобирают unwrapped.
  symlinkJoin {
    name = "neuralnote-${version}";
    paths = [unwrapped desktopItem];
    nativeBuildInputs = [makeWrapper];

    # JUCE грузит X11-библиотеки и libcurl, а ggml — libvulkan через dlopen;
    # без X11 окно молча не создаётся.
    postBuild = ''
      wrapProgram $out/bin/NeuralNote \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
        vulkan-loader
        curl
        libX11
        libXext
        libXinerama
        libXrandr
        libXcursor
        libXcomposite
        libXrender
      ]}
    '';

    passthru = {inherit unwrapped modelLarge;};

    meta = {
      description = "Audio to MIDI transcription plugin (MuScriptor)";
      homepage = "https://github.com/DamRsn/NeuralNote";
      license = lib.licenses.asl20;
      platforms = ["x86_64-linux"];
      mainProgram = "NeuralNote";
    };
  }
