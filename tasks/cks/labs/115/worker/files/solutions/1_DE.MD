[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - Kurzlösung

> Advanced/production track. Die genauen Versionen/Flags der CLI können sich zwischen den
> Cilium-Releases unterscheiden - prüfe `cilium install --help`/`cilium upgrade --help`,
> wenn etwas von dem Folgenden nicht wortwörtlich funktioniert.

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

## 2. Cilium als Ersatz für kube-proxy

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

> `cilium status` aus cilium-cli 0.19 gibt die Zeilen `KubeProxyReplacement`/`Encryption` nicht aus;
> sie zeigt `cilium-dbg status` innerhalb des Pods des agent (so prüft es auch der Checker).

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

`403` (nicht `000`) - bedeutet, dass TCP/TLS zur API über den Service ClusterIP tatsächlich ohne
kube-proxy funktioniert; `403` ist hier erwartet, da die Anfrage ohne Token erfolgt, die bloße Tatsache einer Antwort genügt.

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

> `cilium upgrade` ändert nur das ConfigMap: Der agent übernimmt `encryption.*` nach dem Neustart
> (davor `Encryption: Disabled`).

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

Keine Regression - dasselbe Ergebnis wie in Aufgabe 2.

## 4. Cilium Mutual Authentication (SPIRE)

Drei Parameter über die minimalen aus der Aufgabe hinaus werden gerade in diesem Teststand gebraucht:

- `authentication.enabled=true` - ohne ihn lehnt das chart `spire.enabled=true` ab
  (`SPIRE integration requires .Values.authentication.enabled=true ...`).
- `install.server.dataStorage.enabled=false` - im Cluster gibt es keine StorageClass, daher bleibt die PVC
  `spire-data-spire-server-0` für immer `Pending`, und `spire-server-0` ist `Pending`
  (für die Lab genügt ephemerer Speicher).
- `install.server.securityContext.runAsUser=0` - das Image `spire-server` startet als uid 1000 und
  kann `api.sock` im hostPath-Verzeichnis `root:755` nicht erstellen; der Server beendet die
  endpoints stillschweigend und wird von der liveness-probe getötet (`Waiting for spire-server to start...` in `cilium-init`).

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

Die SPIRE-Pods leben im Namespace `cilium-spire`. Starte Cilium direkt nach der Installation neu,
damit agent und operator die identities im bereits laufenden SPIRE neu registrieren:

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. CiliumNetworkPolicy mit verpflichtender mutual authentication

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

Die negative control ist ein **separater Pod** in `app-115`: Traffic eines Pods zu sich selbst (auch
über einen Service) lässt Cilium immer durch, daher belegt ein `exec` in `backend` nichts.

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

`client` aus `ingress-115` besteht die mutual authentication (Eintrag `spire` in `auth list`) und
erhält `200`; `intruder` aus `app-115` - transport deny (kein allow für seine identity).
Die erste Anfrage eines neuen Clients kann einige Sekunden dauern: Das SYN wird verworfen, solange der
SPIFFE-handshake läuft, dann geht die Retransmission durch.

---

## Prüfung

```bash
check_result
```
