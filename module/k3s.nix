{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.services.k3s;
  isServer = cfg.role == "server";
  isAgent = cfg.role == "agent";
in {
  services.k3s = {
    enable = lib.mkDefault true;
    role = lib.mkDefault "server";
    package = pkgs.k3s;
    
    # Эти опции стандартные для модуля k3s в NixOS
    # serverAddr = ...;
    # token = ...;
    # Но мы будем использовать их через передачу в устройствах

    extraFlags = toString ([
      "--kubelet-arg=fail-swap-on=false"
    ] ++ (lib.optionals isServer [
      "--write-kubeconfig-mode 644"
      "--disable=traefik"
    ]));
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
    KUBECONFIG = if isServer then "/etc/rancher/k3s/k3s.yaml" else null;
  };
}
