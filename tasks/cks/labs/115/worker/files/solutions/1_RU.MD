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
kubectl get nodes
```

```
KubeProxyReplacement:   True   [eth0 10.115.1.x (Direct Routing)]
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
cilium status --wait
```

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

```bash
cilium upgrade --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443 \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set authentication.mutual.spire.enabled=true \
  --set authentication.mutual.spire.install.enabled=true
kubectl get pods -A | grep spire
```

```
kube-system   spire-agent-xxxxx    1/1     Running   0    2m
kube-system   spire-server-0       1/1     Running   0    2m
```

```bash
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

```bash
kubectl -n ingress-115 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m5 http://backend.app-115.svc.cluster.local/
kubectl -n app-115 exec backend -- curl -sS -o /dev/null -w 'self HTTP:%{http_code}\n' -m5 http://backend.app-115.svc.cluster.local/
```

```
client HTTP:200
self HTTP:000
curl: (28) Connection timed out after 5000 milliseconds
```

`client` из `ingress-115` проходит mutual authentication и получает `200`; probe из
`app-115` с чужой identity - transport deny (не `k8s-app=backend` selector allow, и не
`ingress-115` identity, требуемая policy).

---

## Проверка

```bash
check_result
```
