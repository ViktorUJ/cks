# Лаба 110 - эталонное решение: gVisor, WireGuard и Istio STRICT

> Все Kubernetes-команды выполняются на рабочей машине. Имена `gvisor-sandbox`,
> `runc-baseline`, `gvisor-echo`, `market-api`, `market-client`, `mesh-outside` и пути
> артефактов являются частью проверяемого контракта лабы.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. Проверить runsc и создать RuntimeClass

Нода `k8s110_node_gvisor` уже доставлена как dedicated pool: `runsc` и containerd
handler предустановлены bootstrap. Это не означает, что Kubernetes сам выберет этот
handler: Pod получает его только через `RuntimeClass`.

```bash
ssh k8s110_node_gvisor 'runsc --version; sudo systemctl is-active containerd'
```

```yaml
# runtimeclass-gvisor.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
kubectl get runtimeclass gvisor -o yaml
printf 'RuntimeClass gvisor: handler runsc\n' \
  > /var/work/tests/artifacts/1/runsc-runtime.txt
```

`scheduling.nodeSelector` - важная граница: scheduler не назначит `runsc` workload
на control-plane, где такого handler нет.

## 2. Запустить sandboxed Pod и Service

`busybox httpd` одновременно даёт shell для `uname` и небольшой HTTP endpoint для
межнодового опыта WireGuard. `runtimeClassName` применён на Pod, а не на контейнер.

```yaml
# gvisor-sandbox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-sandbox
  namespace: sandbox-110
  labels:
    app: gvisor-echo
spec:
  runtimeClassName: gvisor
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      mkdir -p /www
      printf 'CKS110-WIREGUARD-MARKER\n' >/www/index.html
      exec httpd -f -p 8080 -h /www
    ports:
    - containerPort: 8080
      name: http
---
apiVersion: v1
kind: Service
metadata:
  name: gvisor-echo
  namespace: sandbox-110
spec:
  selector:
    app: gvisor-echo
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f gvisor-sandbox.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/gvisor-sandbox --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf '\n--- gvisor dmesg ---\n'
  kubectl exec -n sandbox-110 gvisor-sandbox -- dmesg 2>&1 || true
} | tee /var/work/tests/artifacts/2/gvisor-kernel.txt
kubectl get pod -n sandbox-110 gvisor-sandbox -o wide
```

gVisor Sentry показывает workload синтетический kernel view; `dmesg` может быть
ограничен. Это ожидаемо и не является причиной выдавать контейнеру лишние privileges.

## 3. Обычный runc Pod для сравнения

Отсутствие `runtimeClassName` оставляет default handler `runc`. Selector намеренно
помещает этот Pod на control-plane, поэтому следующие задания генерируют межнодовый
трафик.

```yaml
# runc-baseline.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runc-baseline
  namespace: sandbox-110
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f runc-baseline.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/runc-baseline --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf 'runc uname -r: '
  kubectl exec -n sandbox-110 runc-baseline -- uname -r
} | tee /var/work/tests/artifacts/3/runtime-comparison.txt
cat /var/work/tests/artifacts/3/runtime-comparison.txt
```

Обычный `runc` контейнер видит host kernel release, а gVisor workload - Sentry view.
Это дополнительная граница исполнения, а не замена `SecurityContext`, seccomp или
проверки image.

## 4. Включить Cilium WireGuard

Cilium управляет WireGuard keys и peers сам. Включаем один backend шифрования - не
добавляем IPsec. Важно: у **клиентского** `cilium` CLI (установлен на worker) нет
подкоманды `encrypt enable`; WireGuard включается через конфигурацию Cilium, а не
рантайм-командой. Сначала зафиксируем версии и сверим agent с requirements matrix:

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf 'Kubernetes='
  kubectl version -o json | jq -r '.serverVersion.gitVersion'
  printf 'Cilium agent='
  kubectl -n kube-system get pod "$agent" -o jsonpath='{.spec.containers[?(@.name=="cilium-agent")].image}'
  printf '\n'
  cilium version --client
  printf 'Cilium CLI=v0.19.7\n'
  printf 'Istio=1.30.4\n'
} | tee /var/work/tests/artifacts/4/tool-versions.txt
```

Для Helm-managed Cilium source of truth — Helm values:
`helm upgrade cilium cilium/cilium -n kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard`.
В учебной установке Cilium не имеет Helm release, поэтому используем documented ConfigMap
key и перезапускаем agents:

```bash
kubectl -n kube-system patch configmap cilium-config --type merge \
  -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
