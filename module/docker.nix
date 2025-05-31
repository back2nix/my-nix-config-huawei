{
  inputs,
  config,
  pkgs,
  pkgs-master,
  pkgs-23-11,
  ...
}: {
  # sudo systemctl daemon-reload
  # sudo systemctl restart docker
  # systemctl --user restart docker
  virtualisation = {
    docker = {
      enable = true;
      liveRestore = false;
      storageDriver =
        if config.fileSystems."/".fsType == "btrfs"
        then "btrfs"
        else "overlay2";
      rootless = {
        enable = true;
        setSocketVariable = true;
        daemon = {
          settings = {
            dns = ["9.9.9.9"];
            insecure-registries = [
              "localhost:5000"
              "172.18.0.2:5000"
            ];
          };
        };
      };
      autoPrune.enable = true;
      daemon = {
        settings = {
          # data-root = "/home/docker";
          # ip = "127.0.0.1";
          # dns = ["127.0.0.11" "8.8.8.8" "8.8.4.4" "1.1.1.1" "1.0.0.1"];
          dns = ["9.9.9.9"];
          insecure-registries = [
            "localhost:5000"
            "172.18.0.2:5000"
          ];
        };
      };
    };
  };

  virtualisation.oci-containers.backend = "docker";

  boot.kernel.sysctl = {
    "kernel.unprivileged_userns_clone" = 1;
    "net.ipv4.ip_unprivileged_port_start" = 0;
  };

  virtualisation.multipass = {
    enable = true;
  };

  virtualisation.containers.registries.search = ["docker.io"];
  virtualisation.containers.registries.insecure = [
    "localhost:5000"
    "localhost:29003"
    "dev.ilx.yjpark.org"
  ];

  environment.systemPackages = with pkgs; [
    pkgs-master.docker-client
    pkgs-master.distrobox
    pkgs-master.docker-compose
    slirp4netns # Важно для rootless networking
    fuse-overlayfs # Важно для storage driver
    shadow # Для usermod и других утилит управления пользователями
  ];
}
