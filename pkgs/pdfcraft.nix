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

  # fetchCargoVendor (not importCargoLock): Cargo.lock has two git revs of winprint 0.2.1,
  # which importCargoLock cannot vendor side by side.
  cargoHash = "sha256-sjnRF9WVDRPrgEgwZEyVIEk3qq3Erkv9cBtlkgb52lc=";

  # The [patch.crates-io] block lists egui demo crates that the pinned fork rev does not
  # contain; cargo refuses to resolve the workspace with them, and nothing here uses them.
  # Only that section is touched: [workspace.dependencies] still needs egui_kittest.
  postPatch = ''
    sed -i -E '/^\[patch\.crates-io\]/,/^\[/{/^(egui_demo_lib|egui_inspection|egui_system_font_provider) = /d}' Cargo.toml

    # nixpkgs rustc 1.95 is linked against LLVM 21, but its stdarch already declares
    # llvm.x86.avx512.vpdpbusd.512 with the LLVM 22 (<64 x i8>) signature, so any use of
    # _mm512_dpbusd_epi32 fails to codegen. Emit the instruction via inline asm instead.
    substituteInPlace "$cargoDepsCopy"/source-registry-0/rten-gemm-0.26.0/src/i8dot.rs \
      --replace-fail '_mm512_dpbusd_epi32(acc.0, a.0, b.0).into()' \
        'let mut r = acc.0; std::arch::asm!("vpdpbusd {r}, {a}, {b}", r = inout(zmm_reg) r, a = in(zmm_reg) a.0, b = in(zmm_reg) b.0, options(pure, nomem, nostack)); r.into()'
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
