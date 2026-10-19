# Лаба 110 - эталонное решение: gVisor, WireGuard и Istio STRICT

> Работаем как на экзамене: `kubectl`, `cilium` и `istioctl` - на рабочей машине, а операции над
> узлом (containerd, tcpdump) - на самом узле: зайдите на него `ssh <узел>`, перейдите в root
> (`sudo -i`), выполните команды и выйдите (`exit`, `exit`). Имена `gvisor-sandbox`,
> `runc-baseline`, `gvisor-echo`, `market-api`, `market-client`, `mesh-outside` и пути
> артефактов являются частью проверяемого контракта лабы.

## Где взять примеры в документации

| Что нужно | Страница и раздел |
| :--- | :--- |
| Секция `runsc` в `/etc/containerd/config.toml` (`runtime_type = "io.containerd.runsc.v1"`), перезапуск containerd и YAML `RuntimeClass` с `handler: runsc` | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`, поля `scheduling.nodeSelector` и `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| Включить WireGuard (`encryption.enabled=true`, `encryption.type=wireguard`) и проверить (`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| `PeerAuthentication` с `mtls.mode: STRICT` | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. Восстановить containerd runtime и создать RuntimeClass

Нода `k8s110_node_gvisor` уже доставлена как dedicated pool с установленным `runsc`, но
bootstrap намеренно убрал runtime-секцию `runsc` из `/etc/containerd/config.toml` -
типичная экзаменационная ситуация, когда бинарник есть, а containerd про него не знает.

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# на gVisor-ноде (root): бинарник есть, containerd активен, секции runsc в конфиге нет
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# дописать секцию runsc (значение runtime_type обязательно точное) и перезапустить containerd
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # из root
exit   # с gVisor-ноды
```

Kubelet не нужно перезапускать: `RuntimeClass` вызывает containerd runtime handler по
имени при каждом создании Pod, а не при старте kubelet.

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
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
kubectl get runtimeclass gvisor -o yaml
printf 'RuntimeClass gvisor: handler runsc\n' \
  > /var/work/tests/artifacts/1/runsc-runtime.txt
```

`scheduling.nodeSelector` - важная граница: scheduler не назначит `runsc` workload на
control-plane, где такого handler нет. gVisor-нода при этом помечена taint'ом
`sandbox.runtime/gvisor=true:NoSchedule` (`kubectl describe node <gvisor-узел> | grep Taints`):
на неё не попадёт ни один Pod, кроме тех, что его терпят. `scheduling.tolerations` в RuntimeClass
автоматически добавляются ко всем Pod с этим классом, поэтому `gvisor-sandbox` туда попадает,
а остальные - нет.

## 2. Запустить sandboxed Pod и Service

`busybox httpd` одновременно даёт shell для `uname` и небольшой HTTP endpoint для
межнодового опыта WireGuard. `runtimeClassName` применён на Pod, а не на контейнер.

`nodeSelector` и `tolerations` в Pod заданы явно: так видно, на какую ноду и почему он попадает.
Это то же самое, что описано в `scheduling` самого `RuntimeClass`. Если в Pod их не указать,
ничего не сломается: при создании Pod с `runtimeClassName` Kubernetes сам **добавляет** в него
`nodeSelector` и `tolerations` из `RuntimeClass.scheduling` (проверить: `kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`). Но тогда в манифесте этого не видно, а без
`scheduling` в RuntimeClass Pod мог бы попасть на ноду без `runsc` и не запуститься.

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
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
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
} > /var/work/tests/artifacts/2/gvisor-kernel.txt
cat /var/work/tests/artifacts/2/gvisor-kernel.txt
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
} > /var/work/tests/artifacts/3/runtime-comparison.txt
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
  printf 'Cilium data plane=verify current supported lab build against Kubernetes 1.36 requirements matrix\n'
  printf 'Istio=1.30.4\n'
} > /var/work/tests/artifacts/4/tool-versions.txt
cat /var/work/tests/artifacts/4/tool-versions.txt
```

Кластер развёрнут командой `cilium install`, которая устанавливает Cilium **через Helm**.
Долговременный source of truth — Helm values release `cilium`; используем pinned Cilium CLI upgrade и после него проверяем live ConfigMap и agents:

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm меняет только ConfigMap: шаблон DaemonSet не меняется, поэтому агенты сами
# не перезапускаются и продолжают работать без WireGuard - перезапустите их явно.
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

Статус шифрования читаем у агента через `cilium-dbg`: это in-pod debug CLI, поставляемый с Cilium agent. Локальный `cilium` CLI остаётся инструментом install/cluster-level и не заменяет его внутри Pod. У `cilium-dbg status` НЕТ флага `--all-encryption` (в 1.20.x доступны только `--all-addresses`, `--all-clusters`, `--all-controllers`, `--all-health`, `--all-nodes`, `--all-redirects`, `--verbose`) - подробный peer/allowed-IP/remote-node evidence получаем через `cilium-dbg debuginfo --output json`, а не через несуществующий флаг.

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf '$ cilium-dbg encrypt status
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg encrypt status
  printf '$ cilium-dbg debuginfo --output json
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg debuginfo --output json
} > /var/work/tests/artifacts/4/cilium-encrypt-status.txt
cat /var/work/tests/artifacts/4/cilium-encrypt-status.txt
grep -Eqi 'peer|allowed[ -]?ip|remote node' /var/work/tests/artifacts/4/cilium-encrypt-status.txt
```

## 5. Захват межнодового WireGuard пакета

WireGuard по умолчанию использует UDP/51871. Фильтр ТОЛЬКО по `udp port 51871` заранее
исключает plaintext TCP из результата и поэтому НЕ доказывает его отсутствие - вместо этого
используем один и тот же capture scope (`host <remote-node-ip>`, без port-фильтра) и сравниваем
ДО/ПОСЛЕ включения WireGuard по одному и тому же межнодовому flow.

Захват на `any` НЕ является корректной точкой наблюдения on-wire state: `any` видит и внутренний
Cilium-интерфейс `cilium_wg0`, на котором по конструкции туннеля проходит УЖЕ РАСШИФРОВАННЫЙ
трафик. Захватывать нужно физический egress-интерфейс к удалённому узлу (не `any`, `cilium_*`,
`lxc*`, `veth*`).

Понадобятся два терминала: **терминал 1** - control-plane (там `tcpdump`), **терминал 2** -
рабочая машина (запросы и `kubectl`).

```bash
# терминал 2 (рабочая машина): IP узла с gVisor-Pod'ом - это "удалённый" узел для control-plane
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# терминал 1: зайти на control-plane и узнать физический интерфейс к remote_ip
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# терминал 1 (control-plane, root): впишите значение remote_ip из терминала 2
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- интерфейс (ens5), не any / cilium_* / lxc* / veth*
```

**Baseline: WireGuard выключен.** Временно отключаем WireGuard и повторяем ТОТ ЖЕ запрос с ТЕМ ЖЕ
capture scope. В конце обязательно вернём `enable-wireguard: "true"`.

```bash
# терминал 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# терминал 1 (control-plane, root): захват 20 секунд, затем сразу запустите запрос в терминале 2
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# терминал 2: пока идёт захват (первые ~15 секунд)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# терминал 1 (после окончания захвата): plaintext marker виден, WireGuard выключен
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**После: WireGuard включён.** Восстанавливаем WireGuard и повторяем ТОТ ЖЕ запрос с ТЕМ ЖЕ scope
захвата: теперь должен быть виден WireGuard UDP/51871 и не должно быть marker.

