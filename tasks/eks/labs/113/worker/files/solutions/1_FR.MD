[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - solution de référence (mise à niveau et rollback du cluster)

Toutes les commandes s'exécutent sur la machine de travail via SSH. kubectl et aws cli y sont
déjà configurés pour le cluster du laboratoire. Enregistrez d'abord le nom du cluster dans une
variable - vous en aurez besoin dans presque chaque commande :

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Tâche 1. Namespace et la version de départ du cluster

```bash
kubectl create namespace eks-113

aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Sortie attendue - `"1.35"`. Le cluster de ce laboratoire démarre délibérément une version
mineure sous la GA actuelle `1.36`, afin que vous puissiez ensuite passer par une véritable
mise à niveau et un véritable rollback.

En plus (non vérifié, mais utile avant la mise à niveau) : regardez quel `apiVersion` le
serveur API sert actuellement, pour le comparer avec la version après la mise à niveau plus
tard :

```bash
kubectl get --raw /apis | grep -o '"groupVersion":"[^"]*"'
```

## Tâche 2. Vérification de la disponibilité de la mise à niveau

Upgrade insights est une vérification intégrée d'EKS qui recherche ce qui pourrait bloquer la
mise à niveau : l'utilisation d'API qui seront supprimées dans la version cible, et la santé
générale du cluster. La liste des insights du cluster sans `--filter` inclut toutes les
catégories, y compris la mise à niveau :

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks list-insights --cluster-name "$CLUSTER" \
  > /var/work/tests/artifacts/2/upgrade_insights.json
cat /var/work/tests/artifacts/2/upgrade_insights.json
```

Vérifiez qu'il n'y a pas de statut `ERROR` parmi les insights (il bloque la mise à niveau
jusqu'à correction) :

```bash
grep '"status"' /var/work/tests/artifacts/2/upgrade_insights.json
```

Si un insight a le statut `WARNING` - ce n'est pas bloquant, mais il vaut la peine de lire la
recommandation via `aws eks describe-insight --cluster-name "$CLUSTER" --id <insight-id>`.
S'il y a un `ERROR`, corrigez la cause (généralement un `apiVersion` déprécié dans des
manifestes) et relancez `aws eks list-insights` - EKS rafraîchit les insights une fois toutes
les 24 heures, vous pouvez forcer un rafraîchissement via
`aws eks start-insights-refresh --cluster-name "$CLUSTER"`.

## Tâche 3. Mise à niveau du control plane vers 1.36

La mise à niveau ne fait avancer qu'une version mineure à la fois : `1.35` -> `1.36`.
Démarrez-la et enregistrez l'`id` de la mise à jour :

```bash
UPDATE_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.36 \
  --query 'update.id' --output text)
echo "$UPDATE_ID"
```

La mise à jour du control plane s'exécute en arrière-plan et peut prendre 20 à 40 minutes.
Attendez le statut `Successful` :

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$UPDATE_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Confirmez la nouvelle version :

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Sortie attendue - `"1.36"`. Les nœuds et les add-ons ne changent pas encore de version à ce
stade - c'est l'étape suivante.

## Tâche 4. Mise à niveau des add-ons principaux vers des versions pour 1.36

Le control plane a été mis à jour, mais `kube-proxy` et `coredns` ne le suivent pas
automatiquement - ils sont mis à jour séparément, vers des versions compatibles avec la
nouvelle version mineure. Vérifiez les versions compatibles exactes ainsi (si vous n'avez pas
le tableau du cours sous la main) :

```bash
aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.36 \
  --query 'addons[].addonVersions[].{Version:addonVersion,Default:compatibilities[0].defaultVersion}'
```

Mettez à jour les deux add-ons (mêmes versions que dans le laboratoire 101, où le cluster
démarre directement sur `1.36`) :

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.14
aws eks update-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --addon-version v1.14.3-eksbuild.3
```

Attendez `ACTIVE` pour chacun d'eux :

```bash
for addon in kube-proxy coredns; do
  while true; do
    status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$addon" \
      --query 'addon.status' --output text)
    echo "$addon status=$status"
    [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
    sleep 10
  done
done
```

Vérifiez les versions obtenues :

```bash
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --query 'addon.addonVersion'
aws eks describe-addon --cluster-name "$CLUSTER" --addon-name coredns \
  --query 'addon.addonVersion'
```

`vpc-cni` et `eks-pod-identity-agent` ne sont pas liés à la version mineure de Kubernetes
aussi étroitement que `kube-proxy` et `coredns`, donc dans ce laboratoire vous pouvez les
laisser tels quels - mais en exploitation réelle, il vaut tout de même la peine de vérifier
leurs versions via `describe-addon-versions`.

## Tâche 5. Vérification de la disponibilité du rollback

Les rollback readiness insights n'apparaissent qu'après une mise à niveau et vivent pendant
exactement 7 jours - la fenêtre de rollback. Regardez-les avec un filtre de catégorie :

```bash
mkdir -p /var/work/tests/artifacts/5
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  > /var/work/tests/artifacts/5/rollback_readiness.json
cat /var/work/tests/artifacts/5/rollback_readiness.json
```

Vérifiez les statuts - `ERROR` et `UNKNOWN` bloquent le rollback :

```bash
grep '"status"' /var/work/tests/artifacts/5/rollback_readiness.json
```

Si vous venez de corriger un des blocages et que vous ne voulez pas attendre le rafraîchissement
quotidien :

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
```

## Tâche 6. Rollback du control plane vers 1.35

À la tâche 4, nous avons mis à niveau `kube-proxy` vers la version compatible avec `1.36`. Si
vous essayez de ramener le control plane en arrière tout de suite, EKS recalcule les rollback
readiness insights à nouveau au moment où `update-cluster-version` est appelé et trouve un
`ERROR` sur la vérification `kube-proxy version rollback compatibility` : la version `1.36` de
`kube-proxy`, après que le control plane revient à `1.35`, se retrouverait plus récente que le
control plane, ce qui viole la politique de version skew. C'est exactement pourquoi le
chapitre 39 dit « ramenez les nœuds/add-ons en arrière avant le control plane si la version de
l'add-on est en avance sur la version cible » - `aws eks list-insights` juste après la mise à
niveau ne montrera pas encore ce problème (les insights de rollback sont recalculés par rapport
à l'état actuel du cluster), mais il apparaîtra si vous les redemandez après la mise à jour de
l'add-on.

L'ordre correct est de d'abord ramener `kube-proxy` lui-même vers une version compatible avec
`1.35`, et de ne ramener le control plane en arrière qu'ensuite :

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
  --addon-version v1.35.3-eksbuild.13

while true; do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER" --addon-name kube-proxy \
    --query 'addon.status' --output text)
  echo "kube-proxy status=$status"
  [[ "$status" == "ACTIVE" || "$status" == "DEGRADED" ]] && break
  sleep 10
done
```

Vérifiez que l'insight kube-proxy est devenu `PASSING` (vous pouvez forcer un recalcul si vous
ne voulez pas attendre un jour) :

```bash
aws eks start-insights-refresh --cluster-name "$CLUSTER"
sleep 30
aws eks list-insights --cluster-name "$CLUSTER" \
  --filter '{"categories": ["ROLLBACK_READINESS"]}' \
  --query 'insights[].{name:name,status:insightStatus.status}'
```

Vous pouvez maintenant ramener le control plane en arrière sans `--force` - de la manière
standard, comme pour la mise à niveau, mais avec la version précédente :

```bash
ROLLBACK_ID=$(aws eks update-cluster-version --name "$CLUSTER" --kubernetes-version 1.35 \
  --query 'update.id' --output text)
echo "$ROLLBACK_ID"

aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type'
```

Le type de mise à jour dans la réponse est `VersionRollback`, et non un `VersionUpdate`
ordinaire. Enregistrez-le dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/6
aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
  --query 'update.type' --output text > /var/work/tests/artifacts/6/rollback_update.txt
cat /var/work/tests/artifacts/6/rollback_update.txt
```

Le rollback s'exécute aussi en arrière-plan et peut prendre 20 à 40 minutes. Attendez
`Successful` :

```bash
while true; do
  status=$(aws eks describe-update --name "$CLUSTER" --update-id "$ROLLBACK_ID" \
    --query 'update.status' --output text)
  echo "status=$status"
  [[ "$status" == "Successful" || "$status" == "Failed" || "$status" == "Cancelled" ]] && break
  sleep 30
done
```

Confirmez que le control plane est revenu sur `1.35` :

```bash
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.version'
```

Sortie attendue - `"1.35"`. Les données etcd, les workloads et les volumes persistants ne sont
pas touchés pendant le rollback - seule la version du control plane revient en arrière, ceci
ne remplace pas une sauvegarde.

## Vérification rapide

```bash
check_result
```
