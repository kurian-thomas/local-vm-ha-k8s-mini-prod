#!/bin/bash

# --- Configuration ---
BASE_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMAGE="ubuntu-24.04-server-cloudimg-amd64.img"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
VM_DIR="/var/lib/libvirt/images"
BASE_IMAGE_PATH="$VM_DIR/$BASE_IMAGE"

TEMPLATE_DIR="$BASE_CONFIG_DIR/template-config"
CLOUD_CONFIG_TEMPLATE="$TEMPLATE_DIR/cloud-config.yaml"
KUBE_VIP_TEMPLATE="$TEMPLATE_DIR/kube-vip.yaml"
META_TEMPLATE="$TEMPLATE_DIR/meta-data.yaml"
NETWORK_TEMPLATE="$TEMPLATE_DIR/network-config.yaml"

# Read shared Ansible vars for a single source of truth
ROOT_DIR="$(cd "$BASE_CONFIG_DIR/.." && pwd)"
ANSIBLE_VARS_FILE="$ROOT_DIR/ansible/group_vars/all.yaml"

# Verify SSH key exists before setting the variable
if [ -f ~/.ssh/k8s_ansible_key.pub ]; then
  SSH_PUB_KEY=$(cat ~/.ssh/k8s_ansible_key.pub)
else
  echo "Error: SSH public key not found!"
  exit 1
fi

if [ "${REQUIRE_VIP:-}" = "true" ]; then
  if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required but not installed."
    exit 1
  fi

  if [ ! -f "$ANSIBLE_VARS_FILE" ]; then
    echo "Error: $ANSIBLE_VARS_FILE not found."
    exit 1
  fi

  VIP_ADDRESS="$(yq -r '.k8s_vip // empty' "$ANSIBLE_VARS_FILE")"
  if [ -z "$VIP_ADDRESS" ]; then
    echo "Error: k8s_vip not set in $ANSIBLE_VARS_FILE."
    exit 1
  fi
fi

# Define Nodes: "Hostname RAM(MB) vCPUs"
NODES=(
  "master-1 4096 2"
  "master-2 4096 2"
  "master-3 4096 2"
  "worker-1 8192 4"
)