cilium status --wait || true
```

Статус шифрования читаем у агента: подкоманда `encrypt status` есть именно в agent-side
CLI (внутри Cilium pod), а не в клиентском `cilium`.

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  kubectl -n kube-system exec "$agent" -- cilium encrypt status
  kubectl -n kube-system exec "$agent" -- cilium status
} | tee /var/work/tests/artifacts/4/cilium-encrypt-status.txt
```

## 5. Захват межнодового WireGuard пакета

WireGuard по умолчанию использует UDP/51871. Capture выполняется на node interface;
`-A` специально делает отсутствие marker проверяемым. Внутри зашифрованного пакета
marker существует, поэтому ответ `wget` всё равно его содержит.

```bash
capture=/var/work/tests/artifacts/5/wireguard-tcpdump.txt
ssh k8s110_controlPlane_1 'sudo timeout 20 tcpdump -nni any udp port 51871 -A' >"$capture" 2>&1 &
capture_pid=$!
sleep 3
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
wait "$capture_pid" || true

grep -E 'UDP|51871' "$capture"
if grep -Fq 'CKS110-WIREGUARD-MARKER' "$capture"; then
  echo 'marker leaked to node capture' >&2
  exit 1
fi
```

Не делайте вывод по `tcpdump` в Pod netns: там трафик до Cilium encryption point ещё
может быть plaintext. Доказательство здесь - отсутствие HTTP marker на node capture при
наличии UDP WireGuard пакетов.

## 6. Istio и PeerAuthentication STRICT

Ставим только Istio control plane в minimal profile. Namespace был подготовлен с
`istio-injection=enabled`, поэтому workloads в `market` получают Envoy sidecar при
создании. `market-api` располагается на gVisor worker, client - на control-plane, что
также делает запрос межнодовым.

```bash
istioctl install --set profile=minimal -y
kubectl -n istio-system rollout status deployment/istiod --timeout=180s
kubectl get namespace market --show-labels
```

```yaml
# market-workloads.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-api
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-api}
  template:
    metadata:
      labels: {app: market-api}
    spec:
      nodeSelector:
        lab.cks.io/role: gvisor
      automountServiceAccountToken: false
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-ec", "mkdir -p /www; printf 'market-110\\n' >/www/index.html; exec httpd -f -p 8080 -h /www"]
        ports:
        - containerPort: 8080
          name: http
---
apiVersion: v1
kind: Service
metadata:
  name: market-api
  namespace: market
spec:
  selector: {app: market-api}
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-client
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-client}
  template:
    metadata:
      labels: {app: market-client}
    spec:
      nodeSelector:
        lab.cks.io/role: control-plane
      automountServiceAccountToken: false
      containers:
      - name: app
        image: curlimages/curl:8.11.0
        command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: mesh-outside
  namespace: default
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: curlimages/curl:8.11.0
    command: ["sh", "-c", "sleep 3600"]
---
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: market-strict
  namespace: market
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f market-workloads.yaml
kubectl rollout status -n market deployment/market-api --timeout=180s
kubectl rollout status -n market deployment/market-client --timeout=180s
kubectl wait -n default --for=condition=Ready pod/mesh-outside --timeout=180s
kubectl get pods -n market
kubectl get peerauthentication -n market market-strict -o yaml

kubectl exec -n market deploy/market-client -- \
  curl -si http://market-api | tee /var/work/tests/artifacts/6/market-inside.txt
# HTTP/1.1 200 OK

set +e
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
outside_status=$?
set -e
cat /var/work/tests/artifacts/6/market-outside.txt
[[ "$outside_status" -ne 0 ]]
grep -Eqi 'connection reset by peer|recv failure.*reset' \
  /var/work/tests/artifacts/6/market-outside.txt
```

`PeerAuthentication` управляет inbound server mode. Внутренний client получает
сертификат и использует mTLS автоматически; Pod в `default` не имеет sidecar и посылает
plaintext, поэтому Envoy server при `STRICT` сбрасывает соединение. Завершите работой:

```bash
check_result
```
