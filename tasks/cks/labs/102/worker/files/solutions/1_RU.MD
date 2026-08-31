[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 102 - эталонное решение: CiliumNetworkPolicy L3/L4/L7 и Hubble

Все команды выполняются на worker. Перед началом убедитесь, что выбран правильный контекст:

```bash
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
cilium status --wait
```

## Задание 1. Namespace и учебные приложения

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: cks-102
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: cks-102
  labels:
    app: backend
spec:
  containers:
    - name: nginx
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: cks-102
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: cks-102
  labels:
    role: frontend
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: cks-102
  labels:
    role: untrusted
spec:
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/backend pod/frontend pod/client -n cks-102 --timeout=180s
```

## Задание 2. CiliumNetworkPolicy L3/L4

Политика выбирает backend, поэтому для него включается ingress enforcement. Разрешён только
source с `role=frontend` и TCP/80; `client` под это правило не подходит.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
EOF

mkdir -p /var/work/tests/artifacts/2
{
  printf 'frontend: '
  kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/
  printf '\nclient: '
  kubectl exec -n cks-102 client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/ || true
  printf '\n'
} > /var/work/tests/artifacts/2/l3-l4.txt
```

Первая строка должна дать `200`; второй запрос не должен дать `200`.

## Задание 3. Ограничение HTTP L7

Заменяем L3/L4-правило, а не добавляем вторую широкую allow-политику: широкое правило на
TCP/80 сделало бы L7-ограничение неэффективным.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-policy
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/"
EOF

mkdir -p /var/work/tests/artifacts/3
{
  printf 'GET /: '
  kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/
  printf '\nPOST /: '
  kubectl exec -n cks-102 frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/
  printf '\n'
} > /var/work/tests/artifacts/3/l7-http.txt
```

Ожидаемые статусы - `200` для GET и `403` для POST, который отклоняет Envoy proxy Cilium.

## Задание 4. DNS-aware egress через toFQDNs

DNS разрешается отдельно: `toFQDNs` разрешает соединение с IP, полученными для FQDN, но не
заменяет доступ к DNS-серверу.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-fqdn
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      role: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s:k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
    - toFQDNs:
        - matchName: example.com
EOF

mkdir -p /var/work/tests/artifacts/4
{
  printf 'example.com: '
  kubectl exec -n cks-102 frontend -- curl -k -sS --max-time 10 -o /dev/null -w '%{http_code}' https://example.com/
  printf '\nwww.google.com: '
  kubectl exec -n cks-102 frontend -- curl -k -sS --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com/ || true
  printf '\n'
} > /var/work/tests/artifacts/4/fqdn.txt
```

`example.com` возвращает успешный HTTP-статус, а `www.google.com` не должен вернуть 2xx/3xx.

## Задание 5. Evidence из Hubble

На worker relay включён стартовым скриптом. Откройте локальный port-forward, запустите
наблюдение, сгенерируйте GET и запрещённый POST, затем завершите оба фоновых процесса.

```bash
cilium hubble port-forward > /tmp/cilium-hubble-port-forward.log 2>&1 &
PF_PID=$!
sleep 3

mkdir -p /var/work/tests/artifacts/5
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf 'start=%s source=cks-102/frontend destination=cks-102/backend\nallowed=GET / denied=POST /\n' \
  "$START" > /var/work/tests/artifacts/5/test-window.txt

hubble observe --from-pod cks-102/frontend --to-pod cks-102/backend \
  --protocol http --since "$START" --output json --follow \
  > /var/work/tests/artifacts/5/hubble-observe.json &
OBSERVE_PID=$!
sleep 2

kubectl exec -n cks-102 frontend -- curl -sS http://backend/ -o /dev/null
kubectl exec -n cks-102 frontend -- curl -sS -X POST http://backend/ -o /dev/null || true
sleep 5
kill "$OBSERVE_PID" "$PF_PID" 2>/dev/null || true

head -n 3 /var/work/tests/artifacts/5/hubble-observe.json
```

Здесь verdict сам по себе недостаточен: evidence связывает временное окно, source/destination,
HTTP method/path и ожидаемый результат policy. Поток другого Pod не подтверждает этот test case.

Проверка всех заданий:

```bash
check_result
```
