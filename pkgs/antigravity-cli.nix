{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, }:
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  version = "1.3.2";
  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.3.2-5813501495738368/linux-x64/cli_linux_x64.tar.gz";
    sha512 = "8dc2bb8471cfa6326e29e2896add767ad2d1f3714304b70fbae720d68af011182e7afde43964a7a3f54c604ab72c4fad772c8595608b059cfc582fb6798a25d2";
  };
  sourceRoot = ".";
  nativeBuildInputs = [autoPatchelfHook];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    runHook postInstall
  '';
  meta = {
    description = "Google Antigravity terminal agent";
    homepage = "https://github.com/google-antigravity/antigravity-cli";
    license = lib.licenses.unfree;
    platforms = ["x86_64-linux"];
    mainProgram = "agy";
  };
}
