[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - solución breve

> Advanced/production track. Las versiones/flags exactos del CLI pueden diferir entre
> releases de Cilium: comprueba `cilium install --help`/`cilium upgrade --help`
> si algo de lo indicado abajo no funciona tal cual.

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

## 2. Cilium como reemplazo de kube-proxy

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

> `cilium status` de cilium-cli 0.19 no imprime las líneas `KubeProxyReplacement`/`Encryption`;
> las muestra `cilium-dbg status` dentro del Pod del agente (así lo comprueba también el checker).

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

`403` (no `000`) significa que el TCP/TLS hasta la API a través del Service ClusterIP realmente funciona sin
kube-proxy; `403` aquí es lo esperado, ya que la petición se hace sin token; basta con que haya respuesta.

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

> `cilium upgrade` cambia solo el ConfigMap: el agente aplica `encryption.*` tras el reinicio
> (hasta entonces, `Encryption: Disabled`).

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

No hay regresión: el mismo resultado que en la tarea 2.

## 4. Cilium Mutual Authentication (SPIRE)

Además de los parámetros mínimos de la tarea, este banco de pruebas requiere precisamente tres más:

- `authentication.enabled=true`: sin él el chart rechaza `spire.enabled=true`
  (`SPIRE integration requires .Values.authentication.enabled=true ...`).
- `install.server.dataStorage.enabled=false`: en el clúster no hay StorageClass, por lo que el PVC
  `spire-data-spire-server-0` se queda para siempre en `Pending`, y `spire-server-0` en `Pending`
  (para el laboratorio basta con un almacenamiento efímero).
- `install.server.securityContext.runAsUser=0`: la imagen `spire-server` arranca con uid 1000 y
  no puede crear `api.sock` en el directorio hostPath `root:755`; el servidor silenciosamente no levanta sus
  endpoints y la liveness probe lo mata (`Waiting for spire-server to start...` en `cilium-init`).

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

Los Pods de SPIRE viven en el namespace `cilium-spire`. Justo después de la instalación, reinicia Cilium
para que el agente y el operador vuelvan a registrar las identities en el SPIRE ya en funcionamiento:

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. CiliumNetworkPolicy con mutual authentication obligatoria

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

El control negativo es un **Pod aparte** en `app-115`: el tráfico de un Pod a sí mismo (incluso
a través del Service) Cilium siempre lo deja pasar, por lo que un `exec` en `backend` no demuestra nada.

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

`client` de `ingress-115` pasa la mutual authentication (la entrada `spire` en `auth list`) y
recibe `200`; `intruder` de `app-115`: transport deny (no hay allow para su identity).
La primera petición de un nuevo cliente puede tardar unos segundos: el SYN se descarta mientras dura el
handshake SPIFFE, y luego la retransmisión pasa.

---

## Comprobación

```bash
check_result
```
