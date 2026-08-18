#!/bin/bash
# Задание 3: Cilium через Helm в режиме aws-cni chaining, только на пуле cilium-demo.
set -u
helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1
helm repo update >/dev/null 2>&1

cat <<'EOF' > /tmp/cilium-values.yaml
cni:
  chainingMode: aws-cni
  exclusive: false
enableIPv4Masquerade: false
routingMode: native
nodeSelector:
  work_type: cilium-demo
tolerations:
  - key: dedicated
    operator: Equal
    value: cilium-demo
    effect: NoSchedule
operator:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
EOF

echo "=== helm install cilium 1.20.0 ==="
helm install cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml 2>&1 | tail -6

echo "=== rollout daemonset/cilium ==="
kubectl -n kube-system rollout status daemonset/cilium --timeout=300s 2>&1 | tail -5
echo "=== поды cilium ==="
kubectl get pods -n kube-system -l k8s-app=cilium -o wide 2>&1 | cut -c1-110
echo "=== operator ==="
kubectl get pods -n kube-system -l io.cilium/app=operator -o wide 2>&1 | cut -c1-110
echo "=== события/логи при проблемах ==="
kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].status.containerStatuses[*].state}' 2>/dev/null; echo
