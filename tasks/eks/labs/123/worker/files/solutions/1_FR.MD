[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 123 - solution de référence (Karpenter : NodePool, consolidation, StatefulSet)

Toutes les commandes s'exécutent sur la machine worker par SSH. kubectl est déjà
configuré pour le cluster (le kubeconfig a été assemblé via `aws eks update-kubeconfig` au
démarrage de la machine).

## Tâche 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## Tâche 2. Inventaire de NodePool, EC2NodeClass, NodeClaim

Nous regardons quels pools sont déjà configurés dans le cluster : le `default` (spot et
on-demand) et le nouveau `stateful` (on-demand uniquement, taint `dedicated=stateful`) :

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== nodepools ==="
  kubectl get nodepools -o wide
  echo "=== ec2nodeclasses ==="
  kubectl get ec2nodeclasses
  echo "=== nodeclaims ==="
  kubectl get nodeclaims
} > /var/work/tests/artifacts/2/inventory.txt

cat /var/work/tests/artifacts/2/inventory.txt
```

La sortie doit contenir des lignes avec les noms `default` et `stateful` - ce sont deux
NodePools indépendants, chacun avec son propre `EC2NodeClass` (chapitre 12.2-12.3).

## Tâche 3. StatefulSet `db` sur le pool `stateful`

Le pool `stateful` est fermé par le taint `dedicated=stateful:NoSchedule`, donc le pod a
besoin d'une toleration. Les volumes ne sont pas obligatoires pour les besoins de cette
lab - l'accent est sur la disruption, pas sur EBS (le volume d'un StatefulSet avec son
propre PVC est traité au chapitre 23) :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-123
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: stateful
          effect: NoSchedule
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          resources:
            requests:
              cpu: "250m"
              memory: "128Mi"
EOF

kubectl rollout status statefulset/db -n eks-123
```

Nous vérifions que toutes les replicas ont atterri sur le pool `stateful` (label de node
`work_type=stateful`) :

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## Tâche 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` est le principal frein à l'éviction volontaire. Karpenter draine via
l'Eviction API, donc le PDB n'autorisera pas plus d'une replica évincée à la fois :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: db-pdb
  namespace: eks-123
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: db
EOF

kubectl get pdb db-pdb -n eks-123
```

## Tâche 5. Symptôme : un PDB sans droit d'éviction bloque la consolidation

Les nodes du pool `stateful` sont déjà sous-utilisés : trois replicas de `250m` chacune se
sont retrouvées réparties sur deux nodes `m6g.medium`, et Karpenter avec
`consolidateAfter: 30s` essaie constamment de les consolider. Pas besoin de forcer une
charge - il faut juste regarder ce qui bloque la consolidation.

Important : avec `maxUnavailable: 1`, le PDB NE bloque PAS la consolidation. Il autorise
une éviction à la fois (`ALLOWED DISRUPTIONS=1`), Karpenter draine le node une replica à la
fois et le supprime tranquillement. Le blocage n'arrive que lorsque le PDB n'autorise
aucune éviction. Nous renforçons la protection jusqu'à un verrouillage complet -
`minAvailable: 3` avec trois replicas :

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

La colonne `ALLOWED DISRUPTIONS` affiche maintenant `0`. Après 1-2 minutes, un événement de
blocage apparaît sur les nodes du pool. Remarque : ce n'est PAS `Unconsolidatable`, mais un
`DisruptionBlocked` distinct :

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

Ligne attendue : `Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`. Les
logs du contrôleur lui-même se trouvent dans le namespace `karpenter` (pas dans
`kube-system` - qui ne contient que des addons, Karpenter est déployé comme un release
séparé sur le profil Fargate) :

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

Nous enregistrons l'observation dans un artefact - la sortie de `get pdb` plus
l'événement réel du node :

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "Symptome : un PDB qui n'autorise aucune eviction bloque la consolidation."
  echo "db-pdb renforce a minAvailable=3 avec 3 replicas -> ALLOWED DISRUPTIONS=0."
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== evenements des nodes du pool stateful ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

Nous remettons le PDB dans un état fonctionnel, sinon la tâche 4 ne passera pas, et le node
du pool ne pourra jamais partir :

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` redevient `1`. Conclusion pour l'exploitation : `minAvailable` égal
au nombre de replicas (ou `maxUnavailable: 0`) arrête non seulement la consolidation, mais
tout drain - donc aussi les mises à jour de nodes et l'upgrade du cluster (chapitre 12.6,
chapitre 40).

## Tâche 6. Correction : un `do-not-disrupt` ciblé

La bonne protection d'un StatefulSet est la combinaison de trois parties (chapitre 12.7),
pas une seule annotation sur tout. Le PDB (tâche 4) donne déjà une éviction par replica. Le
disruption budget du pool `stateful` (`nodes: 50%` dans
`eks_karpenter_stateful_vng/terragrunt.hcl`) limite le rythme, pour que Karpenter ne touche
pas tous les nodes du pool à la fois. La troisième partie est `do-not-disrupt`, ciblée
uniquement sur la replica où une interruption est actuellement inacceptable (par exemple
`db-0` détient un leadership ou une opération longue), pas sur tout le StatefulSet :

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` et `db-2` ne reçoivent pas l'annotation - sinon la protection deviendrait totale et
bloquerait non seulement la consolidation, mais aussi le drift (mises à jour d'AMI), comme
décrit au chapitre 12.8.

Que l'annotation fonctionne réellement se voit par le même mécanisme que le PDB dans la
tâche 5 - Karpenter écrit un événement séparé sur le node qui porte `db-0` :

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

Ligne attendue : `DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt" annotation
(Pod=eks-123/db-0)`. C'est-à-dire que l'annotation ciblée n'arrête la consolidation que
du node qui porte la replica protégée, tandis que Karpenter peut toujours toucher les
autres nodes du pool.

Nous enregistrons l'explication dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
La protection correcte du StatefulSet db pendant la consolidation, ce sont trois parties
independantes, pas une seule annotation totale :

1. PDB db-pdb (maxUnavailable: 1) - eviction par replica, le quorum n'est jamais perdu.
   C'est exactement cette valeur qui laisse ALLOWED DISRUPTIONS=1. Une protection totale
   (minAvailable=3 avec trois replicas) donne ALLOWED DISRUPTIONS=0 et un evenement
   DisruptionBlocked "Pdb prevents pod evictions" - pour toujours, jusqu'a corriger le PDB
   lui-meme (tache 5).
2. Le disruption budget du pool stateful (nodes: 50%) - limite le nombre de nodes du pool
   que Karpenter peut toucher en meme temps, empechant de consolider tout le pool a la fois.
3. karpenter.sh/do-not-disrupt=true cible sur db-0 - protege la replica precise ou une
   interruption est actuellement inacceptable, pas tout le StatefulSet.

Si do-not-disrupt etait sur db-0, db-1 et db-2 en meme temps, cela bloquerait non seulement
la consolidation, mais aussi le drift : quand une nouvelle AMI sort, les nodes du pool
stateful ne pourraient pas se mettre a jour, et une dette de CVE s'accumulerait (chapitre
12.8). C'est pourquoi l'annotation est posee sur une seule replica et retiree une fois
l'operation critique terminee.
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## Vérification rapide

```bash
check_result
```
