[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - solution de référence : gVisor, WireGuard et Istio STRICT

> Nous travaillons comme à l'examen : `kubectl`, `cilium` et `istioctl` sur la machine de travail, et les opérations sur le
> nœud (containerd, tcpdump) - sur le nœud lui-même : entrez-y avec `ssh <nœud>`, passez en root
> (`sudo -i`), exécutez les commandes et sortez (`exit`, `exit`). Les noms `gvisor-sandbox`,
> `runc-baseline`, `gvisor-echo`, `market-api`, `market-client`, `mesh-outside` et les chemins des
> artefacts font partie du contrat vérifiable du lab.

## Où trouver des exemples dans la documentation

| Ce qu'il faut | Page et section |
| :--- | :--- |
| La section `runsc` dans `/etc/containerd/config.toml` (`runtime_type = "io.containerd.runsc.v1"`), le redémarrage de containerd et le YAML de `RuntimeClass` avec `handler: runsc` | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`, les champs `scheduling.nodeSelector` et `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| Activer WireGuard (`encryption.enabled=true`, `encryption.type=wireguard`) et vérifier (`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| `PeerAuthentication` avec `mtls.mode: STRICT` | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. Rétablir le runtime de containerd et créer le RuntimeClass

Le nœud `k8s110_node_gvisor` a déjà été livré comme dedicated pool avec `runsc` installé, mais
le bootstrap a volontairement retiré la section runtime de `runsc` de `/etc/containerd/config.toml` -
situation d'examen typique où le binaire est là, mais containerd n'en sait rien.

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# sur le nœud gVisor (root) : le binaire est là, containerd est actif, la section runsc n'est pas dans la config
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# ajouter la section runsc (la valeur de runtime_type doit être exacte) et redémarrer containerd
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # de root
exit   # du nœud gVisor
```

Il n'est pas nécessaire de redémarrer le kubelet : `RuntimeClass` appelle le runtime handler de containerd par
nom à chaque création de Pod, et non au démarrage du kubelet.

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

`scheduling.nodeSelector` est une frontière importante : le scheduler n'affectera pas de workload `runsc` au
control-plane, où un tel handler n'existe pas. Le nœud gVisor est en outre marqué du taint
`sandbox.runtime/gvisor=true:NoSchedule` (`kubectl describe node <nœud-gvisor> | grep Taints`) :
aucun Pod n'y arrivera, sauf ceux qui le tolèrent. Les `scheduling.tolerations` du RuntimeClass
sont automatiquement ajoutés à tous les Pod avec cette classe, c'est pourquoi `gvisor-sandbox` y arrive,
et pas les autres.

## 2. Lancer un Pod sandboxed et un Service

`busybox httpd` donne à la fois un shell pour `uname` et un petit HTTP endpoint pour
l'expérience inter-nœuds de WireGuard. `runtimeClassName` est appliqué au Pod, et non au conteneur.

`nodeSelector` et `tolerations` dans le Pod sont indiqués explicitement : on voit ainsi sur quel nœud il arrive et pourquoi.
C'est la même chose que ce qui est décrit dans le `scheduling` du `RuntimeClass` lui-même. Si on ne les indique pas dans le Pod,
rien ne sera cassé : lors de la création d'un Pod avec `runtimeClassName`, Kubernetes **ajoute** lui-même dedans
le `nodeSelector` et les `tolerations` de `RuntimeClass.scheduling` (vérification : `kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`). Mais alors, dans le manifest, cela ne se voit pas, et sans
`scheduling` dans le RuntimeClass, le Pod pourrait arriver sur un nœud sans `runsc` et ne pas démarrer.

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

gVisor Sentry montre au workload un kernel view synthétique ; `dmesg` peut être
limité. C'est attendu et ce n'est pas une raison de donner au conteneur des privileges superflus.

## 3. Un Pod runc ordinaire pour comparer

L'absence de `runtimeClassName` laisse le handler par défaut `runc`. Le selector place
volontairement ce Pod sur le control-plane, c'est pourquoi les tâches suivantes génèrent du trafic
inter-nœuds.

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

Un conteneur `runc` ordinaire voit le host kernel release, et le workload gVisor, le Sentry view.
C'est une frontière d'exécution supplémentaire, et non un remplacement de `SecurityContext`, seccomp ou de la
vérification de l'image.

## 4. Activer Cilium WireGuard

Cilium gère lui-même les keys et les peers de WireGuard. Nous activons un seul backend de chiffrement - nous
n'ajoutons pas IPsec. Important : le CLI `cilium` **client** (installé sur le worker) n'a pas
la sous-commande `encrypt enable` ; WireGuard s'active via la configuration de Cilium, et non par une
commande de runtime. D'abord, nous enregistrerons les versions et comparerons l'agent avec la requirements matrix :

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

Le cluster a été déployé avec la commande `cilium install`, qui installe Cilium **via Helm**.
La source of truth durable — les Helm values du release `cilium` ; nous utilisons un upgrade avec le Cilium CLI figé puis nous vérifions le ConfigMap live et les agents :

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm ne change que le ConfigMap : le template du DaemonSet ne change pas, donc les agents ne
# redémarrent pas d'eux-mêmes et continuent à fonctionner sans WireGuard - redémarrez-les explicitement.
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

L'état du chiffrement se lit chez l'agent via `cilium-dbg` : c'est le debug CLI in-pod, fourni avec le Cilium agent. Le CLI `cilium` local reste un outil d'install/cluster-level et ne le remplace pas à l'intérieur du Pod. `cilium-dbg status` N'A PAS de flag `--all-encryption` (dans 1.20.x, seuls sont disponibles `--all-addresses`, `--all-clusters`, `--all-controllers`, `--all-health`, `--all-nodes`, `--all-redirects`, `--verbose`) - l'evidence détaillée de peer/allowed-IP/remote-node, nous l'obtenons via `cilium-dbg debuginfo --output json`, et non via un flag inexistant.

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

## 5. Capture d'un paquet WireGuard inter-nœuds

WireGuard utilise par défaut UDP/51871. Un filtre UNIQUEMENT sur `udp port 51871` exclut d'avance
le TCP plaintext du résultat et ne démontre donc PAS son absence - à la place
nous utilisons un même capture scope (`host <remote-node-ip>`, sans filtre de port) et comparons
AVANT/APRÈS l'activation de WireGuard sur un même flow inter-nœuds.

La capture sur `any` N'est PAS un point d'observation correct de l'on-wire state : `any` voit aussi
l'interface interne de Cilium `cilium_wg0`, par laquelle, par conception du tunnel, passe du trafic DÉJÀ DÉCHIFFRÉ.
Il faut capturer sur l'interface physique d'egress vers le nœud distant (pas `any`, `cilium_*`,
`lxc*`, `veth*`).

Il faudra deux terminaux : le **terminal 1** est le control-plane (là, `tcpdump`), le **terminal 2** est la
machine de travail (requêtes et `kubectl`).

```bash
# terminal 2 (machine de travail) : IP du nœud avec le gVisor-Pod : c'est le nœud « distant » pour le control-plane
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# terminal 1 : entrer sur le control-plane et trouver l'interface physique vers remote_ip
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# terminal 1 (control-plane, root) : saisissez la valeur de remote_ip du terminal 2
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- l'interface (ens5), pas any / cilium_* / lxc* / veth*
```

**Baseline : WireGuard désactivé.** Nous désactivons temporairement WireGuard et répétons LA MÊME requête avec LE MÊME
capture scope. À la fin, rétablissez obligatoirement `enable-wireguard: "true"`.

```bash
# terminal 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# terminal 1 (control-plane, root) : capture de 20 secondes, puis lancez aussitôt la requête dans le terminal 2
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# terminal 2 : pendant la capture (les ~15 premières secondes)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# terminal 1 (après la fin de la capture) : le plaintext marker est visible, WireGuard est désactivé
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**Après : WireGuard activé.** Nous rétablissons WireGuard et répétons LA MÊME requête avec LE MÊME scope
de capture : on doit maintenant voir WireGuard UDP/51871 et il ne doit pas y avoir de marker.

```bash
# terminal 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# terminal 1 (control-plane, root) : capture de 20 secondes
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# terminal 2 : pendant la capture
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# terminal 1 (après la fin de la capture)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # de root
exit   # du control-plane
```

```bash
# terminal 2 : récupérer le capture pour la vérification
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

Ne tirez pas de conclusion d'un `tcpdump` dans le Pod netns : là, le trafic avant le Cilium encryption point peut encore être
plaintext. La preuve ici est le passage d'un marker visible (WireGuard désactivé) à son
absence (WireGuard activé) avec UN MÊME capture scope.

## 6. Istio et PeerAuthentication STRICT

Nous n'installons que l'Istio control plane en minimal profile. Le namespace a été préparé avec
`istio-injection=enabled`, donc les workloads dans `market` reçoivent un Envoy sidecar à leur
création. `market-api` se trouve sur le gVisor worker, le client - sur le control-plane, ce qui
rend aussi la requête inter-nœuds.

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
        readinessProbe:
          httpGet:
            path: /
            port: 8080
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

# Baseline (STRICT pas encore appliquée) : un plaintext client hors du mesh doit recevoir 200 :
# cela démontre que la connectivité fonctionne en principe et que tout refus ultérieur
# sera causé précisément par STRICT mTLS, et non par un problème indépendant de DNS/network.
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# on attend : HTTP/1.1 200 OK et à la fin exit_code=0
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

# requête depuis l'intérieur du mesh (client avec sidecar)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# on attend : HTTP/1.1 200 OK et à la fin exit_code=0

# la même requête depuis l'extérieur du mesh (plaintext, sans sidecar)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# on attend : Recv failure: Connection reset by peer et à la fin exit_code=56 (pas 0)
```

`PeerAuthentication` contrôle l'inbound server mode. Le client interne reçoit un
certificat et utilise mTLS automatiquement ; le Pod dans `default` n'a pas de sidecar et envoie du
plaintext, c'est pourquoi l'Envoy server avec `STRICT` réinitialise la connexion. Terminez par :

```bash
check_result
```
