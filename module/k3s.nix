# module/k3s.nix
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
      # Опционально: отключаем kube-proxy, если хочешь использовать Cilium для замены
      # "--disable=traefik"  # уже отключен в тестах
    ];
  };

  # Создаем группу k3s
  users.groups.k3s = {};

  # Настраиваем права доступа к сокету через systemd-tmpfiles
  systemd.tmpfiles.rules = [
    "z /run/k3s/containerd/containerd.sock 0660 root k3s -"
  ];

  environment.systemPackages = with pkgs; [
    k3s
    cilium-cli  # CLI для управления Cilium
    kubernetes-helm  # Может понадобиться для ручной установки
  ];

  # Устанавливаем переменную окружения для kubectl
  environment.variables = {
    KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  };
}
