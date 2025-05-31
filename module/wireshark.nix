{
  pkgs-master,
  cfg,
  lib,
  ...
}: {
  # Define the wireshark group and set dumpcap with it.  This allows us to capture as nonroot
  # The wireshark package won't do this for us
  users.groups.wireshark = {};

  # security.wrappers.dumpcap = {
  #   source = "${pkgs-master.wireshark}/bin/dumpcap";
  #   permissions = lib.mkForce "u+xs,g+x";
  #   owner = "root";
  #   group = "wireshark";
  # };

  security.wrappers.dumpcap = {
    source = "${pkgs-master.wireshark}/bin/dumpcap";
    capabilities = "cap_net_raw,cap_net_admin+ep";
    # permissions = "u+rx,g+x";
    owner = "root";
    group = "wireshark";
    setuid = false;
    setgid = false;
  };

  # Add myself to this new group
  users.users.bg.extraGroups = ["wireshark"];

  environment.systemPackages = [
    pkgs-master.wireshark
  ];
}
