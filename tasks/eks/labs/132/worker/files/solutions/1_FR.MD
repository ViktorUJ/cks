[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 132 - solution de référence (Cilium en mode CNI chaining sur VPC CNI)

Toutes les commandes s'exécutent sur la machine de travail (worker) par SSH. kubectl et
helm sont déjà configurés (le kubeconfig a été construit via `aws eks update-kubeconfig` au
démarrage de la machine).

> Les versions de Cilium et les noms exacts des flags de values du mode chaining changent
> vite entre les releases. Les commandes ci-dessous ont été vérifiées sur un banc en vie
> avec Cilium `1.20.0` et EKS `1.36`. Si vous utilisez une autre version, vérifiez la
> syntaxe avec la documentation Cilium
> (`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`).

## Tâche 1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## Tâche 2. Charge sur le pool `cilium-demo` sans Cilium

Le NodePool `cilium-demo` existe déjà en tant que code (taint
`dedicated=cilium-demo:NoSchedule`, label `work_type=cilium-demo`), mais tant qu'aucun pod
avec toleration n'y arrive, Karpenter ne montera aucun nœud. Nous créons tout de suite le
Deployment `api` et `client` avec `nodeSelector` et toleration, pour qu'ils atterrissent
exactement là :

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

Karpenter monte un nouveau nœud dans le pool `cilium-demo` (généralement 60-90 secondes).
Dès que `rollout status` confirme la disponibilité, nous vérifions la connectivité via le
VPC CNI standard - Cilium n'est pas encore installé :

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## Tâche 3. Cilium via Helm en mode CNI chaining, uniquement sur `cilium-demo`

Nous ajoutons le dépôt Cilium et préparons le fichier de values. Le paramètre clé est
`cni.chainingMode: aws-cni` : VPC CNI (`aws-node`) reste l'IPAM principal, Cilium se branche
dans la chaîne et ajoute des programmes eBPF au-dessus de l'interface du pod déjà
configurée.

Trois blocs `nodeSelector`/`tolerations` (niveau supérieur pour l'agent, `envoy` et
`operator`) confinent tous les composants de Cilium au pool `cilium-demo`. Le
`nodeSelector` de niveau supérieur n'est hérité que par le DaemonSet `cilium` ; `cilium-envoy`
et `cilium-operator` ont leurs propres sections, et sans elles les pods Envoy restent
bloqués en `Pending` sur tous les autres nœuds, et `cilium status` affiche
`Envoy DaemonSet: 1 errors`.

Nous désactivons séparément `operator.unmanagedPodWatcher.restart`. C'est un flag
obligatoire pour ce banc, pas un réglage fin : par défaut l'opérateur supprime toutes les
15 secondes les pods qui n'ont pas de `CiliumEndpoint`, pour qu'ils redémarrent et rejoignent
la chaîne CNI. Les pods `coredns` vivent sur Fargate, où il n'y a et ne peut y avoir d'agent
Cilium, donc ils ne deviendront jamais managed - l'opérateur les tue sans fin, faisant
naître chaque fois un nouveau nœud Fargate, et le DNS du cluster tombe (détails dans la
section « Pièges » ci-dessous).

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

Les pods `api` et `client` ont été démarrés avant l'installation de Cilium, donc le CNI
chaining n'a pas encore agi sur eux (la documentation Cilium prévient explicitement de
cela : les pods existants doivent être redémarrés). Nous redémarrons les deux Deployment :

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Nous installons le Cilium CLI et vérifions l'état :

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

Dans la sortie doivent apparaître `Cilium: OK`, `Operator: OK` et `Envoy DaemonSet: OK`, et
le nombre `Desired` des deux DaemonSet doit correspondre au nombre de nœuds `cilium-demo`.

## Tâche 4. Preuve du chaining : les adresses viennent toujours de VPC CNI

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

Les IP des pods `api` et `client` proviennent du CIDR `10.10.0.0/16` - le même intervalle
que la VPC elle-même. Si c'était un remplacement complet de VPC CNI avec mode overlay, les
adresses viendraient d'un pool virtuel séparé (`cluster-pool`), pas du sous-réseau du nœud.
Ici l'IPAM est resté du côté de VPC CNI - c'est précisément le principe du chaining
(chapter 8).

## Tâche 5. Politique L7 : GET uniquement

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

Nous vérifions le GET autorisé et le POST bloqué :

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

