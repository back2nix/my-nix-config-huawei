{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-23-11,
  ...
}: {
  virtualisation.docker.enable = false;

  virtualisation.podman = {
    enable = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
    extraPackages = [pkgs.zfs];
  };

  virtualisation.containers.registries.search = [
    "docker.io"
  ];

  # Note: need to create the zfs mount manually
  # bin/nixos/podman-setup-zfs-storage

  virtualisation.containers.registries.insecure = [
    "localhost:5000"
    "localhost:29003"
    "dev.ilx.yjpark.org"
  ];

  environment.systemPackages = with pkgs; [
    pkgs-23-11.arion
    pkgs-master.podman-compose
    pkgs-master.podman-tui
    pkgs-master.docker-client
    pkgs-master.distrobox
  ];
}
