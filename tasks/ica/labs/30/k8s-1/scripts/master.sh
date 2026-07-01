#!/bin/bash
echo " *** master node ica lab-30 k8s-1 (StatefulSet / headless services)"
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

# Install Istio (default profile).
istioctl install --set profile=default -y
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done

# Deploy the injected namespace and an in-mesh client. Deploying a StatefulSet
# behind a headless Service and reaching each replica by its stable identity
# under STRICT mTLS is the task of this lab — see README.MD.
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-151/tasks/ica/labs/30/k8s-1/scripts/1.yaml
