#!/usr/bin/env bash

INTERFACE=$1

# Получите оригинальный MAC-адрес из permaddr
ORIGINAL_MAC=$(ethtool -P "$INTERFACE" | awk '{print $3}')

ip link set dev "$INTERFACE" down
ip link set dev "$INTERFACE" address "$ORIGINAL_MAC"
ip link set dev "$INTERFACE" up
