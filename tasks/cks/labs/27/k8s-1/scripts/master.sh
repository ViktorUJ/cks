#!/bin/bash
echo " *** master node cks lab-27 k8s-1"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Installation of the ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/cloud/deploy.yaml

# Install local path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml

# Reinstalling cilium
cur_ver=$(cilium version | grep running | awk -F ':' '{print $2}' | sed 's/[[:space:]]//g')
cilium uninstall
cilium install --version $cur_ver --set authentication.mutual.spire.enabled=true --set authentication.mutual.spire.install.enabled=true

kubectl patch pvc spire-data-spire-server-0 -n cilium-spire --type='json' \
-p='[{"op": "add", "path": "/spec/storageClassName", "value": "local-path"}]'

echo "Waiting for ingress-nginx pods to be ready..."
kubectl wait --namespace ingress-nginx --for=condition=Ready pod --selector=app.kubernetes.io/component=controller --timeout=180s || { echo "Timed out waiting for ingress-nginx pods"; exit 1; }
echo "Ingress-nginx pods are ready."

kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/labs/27/k8s-1/scripts/app.yaml
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/labs/27/k8s-1/scripts/default-deny.yaml

kubectl patch svc ingress-nginx-controller -n ingress-nginx --type='json' -p='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}, {"op": "add", "path": "/spec/ports/0/nodePort", "value": 30800}]'

echo "127.0.0.1 myapp.local" >> /etc/hosts

