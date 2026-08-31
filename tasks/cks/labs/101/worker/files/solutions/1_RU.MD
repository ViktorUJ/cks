[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 101 - эталонное решение: NetworkPolicy default-deny и защита metadata

> `NetworkPolicy` является allow-list. У native Kubernetes `NetworkPolicy` нет правила
> `deny` для отдельного CIDR: доступ к `169.254.169.254` блокирует egress default-deny,
> потому что ни одна allow policy не включает этот адрес.

## Задание 1. Namespace, frontend/backend и Service

Сохраните следующий манифест как `app.yaml` и примените его:

```yaml
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
          image: viktoruj/ping_pong:latest
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
          image: viktoruj/ping_pong:latest
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
      protocol: TCP
```

```bash
kubectl apply -f app.yaml
kubectl -n cks-101 rollout status deployment/frontend
kubectl -n cks-101 rollout status deployment/backend
kubectl -n cks-101 get pods,svc,endpoints
```

## Задание 2. Default-deny ingress и egress

```yaml
# default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress-egress
  namespace: cks-101
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

```bash
kubectl apply -f default-deny.yaml
kubectl -n cks-101 get networkpolicy
```

## Задание 3. Разрешить только frontend -> backend:8080

Для соединения нужны обе стороны: egress frontend и ingress backend.

```yaml
# frontend-backend.yaml
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
```

```bash
kubectl apply -f frontend-backend.yaml
BACKEND_IP=$(kubectl -n cks-101 get svc backend -o jsonpath='{.spec.clusterIP}')
mkdir -p /var/work/tests/artifacts/3
kubectl -n cks-101 run check-frontend --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=frontend --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/" \
  | tee /var/work/tests/artifacts/3/frontend.txt
kubectl -n cks-101 run check-foreign --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=foreign --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/" \
  > /var/work/tests/artifacts/3/foreign.txt 2>&1 || true
```

Временный client Pod имеет ту же security identity (`app=frontend`), что и frontend.
Это необходимо, потому что минимальный образ `viktoruj/ping_pong:latest` не содержит shell
и `curl`.

## Задание 4. Разрешить DNS только к kube-dns

```yaml
# allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: cks-101
spec:
  podSelector: {}
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
```

```bash
kubectl apply -f allow-dns.yaml
mkdir -p /var/work/tests/artifacts/4
kubectl -n cks-101 run check-dns --rm -i --restart=Never \
  --image=busybox:1.36.1 --labels=app=frontend --command -- \
  nslookup kubernetes.default.svc.cluster.local \
  | tee /var/work/tests/artifacts/4/dns.txt
```

## Задание 5. Проверить защиту metadata

Дополнительная policy не требуется: default-deny не содержит egress rule для
`169.254.169.254`, а allow policies выше разрешают только backend и DNS. Проверим это
отдельным client Pod с frontend identity:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl -n cks-101 run check-metadata --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=frontend --command -- \
  sh -c 'set +e; out=$(curl -sS -o /dev/null -w "HTTPCODE:%{http_code}" --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1); rc=$?; printf "CURL_EXIT:%s\n%s\n" "$rc" "$out"' \
  | tee /var/work/tests/artifacts/5/metadata.output

rc=$(sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' /var/work/tests/artifacts/5/metadata.output | tail -1)
http_code=$(sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' /var/work/tests/artifacts/5/metadata.output | tail -1)
printf '%s\n' "$rc" | tee /var/work/tests/artifacts/5/metadata.exit-code

case "$rc" in
  6) echo 'level=dns outcome=name-resolution-failure' ;;
  7) echo 'level=network outcome=tcp-connect-failure' ;;
  28) echo 'level=network outcome=timeout' ;;
  0) echo "level=http outcome=response status=$http_code" ;;
  *) echo "level=other outcome=curl-exit-$rc" ;;
esac | tee -a /var/work/tests/artifacts/5/metadata.output

test "$http_code" = 000
case "$rc" in 7|28) ;; *) exit 1 ;; esac
```

`curl -f` здесь намеренно не используется: доступный endpoint с HTTP `401/403` тоже дал бы
ненулевой exit code и создал ложное доказательство network deny. Только `http_code=000`
вместе с connect failure/timeout подтверждает сетевой уровень отказа. Если приходит любой
HTTP status, проверьте, что не создана широкая egress policy (`ipBlock: 0.0.0.0/0`, пустая
`to` или разрешение всей подсети metadata).

## Быстрая самопроверка

```bash
kubectl -n cks-101 get networkpolicy
check_result
```
