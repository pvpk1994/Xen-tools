#!/bin/bash

# only root user privileges
if [[ $EUID -ne 0 ]]; then
	echo "Script can only be run as a root!"
	exit 1
fi

# Let's limit to only a single tap device for now
TAP_DEVICE="tap0"

# Assuming bridge xenbr0 is already setup
BRIDGE="xenbr0"

# This script assumes xenbr0 bridge is setup and configured
# i.e., brctl show should display 'xenbr0' under bridge name
echo "[*] Creating TAP device: $TAP_DEVICE"

# $USER needs to be root
ip tunap add dev "$TAP_DEVICE" mode tap user "$USER" || {
	echo "[-] Failed to create TAP device: '$TAP_DEVICE'"
	exit 1
}

# Bring up TAP device
echo "[*] Bringing up TAP device: $TAP_DEVICE"
ip link set "$TAP_DEVICE" up || {
	echo "[-] Failed to bring up TAP device: '$TAP_DEVICE'"
	exit 1
}

# Attach TAP to xenbr0 bridge
echo "[*] Attaching TAP device ('$TAP_DEVICE') to bridge ('$BRIDGE')"
brctl addif "$BRDIGE" "$TAP_DEVICE" || {
	echo "[-] Failed to attach TAP device to bridge"
	exit 1
}

# Confirm setup
echo "[*] Bridge confirmation:"
brctl show "$BRIDGE"

# TAP device's status
echo "[*] TAP device status:"
ip addr show "$TAP_DEVICE"

echo "[*] TAP and bridge configuration complete"


