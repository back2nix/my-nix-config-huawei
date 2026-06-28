{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.42.4";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "1v559pai82mwbjxqzq555zlg88vw25qyic0cbnl7jzayypjcjwpj";
  };

  cargoHash = "sha256-YsKOyEZ281ojqiitnvCFGy/MzHMyr4hlxqMnvrQwguQ=";

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
