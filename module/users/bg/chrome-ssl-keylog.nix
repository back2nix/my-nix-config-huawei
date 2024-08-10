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
          (pkgs-master.writeScriptBin "chrome-ssl-keylog" ''
            #!${pkgs-master.stdenv.shell}
            KEYLOG_FILE=''${KEYLOG_FILE:-${cfg.keylogFile}}
            KEYLOG_DIR=$(dirname "$KEYLOG_FILE")
            mkdir -p "$KEYLOG_DIR"
            touch "$KEYLOG_FILE"
            chmod 600 "$KEYLOG_FILE"
            export SSLKEYLOGFILE="$KEYLOG_FILE"
            exec ${cfg.package}/bin/google-chrome-stable \
              --ssl-key-log-file="$SSLKEYLOGFILE" \
              "$@"
          '')
          (pkgs-master.writeScriptBin "wireshark-with-keylog" ''
            #!${pkgs-master.stdenv.shell}
            KEYLOG_FILE=''${KEYLOG_FILE:-${cfg.keylogFile}}
            if [ ! -f "$KEYLOG_FILE" ]; then
              echo "SSL keylog file not found: $KEYLOG_FILE"
              exit 1
            fi
            exec ${pkgs-master.wireshark}/bin/wireshark \
              -o ssl.keylog_file:"$KEYLOG_FILE" \
              "$@"
          '')
        ];
        buildInputs = [pkgs-master.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/chrome-ssl-keylog \
            --prefix PATH : ${lib.makeBinPath [cfg.package]} \
            --set CHROME_WRAPPER "$out/bin/chrome-ssl-keylog"
          wrapProgram $out/bin/wireshark-with-keylog \
            --prefix PATH : ${lib.makeBinPath [pkgs-master.wireshark]}
        '';
      })
    ];

    home.file.".local/share/applications/chrome-ssl-keylog.desktop".text = ''
      [Desktop Entry]
      Name=Google Chrome (SSL Keylog)
      Exec=chrome-ssl-keylog %U
      Terminal=false
      Type=Application
      Icon=google-chrome
      Categories=Network;WebBrowser;
      MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
      StartupNotify=true
    '';

    home.file.".local/share/applications/wireshark-with-keylog.desktop".text = ''
      [Desktop Entry]
      Name=Wireshark (with SSL Keylog)
      Exec=wireshark-with-keylog %U
      Terminal=false
      Type=Application
      Icon=wireshark
      Categories=Network;PacketAnalyzer;
      MimeType=application/vnd.tcpdump.pcap;application/x-pcapng;application/x-snoop;application/x-iptrace;application/x-lanalyzer;application/x-nettl;application/x-radcom;
      StartupNotify=true
    '';
  };
}
