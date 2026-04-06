mkdir -p ~/.kube
ssh -i ~/.ssh/k8s_ansible_key ansible@192.168.122.245 "sudo cp /etc/kubernetes/admin.conf /home/ansible/config && sudo chown ansible:ansible /home/ansible/config"
scp -i ~/.ssh/k8s_ansible_key ansible@192.168.122.245:/home/ansible/config ~/.kube/config

watch -n 2 kubectl get nodes

# simulate outage in a different terminal, above watch will eventually show not ready
sudo virsh destroy master-1

# Node port, even though master is down it should reach the pods
curl http://192.168.122.200:32286 

# master must start and rejoin cluster, watch should show ready
sudo virsh start master-1
