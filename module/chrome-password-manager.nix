{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.chrome-password-manager;

  # Официальный ID расширения KeePassXC-Browser в Chrome Web Store.
  keepassxcExtensionId = "oboonakemofpalcgghocfoadofidjkkk";

  nativeHost = {
    name = "org.keepassxc.keepassxc_browser";
    description = "KeePassXC integration with native messaging support";
    path = "${cfg.package}/bin/keepassxc-proxy";
    type = "stdio";
    allowed_origins = ["chrome-extension://${keepassxcExtensionId}/"];
  };

  policy = {
    # Отключаем встроенный менеджер: Chrome перестаёт предлагать
    # сохранение и не пишет новые записи в Login Data.
    PasswordManagerEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
  };
in {
  options.programs.chrome-password-manager = {
    enable = lib.mkEnableOption "KeePassXC как менеджер паролей для google-chrome (вместо встроенного)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.keepassxc;
      defaultText = lib.literalExpression "pkgs.keepassxc";
      description = "Пакет KeePassXC, из которого берётся keepassxc-proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package

      # Разовая чистка уже сохранённых паролей из Login Data.
      # По умолчанию сухой прогон, удаление — только с --yes.
      (pkgs.writeShellApplication {
        name = "chrome-purge-passwords";
        runtimeInputs = [pkgs.sqlite pkgs.procps pkgs.coreutils pkgs.findutils];
        text = builtins.readFile ../scripts/chrome-purge-passwords.sh;
      })
    ];

    environment.etc = {
      # Native messaging host кладём СИСТЕМНО, а не в
      # ~/.config/google-chrome/NativeMessagingHosts: у нас несколько
      # user-data-dir (chrome-mcp :9222, chrome-debug :9333 — см.
      # module/users/bg/chrome-{mcp,debug}.nix), а Chrome ищет хосты в
      # <user-data-dir>/NativeMessagingHosts. Системный путь читают все
      # профили сразу, поэтому интеграция не отваливается в отладочных
      # инстансах.
      "opt/chrome/native-messaging-hosts/${nativeHost.name}.json".text =
        builtins.toJSON nativeHost;

      # Тот же хост для chromium-сборок, если они когда-нибудь появятся.
      "chromium/native-messaging-hosts/${nativeHost.name}.json".text =
        builtins.toJSON nativeHost;

      "opt/chrome/policies/managed/password-manager.json".text =
        builtins.toJSON policy;
      "chromium/policies/managed/password-manager.json".text =
        builtins.toJSON policy;
    };
  };
}