```bash
# терминал 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# терминал 1 (control-plane, root): захват 20 секунд
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# терминал 2: пока идёт захват
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# терминал 1 (после окончания захвата)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # из root
exit   # с control-plane
```

```bash
# терминал 2: забрать capture для проверки
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

Не делайте вывод по `tcpdump` в Pod netns: там трафик до Cilium encryption point ещё может быть
plaintext. Доказательство здесь - переход от видимого marker (WireGuard отключён) к его
отсутствию (WireGuard включён) при ОДНОМ И ТОМ ЖЕ capture scope.

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
      tolerations:
      - key: sandbox.runtime/gvisor
        operator: Equal
        value: "true"
        effect: NoSchedule
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
```

```bash
kubectl apply -f market-workloads.yaml
kubectl rollout status -n market deployment/market-api --timeout=180s
kubectl rollout status -n market deployment/market-client --timeout=180s
kubectl wait -n default --for=condition=Ready pod/mesh-outside --timeout=180s
kubectl get pods -n market

# Baseline (STRICT еще не применена): plaintext client вне mesh должен получить 200 -
# это доказывает, что связность в принципе работает и любой последующий отказ будет
# вызван именно STRICT mTLS, а не независимой DNS/network-проблемой.
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# ожидаем: HTTP/1.1 200 OK и в конце exit_code=0
```

```yaml
# market-strict.yaml
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
kubectl apply -f market-strict.yaml
kubectl get peerauthentication -n market market-strict -o yaml

# запрос изнутри mesh (client с sidecar)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# ожидаем: HTTP/1.1 200 OK и в конце exit_code=0

# тот же запрос снаружи mesh (plaintext, без sidecar)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# ожидаем: Recv failure: Connection reset by peer и в конце exit_code=56 (не 0)
```

`PeerAuthentication` управляет inbound server mode. Внутренний client получает
сертификат и использует mTLS автоматически; Pod в `default` не имеет sidecar и посылает
plaintext, поэтому Envoy server при `STRICT` сбрасывает соединение. Завершите работой:

```bash
check_result
```
