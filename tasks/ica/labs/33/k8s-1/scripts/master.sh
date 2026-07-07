#!/bin/bash
echo " *** master node ica lab-33 k8s-1 (control plane performance & operations)"
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

# Install Istio (default profile). Discovery is cluster-wide by default (no
# discoverySelectors) and each proxy gets the full mesh config (no Sidecar
# scope) - the student narrows both as the task of this lab.
# Save the IstioOperator so it can be re-applied with discoverySelectors.
cat <<'EOF' > /root/istio-install.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
EOF
istioctl install -f /root/istio-install.yaml -y

# Pre-install OPA Gatekeeper (the admission controller). The student writes the
# ConstraintTemplate + Constraint that enforces an Istio deploy policy.
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.17.1/deploy/gatekeeper.yaml
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=180s || true
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-audit --timeout=180s || true

# Deploy the workloads across three namespaces:
#   - app    : injected + discovered, target for the Sidecar egress scope.
#   - shop   : injected + discovered, observation point / excluded by app scope.
#   - legacy : NOT injected and NOT labelled for discovery -> excluded once
#              discoverySelectors are enabled.
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
# Label istio-system so it stays discovered once the student enables
# discoverySelectors matching label mesh=enabled.
kubectl label ns istio-system mesh=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-153/tasks/ica/labs/33/k8s-1/scripts/1.yaml