Le GET passe (`HTTP_CODE=200`), le POST est bloqué par le proxy Envoy de Cilium au niveau
L7 (`HTTP_CODE=403`, accès refusé avant même que la requête n'atteigne l'application). La
NetworkPolicy intégrée de VPC CNI n'a pas ce filtre par méthode HTTP - seulement L3/L4
(chapter 8).

Utilisez le nom complet `ciliumnetworkpolicies.cilium.io` : le nom court `cnp` est ambigu
dans ce cluster, car VPC CNI apporte sa propre ressource
`clusternetworkpolicies.networking.k8s.aws`, et kubectl vous en avertit.

## Tâche 6. Politique FQDN : egress uniquement vers `aws.amazon.com`

Il y a deux endroits où cette politique se comporte différemment de l'exemple typique de la
documentation.

Premièrement : la règle pour le DNS ne peut pas s'écrire via `toEndpoints` avec le label
`k8s-app: kube-dns`. `toEndpoints` fonctionne par identité Cilium, et les pods `coredns` de
ce cluster vivent sur Fargate, où il n'y a pas d'agent Cilium - ils n'ont pas de
`CiliumEndpoint`, n'entrent pas dans l'`ipcache` et du point de vue de la politique
apparaissent comme `reserved:world`. Une règle par label ne correspondrait jamais, le DNS
serait fermé par default-deny, et `curl` ne pourrait même pas résoudre le nom. Nous
autorisons donc le DNS par CIDR : la plage de service du cluster (`172.20.0.0/16`, où se
trouve le ClusterIP `kube-dns`) et le CIDR de la VPC (`10.10.0.0/16`, où vivent les pods
`coredns` eux-mêmes). Les règles L7 `rules.dns` sur `toCIDRSet` fonctionnent normalement -
c'est exactement ainsi que Cilium documente le cas d'un serveur DNS externe.

Deuxièmement : le `endpointSelector` sur `app: client` active le default-deny pour tout
l'egress de ce pod. Si nous ne laissons que `toFQDNs` et le DNS, le GET vers `api` de la
tâche 5 casserait - ses paquets seraient rejetés. Donc, comme troisième bloc, nous
autorisons explicitement l'egress vers `api:8080`. Ainsi l'état final du banc est cohérent :
la tâche 5 et la tâche 6 sont vraies en même temps.

L'ordre des blocs compte : `toFQDNs` doit rester en premier (`egress[0]`), le test
automatisé regarde précisément là.

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

Nous vérifions :

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

`aws.amazon.com` se résout et `curl` passe - `HTTP_CODE=200`. `example.com` se résout aussi
(le DNS est autorisé), mais la session TCP vers son adresse n'entre pas dans `toFQDNs`, les
paquets sont rejetés, et `curl` reste bloqué jusqu'à `--max-time` - `HTTP_CODE=000`. La
NetworkPolicy intégrée de VPC CNI n'a pas du tout ce type de politique par nom DNS -
seulement `ipBlock` par IP/CIDR (chapter 8).

## Tâche 7. Hubble : observabilité des flux avec verdict

Nous activons Hubble relay au-dessus du Cilium déjà installé, avec le même `nodeSelector`
sur `cilium-demo` :

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

Nous installons le Hubble CLI :

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

Nous lançons un port-forward vers le relay (`4245`), répétons les requêtes bloquées des
tâches 5 et 6 pour obtenir des événements `DROPPED`, et lisons le flux :

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

Lancez toujours le port-forward via `setsid nohup ... </dev/null &` : un
`kubectl port-forward &` classique reste accroché à la session SSH et se coupe si celle-ci
se termine.

Le fichier doit contenir des lignes avec le verdict `DROPPED` - ce sont les SYN rejetés vers
des adresses `example.com` (`policy-verdict:none ... Policy denied DROPPED`). La
NetworkPolicy intégrée de VPC CNI n'a pas une telle carte de flux avec verdict par flux -
là il n'y a que des logs de l'agent `aws-network-policy-agent` et des métriques
(chapter 8).

## Tâche 8. Comparaison : VPC CNI NP face à Cilium dans ce lab

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
Ce que sait faire la NetworkPolicy intégrée de VPC CNI, ce qu'a ajouté Cilium, ce que ça coûte :

1. VPC CNI NetworkPolicy ne couvre que L3/L4. Cilium dans ce lab a ajouté une règle L7 par
   méthode HTTP : GET autorisé (200), POST rejeté par le proxy Envoy avec le code 403.

