#!/bin/bash

create-user-data-inject-file() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-user-data.yaml"

  echo "==> Creating base user-data for $HOSTNAME"
  cp "$CLOUD_CONFIG_TEMPLATE" "$OUT_FILE"

  # yq requires the variable to be exported locally to use env.SSH_PUB_KEY
  export SSH_PUB_KEY
  yq -i '.users[0].ssh_authorized_keys = [strenv(SSH_PUB_KEY)]' "$OUT_FILE"
}

append-runcmd() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-user-data.yaml"

  echo "==> Injecting runcmd for $HOSTNAME"
  
  export HOSTNAME
  yq -i '
    .runcmd += [
      "echo Running cloud-init on " + strenv(HOSTNAME),
      "hostnamectl set-hostname " + strenv(HOSTNAME)
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
  yq -i '
  ."instance-id" = strenv(HOSTNAME) |
  ."local-hostname" = strenv(HOSTNAME)
  ' "$OUT_FILE"
}

append-env-vars() {
  local HOSTNAME=$1
  local OUT_FILE="/tmp/${HOSTNAME}-user-data.yaml"

  echo "==> Injecting environment variables into $HOSTNAME"

  # Ensure the variable is exported so yq can see it
  export VIP_ADDRESS

  # We use 'append: true' so we don't overwrite existing entries in /etc/environment
  yq -i '
  .write_files += [{
    "path": "/etc/environment",
    "content": "VIP_ADDRESS=" + strenv(VIP_ADDRESS) + "\n",
    "append": true
  }]
  ' "$OUT_FILE"
}

# curl -sL https://cloud-images.ubuntu.com/noble/current/SHA256SUMS | grep "noble-server-cloudimg-amd64.img"
# # Force a fresh download of the image before verifying
# wget -O /var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
verify_cloud_image() {
  IMAGE_BASE_URL="${IMAGE_URL%/*}"
  UBUNTU_IMAGE_KEY="D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81"

  # 1. Prerequisite checks
  if ! command -v gpg >/dev/null 2>&1; then
    echo "Error: gpg is required but not installed."
    exit 1
  fi

  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "Error: sha256sum is required but not installed."
    exit 1
  fi

  # 2. Use mktemp for a secure, unique temporary directory
  CHECKSUMS_DIR=$(mktemp -d -t ubuntu-checksums-XXXXXX)
  # Ensure cleanup of the temp directory on script exit
  trap 'rm -rf "$CHECKSUMS_DIR"' EXIT

  SHA256SUMS_PATH="$CHECKSUMS_DIR/SHA256SUMS"
  SHA256SUMS_SIG_PATH="$CHECKSUMS_DIR/SHA256SUMS.gpg"

  echo "Downloading checksum files..."
  curl -fsSL -o "$SHA256SUMS_PATH" "$IMAGE_BASE_URL/SHA256SUMS"
  curl -fsSL -o "$SHA256SUMS_SIG_PATH" "$IMAGE_BASE_URL/SHA256SUMS.gpg"

  # 3. Fetch GPG key if missing
  if ! gpg --list-keys "$UBUNTU_IMAGE_KEY" >/dev/null 2>&1; then
    echo "Fetching Ubuntu Cloud Image GPG key..."
    gpg --keyid-format long --keyserver hkp://keyserver.ubuntu.com --recv-keys "$UBUNTU_IMAGE_KEY" || {
      echo "Error: Failed to fetch GPG key."
      exit 1
    }
  fi

  # 4. CRITICAL FIX: Halt execution if GPG verification fails
  echo "Verifying GPG signature..."
  if ! gpg --keyid-format long --verify "$SHA256SUMS_SIG_PATH" "$SHA256SUMS_PATH"; then
    echo "Error: GPG signature verification failed! The checksum file may be compromised."
    exit 1
  fi

  # 5. Extract expected hash
  IMAGE_FILENAME="$(basename "$IMAGE_URL")"
  # Cleaner extraction: grep for the exact filename, grab the first column (the hash)
  expected_hash="$(grep "[ *]$IMAGE_FILENAME\$" "$SHA256SUMS_PATH" | awk '{print $1}')"

  if [ -z "$expected_hash" ]; then
    echo "Error: Checksum entry not found for $IMAGE_FILENAME."
    exit 1
  fi

  # 6. Verify actual hash
  echo "Calculating local file hash..."
  actual_hash="$(sudo sha256sum "$BASE_IMAGE_PATH" | awk '{print $1}')"

  if [ "$expected_hash" != "$actual_hash" ]; then
    echo "Error: Checksum mismatch for $BASE_IMAGE_PATH."
    echo "Expected: $expected_hash"
    echo "Actual:   $actual_hash"
    exit 1
  fi

  echo "==> Cloud image checksum verified successfully."
}
