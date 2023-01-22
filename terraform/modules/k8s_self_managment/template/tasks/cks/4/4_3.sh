# Add two new namespaces

kubectl create ns dev-ns --kubeconfig=/root/.kube/config
kubectl create ns prod-a --kubeconfig=/root/.kube/config
kubectl create ns prod-b --kubeconfig=/root/.kube/config

# add user
sh -c "useradd -m -s /bin/bash dan ; echo "dan:danpassword" | chpasswd"
sh -c "useradd -m -s /bin/bash paul ; echo "paul:paulpassword" | chpasswd"

#
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

cd /root/
aws s3 cp s3://viktoruj-terraform-state-backet/lab . --recursive
