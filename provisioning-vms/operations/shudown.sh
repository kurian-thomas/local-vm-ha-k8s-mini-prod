#!/bin/bash

echo "==> Requesting graceful shutdown for selected VMs..."

#!/bin/bash

echo "==> Requesting graceful shutdown for selected VMs..."

# Get list of running VMs and filter by name
for vm in $(sudo virsh list --name --state-running | grep -E '^(master-|worker-)'); do
    echo "Shutting down $vm..."
    sudo virsh shutdown "$vm"
done

echo "==> Shutdown commands sent. Use 'virsh list --all' to monitor status."
