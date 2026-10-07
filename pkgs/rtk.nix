{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.51.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "1igj459n1s4d0s2v7s1cqgl4zkgnjpgclpq9ra78sr5prpwf7h18";
  };

  cargoHash = "sha256-tc3bHU6cgod1K6uqWEjDQc8IEgCrPRR1WAHP+ofelw0=";

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
