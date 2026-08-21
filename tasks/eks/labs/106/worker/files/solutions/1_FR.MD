[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - solution de référence (EBS CSI : gp3, rattachement à l'AZ, extension, snapshot)

Toutes les commandes s'exécutent sur la machine de travail (worker) via SSH. kubectl est
déjà configuré pour le cluster. Le driver `aws-ebs-csi-driver` (provisionneur
`ebs.csi.aws.com`) est déjà installé comme managed addon avec un rôle via IRSA (composant
`eks_addon_ebs_irsa`) - pas besoin de recréer le rôle.

## Tâche 1. Namespace `eks-106`

```bash
kubectl create namespace eks-106
```

## Tâche 2. StorageClass `gp3-immediate` (configuration cassée)

On prend délibérément `volumeBindingMode: Immediate` - c'est justement lui qui piège le
volume dans une zone aléatoire :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-immediate
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF
```

## Tâche 3. StatefulSet `db` sur `gp3-immediate`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-106
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3-immediate
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl get pvc -n eks-106
kubectl get po db-0 -n eks-106 -o wide
```

Le cluster du lab est déployé sur deux AZ (`eu-central-1a` et `eu-central-1b`). Avec
`Immediate`, le driver crée le volume dès que le PVC apparaît, sans attendre de savoir où le
planificateur va placer le pod, donc la zone du volume est choisie indépendamment de
l'endroit où Karpenter va réellement lever le nœud. Sur deux AZ, le conflit
`volume node affinity conflict` survient réellement, mais pas de façon garantie à chaque
essai : le volume peut tomber par hasard dans la même zone où il y a déjà un nœud adapté.
C'est pourquoi, à la tâche 4, le diagnostic est obligatoire quel que soit le résultat.

## Tâche 4. Diagnostic : symptôme d'Immediate contre rattachement à la zone

```bash
mkdir -p /var/work/tests/artifacts/4

kubectl describe pod db-0 -n eks-106 | sed -n '/Events/,$p' \
  > /var/work/tests/artifacts/4/describe.txt

PV=$(kubectl get pvc data-db-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/4/pv.yaml
grep -A6 nodeAffinity /var/work/tests/artifacts/4/pv.yaml
```

On regarde où le pod a réellement été placé et si la zone du volume correspond à la zone du
nœud :

```bash
PHASE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.status.phase}')
NODE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "phase=$PHASE node=$NODE pv_zone=$PV_ZONE"
```

On enregistre l'explication dans un artefact. La formulation doit fonctionner dans les deux
cas - que le pod soit bloqué en `Pending` ou qu'il ait eu de la chance par hasard :

```bash
cat > /var/work/tests/artifacts/4/diagnosis.txt <<'EOF'
Le StorageClass gp3-immediate utilise volumeBindingMode: Immediate. Cela signifie que le
driver CSI ebs.csi.aws.com crée le volume EBS dès que le PVC apparaît, avant que le
planificateur ait choisi un nœud pour le pod. La zone du volume est fixée dans le PV via
spec.nodeAffinity.required.nodeSelectorTerms[].matchExpressions[].key:
topology.ebs.csi.aws.com/zone, et le planificateur est obligé de respecter ce rattachement.

Si le pod db-0 est en Pending, kubectl describe pod affiche l'événement
"0/N nodes are available: N node(s) had volume node affinity conflict" - le volume a été
créé dans une zone où il n'y a pas de nœud adapté.

Si le pod db-0 est en Running, cela ne veut pas dire que la configuration est correcte : le
cluster n'a que deux AZ (eu-central-1a, eu-central-1b), et avec Immediate le volume est
tombé, par pur hasard, dans une zone où un nœud existait déjà. Lors d'un autre essai, lors
d'une consolidation de Karpenter, ou lors d'un passage à un plus grand nombre d'AZ, le même
StorageClass redonnera un volume node affinity conflict. Seul WaitForFirstConsumer
fonctionne de façon garantie, où la zone du volume est toujours égale à la zone du nœud déjà
choisi - c'est la tâche 5.
EOF
cat /var/work/tests/artifacts/4/diagnosis.txt
```

## Tâche 5. Correction : StorageClass `gp3` avec `WaitForFirstConsumer`

Un PVC se lie à son StorageClass une seule fois, il est impossible de changer la classe sur
un PVC existant, donc on corrige non pas par un patch sur `gp3-immediate`, mais avec une
nouvelle classe et un nouveau StatefulSet :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-fixed
  namespace: eks-106
spec:
  serviceName: db-fixed
  replicas: 1
  selector:
    matchLabels:
      app: db-fixed
  template:
    metadata:
      labels:
        app: db-fixed
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl rollout status statefulset/db-fixed -n eks-106
```

Avec `WaitForFirstConsumer`, le provisioning du volume est différé jusqu'à ce que le
planificateur choisisse un nœud pour `db-fixed-0`. Ce n'est qu'ensuite que le driver crée le
volume dans la zone de ce nœud, et le conflit `nodeAffinity` devient impossible par
construction. On vérifie que la zone du volume correspond à la zone du nœud :

```bash
NODE=$(kubectl get po db-fixed-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
PV=$(kubectl get pvc data-db-fixed-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "node_zone=$NODE_ZONE pv_zone=$PV_ZONE"
```

Les valeurs `node_zone` et `pv_zone` doivent correspondre - c'est le signe d'un
fonctionnement correct, et non d'un coup de chance. On peut aussi restreindre explicitement
l'ensemble des zones via `allowedTopologies` dans le StorageClass (clé
`topology.ebs.csi.aws.com/zone`), si l'on veut exclure une AZ précise du provisioning des
volumes.

## Tâche 6. Extension du volume `data-db-fixed-0` de 5Gi à 10Gi

`allowVolumeExpansion: true` sur `gp3` permet l'extension à chaud, sans recréer le pod :

```bash
kubectl patch pvc data-db-fixed-0 -n eks-106 \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# on attend que le driver CSI termine la modification du volume et du système de fichiers
until [[ "$(kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}')" == "10Gi" ]]; do
  sleep 5
done

kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}'
echo
```

Impossible de réduire le volume - uniquement l'augmenter, et pas plus souvent que ne le
permet la limite des modifications EBS.

## Tâche 7. Snapshot du volume et restauration (best effort)

Le snapshot fonctionne via trois objets : `VolumeSnapshotClass`, `VolumeSnapshot` et le
`VolumeSnapshotContent` créé automatiquement. Le snapshot-controller et les CRD sont déjà
installés dans le cluster comme managed addon `snapshot-controller` (composant
`eks_addons`) :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: db-snap
  namespace: eks-106
spec:
  volumeSnapshotClassName: ebs-snapclass
  source:
    persistentVolumeClaimName: data-db-fixed-0
EOF

kubectl get volumesnapshot db-snap -n eks-106
```

On attend que le snapshot soit prêt (`readyToUse: true`), puis on le restaure dans un
nouveau PVC. Le snapshot EBS est un objet régional, mais le volume restauré à partir de lui
redevient zonal, donc la classe avec `WaitForFirstConsumer` est aussi nécessaire ici :

```bash
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/db-snap -n eks-106 --timeout=180s

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-restored
  namespace: eks-106
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  dataSource:
    kind: VolumeSnapshot
    name: db-snap
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 10Gi
EOF

kubectl get pvc data-restored -n eks-106
```

`data-restored` restera en `Pending` tant qu'aucun pod ne le sollicite (classe `gp3` -
`WaitForFirstConsumer`), et c'est attendu : le provisioning du volume restauré est lui aussi
différé jusqu'à la planification. Si, pour une raison quelconque, le snapshot-controller ou
les CRD sont absents du cluster, cette tâche ne bloque pas le reste du lab - c'est une étape
de vérification distincte et facultative.

## Vérification rapide

```bash
check_result
```
