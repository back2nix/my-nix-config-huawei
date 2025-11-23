# module/k3s.nix
{ pkgs, ... }: {
  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s;

    # Дополнительные флаги запуска
    extraFlags = toString [
      # Разрешить чтение конфига пользователям (удобно для локальной разработки)
      # Иначе придется каждый раз делать sudo k3s kubectl
      "--write-kubeconfig-mode 644"

      # Важно: у тебя включен Swap, k3s по умолчанию падает при наличии swap.
      # Этот флаг говорит игнорировать наличие swap.
      "--kubelet-arg=fail-swap-on=false"

      # Отключаем встроенный Traefik, если планируешь ставить свой Ingress (Nginx/Istio)
      # Если нужен "просто рабочий кластер" - закомментируй эту строку
      # "--disable traefik"

      # Отключаем servicelb, если будешь использовать MetalLB
      # "--disable servicelb"
    ];
  };

  environment.systemPackages = [ pkgs.k3s ];
}
