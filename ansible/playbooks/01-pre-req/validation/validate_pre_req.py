#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path
import socket
import re


def run_cmd(cmd):
    """Runs a shell command and returns stdout."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode


def check_step(name, condition, error_msg):
    if condition:
        print(f"✅ {name}")
        return True
    else:
        print(f"❌ {name} - FAILED: {error_msg}")
        return False


def validate():
    print("--- Starting Kubernetes Node Validation ---")
    all_passed = []

    # 1. Swap Check
    swap_out, _ = run_cmd("swapon --show --noheadings")
    all_passed.append(
        check_step("Swap is disabled", swap_out == "", "Swap is still active.")
    )

    # 2. Kernel Modules
    modules = ["overlay", "br_netfilter"]
    with open("/proc/modules", "r") as f:
        loaded_modules = f.read()
    for mod in modules:
        all_passed.append(
            check_step(
                f"Module {mod} loaded",
                mod in loaded_modules,
                f"Module {mod} not found in /proc/modules.",
            )
        )

    # 3. Sysctl Params
    sysctl_checks = {
        "net.bridge.bridge-nf-call-iptables": "1",
        "net.ipv4.ip_forward": "1",
    }
    for param, expected in sysctl_checks.items():
        val, _ = run_cmd(f"sysctl -n {param}")
        all_passed.append(
            check_step(
                f"Sysctl {param}", val == expected, f"Expected {expected}, got {val}"
            )
        )

    # 4. Containerd Status
    _, container_code = run_cmd("systemctl is-active --quiet containerd")
    all_passed.append(
        check_step("Containerd service", container_code == 0, "Service is not running.")
    )

    # 5. Binaries
    binaries = ["kubelet", "kubeadm", "kubectl"]
    for b in binaries:
        exists = Path(f"/usr/bin/{b}").exists() or Path(f"/usr/local/bin/{b}").exists()
        all_passed.append(
            check_step(
                f"Binary {b} exists", exists, f"{b} not found in standard paths."
            )
        )

    if all(all_passed):
        print("\n🚀 Node is ready for 'kubeadm init/join'!")
        sys.exit(0)
    else:
        print("\n⚠️  Node is NOT ready. Fix the errors above.")
        sys.exit(1)


if __name__ == "__main__":
    validate()
