# Dedicated consumers. Legacy 1082/1088/1090 selectors remain independent.
let
  tunnels = ["ssh-out1" "ssh-out1-via-casino" "ssh-frankfurt" "ssh-astana"];
in {
  selectors = [
    {
      name = "claude";
      default = "ssh-astana";
      outbounds = tunnels ++ ["isp-kazakhstan"];
    }
    {
      name = "codex";
      default = "ssh-out1";
      outbounds = tunnels ++ ["isp-kazakhstan"];
    }
    {
      name = "nix";
      default = "ssh-out1";
      outbounds = tunnels ++ ["direct-out"];
    }
  ];
  routes = [
    {
      name = "claude";
      httpPort = 1101;
      outbound = "claude-select";
    }
    {
      name = "codex";
      httpPort = 1103;
      outbound = "codex-select";
    }
    {
      name = "nix";
      httpPort = 1105;
      socksPort = 1104;
      outbound = "nix-select";
    }
    {
      name = "browser-usa";
      httpPort = 1111;
      socksPort = 1110;
      outbound = "ssh-out1";
    }
    {
      name = "browser-casino";
      httpPort = 1117;
      socksPort = 1116;
      outbound = "ssh-out1-via-casino";
    }
    {
      name = "browser-fra";
      httpPort = 1113;
      socksPort = 1112;
      outbound = "ssh-frankfurt";
    }
    {
      name = "browser-kz";
      httpPort = 1115;
      socksPort = 1114;
      outbound = "ssh-astana";
    }
  ];
}
