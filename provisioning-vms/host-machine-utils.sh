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
