{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "0nfgjrly7zh53gcdfc6w7q555ffz8cvyvzd7m479mfl6ljmzcxzj";
  };

  cargoHash = "sha256-WoBuQ+Meml4wXSp8bQTckjvjriKsSOs0vSijWo0frq8=";

  doCheck = false;

  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
  ];

  meta = with lib; {
    description = "CLI proxy that reduces LLM token consumption by 60-90%";
    homepage = "https://github.com/rtk-ai/rtk";
    license = licenses.mit;
    maintainers = with maintainers; [];
    mainProgram = "rtk";
  };
}
