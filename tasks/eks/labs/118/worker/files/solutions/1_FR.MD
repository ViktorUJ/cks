[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labo 118 - solution de référence (GitOps : Argo CD, drift et self-heal, sync waves)

Toutes les commandes s'exécutent sur la machine de travail (worker) via SSH. kubectl
est déjà configuré pour le cluster (le kubeconfig est construit via `aws eks
update-kubeconfig` au démarrage de la machine).

## Tâche 1. Installation d'Argo CD via Helm

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd

kubectl rollout status deployment/argocd-server -n argocd
```

Vérifions que le serveur a démarré :

```bash
kubectl get deploy argocd-server -n argocd
kubectl get pods -n argocd
```

## Tâche 2. Namespace `eks-118` et objet Application

```bash
kubectl create namespace eks-118
```

L'Application relie une source Git (le dépôt du cours lui-même, branche `AG-155`,
chemin `tasks/eks/labs/118/gitops-demo`) au cluster et au namespace cible `eks-118`.
`selfHeal: true` annule les modifications manuelles, `prune: true` supprime du cluster
les ressources retirées de Git :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ViktorUJ/cks.git
    targetRevision: AG-155
    path: tasks/eks/labs/118/gitops-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: eks-118
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF
```

Attendons que l'Application atteigne `Synced` et `Healthy` :

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}'
echo
```

Les deux commandes doivent finir par renvoyer `Synced` et `Healthy` respectivement
(Argo CD interroge Git et applique les manifestes automatiquement, l'auto-sync est
activé par défaut).

## Tâche 3. Vérification que les objets ont bien été appliqués

```bash
kubectl get deployment demo-app -n eks-118
kubectl get configmap demo-config -n eks-118 -o yaml
kubectl rollout status deployment/demo-app -n eks-118
```

Le Deployment `demo-app` (image `viktoruj/ping_pong:latest`, 2 réplicas) et le
ConfigMap `demo-config` viennent de Git via Argo CD, et non d'un `kubectl apply`
manuel de l'étudiant.

## Tâche 4. Drift et self-heal

Un détail important qui ne se voit que sur un cluster en direct : avec `selfHeal`
activé, le contrôleur annule le drift en quelques secondes, et il est pratiquement
impossible d'observer `OutOfSync` à l'œil (un `kubectl scale` manuel est annulé avant
même le premier `kubectl get application`). C'est pourquoi le drift est montré en deux
étapes : on désactive d'abord l'auto-guérison, on capture `OutOfSync`, puis on
réactive l'auto-guérison et on observe l'annulation.

Étape 1. On désactive uniquement `selfHeal`, on laisse `prune` activé :

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false,"prune":true}}}}'
```

Étape 2. On casse l'état en direct en contournant Git et on capture le drift :

```bash
kubectl scale deployment demo-app -n eks-118 --replicas=5

for i in $(seq 1 20); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  [[ "$status" == "OutOfSync" ]] && break
  sleep 3
done

mkdir -p /var/work/tests/artifacts/4
{
  echo "=== drift avec selfHeal=false (kubectl scale manuel --replicas=5) ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} > /var/work/tests/artifacts/4/drift.txt
```

Sans self-heal, l'Application reste `OutOfSync` : l'auto-sync réagit aux changements
dans Git, tandis qu'un écart créé à l'intérieur du cluster est justement ce que
`selfHeal` corrige.

Étape 3. On réactive `selfHeal` et on observe l'annulation automatique vers l'état de
Git :

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

for i in $(seq 1 40); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  replicas=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.spec.replicas}')
  [[ "$status" == "Synced" ]] && [[ "$replicas" == "2" ]] && break
  sleep 3
done

{
  echo "=== apres reactivation de selfHeal : retour a l'etat de Git ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} >> /var/work/tests/artifacts/4/drift.txt

cat /var/work/tests/artifacts/4/drift.txt
```

Le fichier contient à la fois `OutOfSync` (drift sans auto-guérison) et `Synced`
(self-heal a restauré l'état de Git). `replicas` vaut à nouveau `2` à la fin.

## Tâche 5. Sync waves : ordre d'application

`gitops-demo/configmap.yaml` porte l'annotation `argocd.argoproj.io/sync-wave: "0"`,
et `gitops-demo/deployment.yaml` porte `argocd.argoproj.io/sync-wave: "1"`. Le numéro
de vague le plus bas est appliqué en premier, donc le ConfigMap arrive garantie dans le
cluster avant le Deployment (important si le Deployment lit des valeurs du ConfigMap
via `envFrom`) :

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
kubectl get deployment demo-app -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
```

Confirmons que les deux objets finissent synchronisés malgré des vagues différentes :

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.resources}' | head -c 400
```

## Tâche 6. Ce que prune supprime et ce qu'il ne supprime pas : propriété des ressources

`prune: true` est déjà activé depuis la tâche 2. Créons manuellement dans `eks-118` un
ConfigMap qui n'existe pas dans `gitops-demo/` - un objet manuel ordinaire, comme si
quelqu'un l'avait créé en dehors de Git :

```bash
kubectl create configmap manual-extra -n eks-118 --from-literal=note=manual

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

sleep 30
kubectl get configmap manual-extra -n eks-118
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'; echo
```

Résultat inattendu : `prune=true` est activé, mais `manual-extra` **n'est pas
supprimé**, et l'Application reste `Synced`. La raison réside dans le modèle de
propriété : Argo CD ne gère que les objets marqués comme appartenant à l'application.
Dans Argo CD 3.x, c'est l'annotation `argocd.argoproj.io/tracking-id` - regardez comment
est marqué l'objet venu de Git :

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
# demo-app:/ConfigMap:eks-118/demo-config
```

