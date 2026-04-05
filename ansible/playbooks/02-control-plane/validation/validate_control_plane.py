#!/usr/bin/env python3
import subprocess
import sys
import time
from pathlib import Path


KUBECONFIG = "/etc/kubernetes/admin.conf"


def run_cmd(cmd, timeout=15):
    """Run a shell command with timeout."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "TIMEOUT", 1


def check_step(name, condition, error_msg):
    if condition:
        print(f"✅ {name}")
        return True
    else:
        print(f"❌ {name} - FAILED: {error_msg}")
        return False


def validate():
    print("\n--- 🚀 Phase 4 Control Plane Validation ---\n")
    all_passed = []

    # 1. Kubelet Service
    _, _, kubelet_code = run_cmd("systemctl is-active --quiet kubelet")
    all_passed.append(
        check_step("Kubelet service", kubelet_code == 0, "kubelet is not running")
    )

    # 2. Admin Config Exists
    admin_conf = Path(KUBECONFIG)
    all_passed.append(
        check_step(
            "admin.conf exists",
            admin_conf.exists(),
            f"{KUBECONFIG} not found",
        )
    )

    if not admin_conf.exists():
        print("\n⚠️ Cannot proceed without kubeconfig.")
        sys.exit(1)

    # Helper kubectl wrapper
    def kubectl(cmd):
        full_cmd = f"KUBECONFIG={KUBECONFIG} kubectl --request-timeout=10s {cmd}"
        return run_cmd(full_cmd, timeout=20)

    # 3. Core Pods Check
    print("\n⏳ Checking cluster pods...")
    pods_out, pods_err, pods_code = kubectl("get pods -A")

    if pods_code != 0:
        print("DEBUG kubectl error:", pods_err)

    all_passed.append(
        check_step(
            "kube-vip deployed",
            "kube-vip" in pods_out,
            "kube-vip pod not found",
        )
    )

    all_passed.append(
        check_step(
            "Calico/Tigera CNI deployed",
            ("calico" in pods_out.lower() or "tigera" in pods_out.lower()),
            "CNI pods not found",
        )
    )

    # 4. Node Readiness
    print("\n⏳ Waiting up to 120 seconds for node to become Ready...")

    node_ready = False
    nodes_out = ""
    nodes_err = ""

    for i in range(24):  # 24 * 5s = 120s
        nodes_out, nodes_err, code = kubectl("get nodes --no-headers")

        if code == 0 and nodes_out:
            for line in nodes_out.splitlines():
                if " Ready " in line:
                    node_ready = True
                    break

        if node_ready:
            break

        print(f"   Attempt {i + 1}/24: node not ready yet...")
        time.sleep(5)

    if not node_ready:
        print("\nDEBUG nodes output:\n", nodes_out)
        print("DEBUG nodes error:\n", nodes_err)

    all_passed.append(
        check_step(
            "At least one node is Ready",
            node_ready,
            "No nodes reached Ready state",
        )
    )

    # Final Result
    if all(all_passed):
        print("\n🎉 SUCCESS: Control Plane is fully initialized and Ready!\n")
        sys.exit(0)
    else:
        print("\n⚠️ VALIDATION FAILED. Review errors above.\n")
        sys.exit(1)


if __name__ == "__main__":
    validate()

