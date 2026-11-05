{
  wireshark,
  config,
  lib,
  pkgs-master,
  ...
}: let
  cfg = config.programs.chrome-with-ssl-keylog;
in {
  options.programs.chrome-with-ssl-keylog = {
    enable = lib.mkEnableOption "Google Chrome with SSL keylog";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs-master.google-chrome;
      description = "The Google Chrome package to use";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9444;
      description = "Remote debugging port for the SSL keylog browser";
    };
    userDataDir = lib.mkOption {
      type = lib.types.str;
      default = ".config/google-chrome-ssl-keylog";
      description = "Dedicated non-default browser profile, relative to HOME";
    };
    sourceProfile = lib.mkOption {
      type = lib.types.str;
      default = ".config/google-chrome-debug";
      description = "Profile to copy on first launch, relative to HOME";
    };
    keylogFile = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/sslkeylog.txt";
      description = "Default path to the SSL keylog file if KEYLOG_FILE env var is not set";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs-master.symlinkJoin {
        name = "chrome-with-ssl-keylog";
        paths = [
          (pkgs-master.writeShellScriptBin "chrome-ssl-keylog" ''
            # Chrome requires a non-default profile for remote debugging.
            # Seed once; later launches keep this profile's own session.
            PROFILE_DIR="$HOME/"${lib.escapeShellArg cfg.userDataDir}
            SOURCE_DIR="$HOME/"${lib.escapeShellArg cfg.sourceProfile}
            if [ ! -d "$PROFILE_DIR" ]; then
              mkdir -p "$PROFILE_DIR"
              if [ -d "$SOURCE_DIR" ]; then
                ${pkgs-master.rsync}/bin/rsync -a \
                  --exclude 'Cache' --exclude 'Code Cache' --exclude 'GPUCache' \
                  --exclude 'ShaderCache' --exclude 'GraphiteDawnCache' \
                  --exclude 'DawnWebGPUCache' --exclude 'DawnGraphiteCache' \
                  --exclude 'component_crx_cache' --exclude 'extensions_crx_cache' \
                  --exclude 'Service Worker/CacheStorage' \
                  --exclude 'SingletonLock' --exclude 'SingletonSocket' \
                  --exclude 'SingletonCookie' --exclude 'DevToolsActivePort' \
                  "$SOURCE_DIR/" "$PROFILE_DIR/"
              fi
            fi
            KEYLOG_FILE=''${KEYLOG_FILE:-${cfg.keylogFile}}
            KEYLOG_DIR=$(dirname "$KEYLOG_FILE")
            mkdir -p "$KEYLOG_DIR"
            touch "$KEYLOG_FILE"
            chmod 600 "$KEYLOG_FILE"
            export SSLKEYLOGFILE="$KEYLOG_FILE"
            exec ${cfg.package}/bin/google-chrome-stable \
              --lang=en-US \
              --accept-lang=en-US,en \
              --ssl-key-log-file="$SSLKEYLOGFILE" \
              --user-data-dir="$PROFILE_DIR" \
              --remote-debugging-port=${toString cfg.port} \
              --autoplay-policy=user-gesture-required \
              "$@"
          '')
          # [DEPRACTED] work only with sudo
          # (pkgs-master.writeScriptBin "wireshark-with-keylog" ''
          #   KEYLOG_FILE=''${KEYLOG_FILE:-${cfg.keylogFile}}
          #   if [ ! -f "$KEYLOG_FILE" ]; then
          #     echo "SSL keylog file not found: $KEYLOG_FILE"
          #     exit 1
          #   fi
          #   exec ${pkgs-master.wireshark}/bin/wireshark \
          #     -o ssl.keylog_file:"$KEYLOG_FILE" \
          #     "$@"
          # '')
        ];
        buildInputs = [pkgs-master.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/chrome-ssl-keylog \
            --prefix PATH : ${lib.makeBinPath [cfg.package]} \
            --set CHROME_WRAPPER "$out/bin/chrome-ssl-keylog"
          # wrapProgram $out/bin/wireshark-with-keylog \
          #   --prefix PATH : ${lib.makeBinPath [pkgs-master.wireshark]}
        '';
      })
    ];
    home.file.".local/share/applications/chrome-ssl-keylog.desktop".text = ''
      [Desktop Entry]
      Name=Google Chrome (SSL Keylog + Debug ${toString cfg.port})
      Exec=chrome-ssl-keylog %U
      Terminal=false
      Type=Application
      Icon=google-chrome
      Categories=Network;WebBrowser;
      MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
      StartupNotify=true
    '';
    # [DEPRACTED] work only with sudo
    # home.file.".local/share/applications/wireshark-with-keylog.desktop".text = ''
    #   [Desktop Entry]
    #   Name=Wireshark (with SSL Keylog)
    #   Exec=wireshark-with-keylog %U
    #   Terminal=false
    #   Type=Application
    #   Icon=wireshark
    #   Categories=Network;PacketAnalyzer;
    #   MimeType=application/vnd.tcpdump.pcap;application/x-pcapng;application/x-snoop;application/x-iptrace;application/x-lanalyzer;application/x-nettl;application/x-radcom;
    #   StartupNotify=true
    # '';
  };
}
