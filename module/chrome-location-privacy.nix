{...}: let
  policy = {
    # Mandatory policies apply to every profile, including chrome-mcp/debug.
    # Explicit wildcard blocks also override previously granted site access.
    DefaultGeolocationSetting = 2;
    GeolocationBlockedForUrls = ["*"];
    DefaultSensorsSetting = 2;
    SensorsBlockedForUrls = ["*"];
    SensorsAllowedForUrls = [];

    # Prevent WebRTC from bypassing the configured proxy with direct UDP.
    # Calls may fall back to TCP; this does not hide the normal HTTP public IP.
    WebRtcIPHandling = "disable_non_proxied_udp";
    WebRtcIPHandlingUrl = [];

    # Avoid unsolicited connections disclosing the source IP before navigation.
    NetworkPredictionOptions = 2;
    SearchSuggestEnabled = false;
  };
in {
  environment.etc = {
    "opt/chrome/policies/managed/location-privacy.json".text = builtins.toJSON policy;
    "chromium/policies/managed/location-privacy.json".text = builtins.toJSON policy;
  };
}
