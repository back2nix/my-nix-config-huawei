#!/usr/bin/env bash

# Script to diagnose Wi-Fi issues on NixOS
# Run this script *when the internet connection is lost*
# and *before* toggling Wi-Fi or rebooting.

echo "=== Wi-Fi Diagnostics Started: $(date) ==="
LOG_FILE="wifi_diag_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "$LOG_FILE") # Redirect all output to console and log file

echo "INFO: Saving all output to $LOG_FILE"
echo "INFO: Running as user: $(whoami)"
echo "INFO: Ensure 'pkgs.iw', 'pkgs.iptables', 'pkgs.nettools' (for nslookup) are in your systemPackages."
echo ""

# --- Attempt to auto-detect Wi-Fi interface ---
WIFI_IFACE=$(ip -o link show | awk -F': ' '$3 ~ /UP/ && $2 ~ /^(wlan|wlp|ath|wlx)/ {print $2; exit}')
if [ -z "$WIFI_IFACE" ]; then
    # Fallback to the one often seen in your config if auto-detection fails or interface is down
    WIFI_IFACE="wlp0s20f3"
    echo "WARN: Could not auto-detect active Wi-Fi interface, using fallback: $WIFI_IFACE"
    echo "      This might be okay if the interface is down due to the issue."
else
    echo "INFO: Auto-detected Wi-Fi interface: $WIFI_IFACE"
fi
echo ""

echo "--- System Information ---"
uname -a
uptime
echo ""

echo "--- RFKill Status ---"
rfkill list all
echo ""

echo "--- Network Interface Status ($WIFI_IFACE) ---"
ip link show dev "$WIFI_IFACE"
ip addr show dev "$WIFI_IFACE"
echo ""

echo "--- Routing Table ---"
ip route show
GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
echo "Detected Gateway: $GATEWAY_IP"
echo ""

echo "--- Wi-Fi Specifics ($WIFI_IFACE) ---"
if command -v iw &> /dev/null && [ -n "$WIFI_IFACE" ]; then
    echo "--- iw dev $WIFI_IFACE link ---"
    iw dev "$WIFI_IFACE" link
    echo ""
    echo "--- iw dev $WIFI_IFACE station dump ---"
    iw dev "$WIFI_IFACE" station dump
    echo ""
    echo "--- iw dev $WIFI_IFACE scan (might be long) ---"
    sudo iw dev "$WIFI_IFACE" scan | grep -E "SSID|signal|freq" # Needs sudo for some details
    echo ""
else
    echo "WARN: 'iw' command not found or interface not set, skipping iw commands. Consider adding pkgs.iw."
fi


echo "--- NetworkManager Status ---"
if command -v nmcli &> /dev/null; then
    echo "--- nmcli general status ---"
    nmcli general status
    echo ""
    echo "--- nmcli device show $WIFI_IFACE ---"
    nmcli device show "$WIFI_IFACE"
    echo ""
    echo "--- nmcli connection show --active ---"
    nmcli connection show --active
    echo ""
else
    echo "WARN: 'nmcli' command not found, skipping NetworkManager commands."
fi

echo "--- DNS Configuration ---"
echo "--- Contents of /etc/resolv.conf ---"
cat /etc/resolv.conf
echo ""

echo "--- Ping Tests ---"
if [ -n "$GATEWAY_IP" ]; then
    echo "Pinging Gateway ($GATEWAY_IP)..."
    ping -c 4 "$GATEWAY_IP"
else
    echo "WARN: Gateway IP not found, skipping gateway ping."
fi
echo "Pinging 1.1.1.1 (Cloudflare DNS, bypasses local DNS)..."
ping -c 4 1.1.1.1
echo "Pinging google.com (tests DNS resolution and connectivity)..."
ping -c 4 google.com
echo ""

echo "--- DNS Lookup Tests ---"
if command -v nslookup &> /dev/null; then
    echo "Resolving google.com using system configured DNS (/etc/resolv.conf)..."
    nslookup google.com
    echo "Resolving google.com using 1.1.1.1 directly..."
    nslookup google.com 1.1.1.1
else
    echo "WARN: 'nslookup' not found. Consider adding pkgs.nettools or pkgs.dnsutils."
fi
echo ""

echo "--- Service Status ---"
echo "--- NetworkManager.service ---"
systemctl status NetworkManager.service --no-pager -l
echo ""
echo "--- blocky.service (your custom DNS filter) ---"
systemctl status blocky.service --no-pager -l
echo ""
echo "--- cloudflared-doh.service (if DoH mode is active) ---"
systemctl status cloudflared-doh.service --no-pager -l
echo ""

echo "--- Firewall Rules (nftables) ---"
if command -v nft &> /dev/null; then
    echo "--- nft list ruleset ---"
    sudo nft list ruleset # Needs sudo
else
    echo "WARN: 'nft' command not found, skipping nftables rules listing."
fi
echo ""
echo "--- IPTables NAT rules (from your config, checking if active via iptables-nft) ---"
if command -v iptables-save &> /dev/null; then
    echo "--- sudo iptables-save -t nat ---"
    sudo iptables-save -t nat # Needs sudo
else
    echo "WARN: 'iptables-save' command not found. Consider adding pkgs.iptables."
fi
if command -v ip6tables-save &> /dev/null; then
    echo "--- sudo ip6tables-save -t nat ---"
    sudo ip6tables-save -t nat # Needs sudo
else
    echo "WARN: 'ip6tables-save' command not found. Consider adding pkgs.iptables."
fi
echo ""

echo "--- Recent Journal Logs ---"
echo "--- NetworkManager (last 100 lines from 10 min ago) ---"
sudo journalctl -u NetworkManager.service -n 100 --no-pager --since "10 minutes ago"
echo ""
echo "--- blocky.service (last 100 lines from 10 min ago) ---"
sudo journalctl -u blocky.service -n 100 --no-pager --since "10 minutes ago"
echo ""
echo "--- cloudflared-doh.service (last 100 lines from 10 min ago) ---"
sudo journalctl -u cloudflared-doh.service -n 100 --no-pager --since "10 minutes ago"
echo ""
echo "--- Kernel Messages (dmesg, last 100 lines) ---"
sudo dmesg -T | tail -n 100 # Added -T for human-readable timestamps
echo ""

echo "--- Hardware Information ---"
echo "--- lspci -knn (Network controller) ---"
lspci -knn | grep -iA3 net
echo ""
echo "--- lsusb (relevant for Wi-Fi dongles or Bluetooth combo) ---"
lsusb
echo ""


echo "=== Wi-Fi Diagnostics Finished: $(date) ==="
echo "Log file saved to: $LOG_FILE"
echo "Please provide this file for analysis."
