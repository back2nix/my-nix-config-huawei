{ pkgs, ... }: {
  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s;
    extraFlags = toString [
      "--write-kubeconfig-mode 644"
      "--kubelet-arg=fail-swap-on=false"
      # Отключаем встроенный CNI (Flannel) и network policy для Cilium
      "--flannel-backend=none"
      "--disable-network-policy"
      # ВАЖНО: Отключаем Traefik, чтобы освободить порты 80/443 для Ingress-Nginx
      "--disable=traefik"
    ];
  };

  # Создаем группу k3s
  users.groups.k3s = {};

  # Настраиваем права доступа к сокету
  systemd.tmpfiles.rules = [
    "z /run/k3s/containerd/containerd.sock 0660 root k3s -"
  ];

  environment.systemPackages = with pkgs; [
    k3s
    cilium-cli
    kubernetes-helm
  ];

  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
}
