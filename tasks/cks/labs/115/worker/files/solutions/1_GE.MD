[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 115 - მოკლე ამოხსნა

> Advanced/production track. CLI-ის ზუსტი ვერსიები/ფლაგები Cilium-ის რელიზებს შორის
> შეიძლება განსხვავდებოდეს - შეამოწმეთ `cilium install --help`/`cilium upgrade --help`,
> თუ ქვემოთ რომელიმე სიტყვასიტყვით არ მუშაობს.

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

## 2. Cilium როგორც kube-proxy-ის ჩამნაცვლებელი

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

> cilium-cli 0.19-ის `cilium status` სტრიქონებს `KubeProxyReplacement`/`Encryption` არ ბეჭდავს;
> მათ აჩვენებს `cilium-dbg status` აგენტის Pod-ის შიგნით (checker-იც ასე ამოწმებს).

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

`403` (და არა `000`) - ნიშნავს, რომ TCP/TLS API-მდე Service ClusterIP-ით რეალურად მუშაობს
kube-proxy-ის გარეშე; `403` აქ მოსალოდნელია, რადგან მოთხოვნა token-ის გარეშეა, თავად პასუხის ფაქტი საკმარისია.

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

> `cilium upgrade` მხოლოდ ConfigMap-ს ცვლის: აგენტი `encryption.*`-ს გადატვირთვის შემდეგ იყენებს
> (მანამდე `Encryption: Disabled`).

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

რეგრესია არ არის - იგივე შედეგი, რაც დავალება 2-ში.

## 4. Cilium Mutual Authentication (SPIRE)

დავალებაში მითითებული მინიმალური პარამეტრების გარდა, სწორედ ამ სტენდზე საჭიროა კიდევ სამი პარამეტრი:

- `authentication.enabled=true` - მის გარეშე chart უარყოფს `spire.enabled=true`-ს
  (`SPIRE integration requires .Values.authentication.enabled=true ...`).
- `install.server.dataStorage.enabled=false` - კლასტერში StorageClass არ არის, ამიტომ PVC
  `spire-data-spire-server-0` სამუდამოდ `Pending`-ში რჩება, ხოლო `spire-server-0` - `Pending`-ში
  (ლაბისთვის ეფემერული საცავი საკმარისია).
- `install.server.securityContext.runAsUser=0` - image `spire-server` ეშვება uid 1000-ით და
  ვერ ქმნის `api.sock`-ს hostPath-დირექტორიაში `root:755`; სერვერი ჩუმად ხურავს
  endpoint-ებს და liveness-probe მას კლავს (`Waiting for spire-server to start...` `cilium-init`-ში).

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

SPIRE-ის Pod-ები განთავსებულია namespace `cilium-spire`-ში. დაყენებისთანავე გადატვირთეთ Cilium,
რომ აგენტმა და ოპერატორმა identity-ები ხელახლა დაარეგისტრირონ უკვე მომუშავე SPIRE-ში:

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. CiliumNetworkPolicy სავალდებულო mutual authentication-ით

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

ნეგატიური კონტროლი - **ცალკე Pod** `app-115`-ში: Pod-ის ტრაფიკს საკუთარი თავისკენ (Service-ის გავლითაც) Cilium ყოველთვის
უშვებს, ამიტომ `exec` `backend`-ში არაფერს ამტკიცებს.

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

`client` `ingress-115`-დან გადის mutual authentication-ს (ჩანაწერი `spire` `auth list`-ში) და
იღებს `200`-ს; `intruder` `app-115`-დან - transport deny (მისი identity-სთვის allow არ არის).
ახალი კლიენტის პირველ მოთხოვნას შეიძლება რამდენიმე წამი დასჭირდეს: SYN იგდება, სანამ
SPIFFE-handshake მიმდინარეობს, შემდეგ retransmit გადის.

---

## შემოწმება

```bash
check_result
```
