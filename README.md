# Xen-tools

Xen-tools is a straightforward lightweight Xen DomU's provisioning tool. It's central purpose is to
cater for installation of Debian-derived test VMs, that can be kicked-off from the command line.

The end-result of running <code>xen-create-image</code> is a configuration file that is recognizable
by Xen's xl toolstack.

Similarly, the tool also provides support for undoing the work of <code>xen-create-image</code>, which is
<code>xen-delete-image</code>. 


