# module/k3s.nix
{ pkgs, ... }: {
  # ... существующий конфиг ...
  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s;
    extraFlags = toString [
      "--write-kubeconfig-mode 644"
      "--kubelet-arg=fail-swap-on=false"
    ];
  };

  # --- ДОБАВИТЬ ЭТО ---

  # 1. Создаем группу k3s
  users.groups.k3s = {};

  # 2. Настраиваем права доступа к сокету через systemd-tmpfiles
  # Это говорит системе: "Установить для файла сокета права 0660, владельца root и группу k3s"
  systemd.tmpfiles.rules = [
    "z /run/k3s/containerd/containerd.sock 0660 root k3s -"
  ];

  environment.systemPackages = [ pkgs.k3s ];
}
