{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  wayland,
  libxkbcommon,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libGL,
  vulkan-loader,
}:
rustPlatform.buildRustPackage {
  pname = "photocraft";
  version = "0.5.0-unstable-2026-10-09";

  src = fetchFromGitHub {
    owner = "storytold";
    repo = "photocraft";
    rev = "d836e3458d77c316b48604fb54525b1dc9217408";
    hash = "sha256-hmWe/DcEWglcPvWQ7DDFmNs8jqYuslUpbL710zfCbsY=";
  };

  cargoHash = "sha256-C2O1378ePNTBxh6Ma+C0tDEeD1riMaYA8nUPXPWDS0Q=";
  cargoBuildFlags = ["-p" "photocraft" "-p" "photocraft-cli"];
  buildFeatures = ["heif"];
  # Upstream's integration tests need graphical sessions and external fixtures.
  doCheck = false;

  nativeBuildInputs = [pkg-config makeWrapper];
  buildInputs = [wayland libxkbcommon];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.photocraft.desktop \
      $out/share/applications/ai.storyteller.photocraft.desktop
    install -Dm644 packaging/linux/ai.storyteller.photocraft.mime.xml \
      $out/share/mime/packages/ai.storyteller.photocraft.xml
    mkdir -p $out/share/icons
    cp -r assets/app-icon/hicolor $out/share/icons/

    wrapProgram $out/bin/photocraft \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
      wayland
      libxkbcommon
      libX11
      libXcursor
      libXi
      libXrandr
      libGL
      vulkan-loader
    ]}
  '';

  meta = {
    description = "Native image editor with layers and PSD support";
    homepage = "https://github.com/storytold/photocraft";
    license = with lib.licenses; [mit asl20];
    platforms = lib.platforms.linux;
    mainProgram = "photocraft";
  };
}
