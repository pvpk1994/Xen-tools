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

# xen-delete-image on the other hand is useful to undo the actions of xen-create-image
# In short, the command shall erase the (*-disk.img, *-swap.img) along with the config file

# Only root user is allowed to run this script
if [[ $EUID -ne 0 ]]; then
	echo "This script has root-only privileges. Please switch over to sudo"
	exit 1
fi

update_vm_cfg() {
	local VM_NAME="$1"
	local KERN_IMG="$2"
	local INITRD_IMG="$3"
	local CFG_FILE="/etc/xen/${VM_NAME}.cfg"

	# Check if xen-create-image succeeded or not
	if [[ $? -ne 0 ]]; then
		echo "xen-create-image failed. Skipping ${VM_NAME}.cfg updates"
		return 2
	fi

	# If xen-create-image succeeds, check for vm_name.cfg validity
	if [[ ! -f "$CFG_FILE" ]]; then
		echo "VM config file not found: $CFG_FILE"
		return 2
	fi

	# Disable bootloader (PyGrub) option
	sed -i '/^bootloader *=/s/^/#/' "$CFG_FILE"

	# Add kernel and initrd images to VM.cfg, if not present
	if  grep -q '^kernel' "$CFG_FILE" || grep -q '^ramdisk' "$CFG_FILE"; then
		echo "kernel and ramdisk images already present"
		return 2
	else
		echo "kernel = \"$KERN_IMG\"" >> "$CFG_FILE"
		echo "ramdisk = \"$INITRD_IMG\"" >> "$CFG_FILE"
		echo "$CFG_FILE updated with kernel and initrd images"
	fi
}

echo "Choose an option:"
echo "1. Create VM config with xen-create-image"
echo "2. Erase VM config with xen-delete-image"
read -p "Enter 1 or 2: " choice

if [[ "$choice" == "1" ]]; then
	echo "Option 1 selected. Running ./vm_configure.sh for option 1"

	read -p "Enter name of the VM: " VM_NAME
	read -p "Enter RAM size of the VM image (in MB): " VM_SIZE
	read -p "Kernel Image (vmlinuz): " KERN_IMG
	read -p "INITRD image: " INITRD_IMG

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

	# Once here, configuration file should have been successfully generated
	update_vm_cfg "$VM_NAME" "$KERN_IMG" "$INITRD_IMG"

elif [[ "$choice" == "2" ]]; then
	echo "Option 2 selected. Running ./vm_configure.sh for option 2"

	read -p "Enter name of the VM: " VM_NAME

	if ! [[ "$VM_NAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9]{0,61}[a-zA-Z0-9])?$ ]]; then
		echo "Invalid hostname: '$VM_NAME'"
		exit 3
	fi

	xen-delete-image				\
		--dir="/etc/xen/domains/$VM_NAME"	\
		"$VM_NAME"

	if [[ -d "/etc/xen/domains/$VM_NAME" ]]; then
		echo "xen-delete-image --dir could not delete ${VM_NAME}/{disk,swap}.img"
		echo "Forcefully deleting them..."
		rm -rf "/etc/xen/domains/$VM_NAME"
		echo "Done."
	fi

else
	echo "Invalid choice. Please enter either 1 or 2"
	exit 1
fi
