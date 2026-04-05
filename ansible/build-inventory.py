#!/usr/bin/env python3
import subprocess
import logging
import os

# Get the absolute path of the directory where THIS script is located
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

# Define absolute paths for our output files
LOG_PATH = os.path.join(SCRIPT_DIR, "inventory_builder.log")
INVENTORY_PATH = os.path.join(SCRIPT_DIR, "inventory.ini")

# 1. Configure the Logger to use the absolute path
logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)


def get_dhcp_leases():
    """Runs virsh to get the current DHCP leases."""
    logging.info("--- Starting new inventory build ---")
    logging.info("Executing 'virsh net-dhcp-leases default'...")
    try:
        result = subprocess.run(
            ["sudo", "virsh", "net-dhcp-leases", "default"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.splitlines()
    except Exception as e:
        logging.error(f"Failed to execute virsh command: {e}")
        print(f"Error: {e}. Check log for details.")
        return []


def generate_inventory():
    lines = get_dhcp_leases()
    if not lines:
        logging.warning("No lease data retrieved. Aborting build.")
        return

    masters = {}
    workers = {}

    logging.info("Parsing lease data...")

    # 2. Extract Data
    for line in lines:
        parts = line.split()
        if len(parts) >= 6 and parts[3] == "ipv4" and parts[5] != "-":
            ip = parts[4].split("/")[0]
            hostname = parts[5]

            # Sort and log discoveries
            if hostname.startswith("master"):
                masters[hostname] = ip
                logging.info(f"Discovered master node: {hostname} -> {ip}")
            elif hostname.startswith("worker"):
                workers[hostname] = ip
                logging.info(f"Discovered worker node: {hostname} -> {ip}")

    # 3. Write the Inventory File using the absolute path
    logging.info(f"Writing configuration to {INVENTORY_PATH}...")

    try:
        with open(INVENTORY_PATH, "w") as f:
            # Write Masters
            f.write("[masters]\n")
            for host in sorted(masters.keys()):
                f.write(f"{host} ansible_host={masters[host]}\n")
            f.write("\n")

            # Write Workers
            f.write("[workers]\n")
            for host in sorted(workers.keys()):
                f.write(f"{host} ansible_host={workers[host]}\n")
            f.write("\n")

            # Write Groups
            f.write("[k8s_cluster:children]\n")
            f.write("masters\n")
            f.write("workers\n\n")

            # Write Global Vars
            f.write("[all:vars]\n")
            f.write("ansible_user=ansible\n")
            f.write("ansible_ssh_private_key_file=~/.ssh/k8s_ansible_key\n")
            f.write("ansible_python_interpreter=/usr/bin/python3\n")

        logging.info("Inventory build completed successfully.")
        print(f"Success! Inventory updated at {INVENTORY_PATH}.")
        print(f"Check '{LOG_PATH}' for details.")

    except Exception as e:
        logging.error(f"Failed to write to {INVENTORY_PATH}: {e}")
        print("Failed to write inventory. Check log for details.")


if __name__ == "__main__":
    generate_inventory()
