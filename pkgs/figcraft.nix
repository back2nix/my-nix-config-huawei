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
    repo = "figcraft";
    rev = "e65ce42000ea2bd3c31d14f6c7e47d14bc6ab164";
    hash = "sha256-ud057Db5jQQynAQmOad37/OU1LjEBuOIz475TGub4T4=";
  };
in
rustPlatform.buildRustPackage {
  pname = "figcraft";
  version = "0.14.0-unstable-2026-11-02";
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

  cargoBuildFlags = ["-p" "figcraft" "-p" "figcraft-cli"];
  # Upstream's integration tests need graphical sessions and external fixtures.
  doCheck = false;

  nativeBuildInputs = [pkg-config makeWrapper];
  buildInputs = [wayland libxkbcommon];

  postInstall = ''
    install -Dm644 packaging/linux/ai.storyteller.figcraft.desktop \
      $out/share/applications/ai.storyteller.figcraft.desktop
    install -Dm644 packaging/linux/ai.storyteller.figcraft.mime.xml \
      $out/share/mime/packages/ai.storyteller.figcraft.xml
    mkdir -p $out/share/icons
    cp -r assets/app-icon/hicolor $out/share/icons/

    # dbus: rfd's xdg-desktop-portal file dialogs dlopen libdbus-1.so.
    # zenity: fallback file picker used when no portal is running.
    wrapProgram $out/bin/figcraft \
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
    description = "FigCraft: design and vector graphics editor (storytold)";
    homepage = "https://github.com/storytold/figcraft";
    license = with lib.licenses; [mit asl20];
    platforms = lib.platforms.linux;
    mainProgram = "figcraft";
  };
}
