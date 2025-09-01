#!/bin/bash

# xen-create-image tool helps create PV,LV,VG needed for a VM
# Once the volume groups are created, the tool uses the below
# configuration options to build a .cfg file that is xl create ready

# xen-create-image argument walkthrough:
# hostname: Uses system's hostname to create .cfg in /etc/xen.
# NOTE: Hostname cannot have any special characters in them.
# dist: Uses debian distro's name that are supported by debootstrap
# mirror: This flag specifies the Debian/Ubuntu package that will be used
#	  during the guest OS installation via debootstrap
# size: Disk size of the VM image you want to create
# Memory: Sets RAM size (Default - 256MB)
# dir: This flag specifies the base dir in where Xen guest image & config files
#       are created.
# force: Forces overwriting existing images/volumes which would otherwise block
#	 guest creation.
# bootloader: Nullify the bootloader, else it will default to PyGrub
# kernel: Pass the kernel image provided via cmdline
# initrd: Pass the ramdisk image provided via cmdline
# Password: For 'root' username, set a custom password of $VM_NAME

# Only root user is allowed to run this script
if [[ $EUID -ne 0 ]]; then
	echo "This script has root-only privileges. Please switch over to sudo"
	exit 1
fi

# Usage checks
if [[ $# -ne 4 ]]; then
	echo "Usage: $0 <name of the VM> <RAM size of the VM image (in MB)> <kernel-image-path> <initrd-image-path>"
	exit 2
fi

VM_NAME="$1"
VM_SIZE="$2"
KERN_IMG="$3"
INITRD_IMG="$4"

# Cmdline args validations
# Hostname cannot have any special characters in them. Enforce this
if ! [[ "$VM_NAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9]{0,61}[a-zA-Z0-9])?$ ]]; then
	echo "Invalid hostname: '$VM_NAME'"
	exit 3
fi

if ! [[ "$VM_SIZE" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
	echo "Invalid VM size: '$VM_SIZE' is not a number"
	exit 3
fi

if [[ ! -f "$KERN_IMG" ]]; then
	echo "Kernel image not found: $KERN_IMG"
	exit 3
fi

if [[ ! -f "$INITRD_IMG" ]]; then
	echo "Initrd image not found: $INITRD_IMG"
	exit 3
fi

# Ensure all the loop devices are available and not taken up
losetup -D

xen-create-image				\
	--hostname="$VM_NAME" 			\
	--dist=bullseye				\
	--dhcp					\
	--mirror=http://deb.debian.org/debian/	\
	--memory="${VM_SIZE}MB"			\
	--dir=/etc/xen/				\
	--kernel="$KERN_IMG"			\
	--initrd="$INITRD_IMG"			\
	--password="$VM_NAME"			\
	--force
