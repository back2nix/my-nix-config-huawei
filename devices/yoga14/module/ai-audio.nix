{
  config,
  lib,
  ...
}: let
  cfg = config.services.aiAudio;
in {
  options.services.aiAudio = {
    enable =
      lib.mkEnableOption "AI audio mix-minus proxy (virtual sink AI_System_Proxy)"
      // {default = true;};

    targetSink = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alsa_output.pci-0000_00_1f.3.analog-stereo";
      description = ''
        Имя физического sink-а (node.name), в который loopback-выход
        AI_System_Proxy_Output будет направлен явно (playback.props."target.object").

        Если null — маршрут выбирает WirePlumber (обычно default sink), что
        рискованно: если default sink — сам прокси, получится петля.

        Имя устройства НЕ хардкодится в конфиге; смотреть актуальное значение:
          wpctl status  /  pactl list short sinks
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      pulse.enable = true;

      extraConfig.pipewire."99-ai-devices" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "AI_System_Proxy";
              "capture.props" = {
                "node.name" = "AI_System_Proxy";
                "media.class" = "Audio/Sink";
                "audio.position" = ["FL" "FR"];
              };
              "playback.props" =
                {
                  "node.name" = "AI_System_Proxy_Output";
                  "node.passive" = true;
                }
                // lib.optionalAttrs (cfg.targetSink != null) {
                  "target.object" = cfg.targetSink;
                };
            };
          }
        ];
      };
    };
  };
}
