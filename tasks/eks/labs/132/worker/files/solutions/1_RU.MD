[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 132 - эталонное решение (Cilium в режиме CNI chaining над VPC CNI)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl и helm уже настроены
(kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).

> Версии Cilium и точные имена values-флагов chaining-режима быстро меняются между
> релизами. Команды ниже проверены на живом стенде с Cilium `1.20.0` и EKS `1.36`. Если
> берёте другую версию, сверьте синтаксис с документацией Cilium
> (`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`).

## Задание 1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## Задание 2. Нагрузка на пуле `cilium-demo` без Cilium

NodePool `cilium-demo` уже существует как код (taint `dedicated=cilium-demo:NoSchedule`,
label `work_type=cilium-demo`), но пока в него не поступит под с toleration, Karpenter не
поднимет ни одной ноды. Deployment `api` и `client` создаём сразу с `nodeSelector` и
toleration, чтобы они попали именно туда:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: eks-132
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: eks-132
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: eks-132
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: curl
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Karpenter поднимает новую ноду в пуле `cilium-demo` (обычно 60-90 секунд). Как только
`rollout status` подтвердил готовность, проверяем связность через штатный VPC CNI - Cilium
ещё не установлен:

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## Задание 3. Cilium через Helm в режиме CNI chaining, только на `cilium-demo`

Добавляем репозиторий Cilium и готовим values-файл. Ключевой параметр -
`cni.chainingMode: aws-cni`: VPC CNI (`aws-node`) остаётся основным IPAM, Cilium
подключается в цепочку и добавляет eBPF-программы поверх уже настроенного интерфейса пода.

Три блока `nodeSelector`/`tolerations` (верхний уровень для агента, `envoy` и `operator`)
ограничивают все компоненты Cilium пулом `cilium-demo`. Верхний `nodeSelector` наследует
только DaemonSet `cilium`; у `cilium-envoy` и `cilium-operator` свои секции, и без них
поды Envoy повиснут в `Pending` на всех остальных нодах, а `cilium status` будет
показывать `Envoy DaemonSet: 1 errors`.

Отдельно выключаем `operator.unmanagedPodWatcher.restart`. Это обязательный для такого
стенда флаг, а не тонкая настройка: по умолчанию оператор каждые 15 секунд удаляет поды,
у которых нет `CiliumEndpoint`, чтобы они перезапустились и попали в цепочку CNI. Поды
`coredns` живут на Fargate, где агента Cilium нет и быть не может, поэтому managed они не
станут никогда - оператор убивает их бесконечно, каждый раз поднимая новую Fargate-ноду,
и DNS в кластере ложится (подробности - в разделе «Грабли» ниже).

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

cat <<'EOF' > /tmp/cilium-values.yaml
cni:
  chainingMode: aws-cni
  exclusive: false
enableIPv4Masquerade: false
routingMode: native
nodeSelector:
  work_type: cilium-demo
tolerations:
  - key: dedicated
    operator: Equal
    value: cilium-demo
    effect: NoSchedule
envoy:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
operator:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
  unmanagedPodWatcher:
    restart: false
EOF

helm install cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
```

Поды `api` и `client` были запущены до установки Cilium, поэтому CNI chaining на них ещё
не подействовал (документация Cilium прямо предупреждает про это: существующие поды нужно
перезапустить). Перезапускаем оба Deployment:

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Устанавливаем Cilium CLI и проверяем состояние:

```bash
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz"

mkdir -p /var/work/tests/artifacts/3
cilium status | tee /var/work/tests/artifacts/3/cilium_status.txt
```

В выводе должны быть `Cilium: OK`, `Operator: OK` и `Envoy DaemonSet: OK`, а число
`Desired` у обоих DaemonSet должно совпадать с числом нод `cilium-demo`.

## Задание 4. Доказательство chaining: адреса всё ещё от VPC CNI

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

IP подов `api` и `client` из CIDR `10.10.0.0/16` - того же диапазона, что и у самой VPC.
Если бы это была полная замена VPC CNI с overlay-режимом, адреса пришли бы из отдельного
виртуального пула (`cluster-pool`), а не из подсети ноды. Здесь IPAM остался за VPC CNI -
это и есть суть chaining (глава 8).

## Задание 5. L7-политика: только GET

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-l7-allow-get
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/.*"
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-l7-allow-get -n eks-132
```

Проверяем разрешённый GET и заблокированный POST:

```bash
mkdir -p /var/work/tests/artifacts/5
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_get.txt
cat /var/work/tests/artifacts/5/allowed_get.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 -X POST \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_post.txt || true
cat /var/work/tests/artifacts/5/blocked_post.txt
```

GET проходит (`HTTP_CODE=200`), POST блокируется Envoy-прокси Cilium на уровне L7
(`HTTP_CODE=403`, доступ отклонён до того, как запрос дошёл до приложения). У встроенного
VPC CNI NetworkPolicy такого фильтра по HTTP-методу нет - только L3/L4 (глава 8).

Используйте полное имя `ciliumnetworkpolicies.cilium.io`: короткое `cnp` в этом кластере
неоднозначно, потому что VPC CNI приносит свой ресурс
`clusternetworkpolicies.networking.k8s.aws`, и kubectl предупреждает об этом.

## Задание 6. FQDN-политика: egress только на `aws.amazon.com`

Два места, где эта политика ведёт себя не так, как в типовом примере из документации.

Первое: правило для DNS нельзя написать через `toEndpoints` с меткой `k8s-app: kube-dns`.
`toEndpoints` работает по identity Cilium, а поды `coredns` в этом кластере живут на
Fargate, где агента Cilium нет - у них нет `CiliumEndpoint`, они не попадают в `ipcache`
и с точки зрения политики выглядят как `reserved:world`. Правило по метке не сматчится
никогда, DNS будет закрыт default-deny, и `curl` не сможет даже разрешить имя. Поэтому
DNS разрешаем по CIDR: сервисный диапазон кластера (`172.20.0.0/16`, там ClusterIP
`kube-dns`) и CIDR VPC (`10.10.0.0/16`, там сами поды `coredns`). L7-правила `rules.dns`
на `toCIDRSet` работают штатно - именно так Cilium документирует случай внешнего
DNS-сервера.

Второе: `endpointSelector` на `app: client` включает default-deny на весь egress этого
пода. Если оставить только `toFQDNs` и DNS, то сломается GET до `api` из задания 5 - его
пакеты будут дропаться. Поэтому третьим блоком явно разрешаем egress на `api:8080`. Так
конечное состояние стенда согласовано: одновременно верны и задание 5, и задание 6.

Порядок блоков важен: `toFQDNs` должен остаться первым (`egress[0]`), автотест смотрит
именно туда.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-fqdn-allow-aws
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toFQDNs:
    - matchName: "aws.amazon.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toCIDRSet:
    - cidr: 172.20.0.0/16
    - cidr: 10.10.0.0/16
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toEndpoints:
    - matchLabels:
        app: api
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-fqdn-allow-aws -n eks-132
```

Проверяем:

```bash
mkdir -p /var/work/tests/artifacts/6
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://aws.amazon.com \
  > /var/work/tests/artifacts/6/allowed_fqdn.txt || true
cat /var/work/tests/artifacts/6/allowed_fqdn.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://example.com \
  > /var/work/tests/artifacts/6/blocked_other_domain.txt || true
cat /var/work/tests/artifacts/6/blocked_other_domain.txt
```

`aws.amazon.com` резолвится и `curl` проходит - `HTTP_CODE=200`. `example.com` тоже
резолвится (DNS разрешён), но TCP-сессия на его адрес не входит в `toFQDNs`, пакеты
дропаются, и `curl` виснет до `--max-time` - `HTTP_CODE=000`. Такой политики по DNS-имени
у встроенного VPC CNI NetworkPolicy нет вовсе - только `ipBlock` по IP/CIDR (глава 8).

## Задание 7. Hubble: наблюдаемость потоков с verdict

Включаем Hubble relay поверх уже установленного Cilium, тем же `nodeSelector` на
`cilium-demo`:

```bash
cat <<'EOF' >> /tmp/cilium-values.yaml
hubble:
  relay:
    enabled: true
    nodeSelector:
      work_type: cilium-demo
    tolerations:
      - key: dedicated
        operator: Equal
        value: cilium-demo
        effect: NoSchedule
EOF

helm upgrade cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status deployment/hubble-relay --timeout=240s
```

Устанавливаем Hubble CLI:

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

Поднимаем порт-форвард на relay (`4245`), повторяем заблокированные запросы из заданий 5
и 6, чтобы получить события `DROPPED`, и читаем поток:

```bash
setsid nohup kubectl -n kube-system port-forward service/hubble-relay 4245:80 \
  </dev/null >/tmp/pf.log 2>&1 &
sleep 5

CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
for i in 1 2 3; do
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 -X POST \
    http://api.eks-132.svc.cluster.local:8080 >/dev/null 2>&1 || true
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 \
    https://example.com >/dev/null 2>&1 || true
done

mkdir -p /var/work/tests/artifacts/7
hubble observe --server localhost:4245 -n eks-132 --last 200 \
  | tee /var/work/tests/artifacts/7/hubble_denied.txt
grep -c DROPPED /var/work/tests/artifacts/7/hubble_denied.txt
```

Порт-форвард обязательно запускайте через `setsid nohup ... </dev/null &`: обычный
`kubectl port-forward &` держит SSH-сессию и она обрывается по выходу.

В файле должны встречаться строки с verdict `DROPPED` - это дропнутые SYN на адреса
`example.com` (`policy-verdict:none ... Policy denied DROPPED`). Такой карты потоков с
per-flow verdict у встроенного VPC CNI network policy нет - там только логи агента
`aws-network-policy-agent` и метрики (глава 8).

## Задание 8. Сравнение: VPC CNI NP против Cilium в этой лабе

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
Что умеет встроенный VPC CNI NetworkPolicy - что добавил Cilium - чем платите:

1. VPC CNI NetworkPolicy покрывает только L3/L4. Cilium в этой лабе добавил L7-правило
   по HTTP-методу: GET разрешён (200), POST отклонён Envoy-прокси с кодом 403.

2. У VPC CNI NP нет политик по DNS-имени. Cilium добавил CiliumNetworkPolicy с toFQDNs -
   egress разрешён только на aws.amazon.com, example.com дропается (HTTP_CODE=000).

3. Диагностика встроенного VPC CNI NP - только логи агента и метрики. Cilium принёс
   Hubble: карту потоков с per-flow verdict (FORWARDED/DROPPED) через hubble observe.

4. Плата за это: свой Helm-релиз Cilium со своими апгрейдами, вторая модель CRD для
   команды, дополнительный слой в датапасе, а также то, что поды вне пула cilium-demo
   (например coredns на Fargate) остаются вне датапаса Cilium и в политиках видны только
   как reserved:world - правила по label к ним не применимы.

5. Полная замена VPC CNI (когда aws-node удаляется и Cilium сам становится IPAM) в объём
   этой лабы не входит: смена CNI на живом кластере - это blue/green через новые ноды,
   а не переключение флага на лету (глава 8, раздел 8.8). Здесь отработан только
   безопасный вариант - CNI chaining.
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## Быстрая проверка

```bash
check_result
```

## Грабли, на которые наступают в этой лабе

Все четыре пункта проверены на живом стенде.

1. `cilium-operator` уносит DNS кластера. По умолчанию
   `operator.unmanagedPodWatcher.restart=true`: оператор каждые 15 секунд удаляет поды без
   `CiliumEndpoint`. `coredns` на Fargate таким никогда не станет, поэтому его поды
   удаляются по кругу, на каждый рождается новая Fargate-микро-VM, а DNS в кластере то
   есть, то нет. Симптом со стороны пода: `nslookup` отдаёт
   `connection timed out; no servers could be reached`. Кто именно удаляет поды, видно
   в audit-логе control plane: в записях `verb: delete` на поды `coredns` стоит
   `user.username = system:serviceaccount:kube-system:cilium-operator` и
   `userAgent = cilium-operator-generic/1.20.0`. Лечится флагом
   `operator.unmanagedPodWatcher.restart=false` (в `cilium-config` появится
   `unmanaged-pod-watcher-interval: "0"`).

2. Fargate-профиль не умеет `nodeSelector`. Если профиль накрывает namespace
   `kube-system` целиком (`selectors = [{ namespace = "kube-system" }]`), Fargate-webhook
   помечает своим профилем ЛЮБОЙ под, который вы добавите в этот namespace позже, включая
   `cilium-operator`. Дальше под шедулит только `fargate-scheduler`, а он не умеет ни
   `hostNetwork`, ни `nodeSelector` и никогда не откатывается на обычный scheduler.
   Симптомы: `Pod not supported on Fargate: fields not supported: HostNetwork, port
   contains HostIP or HostPort`, а после `operator.hostNetwork=false` -
   `MatchNodeSelector failed: Fargate profile kube-system cannot satisfy pod's node
   selector/affinity requirements`. В этой лабе профиль поэтому сужен label-селектором
   `eks.amazonaws.com/component: coredns` (см. `eks_fargate_system/terragrunt.hcl`).

3. Fargate-профиль пересоздан - перезапустите поды, которые он должен подхватить. Мутация
   пода происходит только в момент его создания, поэтому под `karpenter`, созданный до
   того, как новый профиль стал `ACTIVE`, навсегда останется в `Pending` с
   `0/N nodes are available: N node(s) had untolerated taint(s)`. Лечится
   `kubectl delete pod` этого пода.

4. Поды `cilium-envoy` висят в `Pending`, если задать только верхний `nodeSelector`.
   У DaemonSet `cilium-envoy` своя секция `envoy.nodeSelector` / `envoy.tolerations`;
   без неё он целится на все линуксовые ноды, а `cilium status` показывает
   `Envoy DaemonSet: 1 errors`.
