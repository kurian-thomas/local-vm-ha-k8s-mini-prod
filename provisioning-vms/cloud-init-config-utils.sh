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

  # --- SKELETON KEY ---                                                                                                                                                  │
  # Inject plaintext passwords and enable password auth temporarily for debugging                                                                                         │
  # │    yq -Y -i '                                                                                                                                                              │
  # │      .chpasswd = {                                                                                                                                                         │
  # │        "list": "root:password\nansible:password",                                                                                                                          │
  # │        "expire": false                                                                                                                                                     │
  # │      } |                                                                                                                                                                   │
  # │      .ssh_pwauth = true                                                                                                                                                    │
  # │    ' "$OUT_FILE"

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

verify_cloud_image() {
  IMAGE_BASE_URL="${IMAGE_URL%/*}"
  CHECKSUMS_DIR="/tmp/ubuntu-cloud-image-checksums"
  SHA256SUMS_PATH="$CHECKSUMS_DIR/SHA256SUMS"
  SHA256SUMS_SIG_PATH="$CHECKSUMS_DIR/SHA256SUMS.gpg"
  UBUNTU_IMAGE_KEY="D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81"

  if ! command -v gpg >/dev/null 2>&1; then
    echo "Error: gpg is required but not installed."
    exit 1
  fi

  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "Error: sha256sum is required but not installed."
    exit 1
  fi

  mkdir -p "$CHECKSUMS_DIR"
  curl -fsSL -o "$SHA256SUMS_PATH" "$IMAGE_BASE_URL/SHA256SUMS"
  curl -fsSL -o "$SHA256SUMS_SIG_PATH" "$IMAGE_BASE_URL/SHA256SUMS.gpg"

  if ! gpg --list-keys "$UBUNTU_IMAGE_KEY" >/dev/null 2>&1; then
    gpg --keyid-format long --keyserver hkp://keyserver.ubuntu.com --recv-keys "$UBUNTU_IMAGE_KEY"
  fi

  gpg --keyid-format long --verify "$SHA256SUMS_SIG_PATH" "$SHA256SUMS_PATH"

  IMAGE_FILENAME="$(basename "$IMAGE_URL")"
  expected_hash="$(awk -v file="$IMAGE_FILENAME" '$2 ~ file {gsub(/^\*/, "", $2); if ($2==file) {print $1; exit}}' "$SHA256SUMS_PATH")"
  if [ -z "$expected_hash" ]; then
    echo "Error: checksum entry not found for $IMAGE_FILENAME."
    exit 1
  fi

  actual_hash="$(sudo sha256sum "$BASE_IMAGE_PATH" | awk '{print $1}')"
  if [ "$expected_hash" != "$actual_hash" ]; then
    echo "Error: checksum mismatch for $BASE_IMAGE_PATH."
    exit 1
  fi

  echo "==> Cloud image checksum verified."
}
