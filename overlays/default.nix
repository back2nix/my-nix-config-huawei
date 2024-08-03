# ./overlays/default.nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  nixpkgs.overlays = [
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
    })

    # Overlay 3: Define overlays in other files
    # The content of ./overlays/overlay3/default.nix is the same as above:
    # `(final: prev: { xxx = prev.xxx.override { ... }; })`
    # (import ./overlay3)
  ];
}
