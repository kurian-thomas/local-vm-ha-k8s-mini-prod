#!/bin/bash

check_ufw_virbr0_allow_rules() {
  echo "==> Checking UFW rules for virbr0..."

  IN_RULE_EXISTS=$(sudo ufw status | grep -q "Anywhere on virbr0.*ALLOW" && echo "yes" || echo "no")
  OUT_RULE_EXISTS=$(sudo ufw status | grep -q "Anywhere.*ALLOW OUT.*on virbr0" && echo "yes" || echo "no")

  if [[ "$IN_RULE_EXISTS" == "yes" && "$OUT_RULE_EXISTS" == "yes" ]]; then
    echo "✅ UFW already has both IN and OUT rules for virbr0"
  else
    echo "⚠️ UFW is missing some rules for virbr0. Please run the following:"
    echo ""
    [[ "$IN_RULE_EXISTS" == "no" ]] && echo "sudo ufw allow in on virbr0"
    [[ "$OUT_RULE_EXISTS" == "no" ]] && echo "sudo ufw allow out on virbr0"
    echo ""
    echo "Then reload UFW: sudo ufw reload"
    exit 1
  fi
}

check_ufw_nat_rules() {
  echo "==> Checking NAT rules in UFW..."

  if grep -q "MASQUERADE" /etc/ufw/before.rules; then
    echo "NAT already configured"
  else
    echo "To enable NAT for libvirt in UFW, add the following to /etc/ufw/before.rules
    at the top before the *filter section:

    # NAT for libvirt
    *nat
    :POSTROUTING ACCEPT [0:0]
    -A POSTROUTING -s 192.168.122.0/24 ! -o virbr0 -j MASQUERADE
    COMMIT

    Then reload UFW with: sudo ufw reload"
    exit 1
  fi
}

check_if_vms_can_access_the_internet() {
    echo "== ufw route access for virbr0 =="
    WAN_IF=$(ip route get 1.1.1.1 | awk '{for (i=1; i<=NF; i++) if ($i=="dev") print $(i+1); exit}')
    if [ -z "$WAN_IF" ]; then
      echo "missing: could not determine outbound interface"
      echo "ACTION: run:"
      echo "  ip route get 1.1.1.1" # stable cloudflare ip only for checking
      exit 1
    fi

    BRIDGE_CIDR=$(ip -o -4 addr show dev virbr0 | awk '{print $4}')
    if [ -z "$BRIDGE_CIDR" ]; then
      echo "missing: could not determine virbr0 subnet"
      echo "ACTION: check that the libvirt default network is running:"
      echo "  sudo virsh net-info default"
      echo "  sudo virsh net-start default"
      echo "  sudo virsh net-autostart default"
      echo "verify active status"
      echo "  sudo virsh net-info default"
      exit 1
    fi

    BRIDGE_IP=$(echo "$BRIDGE_CIDR" | cut -d/ -f1)
    PREFIX=$(echo "$BRIDGE_CIDR" | cut -d/ -f2)
    VM_SUBNET="$(echo "$BRIDGE_IP" | cut -d. -f1-3).0/$PREFIX"
    echo "detected outbound interface: $WAN_IF"
    echo "detected VM subnet: $VM_SUBNET"

    if sudo ufw status verbose | grep -E "ALLOW FWD" | grep -Fq "$VM_SUBNET on virbr0"; then
      echo "ok: UFW allows routed traffic from virbr0"
      return 0
    fi

    echo "missing: UFW does not allow routed traffic from virbr0 to $WAN_IF"
    echo "ACTION: run:"
    echo "  sudo ufw route allow in on virbr0 out on $WAN_IF from $VM_SUBNET"
    echo "  sudo ufw reload"
    exit 1
}

# Checks if DHCP assigns the IPs with a timeout
# Assumes Ipv4
wait_for_ips() {
    local timeout=$1
    # SECONDS is a built-in bash variable that tracks script execution time
    local end_time=$((SECONDS + timeout))
    
    echo "==> All VMs are booting. Waiting for IPs (Timeout: ${timeout}s)..."

    while [ $SECONDS -lt $end_time ]; do
        # Capture the current leases
        leases=$(sudo virsh net-dhcp-leases default)

        # Use grep to look for an IPv4 address pattern. 
        # This naturally ignores the table headers.
        if echo "$leases" | grep -qE '([0-9]{1,3}\.){3}[0-9]{1,3}'; then
            echo "==> IPs assigned!"
            echo "$leases"
            return 0
        fi

        sleep 2
    done

    echo "==> Error: Timeout of ${timeout}s reached waiting for IPs."
    return 1
}

delete_subnet_firewall_rule_info() {
  WAN_IF=$(ip route get 1.1.1.1 | awk '{for (i=1; i<=NF; i++) if ($i=="dev") print $(i+1); exit}')
  if [ -z "$WAN_IF" ]; then
    echo "missing: could not determine outbound interface"
    echo "ACTION: run:"
    echo "  ip route get 1.1.1.1" # stable cloudflare ip only for checking
    exit 1
  fi

  BRIDGE_CIDR=$(ip -o -4 addr show dev virbr0 | awk '{print $4}')
  if [ -z "$BRIDGE_CIDR" ]; then
    echo "missing: could not determine virbr0 subnet"
    echo "ACTION: check that the libvirt default network is running:"
    echo "  sudo virsh net-info default"
    echo "  sudo virsh net-start default"
    echo "  sudo virsh net-autostart default"
    echo "verify active status"
    echo "  sudo virsh net-info default"
    exit 1
  fi

  BRIDGE_IP=$(echo "$BRIDGE_CIDR" | cut -d/ -f1)
  PREFIX=$(echo "$BRIDGE_CIDR" | cut -d/ -f2)
  VM_SUBNET="$(echo "$BRIDGE_IP" | cut -d. -f1-3).0/$PREFIX"
  echo "detected outbound interface: $WAN_IF"
  echo "detected VM subnet: $VM_SUBNET"

  echo "sudo ufw route delete allow in on virbr0 out on $WAN_IF from $VM_SUBNET"
  echo "sudo ufw reload"
  echo "sudo ufw status numbered"
}
