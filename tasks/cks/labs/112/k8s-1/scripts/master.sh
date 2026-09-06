#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane / workload node CKS lab 112 bootstrap"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

# This is a one-node lab; workloads used to generate Falco events run on the control plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: runtime-112
---
apiVersion: v1
kind: Secret
metadata:
  name: audit-secret
  namespace: runtime-112
type: Opaque
stringData:
  token: cks-112-audit-value
EOF

# Стартовый ресурс для задания 8: HTTP-приёмник audit webhook. Развёрнут заранее, чтобы
# задание фокусировалось на конфигурации webhook backend kube-apiserver, а не на
# создании самого echo-сервера. Digest фиксирует конкретный образ.
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-receiver
  namespace: runtime-112
  labels:
    app: audit-receiver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audit-receiver
  template:
    metadata:
      labels:
        app: audit-receiver
    spec:
      automountServiceAccountToken: false
      containers:
      - name: receiver
        image: ghcr.io/mendhak/http-https-echo:40
        ports:
        - containerPort: 8080
        env:
        - name: HTTP_PORT
          value: "8080"
---
apiVersion: v1
kind: Service
metadata:
  name: audit-receiver
  namespace: runtime-112
spec:
  selector:
    app: audit-receiver
  ports:
  - name: http
    port: 8080
    targetPort: 8080
EOF

# Falco and audit logging are intentionally not configured. The packages below only make
# the intended administration work reproducible on a fresh Ubuntu control-plane node.
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  ca-certificates curl gpg jq apt-transport-https
install -d -m 0755 /etc/kubernetes/audit /var/log/kubernetes/audit
chmod 0750 /var/log/kubernetes/audit

# Helm и install-kyverno нужны для задания 9 (интеграция с Supply Chain: admission policy
# на trusted registry). Kyverno намеренно НЕ установлен здесь - установка часть задания,
# как в лабе 111.
arch=$(dpkg --print-architecture)
HELM_VERSION="v3.17.3"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz" -o "$workdir/helm.tgz"
tar -xzf "$workdir/helm.tgz" -C "$workdir"
install -m 0755 "$workdir/linux-${arch}/helm" /usr/local/bin/helm

cat >/usr/local/bin/install-kyverno <<'KYVERNO_EOF'
#!/usr/bin/env bash
set -euo pipefail
# Kyverno 1.19 / chart 3.9.0: та же версия, что в лабе 111.
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace \
  --version 3.9.0 \
  --set admissionController.replicas=1 \
  --wait --timeout 5m
KYVERNO_EOF
chmod 0755 /usr/local/bin/install-kyverno

install -d -m 0755 /var/work/tests/artifacts/9

echo "*** CKS lab 112 prerequisites are ready: namespace runtime-112 and audit-secret"
