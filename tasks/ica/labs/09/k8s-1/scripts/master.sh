#!/bin/bash
echo " *** master node ica lab-09 k8s-1 (ambient)"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

# Gateway API CRDs are required for ambient waypoint proxies (L7)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# Install Istio in AMBIENT mode:
#   - istiod (control plane)
#   - istio-cni (traffic redirection)
#   - ztunnel (per-node L4 proxy providing zero-trust mTLS, no sidecars)
istioctl install --set profile=ambient -y
