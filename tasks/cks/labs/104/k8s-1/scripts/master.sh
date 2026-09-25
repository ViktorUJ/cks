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

# После изменения static Pod API server может коротко перезапускаться. Требуем
# несколько ПОДРЯД успешных проверок, а не одну - static Pod restart может дать короткое
# окно доступности между двумя циклами перезапуска, и один успешный readyz не гарантирует
# устойчивую готовность к следующему запросу (наблюдалось на практике: readyz проходил,
# а следующий kubectl apply сразу после получал "connection refused").
ready_streak=0
until [[ "$ready_streak" -ge 3 ]]; do
  if kubectl get --raw=/readyz >/dev/null 2>&1; then
    ready_streak=$((ready_streak + 1))
  else
    ready_streak=0
  fi
  sleep 2
done

# Дополнительная защита от того же транзиентного окна: любой apply, обращающийся к API
# во время ещё нестабильного static Pod restart, оборачиваем retry с backoff, а не
# полагаемся только на однократную проверку готовности выше.
kubectl_apply_retry() {
  local manifest="$1" attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if kubectl apply -f - <<<"$manifest"; then
      return 0
    fi
    echo "*** kubectl apply failed (attempt $attempt/10), retrying after a short wait..." >&2
    sleep 3
  done
  echo "*** FATAL: kubectl apply did not succeed after repeated retries" >&2
  return 1
}

# Стартовая уязвимость для задания 4: cluster-wide wildcard-права.
kubectl_apply_retry "$(cat <<'EOF'
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
)"

# Создание default ServiceAccount в новом namespace - асинхронная операция контроллера
# (не часть самого создания Namespace), поэтому без ожидания Pod ниже мог бы упасть с
# "serviceaccount default not found", даже с automountServiceAccountToken: false - API
# server всё равно проверяет существование объекта default SA при валидации Pod.
until kubectl get serviceaccount default -n security-104 >/dev/null 2>&1; do
  sleep 2
done

# Стартовая уязвимость для задания 6: секрет передаётся приложению через env/envFrom,
# что оставляет его в /proc/1/environ и в выводе describe/logs любого, кто может делать
# kubectl exec или читать логи Pod.
kubectl_apply_retry "$(cat <<'EOF'
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
)"

# Стартовая уязвимость для задания 7: скрытые пути privilege escalation через RBAC verbs
# impersonate/escalate/bind и certificatesigningrequests/approval, а не через wildcard
# resources/verbs (это уже задание 4). ServiceAccount имеет минимальный явный набор прав
# на первый взгляд, но impersonate/escalate позволяют получить куда больше эффективных
# прав, чем показывает сам ClusterRole.
kubectl_apply_retry "$(cat <<'EOF'
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
  verbs: ["create", "update", "bind", "escalate"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterrolebindings"]
  verbs: ["create", "update"]
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
)"

# Стартовая уязвимость для расширения задания 5: непреднамеренная cluster-wide
# ClusterRoleBinding, дающая read-доступ группе system:unauthenticated (то есть любому
# анонимному запросу без credentials вообще). Это ОТДЕЛЬНО от штатных kubeadm-биндингов
# вроде system:public-info-viewer (тоже привязан к system:unauthenticated, но даёт доступ
# ТОЛЬКО к non-resource URL /healthz и /version) - lab104-unintended-anonymous-access даёт
# полноценный RBAC read на pods/secrets/configmaps, что является намеренно lab-owned
# опасной находкой, а не штатным поведением kubeadm, и должно быть удалено студентом без
# затрагивания системных system:* bindings.
kubectl_apply_retry "$(cat <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: lab104-anonymous-debug-access
rules:
- apiGroups: [""]
  resources: ["pods", "secrets", "configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lab104-unintended-anonymous-access
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: lab104-anonymous-debug-access
subjects:
- kind: Group
  name: system:unauthenticated
  apiGroup: rbac.authorization.k8s.io
EOF
)"

# Стартовый fixture для задания 10: существующий Opaque Secret с двумя ключами, который
# студент должен прочитать через API, декодировать и повторно использовать в новом Secret.
kubectl_apply_retry "$(cat <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: legacy-config
  namespace: security-104
type: Opaque
stringData:
  SERVICE_USER: "svc-legacy-104"
  SERVICE_TOKEN: "tok-9f3ac104-legacy"
EOF
)"

# Стартовые fixtures для задания 11: existing Role в rbac-a с лишним verb (delete) и без
# требуемого verb (watch) - студент должен исправить именно этот набор verbs, а не
# создать новый Role с нуля. ConfigMap fixture в отдельном namespace rbac-b должен стать
# доступен ServiceAccount dev из rbac-a через НОВЫЙ Role+RoleBinding, созданные студентом
# уже в rbac-b (RoleBinding поддерживает subject из другого namespace, но scope прав
# остаётся ограничен namespace самого RoleBinding).
kubectl_apply_retry "$(cat <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-a
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev
  namespace: rbac-a
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-role
  namespace: rbac-a
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-role-binding
  namespace: rbac-a
subjects:
- kind: ServiceAccount
  name: dev
  namespace: rbac-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-role
---
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-b
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: shared-config
  namespace: rbac-b
data:
  environment: "lab104-rbac-b-fixture"
EOF
)"

# Стартовый fixture для задания 12: пустой namespace для onboarding нового
# сертификат-based пользователя через CSR. RBAC для него создаёт сам студент.
kubectl_apply_retry "$(cat <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: development
EOF
)"

echo "*** CKS lab 104 bootstrap is ready ***"
