#!/bin/bash
echo " *** master node ica lab-32 k8s-1 (gRPC per-request load balancing)"
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

# Install Istio with the default profile (all traffic in this lab is in-mesh,
# client -> grpc-server, so no ingress gateway configuration is needed).
istioctl install --set profile=default -y

# Deploy the gRPC workload (viktoruj/ping_pong, PingPong.Echo returns the
# serving pod hostname):
#   - grpc-server : gRPC Echo/Health server, 3 replicas (the backends);
#   - grpc-client : same image, used to drive gRPC load.
# IMPORTANT: the grpc-server Service is intentionally created with a MIS-NAMED
# port ("tcp") so that Istio treats gRPC as raw L4 TCP and pins the single
# long-lived HTTP/2 connection to one pod. Fixing the port naming and adding
# retries/timeout is the task of this lab — see README.MD.
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/32/k8s-1/scripts/1.yaml
