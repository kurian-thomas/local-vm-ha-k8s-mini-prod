#!/usr/bin/env python3
import subprocess
import json
import sys
import os

# Explicitly set kubeconfig for the root user running the script via Ansible
os.environ["KUBECONFIG"] = "/etc/kubernetes/admin.conf"


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    RESET = "\033[0m"


def run_kubectl(cmd):
    """Executes a kubectl command and returns the parsed JSON."""
    try:
        result = subprocess.run(
            f"kubectl {cmd} -o json",
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"{Colors.RED}Error running kubectl command: {cmd}{Colors.RESET}")
        print(e.stderr)
        sys.exit(1)


def validate_nodes():
    print(f"{Colors.YELLOW}==> Validating Cluster Nodes...{Colors.RESET}")
    nodes_data = run_kubectl("get nodes")
    nodes = nodes_data.get("items", [])

    expected_masters = 3
    expected_workers = 1
    masters = 0
    workers = 0
    all_ready = True

    for node in nodes:
        name = node["metadata"]["name"]
        labels = node["metadata"]["labels"]
        conditions = node.get("status", {}).get("conditions", [])

        # Check if the Ready condition is True
        is_ready = any(
            c["type"] == "Ready" and c["status"] == "True" for c in conditions
        )

        if "node-role.kubernetes.io/control-plane" in labels:
            masters += 1
            role = "Master"
        else:
            workers += 1
            role = "Worker"

        status_str = (
            f"{Colors.GREEN}Ready{Colors.RESET}"
            if is_ready
            else f"{Colors.RED}NotReady{Colors.RESET}"
        )
        if not is_ready:
            all_ready = False

        print(f"  - {name} ({role}): {status_str}")

    if masters < expected_masters or workers < expected_workers:
        print(
            f"{Colors.RED}FAIL: Expected {expected_masters} masters and {expected_workers} workers. Found {masters} masters and {workers} workers.{Colors.RESET}"
        )
        return False

    if not all_ready:
        print(
            f"{Colors.RED}FAIL: Not all nodes have reached the 'Ready' state.{Colors.RESET}"
        )
        return False

    print(f"{Colors.GREEN}SUCCESS: All nodes are joined and Ready.{Colors.RESET}\n")
    return True


def validate_ha_pods():
    print(f"{Colors.YELLOW}==> Validating HA Control Plane Pods...{Colors.RESET}")
    pods_data = run_kubectl("get pods -n kube-system")
    pods = pods_data.get("items", [])

    # In a 3-node HA setup, we expect exactly 3 of each of these pods
    expected_components = [
        "kube-apiserver",
        "etcd",
        "kube-controller-manager",
        "kube-scheduler",
        "kube-vip",
    ]
    component_counts = {comp: 0 for comp in expected_components}

    for pod in pods:
        name = pod["metadata"]["name"]
        phase = pod.get("status", {}).get("phase", "Unknown")

        if phase == "Running":
            for comp in expected_components:
                if name.startswith(comp):
                    component_counts[comp] += 1
                    break

    success = True
    for comp, count in component_counts.items():
        if count == 3:
            print(f"  - {comp}: {Colors.GREEN}{count}/3 Running{Colors.RESET}")
        else:
            print(f"  - {comp}: {Colors.RED}{count}/3 Running{Colors.RESET}")
            success = False

    if success:
        print(
            f"{Colors.GREEN}SUCCESS: Control plane is Highly Available (Quorum achieved).{Colors.RESET}\n"
        )
    else:
        print(
            f"{Colors.RED}FAIL: Control plane is missing HA components.{Colors.RESET}\n"
        )

    return success


if __name__ == "__main__":
    print("\nStarting Phase 5 Validation (HA & Worker Join)...\n")

    nodes_ok = validate_nodes()
    pods_ok = validate_ha_pods()

    if nodes_ok and pods_ok:
        print(
            f"{Colors.GREEN}All Phase 5 validations passed! Your cluster is ready.{Colors.RESET}"
        )
        sys.exit(0)
    else:
        print(
            f"{Colors.RED}Validation failed. Check the output above to troubleshoot.{Colors.RESET}"
        )
        sys.exit(1)
