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
  dbus,
  zenity,
}:
let
  src = fetchFromGitHub {
    owner = "storytold";
    repo = "pdfcraft";
    rev = "v0.21.1";
    hash = "sha256-2X2ixtr7mxHRpfhcGghKUO7ib0SFBruBmQPIlTFZ8Ds=";
  };
in
rustPlatform.buildRustPackage {
  pname = "pdfcraft";
  version = "0.21.1";
  inherit src;

  # Lets nix fetch the git dependencies (craft-libs, egui and winit forks) itself,
  # so no per-crate outputHashes table has to be maintained.
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };
  # The [patch.crates-io] block lists egui test/demo crates that the pinned fork rev does not
  # contain; cargo refuses to resolve the workspace with them, and nothing here uses them.
  postPatch = ''
    sed -i -E '/^(egui_demo_lib|egui_kittest|egui_inspection|egui_system_font_provider) = /d' Cargo.toml
  '';

  cargoBuildFlags = ["-p" "pdfcraft" "-p" "pdfcraft-cli"];
  # Upstream's integration tests need graphical sessions and external fixtures.
  doCheck = false;

  nativeBuildInputs = [pkg-config makeWrapper];
  buildInputs = [wayland libxkbcommon];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.pdfcraft.desktop \
      $out/share/applications/ai.storyteller.pdfcraft.desktop
    install -Dm644 packaging/linux/ai.storyteller.pdfcraft.mime.xml \
      $out/share/mime/packages/ai.storyteller.pdfcraft.xml
    mkdir -p $out/share/icons
    cp -r assets/app-icon/hicolor $out/share/icons/

    # dbus: rfd's xdg-desktop-portal file dialogs dlopen libdbus-1.so.
    # zenity: fallback file picker used when no portal is running.
    wrapProgram $out/bin/pdfcraft \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
      wayland
      libxkbcommon
      libX11
      libXcursor
      libXi
      libXrandr
      libGL
      vulkan-loader
      dbus
    ]} \
      --prefix PATH : ${lib.makeBinPath [zenity]}
  '';

  meta = {
    description = "PdfCraft: PDF viewer and editor (storytold)";
    homepage = "https://github.com/storytold/pdfcraft";
    license = with lib.licenses; [mit asl20];
    platforms = lib.platforms.linux;
    mainProgram = "pdfcraft";
  };
}
