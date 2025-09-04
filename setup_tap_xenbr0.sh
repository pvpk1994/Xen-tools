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

usage() {
	echo "$0 [flag]"
	echo "==============="
	echo "Available flags"
	echo "==============="
	echo "enable_tap_bridge	Setup TAP device and add to xenbr0 bridge"
	echo "disable_tap_bridge	Remove TAP device from bridge and delete TAP"
	exit 1
}

# Check if only one arg is provided
if [ "$#" -ne 1 ]; then
	usage
fi

enable_tap_bridge() {
	# Skip setting tap device if its already present
	if ip link show "$TAP_DEVICE" > /dev/null 2>&1; then
		echo "[-] '$TAP_DEVICE' already exists. Exiting..."
		exit 1
	fi

	# This script assumes xenbr0 bridge is setup and configured
	# i.e., brctl show should display 'xenbr0' under bridge name
	echo "[*] Creating TAP device: $TAP_DEVICE"

	# $USER needs to be root
	ip tuntap add dev "$TAP_DEVICE" mode tap user "$USER" || {
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
	brctl addif "$BRIDGE" "$TAP_DEVICE" || {
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
}

disable_tap_bridge() {
	# Firstly, check the existence of TAP_DEVICE
	if ! ip link show "$TAP_DEVICE" > /dev/null 2>&1; then
		echo "[-] Error: ${TAP_DEVICE} not found. Exiting..."
		exit 1
	fi

	# Step-1: Remove $TAP_DEVICE from xenbr0 brdige
	echo "[*] Removing ${TAP_DEVICE} from ${BRIDGE}"
	brctl delif "$BRIDGE" "$TAP_DEVICE"

	# Step-2: Bringing $TAP_DEVICE down...
	echo "[*] Bringing ${TAP_DEVICE} down..."
	ip link set "$TAP_DEVICE" down

	# Step-3: Delete the $TAP_DEVICE
	echo "[*] Deleting ${TAP_DEVICE}..."
	ip tuntap del dev "$TAP_DEVICE" mode tap

	echo "[*] ${TAP_DEVICE} has been removed from ${BRIDGE} and deleted"
}

# Case-check
case "$1" in
	enable_tap_bridge)
		enable_tap_bridge
		;;
	disable_tap_bridge)
		disable_tap_bridge
		;;
	*)
		usage
		;;
esac

