# Kimi Code CLI (Moonshot AI).
#
# Апстримный установщик `curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash`
# качает готовый бинарь и кладёт его в ~/.kimi-code/bin, дописывая PATH в rc-файлы.
# Здесь то же самое делается декларативно: берём тот же артефакт, что и install.sh,
# и патчим под NixOS.
#
# Артефакт — Node.js 24 SEA (Single Executable Application, собран через postject):
# один статически сшитый с node бинарь, внешний node в рантайме не нужен.
# Динамически линкуется с libstdc++/libgcc_s, поэтому нужен autoPatchelfHook.
#
# Обновление версии:
#   curl -fsSL https://code.kimi.com/kimi-code/latest                       # версия
#   curl -fsSL https://code.kimi.com/kimi-code/binaries/<ver>/manifest.json # sha256 по платформам
# В manifest.json checksum лежит в hex — переводить в SRI:
#   nix hash to-sri --type sha256 <hex>
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  ripgrep,
  git,
}: let
  version = "0.29.1";

  # filename + hash из binaries/<version>/manifest.json
  sources = {
    x86_64-linux = {
      file = "kimi-code-linux-x64";
      hash = "sha256-F7vWTT9lK0os7+cIJlgp7xhN8FrxMzMHRGZ+gJre0xo=";
    };
    aarch64-linux = {
      file = "kimi-code-linux-arm64";
      hash = "sha256-wr287Wvs9RbicM6hGj7ntUx4nL3+Fb1weX8FvV+UPvA=";
    };
    x86_64-darwin = {
      file = "kimi-code-darwin-x64";
      hash = "sha256-VyaPkMqJBYoXA0CUoBdnVmqaS5ORXltrL4A0/vDIYpQ=";
    };
    aarch64-darwin = {
      file = "kimi-code-darwin-arm64";
      hash = "sha256-bt8bEkqGrJJX7mq8MqqapUiTRUnbEw8k9LxE00VUgaY=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
    or (throw "kimi-code: unsupported platform ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    pname = "kimi-code";
    inherit version;

    src = fetchurl {
      url = "https://code.kimi.com/kimi-code/binaries/${version}/${source.file}";
      inherit (source) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    # SEA-блоб пришит к ELF секцией; strip его ломает.
    dontStrip = true;

    nativeBuildInputs =
      [makeBinaryWrapper]
      ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/kimi
      wrapProgram $out/bin/kimi \
        --set-default KIMI_CODE_NO_AUTO_UPDATE 1 \
        --prefix PATH : ${lib.makeBinPath [ripgrep git]}
      runHook postInstall
    '';

    meta = {
      description = "Kimi Code — агентный CLI от Moonshot AI";
      homepage = "https://code.kimi.com";
      license = lib.licenses.mit;
      mainProgram = "kimi";
      platforms = lib.attrNames sources;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
