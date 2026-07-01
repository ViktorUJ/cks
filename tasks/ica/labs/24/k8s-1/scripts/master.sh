#!/bin/bash
echo " *** master node ica lab-24 k8s-1 (Ambient waypoint + L7 authz)"
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

# Gateway API CRDs are required for waypoint proxies (L7).
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# Install Istio in AMBIENT mode: istiod + istio-cni + ztunnel (per-node L4 mTLS,
# no sidecars). Adding a waypoint proxy and an L7 AuthorizationPolicy is the task.
istioctl install --set profile=ambient -y

# Deploy the app and a client in the ambient namespace.
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-151/tasks/ica/labs/24/k8s-1/scripts/1.yaml
