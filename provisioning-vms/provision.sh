#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRE_VIP=true
source "$SCRIPT_DIR/base-config-vars.sh"
source "$SCRIPT_DIR/cloud-init-config-utils.sh"
source "$SCRIPT_DIR/host-machine-utils.sh"

# Host machine checks
check_ufw_virbr0_allow_rules
check_ufw_nat_rules

# Check for base image
if [ ! -f "$BASE_IMAGE_PATH" ]; then
  echo "==> Downloading Ubuntu 24.04 Cloud Image..."
  sudo curl -fsSL -o "$BASE_IMAGE_PATH" "$IMAGE_URL"
fi

verify_cloud_image

# Execute Provisioning
for NODE_INFO in "${NODES[@]}"; do
  read -r HOSTNAME RAM VCPU <<< "$NODE_INFO"

  echo "==> Preparing cloud-init files for $HOSTNAME... stored at /tmp/"
  
  create-user-data-inject-file $HOSTNAME
  append-env-vars $HOSTNAME

  append-runcmd "$HOSTNAME"
  create-metadata-inject-file $HOSTNAME

  echo "==> Provisioning $HOSTNAME..."
  
  # Create a copy-on-write virtual disk
  sudo qemu-img create \
    -f qcow2 \
    -F qcow2 \
    -b "$BASE_IMAGE_PATH" "$VM_DIR/$HOSTNAME.qcow2" 20G

  # Create the cloud-init ISO
  sudo cloud-localds --network-config="$NETWORK_TEMPLATE" \
  "$VM_DIR/$HOSTNAME-seed.iso" "/tmp/${HOSTNAME}-user-data.yaml" \
  "/tmp/${HOSTNAME}-meta-data.yaml"

  # Install the VM
  sudo virt-install \
      --name "$HOSTNAME" \
      --memory "$RAM" \
      --vcpus "$VCPU" \
      --os-variant ubuntu24.04 \
      --disk path="$VM_DIR/$HOSTNAME.qcow2",device=disk \
      --disk path="$VM_DIR/$HOSTNAME-seed.iso",device=cdrom \
      --network network=default,model=virtio \
      --graphics none \
      --import \
      --noautoconsole

  echo "==> $HOSTNAME provisioned."
done

echo "==> All VMs are booting. Waiting for IPs..."
sleep 20
sudo virsh net-dhcp-leases default
