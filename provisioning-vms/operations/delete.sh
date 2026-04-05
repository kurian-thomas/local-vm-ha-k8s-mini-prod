#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_ROOT/base-config-vars.sh"

echo "==> Starting VM cleanup..."

for NODE_INFO in "${NODES[@]}"; do
  read -r HOSTNAME RAM VCPU <<< "$NODE_INFO"
  echo "==> Deleting $HOSTNAME..."

  # Destroy (stop) the VM if running
  if sudo virsh domstate "$HOSTNAME" &>/dev/null; then
    sudo virsh destroy "$HOSTNAME" 2>/dev/null || true
    sudo virsh undefine "$HOSTNAME" --remove-all-storage 2>/dev/null || true
    echo "    VM $HOSTNAME undefined and storage removed via virsh."
  else
    echo "    VM $HOSTNAME not found in virsh, skipping."
  fi

  # Remove qcow2 disk image (belt-and-suspenders in case --remove-all-storage missed it)
  if [ -f "$VM_DIR/$HOSTNAME.qcow2" ]; then
    sudo rm -f "$VM_DIR/$HOSTNAME.qcow2"
    echo "    Removed $VM_DIR/$HOSTNAME.qcow2"
  fi

  # Remove cloud-init seed ISO
  if [ -f "$VM_DIR/$HOSTNAME-seed.iso" ]; then
    sudo rm -f "$VM_DIR/$HOSTNAME-seed.iso"
    echo "    Removed $VM_DIR/$HOSTNAME-seed.iso"
  fi

  # Remove temporary cloud-init files
  sudo rm -f "/tmp/${HOSTNAME}-user-data.yaml"
  sudo rm -f "/tmp/${HOSTNAME}-meta-data.yaml"
  echo "    Removed /tmp cloud-init files for $HOSTNAME"

  echo "==> $HOSTNAME deleted."
done

echo ""
echo "==> All VMs deleted. Remaining virsh domains:"
sudo virsh list --all