2. VPC CNI NP n'a pas de politiques par nom DNS. Cilium a ajouté une CiliumNetworkPolicy
   avec toFQDNs - l'egress n'est autorisé que vers aws.amazon.com, example.com est rejeté
   (HTTP_CODE=000).

3. Le diagnostic de la VPC CNI NP intégrée se limite aux logs de l'agent et aux métriques.
   Cilium a apporté Hubble : une carte de flux avec verdict par flux (FORWARDED/DROPPED)
   via hubble observe.

4. Le prix à payer pour cela : votre propre release Helm de Cilium avec ses propres mises à
   jour, un second modèle de CRD pour l'équipe, une couche supplémentaire dans le datapath,
   et le fait que les pods hors du pool cilium-demo (par exemple coredns sur Fargate)
   restent hors du datapath de Cilium et ne sont visibles dans les politiques que comme
   reserved:world - les règles par label ne s'appliquent pas à eux.

5. Un remplacement complet de VPC CNI (quand aws-node est supprimé et que Cilium devient
   lui-même l'IPAM) n'entre pas dans le périmètre de ce lab : changer le CNI sur un cluster
   en production est une opération blue/green via de nouveaux nœuds, pas un basculement de
   flag à la volée (chapter 8, section 8.8). Seule l'option sûre - le CNI chaining - a été
   pratiquée ici.
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## Vérification rapide

```bash
check_result
```

## Pièges rencontrés dans ce lab

Les quatre points ont été vérifiés sur un banc en vie.

1. `cilium-operator` fait tomber le DNS du cluster. Par défaut
   `operator.unmanagedPodWatcher.restart=true` : l'opérateur supprime toutes les 15
   secondes les pods sans `CiliumEndpoint`. `coredns` sur Fargate ne le deviendra jamais,
   donc ses pods sont supprimés en boucle, une nouvelle micro-VM Fargate naît à chaque
   fois, et le DNS du cluster va et vient. Le symptôme du côté du pod :
   `nslookup` renvoie `connection timed out; no servers could be reached`. On peut voir qui
   supprime exactement les pods dans le log d'audit du control plane : dans les entrées
   `verb: delete` sur les pods `coredns` figure
   `user.username = system:serviceaccount:kube-system:cilium-operator` et
   `userAgent = cilium-operator-generic/1.20.0`. Cela se corrige avec le flag
   `operator.unmanagedPodWatcher.restart=false` (`cilium-config` obtiendra
   `unmanaged-pod-watcher-interval: "0"`).

2. Le profil Fargate ne connaît pas `nodeSelector`. Si le profil couvre tout le namespace
   `kube-system` (`selectors = [{ namespace = "kube-system" }]`), le webhook Fargate marque
   de son profil TOUT pod que vous ajoutez plus tard à ce namespace, y compris
   `cilium-operator`. Ensuite le pod n'est ordonnancé que par `fargate-scheduler`, qui ne
   connaît ni `hostNetwork` ni `nodeSelector` et ne revient jamais au scheduler normal.
   Symptômes : `Pod not supported on Fargate: fields not supported: HostNetwork, port
   contains HostIP or HostPort`, et après `operator.hostNetwork=false` -
   `MatchNodeSelector failed: Fargate profile kube-system cannot satisfy pod's node
   selector/affinity requirements`. C'est pourquoi dans ce lab le profil est restreint par
   le sélecteur de label `eks.amazonaws.com/component: coredns` (voir
   `eks_fargate_system/terragrunt.hcl`).

3. Le profil Fargate a été recréé - redémarrez les pods qu'il doit récupérer. La mutation du
   pod n'a lieu qu'au moment de sa création, donc un pod `karpenter` créé avant que le
   nouveau profil ne devienne `ACTIVE` restera pour toujours en `Pending` avec
   `0/N nodes are available: N node(s) had untolerated taint(s)`. Cela se corrige avec
   `kubectl delete pod` de ce pod.

4. Les pods `cilium-envoy` restent en `Pending` si seul le `nodeSelector` de niveau
   supérieur est défini. Le DaemonSet `cilium-envoy` a sa propre section
   `envoy.nodeSelector` / `envoy.tolerations` ; sans elle il vise tous les nœuds Linux, et
   `cilium status` affiche `Envoy DaemonSet: 1 errors`.
