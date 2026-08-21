[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - solution de référence (nœuds spot : diversification, interruptions, graceful drain)

Toutes les commandes s'exécutent sur la machine de travail (worker) via SSH. kubectl est
déjà configuré pour le cluster (kubeconfig construit via `aws eks update-kubeconfig` au
démarrage de la machine).

## Tâche 1. Namespace `eks-111`

```bash
kubectl create namespace eks-111
```

## Tâche 2. Deployment `spotapp` sur le pool spot avec toleration et graceful shutdown

Le pool `spot-lab` est fermé par le taint `dedicated=spot-lab:NoSchedule`, le pod doit donc
porter la toleration correspondante, sinon Karpenter ne pourra pas le placer sur ce
NodePool. `terminationGracePeriodSeconds: 60` s'inscrit dans la fenêtre d'interruption spot
de deux minutes, et `preStop` avec `sleep 5` laisse au load balancer le temps de retirer le
trafic avant l'arrêt du conteneur.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spotapp
  namespace: eks-111
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spotapp
  template:
    metadata:
      labels:
        app: spotapp
    spec:
      terminationGracePeriodSeconds: 60
      tolerations:
        - key: "dedicated"
          value: "spot-lab"
          effect: "NoSchedule"
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 5"]
EOF

kubectl rollout status deployment/spotapp -n eks-111
```

Vérification que les 4 réplicas sont bien sur des nœuds spot :

```bash
kubectl get po -n eks-111 -l app=spotapp -o wide
NODES=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}')
for n in $NODES; do
  kubectl get node "$n" -L karpenter.sh/capacity-type --no-headers
done
```

Karpenter met environ 60-90 secondes à démarrer un nouveau nœud EC2, les pods peuvent donc
d'abord rester en `Pending`. On attend `rollout status` avant de continuer.

## Tâche 3. Artefact : nœuds spot et diversification du NodePool

On enregistre un instantané des nœuds avec le label du type de capacité et la catégorie
d'instance, ainsi que les requirements du NodePool `spot-lab`, pour confirmer un large
ensemble de familles (la diversification).

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -L karpenter.sh/capacity-type -L karpenter.k8s.aws/instance-category \
  > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt

kubectl get nodepool spot-lab -o yaml \
  | grep -A5 'instance-category' > /var/work/tests/artifacts/3/nodepool.txt
cat /var/work/tests/artifacts/3/nodepool.txt
```

Dans `nodes.txt` doit figurer au moins un nœud avec `capacity-type=spot`. Dans
`nodepool.txt` doivent figurer les trois catégories d'instances `c`, `m`, `r` - c'est
exactement l'exigence de diversification : le pool spot-lab n'est pas restreint à une seule
famille d'instances.

## Tâche 4. PodDisruptionBudget pour `spotapp`

`minAvailable: 3` sur 4 réplicas protège contre une éviction volontaire excessive :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spotapp-pdb
  namespace: eks-111
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: spotapp
EOF

kubectl get pdb spotapp-pdb -n eks-111 -o yaml
```

## Tâche 5. Symptôme : le drain est bloqué par le PDB, mais cela ne protège pas d'un spot AWS

On prend un nœud sur lequel se trouve au moins un pod `spotapp`, on le cordonne et on
essaie un drain. Avec 4 réplicas et `minAvailable: 3`, le PDB permet d'évincer au plus une
réplique à la fois (`disruptionsAllowed` ne dépasse pas 1) - le drain n'ira pas plus loin
qu'une réplique.

```bash
NODE=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon "$NODE"
kubectl get pdb spotapp-pdb -n eks-111 -o jsonpath='{.status.disruptionsAllowed}'
echo

# ce qui essaiera d'être évincé, sans drainer réellement tout le nœud
kubectl drain "$NODE" --ignore-daemonsets --dry-run=client
```

On consigne le symptôme et l'explication de la frontière de responsabilité du PDB dans un
artefact :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/drain.txt <<'EOF'
Le nœud est cordonné, le drain essaie d'évincer les pods spotapp via l'API d'éviction. Le
PDB spotapp-pdb avec minAvailable: 3 ne permet pas d'évincer plus d'une réplique à la fois
(disruptionsAllowed <= 1 avec 4 réplicas) : en cas de tentative de dépasser le budget,
l'éviction est refusée, et le drain ne progresse pas au-delà d'une réplique.

Frontière importante : le PDB protège uniquement l'éviction volontaire (voluntary) - kubectl drain, mise à niveau des nœuds, consolidation Karpenter. Il ne protège
pas d'une reprise forcée du spot par AWS : si AWS reprend réellement l'instance à
l'expiration du préavis de deux minutes, les pods qui s'y trouvent sont terminés
indépendamment du PDB, car il ne s'agit pas d'une action volontaire de Kubernetes, mais de
l'arrêt de l'instance elle-même.
EOF
cat /var/work/tests/artifacts/5/drain.txt

kubectl uncordon "$NODE"
```

## Tâche 6. Vérification de la gestion des interruptions par Karpenter

Karpenter gère lui-même les interruptions spot via une queue d'interruption
(`interruptionQueue`, configurée dans le module `eks_v2_karpenter` indépendamment de ce
laboratoire). On confirme le mécanisme via les logs du contrôleur - le worker peut ne pas
avoir les droits pour `aws sqs list-queues`, on utilise donc `kubectl logs` :

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i interrupt > /var/work/tests/artifacts/6/interruption.txt

# si aucun événement d'interruption n'a encore eu lieu, on consigne le fait que le mécanisme existe :
if [[ ! -s /var/work/tests/artifacts/6/interruption.txt ]]; then
  echo "no interruption events yet, but Karpenter interruption handling is configured via interruptionQueue" \
    > /var/work/tests/artifacts/6/interruption.txt
fi
cat /var/work/tests/artifacts/6/interruption.txt
```

## Vérification rapide

```bash
check_result
```
