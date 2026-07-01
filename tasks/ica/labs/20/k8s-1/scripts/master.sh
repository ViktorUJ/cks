#!/bin/bash
echo " *** master node ica lab-20 k8s-1 (mTLS migration)"
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

# Install Istio (default profile). With no PeerAuthentication, mTLS is PERMISSIVE
# by default: mesh clients use mTLS and legacy plaintext clients still work.
# Migrating the app namespace to STRICT is the task of this lab — see README.MD.
istioctl install --set profile=default -y

# Deploy the app, an in-mesh client, and a legacy (no-sidecar) client.
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-151/tasks/ica/labs/20/k8s-1/scripts/1.yaml
