{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  wayland,
  libxkbcommon,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  libGL,
  vulkan-loader,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "effectcraft";
  version = "0.6.0";

  src = fetchurl {
    url = "https://github.com/storytold/effectcraft/releases/download/v${finalAttrs.version}/effectcraft-${finalAttrs.version}-linux-x86_64.deb";
    hash = "sha256-GKOPDZb/cWEipD+r6Xui9YLfJqnVrFe4cPlSxvnvm74=";
  };

  nativeBuildInputs = [dpkg autoPatchelfHook makeWrapper];
  buildInputs = [alsa-lib stdenv.cc.cc.lib];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r usr/bin usr/share $out/
    runHook postInstall
  '';

  # winit/wgpu load the window-system and GPU libraries dynamically.
  postFixup = ''
    for program in effectcraft effectcraft-cli; do
      wrapProgram $out/bin/$program \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
      alsa-lib
      wayland
      libxkbcommon
      libX11
      libXcursor
      libXi
      libXrandr
      libGL
      vulkan-loader
    ]}
    done
    # Prefer X11/XWayland for the GUI to avoid Wayland backend issues.
    wrapProgram $out/bin/effectcraft --unset WAYLAND_DISPLAY --unset WAYLAND_SOCKET
  '';

  meta = {
    description = "Motion graphics and visual effects compositor";
    homepage = "https://github.com/storytold/effectcraft";
    license = with lib.licenses; [mit asl20];
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    mainProgram = "effectcraft";
  };
})
