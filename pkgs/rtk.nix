{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.23.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "0na42iar3xs6mddvb66flrkgy9y0vx5yfsq8kxv9lf40y249z06a";
  };

  cargoHash = "sha256-iO78HENuBjb6u+GaMsab/Hs+ypm8lCSxwpny9ak1djY=";

  doCheck = false;

  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
  ];

  meta = with lib; {
    description = "CLI proxy that reduces LLM token consumption by 60-90%";
    homepage = "https://github.com/rtk-ai/rtk";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "rtk";
  };
}
