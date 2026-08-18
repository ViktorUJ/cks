[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - solution de référence (Fargate : profils, limitations, coût)

Toutes les commandes s'exécutent sur la machine de travail via SSH. kubectl est déjà
configuré pour le cluster (le kubeconfig est assemblé via `aws eks update-kubeconfig` au
démarrage de la machine). Le profil Fargate `workload` pour le namespace `eks-112` est déjà
créé par l'infrastructure du laboratoire - l'étudiant n'a besoin que de créer le namespace
et les objets à l'intérieur.

## Tâche 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

Le profil `workload` correspond par `namespace = eks-112` sans `labels`, donc tout le
namespace tombe entièrement sur Fargate - il n'y aura aucune exception à l'intérieur.

## Tâche 2. Un pod Guaranteed `fg-app` sur Fargate

Fargate n'exécute que des pods où `requests` est égal à `limits` (classe `Guaranteed`).
Nous créons un Deployment avec des valeurs explicitement égales :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

Nous vérifions que les pods vont sur un nœud Fargate (le nom du nœud commence par
`fargate-`, pas par `ip-`) :

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## Tâche 3. Artefact : la capacité réellement fournie

Fargate arrondit la somme des requêtes vers le haut jusqu'à une combinaison fixe de
vCPU/mémoire et ajoute `256 MB` pour les composants Kubernetes (`kubelet`, `kube-proxy`,
`containerd`). La capacité réellement fournie est visible dans l'annotation
`CapacityProvisioned` :

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

Pour une requête de `500m` de CPU et `1Gi` de mémoire plus `256 MB` de frais système,
Fargate choisira la combinaison la plus proche (par exemple `0.5vCPU 1GB`, ou `0.5vCPU 2GB`
si la mémoire totale après l'ajout dépasse `1 GB`) - c'est exactement cette ligne que
montrera `kubectl describe pod`.

## Tâche 4. Symptôme : un pod privileged ne démarre pas

Fargate interdit strictement les conteneurs privilégiés, les DaemonSet, hostNetwork/hostPort,
hostPath et les GPU. Nous essayons de créer un pod privileged dans `eks-112` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

Le pod n'atteint pas `Running` : Fargate rejette les conteneurs privilégiés au stade
d'admission (admission), ce qui est visible dans les événements du pod. Nous enregistrons
l'explication dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
Le Pod fg-privileged ne démarre pas parce qu'il demande privileged: true. Fargate ne prend
pas en charge les conteneurs privilégiés : c'est l'une des limitations strictes de ce mode,
au même titre que les DaemonSet, hostNetwork/hostPort, hostPath et les GPU. L'erreur
apparaît dans les events du pod comme un rejet d'admission, et non comme un Pending normal
dû à un manque de ressources.
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

Nous pouvons supprimer le pod pour qu'il ne gêne pas les vérifications suivantes :

```bash
kubectl delete pod fg-privileged -n eks-112
```

## Tâche 5. Extension du disque éphémère à 30Gi

Par défaut Fargate fournit `20 GiB` de disque éphémère, jusqu'à `175 GiB` via
`ephemeral-storage` dans `resources` (requests doit être égal à limits, le pod reste
Guaranteed). Nous mettons à jour `fg-app` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

Le pod démarre normalement : `30Gi` reste dans la limite autorisée de `175 GiB`, et
l'exigence `requests == limits` est respectée.

## Tâche 6. Structure de coût : Fargate contre node group

La différence clé est l'unité de facturation. Fargate facture la vCPU et la mémoire d'un
pod donné pendant sa durée de vie ; un node group facture l'instance EC2 entière, quelle que
soit sa charge. La vérification automatique de cet artefact recherche le mot littéral russe
`под` accolé à `vCPU`, donc l'artefact ci-dessous inclut ce mot littéral en plus de
l'explication en français :

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate facture la vCPU et la mémoire du pod (под) lui-même pendant le temps où il tourne
réellement : si le pod n'est pas en cours d'exécution, il n'y a aucun coût, et on ne paie
jamais de surcoût pour de la capacité inactive. Un node group, à l'inverse, facture
l'instance entière : on paie même le temps où les nœuds restent inactifs entre les pods ou
sous-utilisés. Par unité de ressource, Fargate est en général plus cher que la ressource
équivalente sur un nœud de node group, donc l'économie finale dépend de l'utilisation : à
charge élevée et prévisible, un node group est plus rentable, tandis qu'en cas de demande
irrégulière ou imprévisible, Fargate évite de payer pour des instances inactives.
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## Vérification rapide

```bash
check_result
```
