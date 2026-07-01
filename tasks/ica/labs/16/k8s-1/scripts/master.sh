#!/bin/bash
echo " *** master node ica lab-16 k8s-1 (Gateway API)"
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

# Kubernetes Gateway API CRDs (not bundled with Kubernetes by default).
# Istio implements the Gateway API and needs these CRDs installed.
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# Install Istio (default profile). The task is to configure ingress routing with
# the Kubernetes Gateway API (Gateway + HTTPRoute) — see README.MD.
istioctl install --set profile=default -y
