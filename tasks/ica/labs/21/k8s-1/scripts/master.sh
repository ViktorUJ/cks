#!/bin/bash
echo " *** master node ica lab-21 k8s-1 (Sidecar scoping)"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node so Istio and workloads can be scheduled
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

# Install Istio (default profile). By default every sidecar receives config for
# ALL services in the mesh. Scoping the proxy config with a Sidecar resource is
# the task of this lab — see README.MD.
istioctl install --set profile=default -y

# Deploy workloads in two namespaces (app and other).
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/21/k8s-1/scripts/1.yaml
