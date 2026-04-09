<h1 align="center" border=0>
  K8s Local VM Mini-Prod(ish) setup
  <br>
</h1>

<div align="center">
  
  [![Language](https://img.shields.io/badge/Language-Python-3776AB?logo=python&logoColor=white)](#)
  [![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?logo=gnu-bash&logoColor=white)](#)
  [![Libvirt](https://img.shields.io/badge/Virtualization-Libvirt-FF6600?logo=libvirt&logoColor=white)](#)
  [![Ansible](https://img.shields.io/badge/Automation-Ansible-EE0000?logo=ansible&logoColor=white)](#)
  [![Kubernetes](https://img.shields.io/badge/Infrastructure-Kubernetes-326CE5?logo=kubernetes&logoColor=white)](#)
  [![containerd](https://img.shields.io/badge/Container_Runtime-containerd-575757?logo=containerd&logoColor=white)](#)
</div>

<div align="center">
  
  [![Author LinkedIn](https://img.shields.io/badge/Author-LinkedIn-0077B5?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/kurian-thomas-pulimoottil)
</div>


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
