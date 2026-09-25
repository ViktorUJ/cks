[Eng version](1.MD)

# Лаба 115 - краткое решение

> Advanced/production track. Точные версии/флаги CLI могут отличаться между
> релизами Cilium - проверяйте `cilium install --help`/`cilium upgrade --help`,
> если что-то из ниже не срабатывает буквально.

## 1. Baseline

```bash
kubectl -n kube-system get ds kube-proxy
kubectl get nodes
```

```
Error from server (NotFound): daemonsets.apps "kube-proxy" not found
NAME              STATUS     ROLES           AGE   VERSION
ip-10-115-1-xxx   NotReady   control-plane   2m    v1.36.0
```

## 2. Cilium как замена kube-proxy

```bash
node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
cilium install --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443
cilium status --wait
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep KubeProxyReplacement
kubectl get nodes
```

> `cilium status` из cilium-cli 0.19 не печатает строки `KubeProxyReplacement`/`Encryption`;
> их показывает `cilium-dbg status` внутри Pod'а агента (так же проверяет и checker).

```
KubeProxyReplacement:   True   [ens5 10.115.1.x (Direct Routing)]
NAME              STATUS   ROLES           AGE   VERSION
ip-10-115-1-xxx   Ready    control-plane   4m    v1.36.0
```

```bash
kubectl run svc-check --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep 300
kubectl wait --for=condition=Ready pod/svc-check --timeout=90s
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

`403` (не `000`) - значит TCP/TLS до API через Service ClusterIP реально работает без
kube-proxy; `403` тут ожидаем, т.к. запрос без токена, достаточно самого факта ответа.

## 3. WireGuard encryption

```bash
cilium upgrade --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443 \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
cilium status --wait
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep Encryption
```

> `cilium upgrade` меняет только ConfigMap: агент применяет `encryption.*` после перезапуска
> (до него `Encryption: Disabled`).

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

Регрессии нет - тот же результат, что в задании 2.

## 4. Cilium Mutual Authentication (SPIRE)

Три параметра сверх минимальных из задания нужны именно в этом стенде:

- `authentication.enabled=true` - без него chart отклоняет `spire.enabled=true`
  (`SPIRE integration requires .Values.authentication.enabled=true ...`).
- `install.server.dataStorage.enabled=false` - в кластере нет StorageClass, поэтому PVC
  `spire-data-spire-server-0` навсегда остаётся `Pending`, а `spire-server-0` - `Pending`
  (для лабы хватает эфемерного хранилища).
- `install.server.securityContext.runAsUser=0` - образ `spire-server` стартует от uid 1000 и
  не может создать `api.sock` в hostPath-каталоге `root:755`; сервер молча завершает
  endpoint'ы и убивается liveness-пробой (`Waiting for spire-server to start...` в `cilium-init`).

```bash
cilium upgrade --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443 \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set authentication.enabled=true \
  --set authentication.mutual.spire.enabled=true \
  --set authentication.mutual.spire.install.enabled=true \
  --set authentication.mutual.spire.install.server.dataStorage.enabled=false \
  --set authentication.mutual.spire.install.server.securityContext.runAsUser=0
kubectl -n cilium-spire rollout status statefulset/spire-server --timeout=300s
kubectl -n cilium-spire rollout status daemonset/spire-agent --timeout=300s
kubectl get pods -A | grep spire
```

```
cilium-spire   spire-agent-xxxxx    1/1     Running   0    2m
cilium-spire   spire-server-0       2/2     Running   0    2m
```

Pod'ы SPIRE живут в namespace `cilium-spire`. Сразу после установки перезапустите Cilium,
чтобы агент и оператор заново зарегистрировали identities в уже работающем SPIRE:

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. CiliumNetworkPolicy с обязательной mutual authentication

```bash
kubectl create ns ingress-115
kubectl create ns app-115
kubectl -n app-115 run backend --image=viktoruj/ping_pong:alpine -l app=backend --port=80 --env=SRV_PORT=80
kubectl -n app-115 expose pod backend --port=80
kubectl -n ingress-115 run client --image=curlimages/curl:8.11.1 -l role=client --command -- sleep 3600
kubectl -n app-115 wait --for=condition=Ready pod/backend --timeout=90s
kubectl -n ingress-115 wait --for=condition=Ready pod/client --timeout=90s

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-auth-required
  namespace: app-115
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: ingress-115
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
      authentication:
        mode: "required"
EOF
```

```
namespace/ingress-115 created
namespace/app-115 created
pod/backend created
service/backend exposed
pod/client created
ciliumnetworkpolicy.cilium.io/backend-auth-required created
```

## 6. Positive/negative control

Негативный контроль - **отдельный Pod** в `app-115`: трафик Pod'а к самому себе (в том числе
через Service) Cilium всегда пропускает, поэтому `exec` в `backend` ничего не доказывает.

```bash
kubectl -n app-115 run intruder --image=curlimages/curl:8.11.1 --command -- sleep 3600
kubectl -n app-115 wait --for=condition=Ready pod/intruder --timeout=90s
sleep 20
kubectl -n ingress-115 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m10 http://backend.app-115.svc.cluster.local/
kubectl -n app-115 exec intruder -- curl -sS -o /dev/null -w 'intruder HTTP:%{http_code}\n' -m5 http://backend.app-115.svc.cluster.local/ || true
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg bpf auth list
```

```
client HTTP:200
curl: (28) Connection timed out after 5002 milliseconds
intruder HTTP:000
SRC IDENTITY   DST IDENTITY   REMOTE NODE ID   AUTH TYPE   EXPIRATION
11376          33174          0                spire       ...
```

`client` из `ingress-115` проходит mutual authentication (запись `spire` в `auth list`) и
получает `200`; `intruder` из `app-115` - transport deny (нет allow для его identity).
Первый запрос нового клиента может занять несколько секунд: SYN отбрасывается, пока идёт
SPIFFE-handshake, затем ретрансмит проходит.

---

## Проверка

```bash
check_result
```
