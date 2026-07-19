{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.43.0";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = pname;
    rev = "v${version}";
    sha256 = "0vp24bvzbfx4dyidrpr9330qkbwnwg2a2vcr2cgwwx1bzcyf95lz";
  };

  cargoHash = "sha256-XKUKdhxfnwUCOx9slqx4oUFa09HcosPLVh5Xkh87oSk=";

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
