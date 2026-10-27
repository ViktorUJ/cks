[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - solution brève

> Advanced/production track. Les versions/flags exacts de la CLI peuvent différer entre les
> releases de Cilium - vérifiez `cilium install --help`/`cilium upgrade --help`
> si quelque chose ci-dessous ne fonctionne pas littéralement.

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

## 2. Cilium comme remplacement de kube-proxy

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

> `cilium status` de cilium-cli 0.19 n'affiche pas les lignes `KubeProxyReplacement`/`Encryption` ;
> elles sont affichées par `cilium-dbg status` à l'intérieur du Pod de l'agent (c'est aussi ainsi que le checker vérifie).

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

`403` (et non `000`) signifie que le TCP/TLS jusqu'à l'API via le Service ClusterIP fonctionne réellement sans
kube-proxy ; `403` est attendu ici, car la requête est sans token, le simple fait d'obtenir une réponse suffit.

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

> `cilium upgrade` ne modifie que le ConfigMap : l'agent applique `encryption.*` après le redémarrage
> (avant celui-ci, `Encryption: Disabled`).

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

Pas de régression - le même résultat qu'à la tâche 2.

## 4. Cilium Mutual Authentication (SPIRE)

Trois paramètres en plus des paramètres minimaux de la tâche sont nécessaires précisément sur ce banc :

- `authentication.enabled=true` - sans lui, le chart rejette `spire.enabled=true`
  (`SPIRE integration requires .Values.authentication.enabled=true ...`).
- `install.server.dataStorage.enabled=false` - dans le cluster, il n'y a pas de StorageClass, donc le PVC
  `spire-data-spire-server-0` reste indéfiniment `Pending`, et `spire-server-0` reste lui aussi `Pending`
  (pour le lab, un stockage éphémère suffit).
- `install.server.securityContext.runAsUser=0` - l'image `spire-server` démarre sous l'uid 1000 et
  ne peut pas créer `api.sock` dans le répertoire hostPath `root:755` ; le serveur omet silencieusement de démarrer ses
  endpoints et est tué par la liveness probe (`Waiting for spire-server to start...` dans `cilium-init`).

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

Les Pods SPIRE vivent dans le namespace `cilium-spire`. Juste après l'installation, redémarrez Cilium,
afin que l'agent et l'opérateur réenregistrent les identities dans le SPIRE déjà en fonctionnement :

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. CiliumNetworkPolicy avec mutual authentication obligatoire

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

Le contrôle négatif est un **Pod distinct** dans `app-115` : le trafic d'un Pod vers lui-même (y compris
via un Service), Cilium le laisse toujours passer, donc un `exec` dans `backend` ne démontre rien.

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

`client` de `ingress-115` réussit la mutual authentication (l'entrée `spire` dans `auth list`) et
reçoit `200` ; `intruder` de `app-115` - transport deny (pas d'allow pour son identity).
La première requête d'un nouveau client peut prendre quelques secondes : le SYN est abandonné (drop) pendant le
SPIFFE-handshake, puis la retransmission passe.

---

## Vérification

```bash
check_result
```
