[English version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 - краткое решение

Любой реально полученный HTTP status `1xx–5xx` означает, что сетевой путь до IMDS существует.
`HTTPCODE:000` вместе с transport error/timeout означает отсутствие HTTP-ответа.
Конкретный HTTP status зависит от EC2 metadata options; не используйте конкретный status как признак сетевой доступности.

```bash
set -euo pipefail
IMDS=http://169.254.169.254/
IMDS_CIDR=169.254.169.254/32
kubectl delete ns cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true

kubectl run digest --image=viktoruj/ping_pong:latest --restart=Never
kubectl wait --for=condition=Ready pod/digest --timeout=120s
id=$(kubectl get pod/digest -o jsonpath='{.status.containerStatuses[0].imageID}')
digest=$(sed -n 's/.*@\(sha256:[a-f0-9]\{64\}\).*/\1/p' <<<"$id")
kubectl delete pod/digest
APP_IMAGE="viktoruj/ping_pong@$digest"
```

## 1. Приложение

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: cks-101
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: cks-101
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: app
          image: $APP_IMAGE
          ports:
            - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: cks-101
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: app
          image: $APP_IMAGE
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: cks-101
spec:
  selector:
    app: backend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
EOF
kubectl -n cks-101 rollout status deploy/frontend --timeout=120s
kubectl -n cks-101 rollout status deploy/backend --timeout=120s
BACKEND=http://$(kubectl -n cks-101 get endpoints backend -o jsonpath='{.subsets[0].addresses[0].ip}'):8080/
```

## 2. Default-deny и frontend → backend

```bash
# Функция для IMDS probe: возвращает curl exit code и HTTP code
imds() {
  kubectl -n "$1" exec "$2" -- sh -c \
    "curl -sS -o /dev/null --connect-timeout 2 --max-time 5 -w '%{exitcode} %{http_code}\\n' '$IMDS' || true"
}

# Функция для backend probe: проверяет HTTP reachability
backend_check() {
  kubectl -n cks-101 exec probe -- curl -sS -o /dev/null -w '%{exitcode} %{http_code}\n' --connect-timeout 2 --max-time 5 "$BACKEND" || true
}

# Создаём probe с label frontend до применения любых policy
kubectl -n cks-101 run probe --image=curlimages/curl:8.11.1 --restart=Never \
  --labels=app=frontend --command -- sleep 3600
kubectl -n cks-101 wait --for=condition=Ready pod/probe --timeout=90s

# Baseline 1: frontend -> backend ДО default-deny (должен быть успешным)
read backend_rc backend_code <<<"$(backend_check)"
[[ "$backend_rc" == 0 && "$backend_code" =~ ^[1-5][0-9]{2}$ ]] || { echo "ERROR: frontend->backend baseline failed"; exit 1; }
echo "BASELINE: frontend->backend OK (rc=$backend_rc code=$backend_code)"

# Baseline 2: frontend -> IMDS ДО default-deny (должен быть успешным)
read baseline_rc baseline_code <<<"$(imds cks-101 probe)"
[[ "$baseline_rc" == 0 && "$baseline_code" =~ ^[1-5][0-9]{2}$ ]] || { echo "ERROR: IMDS baseline failed"; exit 1; }
echo "BASELINE: frontend->IMDS OK (rc=$baseline_rc code=$baseline_code)"

# Baseline 3: независимый namespace без policy
kubectl create ns imds-control
kubectl -n imds-control run imds-control --image=curlimages/curl:8.11.1 --restart=Never \
  --command -- sleep 3600
kubectl -n imds-control wait --for=condition=Ready pod/imds-control --timeout=90s
read control_rc control_code <<<"$(imds imds-control imds-control)"
[[ "$control_rc" == 0 && "$control_code" =~ ^[1-5][0-9]{2}$ ]] || { echo "ERROR: imds-control baseline failed"; exit 1; }
echo "BASELINE: imds-control->IMDS OK (rc=$control_rc code=$control_code)"

# Применяем default-deny
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: cks-101
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF

# Даём время policy примениться
sleep 2

# После default-deny: frontend -> backend должен быть ЗАБЛОКИРОВАН
read deny_backend_rc deny_backend_code <<<"$(backend_check)"
[[ "$deny_backend_code" == 000 && "$deny_backend_rc" =~ ^(7|28)$ ]] || { echo "ERROR: backend should be denied after default-deny"; exit 1; }
echo "AFTER DENY: frontend->backend BLOCKED (rc=$deny_backend_rc code=$deny_backend_code)"

# После default-deny: frontend -> IMDS должен быть ЗАБЛОКИРОВАН
read deny_rc deny_code <<<"$(imds cks-101 probe)"
[[ "$deny_code" == 000 && "$deny_rc" =~ ^(7|28)$ ]] || { echo "ERROR: IMDS should be denied after default-deny"; exit 1; }
echo "AFTER DENY: frontend->IMDS BLOCKED (rc=$deny_rc code=$deny_code)"

# После default-deny: imds-control должен по-прежнему работать (независимый namespace)
read after_control_rc after_control_code <<<"$(imds imds-control imds-control)"
[[ "$after_control_rc" == 0 && "$after_control_code" =~ ^[1-5][0-9]{2}$ ]] || { echo "ERROR: imds-control should still work after default-deny"; exit 1; }
echo "AFTER DENY: imds-control->IMDS OK (rc=$after_control_rc code=$after_control_code)"

echo "=== Task 2 VERIFIED: baseline works, default-deny blocks cks-101, imds-control stays reachable ==="

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-to-backend
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-frontend
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF

kubectl -n cks-101 exec probe -- curl -fsS --connect-timeout 2 --max-time 5 "$BACKEND"
# Ответ приложения: разрешён только frontend → backend.

# === Task 3: Negative ingress verification (чтобы доказать точность политики) ===
# Создаём временную "чужую" identity без label=frontend
kubectl -n cks-101 run foreign-probe --image=curlimages/curl:8.11.1 --restart=Never \
  --labels=app=foreign --command -- sleep 3600
kubectl -n cks-101 wait --for=condition=Ready pod/foreign-probe --timeout=90s

# Даём временный egress к backend для foreign (проверяем что ingress отклоняет)
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: temp-foreign-egress
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: foreign
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
EOF
sleep 2

# Проверяем: foreign не может достичь backend, несмотря на свой egress
read foreign_rc foreign_code <<<"$(kubectl -n cks-101 exec foreign-probe -- sh -c \
  "curl -sS -o /dev/null -w '%{exitcode} %{http_code}\n' --connect-timeout 2 --max-time 5 '$BACKEND' || true")"
[[ "$foreign_code" == 000 && "$foreign_rc" =~ ^(7|28)$ ]] || { echo "ERROR: foreign should be denied at ingress"; exit 1; }
echo "TASK 3 VERIFIED: foreign identity BLOCKED at ingress (rc=$foreign_rc code=$foreign_code)"

# Удаляем временные ресурсы
kubectl -n cks-101 delete networkpolicy temp-foreign-egress --ignore-not-found
kubectl -n cks-101 delete pod foreign-probe --ignore-not-found
```

## 3. DNS и evidence IMDS

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-dns
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
kubectl -n cks-101 exec probe -- nslookup kubernetes.default.svc.cluster.local
# Имя должно разрешиться.

read deny_rc deny_code <<<"$(imds cks-101 probe)"

# Проверяем, что imds-control Pod существует (создан в задании 2)
if ! kubectl -n imds-control get pod imds-control >/dev/null 2>&1; then
  kubectl -n imds-control run imds-control --image=curlimages/curl:8.11.1 --restart=Never \
    --command -- sleep 3600
  kubectl -n imds-control wait --for=condition=Ready pod/imds-control --timeout=90s
fi
read control_rc control_code <<<"$(imds imds-control imds-control)"

# Верификация перед записью artifact
[[ "$deny_code" == "000" && "$deny_rc" =~ ^(7|28)$ ]] || {
  echo "ERROR: frontend IMDS probe is not a network deny: rc=$deny_rc code=$deny_code" >&2
  exit 1
}

[[ "$control_rc" == "0" && "$control_code" =~ ^[1-5][0-9]{2}$ ]] || {
  echo "ERROR: imds-control did not prove IMDS reachability: rc=$control_rc code=$control_code" >&2
  exit 1
}

mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/metadata.output <<EOF
target=$IMDS
imds_cidr=$IMDS_CIDR
baseline_CURL_EXIT:$baseline_rc
baseline_HTTPCODE:$baseline_code
control_CURL_EXIT:$control_rc
control_HTTPCODE:$control_code
deny_CURL_EXIT:$deny_rc
deny_HTTPCODE:$deny_code
level=network
EOF
# baseline/control дают HTTP; deny из cks-101 должен быть 7|28 и 000.
```

## 4. Legacy: AND peer и исключение IMDS `/32`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: cks-101-legacy
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-client
  namespace: cks-101-legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy-client
  template:
    metadata:
      labels:
        app: legacy-client
    spec:
      containers:
        - name: app
          image: curlimages/curl:8.11.1
          command:
            - sleep
            - "3600"
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-legacy-egress
  namespace: cks-101-legacy
spec:
  podSelector:
    matchLabels:
      app: legacy-client
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.169.254/32
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-legacy
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
          podSelector:
            matchLabels:
              app: legacy-client
      ports:
        - protocol: TCP
          port: 8080
EOF
kubectl -n cks-101-legacy rollout status deploy/legacy-client --timeout=120s
legacy=$(kubectl -n cks-101-legacy get pod -l app=legacy-client -o jsonpath='{.items[0].metadata.name}')

# === Task 6: AND semantics verification ===

# 1. Проверяем IMDS deny для actual legacy-client
read legacy_imds_rc legacy_imds_code <<<"$(imds cks-101-legacy "$legacy")"
[[ "$legacy_imds_code" == 000 && "$legacy_imds_rc" =~ ^(7|28)$ ]] || { echo "ERROR: legacy IMDS should be denied"; exit 1; }
echo "TASK 6: IMDS DENIED for actual legacy-client (rc=$legacy_imds_rc code=$legacy_imds_code)"

# 2. Проверяем что actual legacy-client ДОСТИГАЕТ backend
read legacy_backend_rc legacy_backend_code <<<"$(kubectl -n cks-101-legacy exec "$legacy" -- sh -c \
  "curl -sS -o /dev/null -w '%{exitcode} %{http_code}\n' --connect-timeout 2 --max-time 5 '$BACKEND' || true")"
[[ "$legacy_backend_rc" == 0 && "$legacy_backend_code" =~ ^[1-5][0-9]{2}$ ]] || { echo "ERROR: actual legacy should reach backend"; exit 1; }
echo "TASK 6: ACTUAL legacy-client -> backend ALLOWED (rc=$legacy_backend_rc code=$legacy_backend_code)"

# 3. Проверяем wrong-label Pod в cks-101-legacy (имеет egress к backend, но неверный label)
kubectl -n cks-101-legacy run wrong-label-probe --image=curlimages/curl:8.11.1 --restart=Never \
  --labels=app=wrong-label --command -- sleep 3600
kubectl -n cks-101-legacy wait --for=condition=Ready pod/wrong-label-probe --timeout=90s

# Используем namespaceSelector + podSelector для cross-namespace egress
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: temp-wrong-label-egress
  namespace: cks-101-legacy
spec:
  podSelector:
    matchLabels:
      app: wrong-label
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101
          podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
EOF
sleep 2
read wrong_label_rc wrong_label_code <<<"$(kubectl -n cks-101-legacy exec wrong-label-probe -- sh -c \
  "curl -sS -o /dev/null -w '%{exitcode} %{http_code}\n' --connect-timeout 2 --max-time 5 '$BACKEND' || true")"
[[ "$wrong_label_code" == 000 && "$wrong_label_rc" =~ ^(7|28)$ ]] || { echo "ERROR: wrong-label should be denied at ingress"; exit 1; }
echo "TASK 6: WRONG-LABEL denied at ingress (rc=$wrong_label_rc code=$wrong_label_code)"

# 4. Проверяем Pod с label=legacy-client в НЕПРАВИЛЬНОМ namespace (cks-101)
kubectl -n cks-101 run wrong-namespace-probe --image=curlimages/curl:8.11.1 --restart=Never \
  --labels=app=legacy-client --command -- sleep 3600
kubectl -n cks-101 wait --for=condition=Ready pod/wrong-namespace-probe --timeout=90s
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: temp-wrong-ns-egress
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: legacy-client
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
EOF
sleep 2
read wrong_ns_rc wrong_ns_code <<<"$(kubectl -n cks-101 exec wrong-namespace-probe -- sh -c \
  "curl -sS -o /dev/null -w '%{exitcode} %{http_code}\n' --connect-timeout 2 --max-time 5 '$BACKEND' || true")"
[[ "$wrong_ns_code" == 000 && "$wrong_ns_rc" =~ ^(7|28)$ ]] || { echo "ERROR: wrong-namespace should be denied at ingress"; exit 1; }
echo "TASK 6: WRONG-NAMESPACE denied at ingress (rc=$wrong_ns_rc code=$wrong_ns_code)"

# Удаляем временные ресурсы
kubectl -n cks-101-legacy delete pod wrong-label-probe --ignore-not-found
kubectl -n cks-101-legacy delete networkpolicy temp-wrong-label-egress --ignore-not-found
kubectl -n cks-101 delete pod wrong-namespace-probe --ignore-not-found
kubectl -n cks-101 delete networkpolicy temp-wrong-ns-egress --ignore-not-found

echo "=== Task 6 VERIFIED: IMDS deny + AND semantics confirmed ==="
```

## 5. hostNetwork: только зафиксировать результат

```bash
kubectl -n cks-101 run hostnetwork-probe --image=curlimages/curl:8.11.1 --restart=Never \
  --labels=app=frontend --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}' \
  --command -- sleep 3600
kubectl -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=90s
read host_rc host_code <<<"$(imds cks-101 hostnetwork-probe)"

mkdir -p /var/work/tests/artifacts/7
printf 'CURL_EXIT:%s\nHTTPCODE:%s\n' "$host_rc" "$host_code" \
  > /var/work/tests/artifacts/7/hostnetwork-metadata.output
cat > /var/work/tests/artifacts/7/comparison.txt <<EOF
task5_result=curl_exit=$deny_rc http_code=$deny_code
task7_result=curl_exit=$host_rc http_code=$host_code
environment-specific: результат зависит от CNI и узла.
EOF
# Не ожидайте фиксированный allow/deny: сравнение - лишь наблюдение среды.
```