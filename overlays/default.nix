# ./overlays/default.nix
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  nixpkgs.overlays = [
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
       # Claude Desktop с поддержкой прокси
      claude-desktop-proxy = prev.writeShellScriptBin "claude-desktop" ''
        export HTTP_PROXY="http://127.0.0.1:1083"
        export HTTPS_PROXY="http://127.0.0.1:1083"
        export NO_PROXY="localhost,127.0.0.1,::1"

        exec ${prev.electron}/bin/electron \
          ${inputs.claude-desktop.packages.${prev.system}.claude-desktop}/lib/claude-desktop/app.asar \
          --proxy-server=http://127.0.0.1:1083 \
          --proxy-bypass-list="localhost;127.0.0.1;::1" \
          --disable-web-security \
          --ignore-certificate-errors \
          "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
          "$@"
      '';
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
      #   vendorSha256 = lib.fakeSha256;
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
