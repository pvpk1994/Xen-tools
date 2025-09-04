# Xen-tools

Xen-tools is a straightforward lightweight Xen DomU's provisioning tool. It's central purpose is to
cater for installation of Debian-derived test VMs, that can be kicked-off from the command line.

The end-result of running <code>xen-create-image</code> is a configuration file that is recognizable
by Xen's xl toolstack.

Similarly, the tool also provides support for undoing the work of <code>xen-create-image</code>, which is
<code>xen-delete-image</code>. 


### Configuring network in Xen's DomU

DomU brought up by configuring <code>xen-create-image</code> has VIF configured for host network bride <code>xenbr0</code>

However, on spinning up a DomU, it may happen that the guest VM fails to start network interface. 

Following steps can be taken to ensure network access to the DomU is restored.

- On spinning up DomU, a VIF is created and is linked to host network bridge via <code>xenbr0</code>.

	brctl show

	|bridge name|     bridge id         |  STP enabled |    interfaces        |
	|-----------|-----------------------|--------------|----------------------|
	|xenb0      |     8000.bec2d2935e73 |   no	   |			  |
	|xenbr0     |     8000.1afffa87021d |   no         |	enp162s0, vif44.0 |


- <code>vif44.0</code> indicates vif has been created successfully and configured to <code>xenbr0</code>

- Although, things are setup properly on the host, guest VM dmesg can still report the following:

		Failed to start raise network interfaces

- This usually suggests that guest VM's networking service could not bring up expected network interfaces during boot.

- Look at the system's network interfaces and their respective IP addresses:

		ip a 

- If any of the interfaces (example: <code>enX0</code>) are <code>DOWN</code>. Bring them <code>UP</code> using:

		sudo ip link set <interface-name> up

- Once the interface is <code>UP</code>, go to <code>/etc/network/interfaces</code> and make changes as follows:

		auto <interface-name>
		iface <interface-name> inet dhcp

- Restart the network service and this should restore the network access:

		sudo systemctl restart networking

### Configuring network in KVM's guest VM

With network bridge <code>xenbr0</code> setup, the ideal way to configure network access for KVM's guests is via TAP interfacing. 

<code>setup_tap_xenbr0.sh</code> helps in setting up a TAP device and configures the device with <code>xenbr0</code> bridge.

		./setup_tap_xenbr0.sh enable_tap_bridge

The above command sets up <code>TAP0</code> interface and configures it with <code>xenbr0</code>

		./setup_tap_xenbr0.sh disable_tap_bridge

This command helps in deconfiguring <code>TAP0</code> from <code>xenbr0</code> and then safely deletes <code>TAP0</code>.

Once the TAP-bridge configuration is complete, following changes are required to <code>launch_qemu.sh</code> script.

#### Modifications required to launch-qemu script

<code>vm_configure.sh</code> assists in setting up TAP device and configuring it with <code>xenbr0</code> bridge.

The following changes are therefore needed to launch-qemu script to be able to successfully launch KVM guest with TAP network interface:

		add_opts "-netdev tap,id=vmnic,ifname=tap0,script=no,downscript=no"
		add_opts "-device virtio-net-pci,netdev=vmnic"

#### Post KVM Guest VM launch

The guest VM may boot without network access and this is because the network interface (ex: enps0) might be down. 

		ip link set enps0 up
		dhclient enps0

The above <code>dhclient</code> tells the system to request a dynamic IP address for network interface <code>enps0</code> 

