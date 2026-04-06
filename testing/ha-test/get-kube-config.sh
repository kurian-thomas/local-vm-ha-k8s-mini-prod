# check ansible group vars

mkdir -p ~/.kube
ssh -i ~/.ssh/k8s_ansible_key ansible@192.168.122.45 "sudo cp /etc/kubernetes/admin.conf /home/ansible/config && sudo chown ansible:ansible /home/ansible/config"
scp -i ~/.ssh/k8s_ansible_key ansible@192.168.122.45:/home/ansible/config ~/.kube/config

watch -n 2 kubectl get nodes

# get node port
ssh -i ~/.ssh/k8s_ansible_key ansible@192.168.122.62  \
"kubectl --kubeconfig /etc/kubernetes/admin.conf get svc whoami-test -o jsonpath='{.spec.ports[0].nodePort}'"

# simulate outage in a different terminal, above watch will eventually show not ready
sudo virsh destroy master-1

# Node port, even though master is down it should reach the pods
curl http://192.168.122.200:31519 

# master must start and rejoin cluster, watch should show ready
sudo virsh start master-1
