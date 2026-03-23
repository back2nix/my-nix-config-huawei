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
  systemd.services.k3s-lo-ip = {
    description = "Add 10.0.0.1/32 to loopback for k3s node IP";
    before = [ "k3s.service" ];
    wantedBy = [ "k3s.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip addr add 10.0.0.1/32 dev lo || true'";
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip addr del 10.0.0.1/32 dev lo || true'";
    };
  };

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
      "--node-ip 10.0.0.1"
      "--node-external-ip 10.0.0.1"
      "--advertise-address 10.0.0.1"
      "--flannel-iface lo"
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
