# get node port of traifk
kubectl --kubeconfig /etc/kubernetes/admin.conf get svc whoami-test -o jsonpath='{.spec.ports[0].nodePort}'
