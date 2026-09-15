[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 101 - эталонное решение: NetworkPolicy default-deny и защита metadata

> `NetworkPolicy` является allow-list. У native Kubernetes `NetworkPolicy` нет правила
> `deny` для отдельного CIDR: доступ к `169.254.169.254` блокирует egress default-deny,
> потому что ни одна allow policy не включает этот адрес.

## Задание 1. Namespace, frontend/backend и Service

Используйте одобренный immutable image reference ниже. Digest content-addressed и не может незаметно смениться, в отличие от mutable tag.

```bash
PING_PONG_IMAGE="viktoruj/ping_pong@sha256:32d367cdfc826dafa36f7d79d4f345425552c9aa2db5bdf3a33f86ff3532fa95"
```

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
          image: ${PING_PONG_IMAGE}
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
          image: ${PING_PONG_IMAGE}
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
envsubst < app.yaml | kubectl apply -f -
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
# Временная policy даёт foreign только egress к backend:8080; поэтому
# ненулевой результат ниже доказывает именно ограничение backend ingress.
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: check-foreign-egress
  namespace: cks-101
spec:
  podSelector:
    matchLabels:
      app: foreign
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
EOF
set +e
kubectl -n cks-101 run check-foreign --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=foreign --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/" \
  > /var/work/tests/artifacts/3/foreign.txt 2>&1
foreign_rc=$?
set -e
kubectl -n cks-101 delete networkpolicy check-foreign-egress
printf 'exit=%s\n' "$foreign_rc" >> /var/work/tests/artifacts/3/foreign.txt
test "$foreign_rc" -ne 0
```

Временный client Pod имеет ту же security identity (`app=frontend`), что и frontend. Это необходимо, потому что образ `viktoruj/ping_pong@sha256:32d367cdfc826dafa36f7d79d4f345425552c9aa2db5bdf3a33f86ff3532fa95` не содержит shell и `curl`. Для отрицательной проверки одного `app=foreign` недостаточно: без отдельного egress он будет заблокирован default-deny ещё до backend ingress.

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

## Задание 6. Ловушка AND vs OR и `ipBlock.except`

Два отдельных элемента массива `from`/`to` означают логическое OR: любой из них по
отдельности открывает доступ. Чтобы получить AND ("только этот Pod внутри этого
namespace"), `namespaceSelector` и `podSelector` должны быть полями **одного и того же**
элемента - без второго дефиса перед `podSelector`.

```yaml
# legacy-client.yaml
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
          command: ["sleep", "3600"]
```

```bash
kubectl apply -f legacy-client.yaml
kubectl -n cks-101-legacy rollout status deployment/legacy-client
```

Ingress policy на `backend` в `cks-101` разрешает **только** Pod с `app=legacy-client`,
находящийся именно в `cks-101-legacy`. Namespace выбирается через её immutable label
`kubernetes.io/metadata.name`, который назначает сам API server:

```yaml
# allow-backend-ingress-from-legacy.yaml
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
```

Ловушка выглядела бы так и означала бы совсем другое правило - "любой Pod из
`cks-101-legacy` ИЛИ любой Pod с `app=legacy-client` в namespace самой policy (`cks-101`)":

```yaml
    # НЕ делайте так - это OR, а не AND:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cks-101-legacy
        - podSelector:
            matchLabels:
              app: legacy-client
```

Egress policy в `cks-101-legacy` открывает широкий внешний доступ, но явно исключает
metadata через `except`. `except` действует только внутри своего правила: другое allow
с более широким CIDR или без `except` снова разрешит адрес.

```yaml
# allow-legacy-egress.yaml
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
```

```bash
kubectl apply -f allow-backend-ingress-from-legacy.yaml
kubectl apply -f allow-legacy-egress.yaml
mkdir -p /var/work/tests/artifacts/6

BACKEND_IP=$(kubectl -n cks-101 get svc backend -o jsonpath='{.spec.clusterIP}')

# Проверяем обе ветки ошибочного OR: wrong-label в legacy namespace и
# legacy-client в namespace самой policy. Для честной проверки ingress им
# временно разрешается только egress к backend:8080.
# Полный runtime-вариант этих двух negative probes выполняет check_result.
kubectl -n cks-101-legacy run policy-legacy-allowed --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -fsS --max-time 5 http://${BACKEND_IP}:8080/"

# except исключил именно metadata, остальной IPv4 остаётся доступен.
kubectl -n cks-101-legacy run policy-legacy-external --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --max-time 5 https://1.1.1.1/"
kubectl -n cks-101-legacy run policy-legacy-metadata --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- \
  sh -c "curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/" || true
```

## Задание 7. `hostNetwork` и границы portability `NetworkPolicy`

Официальная документация Kubernetes прямо называет поведение `NetworkPolicy` для
`hostNetwork` Pod **undefined** и допускает ровно два варианта реализации CNI:
плагин либо различает трафик `hostNetwork` Pod и применяет к нему ту же `NetworkPolicy`,
либо не различает его и обрабатывает как обычный трафик ноды - это самая распространённая
реализация. Ниже мы не доказываем универсальное свойство Kubernetes, а фиксируем
фактически наблюдаемое поведение конкретно для Calico в этой lab-инфраструктуре.

```yaml
# hostnetwork-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostnetwork-probe
  namespace: cks-101
  labels:
    app: frontend
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
task5_code=$(printf '%s\n' "$task5_out" | sed -n 's/^http_code=\([0-9][0-9][0-9]\).*/\1/p' | tail -1)
{
  echo "task5_result=curl_exit=${task5_rc:-missing} http_code=${task5_code:-missing}"
  echo "task7_result=curl_exit=${host_rc:-missing} http_code=${host_code:-missing}; observed for this Calico/AWS lab only, environment-specific and not a universal NetworkPolicy guarantee"
} > /var/work/tests/artifacts/7/comparison.txt
```

`NetworkPolicy` из задания 2/5 не изменяется и продолжает верно защищать обычные Pod
Pod-сети. Для `hostNetwork: true` официальный контракт Kubernetes не гарантирует ни
защиту, ни её отсутствие - фактическое поведение зависит от конкретного CNI. В этой
lab-конфигурации на Calico наблюдаемый результат - трафик `hostNetwork` Pod обрабатывается
как трафик самой ноды и не проходит через тот же dataplane, что обычный Pod-to-Pod трафик.
Не переносите этот наблюдаемый результат на другой CNI без отдельной проверки; закрывать
`hostNetwork` как класс риска нужно на уровне PSA/admission (запрет `hostNetwork` в
namespace) или host firewall, а не полагаться на конкретное поведение одного CNI.

## Быстрая самопроверка

```bash
kubectl -n cks-101 get networkpolicy
kubectl -n cks-101-legacy get networkpolicy
check_result
```
