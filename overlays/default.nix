# ./overlays/default.nix
{
  config,
  inputs,
  libadwaita,
  pkgs,
  lib,
  pkgs-unstable,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (prev.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    })

    # (import ./yandex-browser-updates.nix) # Путь относительно configuration.nix
    # Overlay 1: Use `self` and `super` to express
    # the inheritance relationship
    (self: super: {
      # google-chrome = super.google-chrome.override {
      #   commandLineArgs =
      #     "--proxy-server='https=127.0.0.1:3128;http=127.0.0.1:3128'";
      # };
    })

    # Overlay 2: Use `final` and `prev` to express
    # the relationship between the new and the old
    (final: prev: {
      # --- НАЧАЛО: Патч для gnome-screenshot ---
      # gnome-screenshot = prev.gnome-screenshot.overrideAttrs (oldAttrs: {
      #   patches = (oldAttrs.patches or []) ++ [ ./gnome-screenshot-no-flash.patch ];
      # });

      # gnome-shell — стандартный из nixpkgs.
      # Кастомный патч ./gnome-shell.patch не накладывается на gnome-shell 50.1
      # (изменился screenshot.js / shell-screenshot.c). Чтобы вернуть — обнови
      # патч под новую версию и раскомментируй блок:
      # gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
      #   patches = (oldAttrs.patches or []) ++ [ ./gnome-shell.patch ];
      # });
      # --- КОНЕЦ: Патч для gnome-screenshot ---

      # mutter — используем стандартный из nixpkgs.
      # Чтобы вернуть кастомную сборку (mutter-src + gvdb subproject из glib),
      # раскомментируй блок ниже:

      mutter = prev.mutter.overrideAttrs (oldAttrs: {
        # Указываем на исправленные исходники
        # version = "48.3.1-my";
        src = inputs.mutter-src;

        # Добавляем патч, который копирует недостающий gvdb subproject
        postPatch = (oldAttrs.postPatch or "") + ''
          echo "Unpacking glib source to a temporary directory to get gvdb subproject..."
          # 1. Создаем временную папку
          local glib_unpacked_src=$(mktemp -d)
          # 2. Распаковываем архив glib в эту папку
          tar xf ${final.glib.src} -C $glib_unpacked_src --strip-components=1
          # 3. Копируем нужную под-папку из распакованных исходников
          cp -r $glib_unpacked_src/subprojects/gvdb subprojects/
          # 4. Прибираемся за собой
          rm -rf $glib_unpacked_src
          echo "Successfully copied gvdb subproject."
        '';
      });

      # claude-code-proxy = prev.writeShellScriptBin "claude" ''
      # export HTTP_PROXY="http://127.0.0.1:1083"
      # export HTTPS_PROXY="http://127.0.0.1:1083"
      # export NO_PROXY="localhost,127.0.0.1,::1"

      # exec ${prev.claude-code}/bin/claude "$@"
      # '';
      # # Claude Desktop с поддержкой прокси
      # claude-desktop-proxy = prev.writeShellScriptBin "claude-desktop" ''
      #   export HTTP_PROXY="http://127.0.0.1:1083"
      #   export HTTPS_PROXY="http://127.0.0.1:1083"
      #   export NO_PROXY="localhost,127.0.0.1,::1"

      #   exec ${prev.electron}/bin/electron \
      #     ${inputs.claude-desktop.packages.${prev.system}.claude-desktop}/lib/claude-desktop/app.asar \
      #     --proxy-server=http://127.0.0.1:1083 \
      #     --proxy-bypass-list="localhost;127.0.0.1;::1" \
      #     --disable-web-security \
      #     --flag-switches-begin \
      #     --enable-gpu-rasterization \
      #     --enable-webgpu-developer-features \
      #     --enable-zero-copy \
      #     --ignore-gpu-blocklist \
      #     --enable-features=ExperimentalWebMachineLearningNeuralNetwork,SkiaGraphite,SyncPointGraphValidation,Vulkan,WebMachineLearningNeuralNetwork,ZeroCopyRBPPartialRasterWithGpuCompositor \
      #     --flag-switches-end \
      #     --ignore-certificate-errors \
      #     "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      #     "$@"
      # '';

      # --- НАЧАЛО: Обновление claude-code до 2.1.202 ---
      claude-code = prev.stdenvNoCC.mkDerivation {
        pname = "claude-code";
        version = "2.1.202";
        src = prev.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.202/linux-x64/claude";
          sha256 = "71590202249892db3805ecd5b867f831f04b8129eaabd3f9a5bd4ba16b52c839";
        };
        dontUnpack = true;
        dontBuild = true;
        dontStrip = true;
        nativeBuildInputs = [prev.autoPatchelfHook prev.makeBinaryWrapper];
        buildInputs = [prev.alsa-lib];
        installPhase = ''
          runHook preInstall
          install -Dm755 $src $out/bin/claude
          wrapProgram $out/bin/claude \
            --set DISABLE_AUTOUPDATER 1 \
            --set DISABLE_INSTALLATION_CHECKS 1 \
            --set USE_BUILTIN_RIPGREP 0 \
            --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [prev.alsa-lib]} \
            --prefix PATH : ${prev.lib.makeBinPath [prev.procps prev.ripgrep prev.bubblewrap prev.socat]}
          runHook postInstall
        '';
        meta.mainProgram = "claude";
      };
      # --- КОНЕЦ: Обновление claude-code до 2.1.202 ---

      # --- НАЧАЛО: Обновление gemini-cli до 0.49.0 ---
      # База — свежая деривация из unstable (0.47.0). Начиная с ~0.45 nixpkgs
      # перешёл на сборку через `npmBuildScript = "bundle"` (esbuild) с новым
      # installPhase, поэтому старые postPatch/postInstall (правка scripts/build.js,
      # ручное копирование packages/sdk и packages/devtools) больше не нужны и
      # только ломали бы сборку. Override теперь минимальный: version + src +
      # npmDeps. Всё остальное (postPatch, installPhase) наследуется из nixpkgs.
      #
      # ВНИМАНИЕ: npmDeps считается внутри buildNpmPackage по локальным аргументам,
      # а не по finalAttrs, поэтому overrideAttrs его НЕ пересчитывает — переопределяем
      # вручную под новый src (иначе тянулись бы зависимости базовой версии).
      #
      # Целимся в последний СТАБИЛЬНЫЙ релиз 0.49.0. Последний nightly (0.51.x на
      # 2026-07-07) не собирается: его package-lock.json ссылается на tar@7.5.8,
      # который npm не может разрешить из offline-кэша даже с fetcher v2 и
      # --legacy-peer-deps (битый lockfile самого nightly).
      #
      # Начиная с 0.48 workspace vscode-ide-companion тянет транзитивный `tar`,
      # который fetcher v1 не кладёт в offline-кэш (ENOTCACHED). Нужен fetcher v2.
      # npmDepsFetcherVersion — локальный аргумент buildNpmPackage, overrideAttrs его
      # не видит; напрямую правим env.NIX_NPM_FETCHER_VERSION (база на structured-attrs).
      gemini-cli = final.unstable.gemini-cli.overrideAttrs (oldAttrs: rec {
        version = "0.49.0";

        src = prev.fetchFromGitHub {
          owner = "google-gemini";
          repo = "gemini-cli";
          tag = "v${version}";
          hash = "sha256-C47U5nTWB0Dq2iPRujRHMDjyyrU0d6xZ3Uv7URcIcg8=";
        };

        env = (oldAttrs.env or {}) // {NIX_NPM_FETCHER_VERSION = 2;};
        npmDeps = final.unstable.fetchNpmDeps {
          inherit (oldAttrs) pname;
          inherit version src;
          fetcherVersion = 2;
          hash = "sha256-e3gPyBJg2TPGywpR7iqpDtcRdq6AWlvY725kIGPJmCo=";
        };

        # Апстрим 0.49.0 рассинхронизирован: в package.json ряда workspace'ов
        # точечно пришпилены версии, отличные от резолва в package-lock.json
        # (tar 7.5.8 vs 7.5.11, clipboardy 5.2.0 vs 5.2.1). npm видит рассинхрон
        # и лезет за отсутствующими версиями мимо offline-кэша (ETARGET).
        # Приводим package.json к версиям из lockfile. Сам lockfile не трогаем,
        # поэтому npmDeps.hash не меняется. Список найден сравнением exact-пинов
        # package.json с резолвом в package-lock.json — при апдейте перепроверить.
        postPatch =
          (oldAttrs.postPatch or "")
          + ''
            substituteInPlace packages/a2a-server/package.json packages/cli/package.json \
              --replace-quiet '"tar": "7.5.8"' '"tar": "7.5.11"'
            substituteInPlace packages/cli/package.json \
              --replace-quiet '"clipboardy": "5.2.0"' '"clipboardy": "5.2.1"'
          '';
      });
      # --- КОНЕЦ: Обновление gemini-cli до 0.49.0 ---

      gemini-proxy = prev.writeShellScriptBin "gemini" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        # Изменено: используем наш переопределенный final.gemini-cli
        # вместо final.unstable.gemini-cli
        exec ${final.gemini-cli}/bin/gemini "$@"
      '';

      gemini-china = prev.writeShellScriptBin "gemini-china" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.gemini-cli}/bin/gemini "$@"
      '';

      gemini-vpn3 = prev.writeShellScriptBin "gemini-vpn3" ''
        export HTTP_PROXY="http://127.0.0.1:1087"
        export HTTPS_PROXY="http://127.0.0.1:1087"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.gemini-cli}/bin/gemini "$@"
      '';

      claude-code-proxy = prev.writeShellScriptBin "claude-code" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.claude-code}/bin/claude "$@"
      '';

      claude-code-china = prev.writeShellScriptBin "claude-code-china" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.claude-code}/bin/claude "$@"
      '';

      claude-code-vpn3 = prev.writeShellScriptBin "claude-code-vpn3" ''
        export HTTP_PROXY="http://127.0.0.1:1087"
        export HTTPS_PROXY="http://127.0.0.1:1087"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.claude-code}/bin/claude "$@"
      '';

      gcloud-proxy = prev.writeShellScriptBin "gcloud" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${prev.google-cloud-sdk}/bin/gcloud "$@"
      '';

      gcloud-vpn2 = prev.writeShellScriptBin "gcloud-vpn2" ''
        export HTTP_PROXY="http://127.0.0.1:1085"
        export HTTPS_PROXY="http://127.0.0.1:1085"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${prev.google-cloud-sdk}/bin/gcloud "$@"
      '';

      gcloud-vpn3 = prev.writeShellScriptBin "gcloud-vpn3" ''
        export HTTP_PROXY="http://127.0.0.1:1087"
        export HTTPS_PROXY="http://127.0.0.1:1087"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${prev.google-cloud-sdk}/bin/gcloud "$@"
      '';

      rtk = final.callPackage ../pkgs/rtk.nix {};

      # kilocode-cli-proxy = prev.writeShellScriptBin "kilocode-cli" ''
      #   export HTTP_PROXY="http://127.0.0.1:1083"
      #   export HTTPS_PROXY="http://127.0.0.1:1083"
      #   export NO_PROXY="localhost,127.0.0.1,::1"

      #   exec ${final.unstable.kilocode-cli}/bin/claude "$@"
      # '';

      # steam = prev.steam.override {
      #   extraPkgs = pkgs: with pkgs; [
      #     keyutils
      #     libkrb5
      #     libpng
      #     libpulseaudio
      #     libvorbis
      #     stdenv.cc.cc.lib
      #     xorg.libXcursor
      #     xorg.libXi
      #     xorg.libXinerama
      #     xorg.libXScrnSaver
      #   ];
      #   extraProfile = "export GDK_SCALE=2";
      # };
      bashdbInteractive = final.bashdb.overrideAttrs {
        buildInputs = (prev.buildInputs or []) ++ [final.bashInteractive];
      };
      # xray = prev.xray.overrideAttrs (oldAttrs: rec {
      #   version = "1.8.23";
      #   src = prev.fetchFromGitHub {
      #     owner = "XTLS";
      #     repo = "Xray-core";
      #     rev = "v${version}";
      #     sha256 = "sha256-DnGwxJTfBNeVwAQhWIdRU1w6kMHJ0Vs3vEvwlFe59i8=";
      #   };
      #   vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      #   proxyVendor = true;
      #   vendorSha26 = lib.fakeSha256;
      # });
      # yandex-browser-stable = prev.yandex-browser-stable.overrideAttrs (oldAttrs: {
      #   version = "25.2.6.724-1";
      #   src = prev.fetchurl {
      #     url = "http://repo.yandex.ru/yandex-browser/deb/pool/main/y/yandex-browser-stable/yandex-browser-stable_25.2.6.724-1_amd64.deb";
      #     hash = "";
      #   };
      # });
    })

    # Overlay 3: Define overlays in other files
    # The content of ./overlays/overlay3/default.nix is the same as above:
    # `(final: prev: { xxx = prev.xxx.override { ... }; })`
    # (import ./overlay3)
  ];
}
