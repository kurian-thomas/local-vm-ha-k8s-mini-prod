#!/usr/bin/env bash

# Exit on error
set -euo pipefail

NETWORK="default"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"

echo "Fetching DHCP leases from libvirt network: $NETWORK..."

# Get list of IPv4 addresses (strip CIDR)
ips=$(sudo virsh net-dhcp-leases "$NETWORK" \
  | awk '/ipv4/ {print $5}' \
  | cut -d/ -f1)

if [[ -z "$ips" ]]; then
  echo "No IP addresses found."
  exit 0
fi

echo "Processing hosts..."
echo

for ip in $ips; do
  echo "→ $ip"

  # Remove old host key (ignore errors if not present)
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true

  # Fetch and add new host key
  ssh-keyscan -H "$ip" >> "$KNOWN_HOSTS_FILE" 2>/dev/null

  echo "  Updated known_hosts"
done

echo
echo "Done. All host keys refreshed."
