[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - solution de référence (politique réseau VPC CNI : deny par défaut, label, egress)

Toutes les commandes s'exécutent sur la machine de travail via SSH. kubectl est déjà
configuré pour le cluster (le kubeconfig a été construit via `aws eks update-kubeconfig`
au démarrage de la machine). `enableNetworkPolicy` est déjà activé sur l'add-on `vpc-cni`
via Terraform, donc l'agent `aws-network-policy-agent` dans `aws-node` est présent sur les
nœuds avant même que vous ne commenciez les tâches.

## Tâche 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## Tâche 2. Vérification que l'enforcer est activé

On vérifie les deux faits : le conteneur de l'agent dans le DaemonSet `aws-node` et le
flag de configuration de l'add-on.

```bash
mkdir -p /var/work/tests/artifacts/2

{
  echo "--- kubectl describe daemonset aws-node ---"
  kubectl describe daemonset aws-node -n kube-system | grep -A2 aws-network-policy-agent
  echo
  echo "--- aws eks describe-addon vpc-cni ---"
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's|.*/||')
  aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
    --query "addon.configurationValues" --output text
} > /var/work/tests/artifacts/2/enforcer.txt

cat /var/work/tests/artifacts/2/enforcer.txt
```

La sortie doit contenir le conteneur `aws-network-policy-agent` dans `aws-node` et une
ligne comme `enableNetworkPolicy":"true"` dans la configuration de l'add-on. Cela confirme
que le control plane et l'agent du nœud appliquent réellement les objets `NetworkPolicy`,
pas seulement les acceptent en tant qu'objet API.

## Tâche 3. Symptôme avant toute politique : la connectivité est autorisée par défaut

On crée `api` (le serveur) et `client` (pour `kubectl exec curl`), plus un Service pour
`api` :

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

On vérifie la connectivité : `client` devrait pouvoir atteindre `api` via le nom du
Service.

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

Le fichier doit contenir `HTTP_CODE=200` : sans aucune politique, VPC CNI autorise tout le
trafic east-west - aucun objet `NetworkPolicy` n'a encore été créé dans le cluster.

## Tâche 4. Deny par défaut de l'ingress

On refuse tout le trafic entrant dans le namespace `eks-110` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: eks-110
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF
```

On vérifie que `client` ne peut plus atteindre `api` (on attend le timeout pour ne pas
rester bloqué) :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

Le fichier doit montrer `HTTP_CODE=000` (connexion non établie) - `podSelector: {}`
signifie « chaque pod du namespace », et `policyTypes: ["Ingress"]` sans section
`ingress` signifie « refuser tout le trafic entrant ». C'est un deny par défaut classique,
appliqué par l'agent `aws-network-policy-agent` via eBPF.

## Tâche 5. Autoriser par label : `app: frontend` -> `app: api`

On ajoute une politique qui autorise le trafic entrant vers les pods `app: api`
uniquement depuis les pods labellisés `app: frontend`, sur le port `8080` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

On crée un client avec le bon label (`frontend`) et un client sans celui-ci
(`client-other`), pour pouvoir comparer le résultat :

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` définit automatiquement le label `app: <name>`, donc
`frontend` a déjà `app: frontend`, tandis que `client-other` obtient `app: client-other`
(qui ne correspond pas à la règle).

On vérifie les deux cas :

```bash
mkdir -p /var/work/tests/artifacts/5
FRONTEND=$(kubectl get po -n eks-110 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER=$(kubectl get po -n eks-110 -l app=client-other -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_frontend.txt

kubectl exec "$OTHER" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_other.txt

cat /var/work/tests/artifacts/5/allowed_frontend.txt
cat /var/work/tests/artifacts/5/blocked_other.txt
```

`allowed_frontend.txt` doit montrer `HTTP_CODE=200` (le label correspondait à la règle
`podSelector` dans `ingress.from`), tandis que `blocked_other.txt` doit montrer
`HTTP_CODE=000` (le même `default-deny-ingress` de la tâche 4 s'applique toujours à
chaque pod pour lequel il n'existe pas de règle d'autorisation explicite).

## Tâche 6. Egress avec une exception DNS

On restreint le trafic sortant depuis `frontend` : on autorise uniquement le trafic vers
les pods `app: api` et vers le DNS (`kube-system`, ports `53` UDP/TCP). Tout le reste
(toute adresse externe) est bloqué.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

On vérifie que la résolution du nom `api` et son accès fonctionnent toujours (le DNS et
l'egress autorisé vers le pod `api` sont tous les deux nécessaires) :

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` confirme que l'entrée `to.podSelector: app: api` de la politique autorise
le trafic vers `api`, et que l'exception sur le port `53` dans `kube-system` permet à
`frontend` de résoudre le nom.

On vérifie maintenant qu'une adresse externe arbitraire (non couverte par les règles
autorisées) est bloquée :

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` confirme le deny : `restrict-egress` définit la liste complète des
destinations autorisées pour `app: frontend`, tout le reste est refusé (y compris
internet et tout autre pod du cluster en dehors de `api`).

## Vérification rapide

```bash
check_result
```
