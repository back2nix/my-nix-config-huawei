#!/usr/bin/env bash

INTERFACE=$1
NEW_MAC=$2

ip link set dev "$INTERFACE" down
ip link set dev "$INTERFACE" address "$NEW_MAC"
ip link set dev "$INTERFACE" up
