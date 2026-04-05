#!/bin/bash

# --- Configuration ---
BASE_IMAGE="ubuntu-24.04-server-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
VM_DIR="/var/lib/libvirt/images"
BASE_IMAGE_PATH="$VM_DIR/$BASE_IMAGE"

TEMPLATE_DIR="$SCRIPT_DIR/template-config"
CLOUD_CONFIG_TEMPLATE="$TEMPLATE_DIR/cloud-config.yaml"
KUBE_VIP_TEMPLATE="$TEMPLATE_DIR/kube-vip.yaml"
META_TEMPLATE="$TEMPLATE_DIR/meta-data.yaml"
NETWORK_TEMPLATE="$TEMPLATE_DIR/network-config.yaml"

# Verify SSH key exists before setting the variable
if [ -f ~/.ssh/k8s_ansible_key.pub ]; then
  SSH_PUB_KEY=$(cat ~/.ssh/k8s_ansible_key.pub)
else
  echo "Error: SSH public key not found!"
  exit 1
fi

VIP_ADDRESS="192.168.122.200"

# Define Nodes: "Hostname RAM(MB) vCPUs"
NODES=(
  "master-1 4096 2"
  "master-2 4096 2"
  "master-3 4096 2"
  "worker-1 8192 4"
)
