[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 — эталонное решение: NetworkPolicy

`NetworkPolicy` — allow-list. Metadata блокируется default-deny, пока ни одно egress rule не разрешает этот адрес.

## Задание 1

`latest` используется только для фактического pull и получения digest. Рабочие Deployments получают один immutable reference.

```bash
SOURCE_IMAGE="viktoruj/ping_pong:latest"
kubectl run digest-resolver --image="$SOURCE_IMAGE" --restart=Never
kubectl wait --for=condition=Ready pod/digest-resolver --timeout=120s

IMAGE_ID=$(kubectl get pod digest-resolver \
  -o jsonpath='{.status.containerStatuses[0].imageID}')
DIGEST=$(printf '%s\n' "$IMAGE_ID" \
  | sed -n 's/.*@\(sha256:[a-f0-9]\{64\}\).*/\1/p')
test -n "$DIGEST" || {
  echo "Не удалось извлечь digest из imageID: $IMAGE_ID" >&2
  exit 1
}

export PING_PONG_IMAGE="viktoruj/ping_pong@${DIGEST}"
kubectl delete pod digest-resolver
```

```yaml
# app.yaml
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
    matchLabels: {app: frontend}
  template:
    metadata:
      labels: {app: frontend}
    spec:
      containers:
        - name: app
          image: ${PING_PONG_IMAGE}
          ports: [{containerPort: 8080}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: cks-101
spec:
  replicas: 1
  selector:
    matchLabels: {app: backend}
  template:
    metadata:
      labels: {app: backend}
    spec:
      containers:
        - name: app
          image: ${PING_PONG_IMAGE}
          ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: cks-101
spec:
  selector: {app: backend}
  ports:
    - name: http
      protocol: TCP
      port: 8080
      targetPort: 8080
```

```bash
envsubst < app.yaml | kubectl apply -f -
kubectl -n cks-101 rollout status deployment/frontend
kubectl -n cks-101 rollout status deployment/backend
kubectl -n cks-101 get deploy frontend backend \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
kubectl -n cks-101 get endpoints backend
```

## Задание 2

```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: cks-101
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

```bash
kubectl apply -f default-deny.yaml
kubectl -n cks-101 get networkpolicy default-deny -o yaml
```

## Задание 3

```yaml
# frontend-backend.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-to-backend
  namespace: cks-101
spec:
  podSelector:
    matchLabels: {app: frontend}
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels: {app: backend}
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
    matchLabels: {app: backend}
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels: {app: frontend}
      ports:
        - protocol: TCP
          port: 8080
```

```bash
kubectl apply -f frontend-backend.yaml
BACKEND_IP=$(kubectl -n cks-101 get svc backend -o jsonpath='{.spec.clusterIP}')
kubectl -n cks-101 run verify-frontend --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=frontend --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/"
```

Временное разрешение egress для foreign открывает доступ только к backend, поэтому неудачный запрос проверяет ingress backend, а не egress default-deny.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: verify-foreign-egress
  namespace: cks-101
spec:
  podSelector:
    matchLabels: {app: foreign}
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels: {app: backend}
      ports:
        - protocol: TCP
          port: 8080
EOF
set +e
kubectl -n cks-101 run verify-foreign --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=foreign --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/"
foreign_rc=$?
set -e
kubectl -n cks-101 delete networkpolicy verify-foreign-egress
test "$foreign_rc" -ne 0
```

## Задание 4

```yaml
# allow-frontend-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-dns
  namespace: cks-101
spec:
  podSelector:
    matchLabels: {app: frontend}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - {protocol: UDP, port: 53}
        - {protocol: TCP, port: 53}
```

```bash
kubectl apply -f allow-frontend-dns.yaml
kubectl -n cks-101 run verify-dns --rm -i --restart=Never \
  --image=busybox:1.36.1 --labels=app=frontend --command -- \
  nslookup kubernetes.default.svc.cluster.local
kubectl -n cks-101 get networkpolicy allow-frontend-dns -o yaml
```

## Задание 5

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl -n cks-101 run verify-metadata --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=frontend --command -- \
  sh -c 'set +e; out=$(curl -sS -o /dev/null -w "HTTPCODE:%{http_code}" --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1); rc=$?; printf "CURL_EXIT:%s\n%s\n" "$rc" "$out"' \
  | tee /var/work/tests/artifacts/5/metadata.output

metadata_out=$(cat /var/work/tests/artifacts/5/metadata.output)
metadata_rc=$(printf '%s\n' "$metadata_out" | sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' | tail -1)
metadata_code=$(printf '%s\n' "$metadata_out" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -1)
case "$metadata_rc" in
  7) printf 'level=network outcome=tcp-connect-failure\n' ;;
  28) printf 'level=network outcome=timeout\n' ;;
  6) printf 'level=dns outcome=name-resolution-failure\n' ;;
  0) printf 'level=http outcome=response status=%s\n' "$metadata_code" ;;
  *) printf 'level=other outcome=curl-exit-%s\n' "$metadata_rc" ;;
