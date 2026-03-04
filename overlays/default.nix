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
        inherit (prev) system;
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

      gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [ ./gnome-shell.patch ];
      });
      # --- КОНЕЦ: Патч для gnome-screenshot ---

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

# --- НАЧАЛО: Обновление claude-code до 2.1.63 ---
      claude-code = final.unstable.claude-code.overrideAttrs (oldAttrs: rec {
        version = "2.1.63";
        src = final.fetchzip {
          url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
          hash = "sha256-tVk1GXqh9Ice8ZbbLnmN4sSlIY41KsrqWi2eDo47/zI=";
        };
        npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      });
# --- КОНЕЦ: Обновление claude-code ---

# --- НАЧАЛО: Обновление gemini-cli до 0.33.0 ---
      gemini-cli = final.unstable.gemini-cli.overrideAttrs (oldAttrs: rec {
        version = "0.33.0-nightly.20260228.1ca5c05d0";

        src = prev.fetchFromGitHub {
          owner = "google-gemini";
          repo = "gemini-cli";
          tag = "v${version}";
          hash = "sha256-IAHMY1GMB8dzAJ1ucQR/yQqJ66YiXPZAWkQcZnS/vsI=";
        };

        npmDeps = prev.fetchNpmDeps {
          inherit (oldAttrs) pname;
          inherit version src;
          hash = "sha256-vds0HVlicI28l/SltFFshXEF8wRd3CiW2vRw2h5EsV4=";
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
      # --- КОНЕЦ: Обновление gemini-cli ---

      gemini-proxy = prev.writeShellScriptBin "gemini" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        # Изменено: используем наш переопределенный final.gemini-cli
        # вместо final.unstable.gemini-cli
        exec ${final.gemini-cli}/bin/gemini "$@"
      '';

      gemini-vpn2 = prev.writeShellScriptBin "gemini-vpn2" ''
        export HTTP_PROXY="http://127.0.0.1:1085"
        export HTTPS_PROXY="http://127.0.0.1:1085"
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

      claude-code-vpn2 = prev.writeShellScriptBin "claude-code-vpn2" ''
        export HTTP_PROXY="http://127.0.0.1:1085"
        export HTTPS_PROXY="http://127.0.0.1:1085"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.claude-code}/bin/claude "$@"
      '';

      claude-code-vpn3 = prev.writeShellScriptBin "claude-code-vpn3" ''
        export HTTP_PROXY="http://127.0.0.1:1087"
        export HTTPS_PROXY="http://127.0.0.1:1087"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${final.claude-code}/bin/claude "$@"
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
