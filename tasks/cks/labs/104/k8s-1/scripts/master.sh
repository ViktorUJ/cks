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

# Стартовая уязвимость для задания 6: секрет передаётся приложению через env/envFrom,
# что оставляет его в /proc/1/environ и в выводе describe/logs любого, кто может делать
# kubectl exec или читать логи Pod.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
  namespace: security-104
type: Opaque
stringData:
  DB_PASSWORD: "training-only-password"
---
apiVersion: v1
kind: Pod
metadata:
  name: app-vulnerable
  namespace: security-104
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    envFrom:
    - secretRef:
        name: db-creds
EOF

# Стартовая уязвимость для задания 7: скрытые пути privilege escalation через RBAC verbs
# impersonate/escalate/bind и certificatesigningrequests/approval, а не через wildcard
# resources/verbs (это уже задание 4). ServiceAccount имеет минимальный явный набор прав
# на первый взгляд, но impersonate/escalate позволяют получить куда больше эффективных
# прав, чем показывает сам ClusterRole.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: build-agent
  namespace: security-104
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: build-agent-hidden-privesc
rules:
- apiGroups: [""]
  resources: ["users", "groups", "serviceaccounts"]
  verbs: ["impersonate"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles"]
  verbs: ["bind", "escalate"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/approval"]
  verbs: ["update"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["signers"]
  resourceNames: ["kubernetes.io/kube-apiserver-client"]
  verbs: ["approve"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: build-agent-hidden-privesc
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: build-agent-hidden-privesc
subjects:
- kind: ServiceAccount
  name: build-agent
  namespace: security-104
EOF

echo "*** CKS lab 104 bootstrap is ready ***"
