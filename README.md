# Xen-tools

Xen-tools is a straightforward lightweight Xen DomU's provisioning tool. It's central purpose is to
cater for installation of Debian-derived test VMs, that can be kicked-off from the command line.

The end-result of running <code>xen-create-image</code> is a configuration file that is recognizable
by Xen's xl toolstack.

Similarly, the tool also provides support for undoing the work of <code>xen-create-image</code>, which is
<code>xen-delete-image</code>. 


### Configuring network in DomU

DomU brought up by configuring <code>xen-create-image</code> has VIF configured for host network bride <code>xenbr0</code>

However, on spinning up a DomU, it may happen that the guest VM fails to start network interface. 

Following steps can be taken to ensure network access to the DomU is restored.

- On spinning up DomU, a VIF is created and is linked to host network bridge via <code>xenbr0</code>.

	brctl show

	bridge name     bridge id               STP enabled     interfaces
	xenb0           8000.bec2d2935e73       	no
	xenbr0          8000.1afffa87021d       	no      enp162s0
                                                        	vif44.0

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
