#!/bin/bash
echo " *** master node cks mock3 k8s-12"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Install local path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml

# Install Istio and deploy  with demo profile
export ISTIO_VERSION=1.26.2
curl -L https://istio.io/downloadIstio | sh -
install -m 755 istio-1.26.2/bin/istioctl /usr/bin/
istioctl install --set profile=demo --skip-confirmation

# Add istioctl completion
echo "source <(istioctl completion bash)" | tee -a ~/.bashrc /home/ubuntu/.bashrc > /dev/null

# Init scenario
kubectl create namespace market
kubectl run tester --image=curlimages/curl:8.6.0 -- sleep 1d

kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/mock/03/k8s-12/scripts/app.yaml


