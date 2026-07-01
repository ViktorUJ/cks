#!/bin/bash
echo " *** master node ica lab-25 k8s-1 (Progressive delivery with Flagger)"
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

# Install Istio (default profile) + Prometheus (Flagger reads metrics from it).
istioctl install --set profile=default -y
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/prometheus.yaml

# Install Flagger (configured for the Istio provider, metrics from prometheus.istio-system).
kubectl apply -k github.com/fluxcd/flagger//kustomize/istio

# Public ingress gateway + the demo app (podinfo) + a load tester that generates
# traffic during the canary analysis.
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-151/tasks/ica/labs/25/k8s-1/scripts/1.yaml

kubectl create namespace test
kubectl label namespace test istio-injection=enabled --overwrite
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/podinfo?ref=main
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/tester?ref=main

# NOTE: the Canary resource that drives progressive delivery is the task of this
# lab — see README.MD.
