[English version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 — краткое решение

IMDS — реальный EC2 endpoint `169.254.169.254`; не подменяйте его и не запрашивайте metadata/credentials. HTTP (обычно `401`) означает доступ, `000` — сетевой deny.

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
kubectl -n cks-101 run probe --image=curlimages/curl:8.11.1 --restart=Never \
  --labels=app=frontend --command -- sleep 3600
kubectl -n cks-101 wait --for=condition=Ready pod/probe --timeout=90s

# Печатает: curl exit-code и HTTP code; 0/HTTP — allow, 7|28/000 — deny.
imds() {
  kubectl -n "$1" exec "$2" -- sh -c \
    "curl -sS -o /dev/null --connect-timeout 2 --max-time 5 -w '%{exitcode} %{http_code}\\n' '$IMDS' || true"
}
read baseline_rc baseline_code <<<"$(imds cks-101 probe)"
# До policy: baseline даёт HTTP-код (обычно 401) от реального IMDS.

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

kubectl create ns imds-control
kubectl -n imds-control run imds-control --image=curlimages/curl:8.11.1 --restart=Never \
  --command -- sleep 3600
kubectl -n imds-control wait --for=condition=Ready pod/imds-control --timeout=90s
read control_rc control_code <<<"$(imds imds-control imds-control)"

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
kubectl -n cks-101-legacy exec "$legacy" -- curl -fsS --connect-timeout 2 --max-time 5 "$BACKEND"
imds cks-101-legacy "$legacy"
# Backend отвечает; IMDS даёт 7|28 и 000: исключён literal 169.254.169.254/32.
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
# Не ожидайте фиксированный allow/deny: сравнение — лишь наблюдение среды.
```