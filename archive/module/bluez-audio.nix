{
  config,
  lib,
  ...
}: let
  cfg = config.services.bluezAudio;
in {
  # Общая (переиспользуемая) настройка Bluetooth-аудио для WirePlumber 0.5.
  # Формат WP 0.4 (bluetooth.lua.d/*.lua) в 0.5 ИГНОРИРУЕТСЯ, поэтому всё
  # задаётся через services.pipewire.wireplumber.extraConfig (SPA-JSON).
  options.services.bluezAudio = {
    enable = lib.mkEnableOption "общая конфигурация Bluetooth-аудио для WirePlumber 0.5";

    codecs = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = ["sbc_xq" "aac" "ldac"];
      description = "Список разрешённых A2DP-кодеков (bluez5.codecs). null — не ограничивать.";
    };

    disablePauseOnIdle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Не усыплять bluez_input.*/bluez_output.* ноды (node.pause-on-idle = false).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire.wireplumber.extraConfig."10-bluez" =
      {
        "monitor.bluez.properties" =
          {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.headset-roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
            "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" "a2dp_sink" "a2dp_source"];
          }
          // lib.optionalAttrs (cfg.codecs != null) {
            "bluez5.codecs" = cfg.codecs;
          };
      }
      // lib.optionalAttrs cfg.disablePauseOnIdle {
        "monitor.bluez.rules" = [
          {
            matches = [
              {"node.name" = "~bluez_input.*";}
              {"node.name" = "~bluez_output.*";}
            ];
            actions.update-props = {
              "node.pause-on-idle" = false;
            };
          }
        ];
      };
  };
}
