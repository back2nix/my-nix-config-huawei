{
  buildGoModule,
  fetchFromGitHub,
  lib,
  nixosTests,
}:
buildGoModule rec {
  pname = "blocky";
  version = "0.26.2";

  src = fetchFromGitHub {
    owner = "0xERR0R";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-yo21f12BLINXb8HWdR3ZweV5+cTZN07kxCxO1FMJq/4="; # Заменишь после первой сборки
  };

  # Отключаем тесты, так как они требуют сетевого подключения
  doCheck = false;

  vendorHash = "sha256-cIDKUzOAs6XsyuUbnR2MRIeH3LI4QuohUZovh/DVJzA="; # Заменишь после первой сборки

  ldflags = [
    "-s"
    "-w"
    "-X github.com/0xERR0R/blocky/util.Version=${version}"
  ];

  passthru.tests = {inherit (nixosTests) blocky;};

  meta = with lib; {
    description = "Fast and lightweight DNS proxy as ad-blocker for local network with many features";
    homepage = "https://0xerr0r.github.io/blocky";
    changelog = "https://github.com/0xERR0R/blocky/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ratsclub];
    mainProgram = "blocky";
  };
}
