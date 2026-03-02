{
  config,
  lib,
  pkgs,
  pkgs-master,
  ...
}: let
  cfg = config.programs.chrome-mcp;
in {
  options.programs.chrome-mcp = {
    enable = lib.mkEnableOption "Google Chrome with MCP debugging";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs-master.google-chrome;
      description = "The Google Chrome package to use";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 9222;
      description = "Remote debugging port";
    };
    userDataDir = lib.mkOption {
      type = lib.types.str;
      default = ".cache/chrome-ai-profile";
      description = "Path to the user data directory (relative to HOME)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.symlinkJoin {
        name = "chrome-mcp";
        paths = [
          (pkgs.writeScriptBin "chrome-mcp" ''
            USER_DATA_DIR="$HOME/${cfg.userDataDir}"
            mkdir -p "$USER_DATA_DIR"
            
            exec ${cfg.package}/bin/google-chrome-stable \
              --remote-debugging-port=${toString cfg.port} \
              --user-data-dir="$USER_DATA_DIR" \
              --no-first-run \
              --no-default-browser-check \
              "$@"
          '')
        ];
        buildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/chrome-mcp \
            --prefix PATH : ${lib.makeBinPath [cfg.package]}
        '';
      })
    ];

    home.file.".local/share/applications/chrome-mcp.desktop".text = ''
      [Desktop Entry]
      Name=Google Chrome (AI MCP)
      Comment=Chrome instance for AI MCP with remote debugging
      Exec=chrome-mcp %U
      Terminal=false
      Type=Application
      Icon=google-chrome
      Categories=Network;WebBrowser;
      MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
      StartupNotify=true
    '';
  };
}
