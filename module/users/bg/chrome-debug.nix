{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.chrome-debug;
in {
  options.programs.chrome-debug = {
    enable = lib.mkEnableOption "google-chrome-stable-debug (your profile + remote debugging port)";

    # Уже собранный google-chrome с вшитыми GPU-флагами И --remote-debugging-port
    # (см. programs.google-chrome.commandLineArgs). Обёртка ничего не дублирует —
    # только добавляет отдельный --user-data-dir, иначе Chrome 136+ молча
    # игнорирует --remote-debugging-port на дефолтном профиле.
    package = lib.mkOption {
      type = lib.types.package;
      default = config.programs.google-chrome.finalPackage;
      defaultText = lib.literalExpression "config.programs.google-chrome.finalPackage";
      description = "The wrapped google-chrome package to launch (with baked-in flags)";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 9333;
      description = ''
        Remote debugging port. Kept distinct from programs.chrome-mcp (9222)
        so the two can run side by side. Passed AFTER the baked-in
        --remote-debugging-port=9222, and Chrome takes the last duplicate.
      '';
    };

    sourceProfile = lib.mkOption {
      type = lib.types.str;
      default = ".config/google-chrome";
      description = "Existing profile to seed the debug profile from (relative to HOME)";
    };

    userDataDir = lib.mkOption {
      type = lib.types.str;
      default = ".config/google-chrome-debug";
      description = "Dedicated (non-default) profile dir for debugging (relative to HOME)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.symlinkJoin {
        name = "google-chrome-stable-debug";
        paths = [
          (pkgs.writeShellScriptBin "google-chrome-stable-debug" ''
            SRC="$HOME/${cfg.sourceProfile}"
            DEBUG_DIR="$HOME/${cfg.userDataDir}"

            # Первый запуск: засеять отдельный профиль копией основного
            # (закладки/логины/расширения на месте, тяжёлые кэши пропускаем).
            # Chrome 136+ запрещает remote-debugging на самом дефолтном профиле,
            # поэтому нужен именно ОТДЕЛЬНЫЙ каталог. Дальше он живёт своей жизнью.
            if [ ! -d "$DEBUG_DIR" ]; then
              echo "chrome-debug: seeding $DEBUG_DIR from $SRC ..." >&2
              mkdir -p "$DEBUG_DIR"
              if [ -d "$SRC" ]; then
                ${pkgs.rsync}/bin/rsync -a \
                  --exclude 'Cache' \
                  --exclude 'Code Cache' \
                  --exclude 'GPUCache' \
                  --exclude 'ShaderCache' \
                  --exclude 'GraphiteDawnCache' \
                  --exclude 'DawnWebGPUCache' \
                  --exclude 'DawnGraphiteCache' \
                  --exclude 'component_crx_cache' \
                  --exclude 'extensions_crx_cache' \
                  --exclude 'Service Worker/CacheStorage' \
                  --exclude 'SingletonLock' \
                  --exclude 'SingletonSocket' \
                  --exclude 'SingletonCookie' \
                  "$SRC/" "$DEBUG_DIR/" || true
              fi
            fi

            # google-chrome-stable уже добавляет все GPU-флаги и
            # --remote-debugging-port=9222; мы задаём отдельный профиль и
            # перекрываем порт последним значением (дубликат → Chrome берёт
            # последний), чтобы не конфликтовать с chrome-mcp на 9222.
            exec ${cfg.package}/bin/google-chrome-stable \
              --user-data-dir="$DEBUG_DIR" \
              --remote-debugging-port=${toString cfg.port} \
              "$@"
          '')
        ];
      })
    ];

    home.file.".local/share/applications/google-chrome-stable-debug.desktop".text = ''
      [Desktop Entry]
      Name=Google Chrome (Debug ${toString cfg.port})
      Comment=Your profile with remote debugging port ${toString cfg.port} enabled
      Exec=google-chrome-stable-debug %U
      Terminal=false
      Type=Application
      Icon=google-chrome
      Categories=Network;WebBrowser;
      MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
      StartupNotify=true
    '';
  };
}
