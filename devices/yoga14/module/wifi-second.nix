# Второй Wi-Fi клиент (wlan1) на том же BE200.
# iwlwifi допускает #{managed} <= 2, #channels <= 2 — две сети одновременно,
# в т.ч. на разных каналах (радио одно, каналы делятся по времени).
# Подключение: nmcli dev wifi connect "<SSID>" password "<pass>" ifname wlan1
{pkgs, ...}: {
  systemd.services.wifi-second-iface = {
    description = "Create second managed Wi-Fi interface wlan1";
    after = ["sys-subsystem-net-devices-wlp0s20f3.device"];
    bindsTo = ["sys-subsystem-net-devices-wlp0s20f3.device"];
    wantedBy = ["sys-subsystem-net-devices-wlp0s20f3.device" "multi-user.target"];
    before = ["NetworkManager.service"];
    path = [pkgs.iw pkgs.iproute2];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! ip link show wlan1 >/dev/null 2>&1; then
        iw dev wlp0s20f3 interface add wlan1 type managed
      fi
      # MAC обязан отличаться от основного (locally administered).
      ip link set wlan1 address 02:57:7e:2a:08:4c
    '';
    preStop = "iw dev wlan1 del || true";
  };
}