L'objet manuel n'a pas cette marque, il est donc étranger (orphaned) pour Argo CD et
n'entre pas dans le périmètre de prune. Consignons cette observation :

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== sans annotation de tracking, prune ne touche pas l'objet ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "sync: $(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')"
} > /var/work/tests/artifacts/6/prune.txt
```

Marquons maintenant le ConfigMap comme appartenant à l'application. Le format de la
valeur est `<app>:<group>/<Kind>:<namespace>/<name>`, pour les ressources du core le
group est vide :

```bash
kubectl annotate configmap manual-extra -n eks-118 \
  'argocd.argoproj.io/tracking-id=demo-app:/ConfigMap:eks-118/manual-extra' --overwrite

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

for i in $(seq 1 20); do
  kubectl get configmap manual-extra -n eks-118 >/dev/null 2>&1 || break
  sleep 5
done

kubectl get configmap manual-extra -n eks-118 2>&1
```

Maintenant l'objet est suivi par l'application, il n'est pas dans Git - et prune le
supprime. Pendant ce temps, `demo-config` et `demo-app` restent en place, car ils sont
décrits dans `gitops-demo/` :

```bash
{
  echo "=== apres ajout de l'annotation de tracking, prune a supprime l'objet ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 2>&1 | tail -n1)"
  echo "demo-config: $(kubectl get configmap demo-config -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "demo-app: $(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.metadata.name}')"
  echo
  echo "prune ne supprime que les ressources SUIVIES par l'application absentes de Git."
  echo "Un objet cree a la main sans annotation de tracking est etranger a Argo CD"
  echo "(orphaned) et n'entre pas dans le perimetre de prune - c'etait le premier"
  echo "resultat observe. demo-config et demo-app sont restes car ils sont decrits"
  echo "dans gitops-demo/ et Argo CD continue de les synchroniser."
} >> /var/work/tests/artifacts/6/prune.txt

cat /var/work/tests/artifacts/6/prune.txt
```

## Tâche 7. Diagnostic : sync status et health status - deux axes distincts

Désactivons l'auto-sync (et avec lui self-heal, qui vit dans le même bloc), pour
pouvoir provoquer le symptôme calmement sans annulation immédiate :

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

Cassons le readinessProbe du conteneur directement dans le cluster. Attention : l'image
pédagogique `ping_pong` répond `200` sur n'importe quel chemin, donc une sonde sur une
« URL inexistante » réussit sans problème et ne donne aucun symptôme. Dirigeons la
sonde vers le port fermé `9999` - personne n'y écoute :

```bash
kubectl patch deployment demo-app -n eks-118 --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet": {"path": "/healthz", "port": 9999},
    "initialDelaySeconds": 2,
    "periodSeconds": 3,
    "failureThreshold": 2
  }}
]'
```

Attendons et capturons les statuts. Sync et health sont des axes indépendants : sync
reflète l'écart entre Git et l'état en direct, health est la santé réelle des
ressources (disponibilité des pods, etc.) :

```bash
sleep 30
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== statuts observes apres la modification manuelle du readinessProbe ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  echo
  echo "=== explication : sync status et health status sont des axes differents ==="
  echo "Sync status (Synced/OutOfSync) compare l'etat en direct des objets a ce qui"
  echo "est enregistre dans Git : correspond - Synced, diverge - OutOfSync."
  echo "Health status (Healthy/Progressing/Degraded/Missing) est la sante reelle de"
  echo "la ressource a cet instant : les pods sont-ils prets, les sondes"
  echo "readiness/liveness ont-elles reussi."
  echo "A cause de la sonde sur un port ferme, les nouveaux pods de demo-app ne"
  echo "passent pas le readiness, donc health passe a Progressing (et devient"
  echo "Degraded apres progressDeadlineSeconds), tandis que sync reste Synced. La"
  echo "raison : le champ readinessProbe n'est pas decrit dans le manifeste Git, et"
  echo "le champ ajoute a la main ne compte pas dans l'ecart ; en revanche replicas"
  echo "est bien dans Git, c'est pourquoi sa modification manuelle dans la tache 4"
  echo "a donne OutOfSync."
  echo "Cela prouve que les deux axes sont calcules independamment : on peut etre"
  echo "Synced et Degraded/Progressing en meme temps, comme OutOfSync et Healthy en"
  echo "meme temps."
} > /var/work/tests/artifacts/7/health.txt

cat /var/work/tests/artifacts/7/health.txt
```

Réactivons l'auto-sync et self-heal :

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'
```

Observation importante : self-heal **ne corrigera pas** cette casse. Pour Argo CD, il
n'y a pas d'écart avec Git (`sync=Synced`), donc rien à corriger - pendant ce temps
`health` affiche honnêtement `Progressing`, puis `Degraded`. Conclusion pratique :
`Synced` ne signifie pas que le cluster correspond à Git octet pour octet ; les champs
absents du manifeste restent sous la responsabilité de l'opérateur. On retire donc la
sonde à la main :

```bash
kubectl patch deployment demo-app -n eks-118 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'

for i in $(seq 1 20); do
  health=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}')
  ready=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.status.readyReplicas}')
  [[ "$health" == "Healthy" ]] && [[ "$ready" == "2" ]] && break
  sleep 5
done

kubectl get application demo-app -n argocd \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
```

## Vérification rapide

```bash
check_result
```
