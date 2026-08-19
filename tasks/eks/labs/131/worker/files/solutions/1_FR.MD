[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 131 - solution de référence (le PDB bloque drain, topology spread, matchLabelKeys)

Toutes les commandes s'exécutent sur la machine de travail (worker) par SSH. kubectl est
déjà configuré pour le cluster (le kubeconfig a été construit via `aws eks
update-kubeconfig` au démarrage de la machine).

## Tâche 1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## Tâche 2. Deployment `web` avec topology spread et matchLabelKeys

Le cluster du lab tourne sur deux zones (`eu-central-1a` et `eu-central-1b`), avec des
sous-réseaux privés `eks1`/`eks2` pour chacune. C'est suffisant pour que Karpenter répartisse
les nœuds sur deux zones, et pour que `topologySpreadConstraints` répartisse les pods entre
eux.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

Vérifions la disponibilité et la répartition entre les zones :

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

Dans la colonne `NODE` des trois pods, il doit y avoir au moins deux nœuds différents, et
ces nœuds doivent avoir des valeurs différentes de `topology.kubernetes.io/zone`.
`matchLabelKeys: [pod-template-hash]` n'affecte pas encore ce premier déploiement (une
seule révision) - il se manifestera à la tâche 6.

## Tâche 3. Symptôme : un PDB trop strict bloque drain

Créons un PDB qui exige la disponibilité des 3 réplicas - le budget n'autorise l'éviction
d'aucun pod :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

Prenons le nœud d'un des réplicas de `web` et essayons de l'évacuer :

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

La commande échoue : `kubectl drain` essaie d'appeler l'API d'éviction pour le pod `web`,
mais l'API répond `429` pour violation du budget, et après `--timeout=60s` drain échoue
avec `global timeout reached`. La cause est le PDB `web-pdb` avec `minAvailable: 3`, qui
exige 3 réplicas disponibles alors qu'il y en a exactement 3, donc le budget n'autorise
jamais l'éviction d'un seul : l'éviction ne peut jamais avancer, drain reste bloqué jusqu'à
ce que le budget soit assoupli.

Ajoutons l'explication au même artefact :

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

Explication : le PDB web-pdb fixe minAvailable: 3, égal au nombre de réplicas du
Deployment web. Le budget n'autorise l'éviction d'aucun pod, donc l'API d'éviction répond
429, et kubectl drain se bloque/expire - c'est le symptôme d'un PDB trop strict, pas une
erreur du cluster.
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## Tâche 4. Correction : on assouplit le PDB et on refait drain

On remet d'abord le nœud en service (drain l'a déjà cordonné) :

```bash
kubectl uncordon "$NODE"
```

On assouplit le budget : on peut maintenant évacuer un réplica sur trois
(`minAvailable: 2`) :

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

On refait drain sur le même nœud - le budget autorise maintenant l'éviction d'un pod, drain
passe :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

On remet le nœud en service et on attend que les 3 réplicas soient à nouveau prêts (le
remplacement s'est placé sur un autre nœud) :

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## Tâche 5. unhealthyPodEvictionPolicy: AlwaysAllow

Par défaut, le PDB utilise la politique `IfHealthyBudget` : un pod non sain (pas `Ready`)
ne peut être évincé que si le budget ne serait pas violé de toute façon. Si l'application
est cassée et qu'un pod reste bloqué en `crashloopbackoff`, ce pod bloque lui-même le calcul
du budget et peut empêcher drain pour toujours. `AlwaysAllow` supprime ce blocage : les
pods non sains peuvent toujours être évincés, les pods sains restent protégés par le
budget.

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

On enregistre l'explication dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllow ajouté à web-pdb.

Par défaut (IfHealthyBudget), un pod non sain n'est évincé que si currentHealthy ne
descend pas sous desiredHealthy, donc un pod en crashloopbackoff se compte lui-même comme
partie du budget et peut bloquer drain pour toujours, même si l'application ne fonctionne
déjà plus.

AlwaysAllow autorise l'éviction d'un pod non sain indépendamment du budget : un pod cassé
en crashloopbackoff ne retient plus drain, et les réplicas sains restent protégés par le
PDB.
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## Tâche 6. Rolling update : matchLabelKeys empêche les anciens pods de gêner la répartition

On met à jour le Deployment pour faire apparaître une nouvelle révision (nouveau
`pod-template-hash`) : on ajoute une variable d'environnement. Les anciens et nouveaux pods
portent tous le label `app: web`, mais `matchLabelKeys: [pod-template-hash]` dans
`topologySpreadConstraints` fait compter le skew uniquement à l'intérieur de sa propre
révision, si bien que les nouveaux pods ne sont pas bloqués par les anciens réplicas.

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

On vérifie qu'il n'y a pas de pods `Pending` bloqués et que la mise à jour s'est bien
appliquée :

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

Sans `matchLabelKeys: [pod-template-hash]`, les anciens et les nouveaux pods compteraient
tous les deux pour le skew - ils partagent le label `app: web`. Avec lui, le scheduler
ajoute le label de révision au sélecteur et ne compte la distribution qu'à l'intérieur de
sa propre révision.

Une précision honnête, qu'il vaut mieux vérifier soi-même plutôt que de la croire sur
parole. Sur ce banc d'essai, le rollout réussit AUSSI sans `matchLabelKeys` - vérifié par
l'expérience : un second Deployment avec la même topologie mais sans ce champ, avec
`maxUnavailable: 0` et `maxSurge: 1`, a été mis à jour dans le même temps, `Pending` a duré
moins de cinq secondes et était une attente normale du scheduler, pas un blocage par skew.
La raison est simple : trois réplicas sur deux zones donnent une répartition 2 plus 1, et
le pod supplémentaire trouve toujours de la place dans la zone qui en a le moins, et si les
nœuds manquent de place, Karpenter en ajoute un.

Là où la différence devient réelle : un parc statique sans capacité de réserve, plus de
deux zones, et une ancienne révision mal répartie. Alors le skew calculé sur les deux
révisions à la fois ne laisse aucune zone autorisée au nouveau pod, qui attend le départ
d'un ancien réplica - sur un grand parc, cela se transforme en rollout lent avec des
`Pending` incompris. C'est pourquoi `matchLabelKeys` se met en place à l'avance, pas après
un incident. Le résultat réellement vérifié maintenant est que la nouvelle révision est
restée répartie entre les zones dans les limites de `maxSkew: 1` :

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## Vérification rapide

```bash
check_result
```
