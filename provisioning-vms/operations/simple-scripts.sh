#!/bin/bash

# Release all ips from default dhcp releases
sudo virsh net-dhcp-leases default | awk '
NR > 2 && $4 == "ipv4" {
    mac = $3
    ip = $5
    # Strip the CIDR notation (e.g., /24) from the IP address
    sub(/\/.*/, "", ip)
    
    # Construct the command
    cmd = "sudo dhcp_release virbr0 " ip " " mac
    
    # Print what is happening and execute it
    print "Releasing: " ip " (" mac ")"
    system(cmd)
}'
