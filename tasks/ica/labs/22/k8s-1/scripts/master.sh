#!/bin/bash
echo " *** master node ica lab-22 k8s-1 (TLS origination)"
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

# Create a self-signed cert for the "external", HTTPS-only backend and load it as
# a TLS secret. The backend (nginx) accepts ONLY TLS on port 8443, simulating an
# external service that requires TLS. Making the mesh originate TLS to it is the
# task of this lab — see README.MD.
cd /tmp
openssl req -x509 -newkey rsa:2048 -nodes -keyout tls.key -out tls.crt -days 3650 \
  -subj "/CN=httpsvc.external.svc.cluster.local" 2>/dev/null
kubectl create namespace external
kubectl create secret tls httpsvc-tls -n external --cert=/tmp/tls.crt --key=/tmp/tls.key

kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/22/k8s-1/scripts/1.yaml