esac | tee -a /var/work/tests/artifacts/5/metadata.output
test "$metadata_code" = 000
case "$metadata_rc" in 7|28) ;; *) exit 1 ;; esac
```

`curl -f` не используется: `401/403` означает, что endpoint сетево доступен.

## Задание 6

```yaml
# legacy.yaml
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
    matchLabels: {app: legacy-client}
  template:
    metadata:
      labels: {app: legacy-client}
    spec:
      containers:
        - name: app
          image: curlimages/curl:8.11.1
          command: ["sleep", "3600"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-ingress-from-legacy
  namespace: cks-101
spec:
  podSelector:
    matchLabels: {app: backend}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
          podSelector:
            matchLabels: {app: legacy-client}
      ports:
        - {protocol: TCP, port: 8080}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-legacy-egress
  namespace: cks-101-legacy
spec:
  podSelector:
    matchLabels: {app: legacy-client}
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: [169.254.169.254/32]
```

Селекторы в одном peer объединяются через AND. Следующий вариант неверен, потому что его два peer объединяются через OR:

```yaml
# Не применяйте: отдельные peer с namespaceSelector и podSelector объединяются через OR.
from:
  - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: cks-101-legacy}}
  - podSelector: {matchLabels: {app: legacy-client}}
```

```bash
kubectl apply -f legacy.yaml
kubectl -n cks-101-legacy rollout status deployment/legacy-client
BACKEND_IP=$(kubectl -n cks-101 get svc backend -o jsonpath='{.spec.clusterIP}')
kubectl -n cks-101-legacy run verify-legacy-allowed --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/"

# Неверная метка в legacy namespace имеет обычный egress, но должна быть отклонена ingress backend.
set +e
kubectl -n cks-101-legacy run verify-legacy-wrong-label --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=wrong-label --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/"
wrong_label_rc=$?
set -e

# Той же метке в cks-101 требуется временный egress, чтобы это была проверка ingress.
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: verify-local-legacy-egress
  namespace: cks-101
spec:
  podSelector:
    matchLabels: {app: legacy-client}
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels: {app: backend}
      ports:
        - {protocol: TCP, port: 8080}
EOF
set +e
kubectl -n cks-101 run verify-local-legacy --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/"
local_rc=$?
set -e
kubectl -n cks-101 delete networkpolicy verify-local-legacy-egress
test "$wrong_label_rc" -ne 0
test "$local_rc" -ne 0

kubectl -n cks-101-legacy run verify-legacy-external --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -ksS -o /dev/null -w 'HTTPCODE:%{http_code}' --max-time 5 https://1.1.1.1/"
set +e
kubectl -n cks-101-legacy run verify-legacy-metadata --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/"
legacy_metadata_rc=$?
set -e
test "$legacy_metadata_rc" -ne 0
```

## Задание 7

```yaml
# hostnetwork-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostnetwork-probe
  namespace: cks-101
  labels: {app: frontend}
spec:
  hostNetwork: true
  containers:
    - name: probe
      image: curlimages/curl:8.11.1
      command: ["sleep", "3600"]
```

```bash
kubectl apply -f hostnetwork-probe.yaml
kubectl -n cks-101 wait --for=condition=Ready pod/hostnetwork-probe --timeout=60s
mkdir -p /var/work/tests/artifacts/7
host_out=$(kubectl -n cks-101 exec hostnetwork-probe -- sh -c 'set +e; out=$(curl -sS -o /dev/null -w "HTTPCODE:%{http_code}" --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1); rc=$?; printf "CURL_EXIT:%s\n%s\n" "$rc" "$out"')
printf '%s\n' "$host_out" | tee /var/work/tests/artifacts/7/hostnetwork-metadata.output
host_rc=$(printf '%s\n' "$host_out" | sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' | tail -1)
host_code=$(printf '%s\n' "$host_out" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -1)
task5_out=$(cat /var/work/tests/artifacts/5/metadata.output)
task5_rc=$(printf '%s\n' "$task5_out" | sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' | tail -1)
task5_code=$(printf '%s\n' "$task5_out" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -1)
{
  echo "task5_result=curl_exit=${task5_rc:-missing} http_code=${task5_code:-missing}"
  echo "task7_result=curl_exit=${host_rc:-missing} http_code=${host_code:-missing}"
  echo "environment-specific observation; not a universal NetworkPolicy guarantee"
} > /var/work/tests/artifacts/7/comparison.txt
```

Поведение `hostNetwork` зависит от CNI и окружения; зафиксируйте наблюдение вместо утверждения универсального результата.

## Быстрая самопроверка

```bash
kubectl -n cks-101 get networkpolicy
kubectl -n cks-101-legacy get networkpolicy
check_result
```
