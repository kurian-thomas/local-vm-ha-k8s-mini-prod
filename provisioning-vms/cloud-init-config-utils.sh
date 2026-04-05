#!/bin/bash

create-user-data-inject-file() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-user-data.yaml"

  echo "==> Creating base user-data for $HOSTNAME"
  cp "$CLOUD_CONFIG_TEMPLATE" "$OUT_FILE"

  # yq requires the variable to be exported locally to use env.SSH_PUB_KEY
  export SSH_PUB_KEY
  yq -Y -i '.users[0].ssh_authorized_keys = [env.SSH_PUB_KEY]' "$OUT_FILE"
}

append-runcmd() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-user-data.yaml"

  echo "==> Injecting runcmd for $HOSTNAME"
  
  export HOSTNAME
  yq -Y -i '
    .runcmd += [
      "echo Running cloud-init on \(env.HOSTNAME)",
      "hostnamectl set-hostname \(env.HOSTNAME)"
    ]
  ' "$OUT_FILE"

  # --- SKELETON KEY ---
  # Inject plaintext passwords and enable password auth temporarily for debugging
  yq -Y -i '
    .chpasswd = {
      "list": "root:password\nansible:password",
      "expire": false
    } |
    .ssh_pwauth = true
  ' "$OUT_FILE"

  # Restore #cloud-config at the very end
  sed -i '1i #cloud-config' "$OUT_FILE"
}

create-metadata-inject-file() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-meta-data.yaml"

  echo "==> Creating meta-data for $HOSTNAME"
  cp "$META_TEMPLATE" "$OUT_FILE"

  export HOSTNAME
  yq -Y -i '
    ."instance-id" = env.HOSTNAME |
    ."local-hostname" = env.HOSTNAME
  ' "$OUT_FILE"
}

append-env-vars() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-user-data.yaml"

  echo "==> Injecting environment variables into $HOSTNAME"

  # Ensure the variable is exported so yq can see it
  export VIP_ADDRESS

  # We use 'append: true' so we don't overwrite existing entries in /etc/environment
  yq -Y -i '
    .write_files += [{
      "path": "/etc/environment",
      "content": "VIP_ADDRESS=" + env.VIP_ADDRESS + "\n",
      "append": true
    }]
  ' "$OUT_FILE"
}
