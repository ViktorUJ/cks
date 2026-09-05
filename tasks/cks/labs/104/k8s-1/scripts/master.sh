#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** master node cks lab 104 k8s-1"
while ! kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# Одноузловая лаборатория: обычные Pod должны планироваться на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

# Явно оставляем небезопасный старт для задания 5. Учащийся должен заменить true на false.
api_manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
if grep -q -- '--anonymous-auth=' "$api_manifest"; then
  sed -i 's/--anonymous-auth=[^[:space:]"]*/--anonymous-auth=true/g' "$api_manifest"
else
  sed -i '/- kube-apiserver$/a\    - --anonymous-auth=true' "$api_manifest"
fi

# После изменения static Pod API server может коротко перезапускаться.
until kubectl get --raw=/readyz >/dev/null 2>&1; do
  sleep 5
done

# Стартовая уязвимость для задания 4: cluster-wide wildcard-права.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: security-104
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: legacy-operator
  namespace: security-104
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: legacy-operator-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: legacy-operator-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: legacy-operator-admin
subjects:
- kind: ServiceAccount
  name: legacy-operator
  namespace: security-104
EOF

echo "*** CKS lab 104 bootstrap is ready ***"
