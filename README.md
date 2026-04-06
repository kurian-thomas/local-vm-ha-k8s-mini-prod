# K8s Local VM Prod-ish setup learning

## Ansible Key-Pair Generation

Use ssh-keygen util with -t elleptic type cryptographic algorithm
-C comment (human readable identifier) -f file

```bash
ssh-keygen -t ed25519 -C "ansible_k8s_provisioning" -f ~/.ssh/k8s_ansible_key
```

## Run Provision script in the Repository

```bash
./provision.sh
```

# Ansible

## Setup Ansible Inventory

```bash
python ansible/build-inventory.py
```

## Test if Ansible user can access the Vms via ssh

```bash
# This sets up fingerprint for VM, run for all IPs during the first run
ssh -i ~/.ssh/k8s_ansible_key ansible@<IP>
```

## Test if Ansible can ping the whole cluster

```bash
ansible k8s_cluster -i ansible/inventory.ini -m ping
```

## Run Pre-req playbook

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/01-pre-req/main.yaml
```

## Validate ansible pre-req setup via script

```bash
ansible k8s_cluster -i ansible/inventory.ini \
-m ansible.builtin.script \
-a "executable=/usr/bin/python3 ansible/playbooks/01-pre-req/validation/validate_pre_req.py"
```

## Run Control-plane setup playbook

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/02-control-plane/main.yaml
```

## Validate on Master-1

```bash
ansible master-1 -i ansible/inventory.ini \
  -b \
  -m ansible.builtin.script \
  -a "executable=/usr/bin/python3 ansible/playbooks/02-control-plane/validation/validate_control_plane.py"
```

## Join Masters and works to the cluster

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/03-join-nodes/main.yaml
```

## Validate cluster setup

```bash
ansible master-1 -i ansible/inventory.ini \
  -b \
  -m ansible.builtin.script \
  -a "executable=/usr/bin/python3 ansible/playbooks/03-join-nodes/validation/validate_ha_join.py"
```
