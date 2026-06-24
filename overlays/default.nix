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
      # mutter = prev.mutter.overrideAttrs (oldAttrs: {
      #   # Указываем на исправленные исходники
      #   # version = "48.3.1-my";
      #   src = inputs.mutter-src;
      #
      #   # Добавляем патч, который копирует недостающий gvdb subproject
      #   postPatch = (oldAttrs.postPatch or "") + ''
      #     echo "Unpacking glib source to a temporary directory to get gvdb subproject..."
      #     # 1. Создаем временную папку
      #     local glib_unpacked_src=$(mktemp -d)
      #     # 2. Распаковываем архив glib в эту папку
      #     tar xf ${final.glib.src} -C $glib_unpacked_src --strip-components=1
      #     # 3. Копируем нужную под-папку из распакованных исходников
      #     cp -r $glib_unpacked_src/subprojects/gvdb subprojects/
      #     # 4. Прибираемся за собой
      #     rm -rf $glib_unpacked_src
      #     echo "Successfully copied gvdb subproject."
      #   '';
      # });

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

# --- НАЧАЛО: Обновление claude-code до 2.1.187 ---
      claude-code = prev.stdenvNoCC.mkDerivation {
        pname = "claude-code";
        version = "2.1.187";
        src = prev.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/2.1.187/linux-x64/claude";
          sha256 = "sha256-uwL8szYm+MWZ0Q2L7jhYXUz41CJcO0l4ad7nRU5782E=";
        };
        dontUnpack = true;
        dontBuild = true;
        dontStrip = true;
        nativeBuildInputs = [ prev.autoPatchelfHook prev.makeBinaryWrapper ];
        buildInputs = [ prev.alsa-lib ];
        installPhase = ''
          runHook preInstall
          install -Dm755 $src $out/bin/claude
          wrapProgram $out/bin/claude \
            --set DISABLE_AUTOUPDATER 1 \
            --set DISABLE_INSTALLATION_CHECKS 1 \
            --set USE_BUILTIN_RIPGREP 0 \
            --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.alsa-lib ]} \
            --prefix PATH : ${prev.lib.makeBinPath [ prev.procps prev.ripgrep prev.bubblewrap prev.socat ]}
          runHook postInstall
        '';
        meta.mainProgram = "claude";
      };
# --- КОНЕЦ: Обновление claude-code до 2.1.187 ---

# --- НАЧАЛО: Обновление gemini-cli до 0.44.0-nightly.20260518.g5611ff40e ---
      gemini-cli = final.unstable.gemini-cli.overrideAttrs (oldAttrs: rec {
        version = "0.44.0-nightly.20260518.g5611ff40e";

        src = prev.fetchFromGitHub {
          owner = "google-gemini";
          repo = "gemini-cli";
          tag = "v${version}";
          hash = "sha256-MSdQ55IYvzhk5OSSV2J5FygzH+op7BII1WmAW4b7OGQ=";
        };

        npmDeps = prev.fetchNpmDeps {
          inherit (oldAttrs) pname;
          inherit version src;
          hash = "sha256-jPffaU3Cm9AlzJ02XBU56m5eVoGcbu9QWfgz4QVdm9A=";
        };

        # ИЗМЕНЕНИЕ ЗДЕСЬ: Мы убрали `(oldAttrs.postPatch or "") +`,
        # чтобы старые правила из nixpkgs не отключали сборку devtools!
        postPatch = ''
          find . -name "package.json" -not -path "*/node_modules/*" | while read -r pkg; do
            pkg_name=$(${prev.jq}/bin/jq -r '.name // empty' "$pkg")
            if [[ "$pkg_name" == *"vscode-ide-companion"* ]] || [[ "$pkg_name" == *"test-utils"* ]]; then
              echo "Disabling build for $pkg_name..."
              ${prev.jq}/bin/jq '.scripts.build = "echo skip"' "$pkg" > "$pkg.tmp" && mv "$pkg.tmp" "$pkg"
            fi
          done

          # Патчим корневой build.js — заменяем параллельный --workspaces на последовательную сборку
          sed -i 's|execSync.*npm run build --workspaces.*|execSync("npm run build --workspace=packages/sdk --workspace=packages/devtools --workspace=packages/core --workspace=packages/cli", { stdio: "inherit", cwd: root });|' scripts/build.js
        '';

        postInstall = (oldAttrs.postInstall or "") + ''
          # Копируем новые пакеты, появившиеся в версии 0.30.0, чтобы не было битых симлинков
          rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk || true
          cp -r packages/sdk $out/share/gemini-cli/node_modules/@google/gemini-cli-sdk || true

          rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-devtools || true
          cp -r packages/devtools $out/share/gemini-cli/node_modules/@google/gemini-cli-devtools || true
        '';
      });
      # --- КОНЕЦ: Обновление gemini-cli до 0.44.0-nightly.20260518.g5611ff40e ---

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

      rtk = final.callPackage ../pkgs/rtk.nix { };


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
