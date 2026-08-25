[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 110 - эталонное решение (VPC CNI network policy: default deny, label, egress)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер (kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).
`enableNetworkPolicy` уже включён в аддоне `vpc-cni` через Terraform, поэтому агент
`aws-network-policy-agent` в `aws-node` есть на нодах ещё до начала заданий.

## Задание 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## Задание 2. Проверка, что enforcer включён

Проверяем оба факта: контейнер агента в DaemonSet `aws-node` и флаг конфигурации аддона.

```bash
mkdir -p /var/work/tests/artifacts/2

{
  echo "--- kubectl describe daemonset aws-node ---"
  kubectl describe daemonset aws-node -n kube-system | grep -A2 aws-network-policy-agent
  echo
  echo "--- aws eks describe-addon vpc-cni ---"
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's|.*/||')
  aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
    --query "addon.configurationValues" --output text
} > /var/work/tests/artifacts/2/enforcer.txt

cat /var/work/tests/artifacts/2/enforcer.txt
```

В выводе должен быть контейнер `aws-network-policy-agent` в `aws-node` и строка
`enableNetworkPolicy":"true"` (или похожая) в конфигурации аддона. Это подтверждает, что
control plane и агент на нодах действительно применяют объекты `NetworkPolicy`, а не просто
принимают их как API-объект.

## Задание 3. Симптом до политики: связность разрешена по умолчанию

Создаём `api` (сервер) и `client` (для `kubectl exec curl`), а также Service для `api`:

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

Проверяем связность: `client` должен достучаться до `api` по имени Service.

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

Файл должен содержать `HTTP_CODE=200`: без политик VPC CNI разрешает весь east-west
трафик, объект `NetworkPolicy` в кластере пока не создан.

## Задание 4. Default deny ingress

Запрещаем весь входящий трафик в namespace `eks-110`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: eks-110
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF
```

Проверяем, что `client` больше не достаёт до `api` (ждём таймаут, чтобы не зависнуть):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

Файл должен показать `HTTP_CODE=000` (соединение не установлено) - `podSelector: {}`
означает «все поды namespace», `policyTypes: ["Ingress"]` без секции `ingress` означает
«запретить весь входящий трафик». Это классический default deny, применённый агентом
`aws-network-policy-agent` через eBPF.

## Задание 5. Разрешение по label: `app: frontend` -> `app: api`

Добавляем политику, которая разрешает входящий трафик к подам `app: api` только от подов с
меткой `app: frontend`, на порт `8080`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

Создаём клиента с нужной меткой (`frontend`) и клиента без неё (`client-other`), чтобы
сравнить результат:

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` ставит метку `app: <имя>` автоматически, поэтому у `frontend`
уже есть `app: frontend`, а у `client-other` - `app: client-other` (не совпадает с правилом).

Проверяем оба случая:

```bash
mkdir -p /var/work/tests/artifacts/5
FRONTEND=$(kubectl get po -n eks-110 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER=$(kubectl get po -n eks-110 -l app=client-other -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_frontend.txt

kubectl exec "$OTHER" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_other.txt

cat /var/work/tests/artifacts/5/allowed_frontend.txt
cat /var/work/tests/artifacts/5/blocked_other.txt
```

`allowed_frontend.txt` должен показать `HTTP_CODE=200` (метка совпала с правилом
`podSelector` в `ingress.from`), а `blocked_other.txt` - `HTTP_CODE=000` (тот же
`default-deny-ingress` из задания 4 продолжает действовать на все поды, для которых нет
явного разрешения).

## Задание 6. Egress с исключением на DNS

Ограничиваем исходящий трафик из `frontend`: разрешаем только к подам `app: api` и к DNS
(`kube-system`, порты `53` UDP/TCP). Всё остальное (любой внешний адрес) блокируется.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

Проверяем, что резолвинг имени `api` и доступ к нему работают (нужен и DNS, и разрешённый
egress к поду `api`):

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` подтверждает, что запись политики `to.podSelector: app: api` пропускает
трафик к `api`, а исключение на порт `53` в `kube-system` даёт `frontend` разрешить имя.

Теперь проверяем, что произвольный внешний адрес (не входящий в разрешённые правила)
блокируется:

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` подтверждает запрет: `restrict-egress` определяет полный список
разрешённых направлений для `app: frontend`, всё остальное запрещено (в том числе интернет
и любые другие поды кластера, кроме `api`).

## Быстрая проверка

```bash
check_result
```
