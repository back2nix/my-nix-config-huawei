# OpenAI Codex CLI.
#
# Апстрим предлагает `npm i -g @openai/codex` или готовые бинари из GitHub
# Releases. Здесь берём именно релизный артефакт (musl-статик, никаких
# динамических зависимостей → autoPatchelfHook не нужен).
#
# Обновление версии:
#   curl -s https://api.github.com/repos/openai/codex/releases/latest | jq -r .tag_name
#   nix-prefetch-url https://github.com/openai/codex/releases/download/rust-v<ver>/codex-x86_64-unknown-linux-musl.tar.gz
#   nix hash convert --hash-algo sha256 --to sri <hex>
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  ripgrep,
  git,
}: let
  version = "0.160.0";

  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-MGhlQX1O56kneFhSkQpSf0Hh4Vmt05CsWuOsy2fUShM=";

      # Подставить hash из nix store prefetch-file.
      codeModeHostHash = "sha256-rGzWKI8OOfRqM+uhz9N3EWUfFPM9vHPWobgutF4DjKw=";
    };
  };

  source =
    sources.${stdenvNoCC.hostPlatform.system}
    or (throw "codex: unsupported platform ${stdenvNoCC.hostPlatform.system}");

  codeModeHostSrc = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${source.target}.tar.gz";
    hash = source.codeModeHostHash;
  };
in
  stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;

    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${source.target}.tar.gz";
      inherit (source) hash;
    };

    # В архиве один файл — codex-<target>, без верхнего каталога.
    sourceRoot = ".";
    dontBuild = true;
    dontStrip = true;

    nativeBuildInputs = [makeBinaryWrapper];

    installPhase = ''
      runHook preInstall

      install -Dm755 codex-${source.target} $out/bin/codex

      tar -xzf ${codeModeHostSrc}
      install -Dm755 codex-code-mode-host-${source.target} \
        $out/bin/codex-code-mode-host

      wrapProgram $out/bin/codex \
        --prefix PATH : ${lib.makeBinPath [ripgrep git]}

      runHook postInstall
    '';

    meta = {
      description = "OpenAI Codex — агентный CLI";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = lib.attrNames sources;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
