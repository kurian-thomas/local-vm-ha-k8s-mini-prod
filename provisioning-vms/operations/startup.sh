#!/bin/bash

echo "==> Starting selected VMs..."

sudo virsh list --name --state-shutoff | grep -E '^(master-|worker-)' | while read -r vm; do
    echo "Starting $vm..."
    sudo virsh start "$vm"
done

echo "==> Start commands sent. Use 'virsh list --all' to monitor status."
