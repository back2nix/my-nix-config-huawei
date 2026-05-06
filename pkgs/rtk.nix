{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.38.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "14jmpd4frn28v3z2sh7y2w8dk2mw2y93b2wfgcm9p3jvmfami0vq";
  };

  cargoHash = "sha256-qTDj7xTBM8dOOE7XLTewtHVwHtxVDcvCLs0ebtT2uSI=";

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
