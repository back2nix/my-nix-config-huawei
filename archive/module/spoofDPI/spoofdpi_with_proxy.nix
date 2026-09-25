{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "spoof-dpi";
  version = "0.10.4";

  src = fetchFromGitHub {
    # owner = "xvzc";
    owner = "back2nix";
    repo = "spoofDPI";
    rev = "fc0e4a57963d7a42d05b6376346d1895b1a56b33";
    sha256 = "sha256-hZZGR6Lq84LN0hX2BMB1O7jpExgkwuKJU0faSqxxZPM=";
    # sha256-I93XhIrdCXmoiG6u617toFaB1YALMK8jabCGTp3u4os=
  };

  # sha256-kmp+8MMV1AHaSvLnvYL17USuv7xa3NnsCyCbqq9TvYE=
  vendorHash = "sha256-7mFpEQYckeNHlez0tfqjBz4OKFBxCcjzSs5KQXs8bmw=";

  subPackages = [
    "cmd/spoof-dpi"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A simple and fast anti-censorship tool written in Go";
    homepage = "https://github.com/back2nix/SpoofDPI";
    # homepage = "https://github.com/xvzc/SpoofDPI";
    mainProgram = "spoof-dpi";
    license = licenses.asl20;
  };
}
