#!/bin/bash
echo " *** master node ica lab-34 k8s-1 (hardening & threat model)"
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

# Install Istio (default profile). mTLS is PERMISSIVE, egress is ALLOW_ANY and
# there is no authorization policy yet — the student hardens all of that.
istioctl install --set profile=default -y

# Pre-install OPA Gatekeeper (admission controller). The student writes the
# ConstraintTemplate + Constraint that blocks PeerAuthentication mode: DISABLE.
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.17.1/deploy/gatekeeper.yaml
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=180s || true
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-audit --timeout=180s || true

# Deploy the workloads:
#   app namespace (injected):
#     - frontend : ping_pong HTTP service (the protected workload)
#     - good     : curl client, ServiceAccount "good"  (should be allowed)
#     - bad      : curl client, ServiceAccount "bad"   (should be denied)
#     - ServiceAccount "mesh-editor" (used for the Istio-CRD RBAC task)
#   legacy namespace (NOT injected):
#     - legacy   : curl client with no sidecar (plaintext / sidecar-bypass tests)
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-153/tasks/ica/labs/34/k8s-1/scripts/1.yaml
