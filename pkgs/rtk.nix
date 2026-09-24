{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.49.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "15dcv1pjrb60zpdh4bp7yqx6kqfm9jrwq2khhxn2ccpcyk4gwmn2";
  };

  cargoHash = "sha256-cgRtXTd75uKInBnf6dP6e4KHyA2IP9lLEKwVzGq16gg=";

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
