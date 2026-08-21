[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 129 - solution de référence (Mountpoint for S3 : sémantique des fichiers et backup)

Toutes les commandes s'exécutent sur la machine de travail via SSH. kubectl est déjà
configuré sur le cluster. Le driver `aws-mountpoint-s3-csi-driver` (provisioner
`s3.csi.aws.com`) est déjà installé en tant qu'addon managé avec un rôle via IRSA
(composant `eks_addon_s3_csi_irsa`), et un bucket avec versioning activé et un objet de
test `readme.txt` a déjà été créé par terraform.

## Tâche 1. Namespace `eks-129`

```bash
kubectl create namespace eks-129
```

## Tâche 2. PV/PVC statique sur un vrai bucket

On cherche le nom du vrai bucket :

```bash
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text)
echo "$BUCKET"
```

Mountpoint ne supporte que le provisionnement statique : le PV est écrit à la main et
référence un bucket déjà existant.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1200Gi
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  claimRef:
    namespace: eks-129
    name: s3-pvc
  mountOptions:
    - region eu-central-1
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-demo-volume
    volumeAttributes:
      bucketName: $BUCKET
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc
  namespace: eks-129
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  resources:
    requests:
      storage: 1200Gi
  volumeName: s3-pv
EOF

kubectl get pv s3-pv
kubectl get pvc s3-pvc -n eks-129
```

`capacity`/`requests.storage` sont des valeurs de remplissage - le schéma les exige, mais
Mountpoint les ignore : la taille réelle est déterminée par le contenu du bucket.

## Tâche 3. Opérations réussies : nouveau fichier et lecture

On déploie un pod avec ce PVC :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mountpoint-app
  namespace: eks-129
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mountpoint-app
  template:
    metadata:
      labels:
        app: mountpoint-app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        volumeMounts:
        - name: s3
          mountPath: /data
      volumes:
      - name: s3
        persistentVolumeClaim:
          claimName: s3-pvc
EOF

kubectl rollout status deployment/mountpoint-app -n eks-129
POD=$(kubectl get po -n eks-129 -l app=mountpoint-app -o jsonpath='{.items[0].metadata.name}')
```

L'image ici est précisément `busybox`, et non l'application des autres labos du cours :
`viktoruj/ping_pong` n'a ni `sh` ni `cat`, et `kubectl exec` dedans répond
`exec: "sh": executable file not found in $PATH` (vérifié). Tout ce labo porte sur des
opérations du système de fichiers à l'intérieur du pod, il faut donc une image avec un
shell, `mv` et `dd`. Le pod doit juste rester en vie, d'où le `command` avec `sleep`.

Créer un nouveau fichier est une écriture séquentielle depuis le début, ce qui correspond
au modèle `PutObject` d'un objet entier, donc ça fonctionne :

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec "$POD" -n eks-129 -- sh -c 'echo test > /data/newfile.txt && cat /data/newfile.txt' \
  > /var/work/tests/artifacts/3/create.txt
cat /var/work/tests/artifacts/3/create.txt
```

La lecture, y compris celle de l'objet existant du bucket `readme.txt`, fonctionne aussi -
c'est un `GetObject` :

```bash
kubectl exec "$POD" -n eks-129 -- cat /data/readme.txt \
  > /var/work/tests/artifacts/3/read.txt
cat /var/work/tests/artifacts/3/read.txt
```

## Tâche 4. Symptôme : `rename` échoue

Renommer n'est pas une opération bon marché sur un stockage d'objets, et Mountpoint la
rejette honnêtement sur les buckets ordinaires :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$POD" -n eks-129 -- \
  mv /data/newfile.txt /data/renamed.txt \
  > /var/work/tests/artifacts/4/rename.txt 2>&1
cat /var/work/tests/artifacts/4/rename.txt
```

La sortie est `mv: can't rename '/data/newfile.txt': Function not implemented` (vérifié sur
le stand, driver v1.15.0-eksbuild.1, busybox 1.36). Notez l'errno : c'est `ENOSYS`,
Mountpoint n'implémente pas du tout l'appel système `rename`. La tâche 5 aura un échec
différent - `EPERM`, `Operation not permitted` : là l'opération est implémentée mais
interdite par les réglages de montage. C'est utile de les distinguer en astreinte :
`ENOSYS` signifie « ce n'est pas dans le driver et ça ne le sera jamais », tandis que
`EPERM` signifie « ça pourrait marcher avec d'autres mount options ».

Le fichier `newfile.txt` reste en place, et `renamed.txt` n'apparaît pas : l'opération n'a
pas démarré et n'a pas laissé le bucket dans un état intermédiaire. On peut le vérifier du
côté AWS :

```bash
aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' --output text
```

## Tâche 5. Symptôme : l'append et une écriture au milieu du fichier échouent

Les deux cas sont des tentatives de modification partielle d'un objet déjà existant, et un
objet S3 est immuable - il n'est mis à jour qu'entièrement, via un nouveau `PutObject` :

```bash
mkdir -p /var/work/tests/artifacts/5

{
  echo "=== append (echo >>) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo more >> /data/newfile.txt' 2>&1

  echo
  echo "=== écriture au milieu du fichier (dd seek + conv=notrunc) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c \
    'echo patched | dd of=/data/newfile.txt bs=1 seek=1 conv=notrunc' 2>&1

  echo
  echo "=== réécriture d'un fichier existant (nécessite allow-overwrite) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo test2 > /data/newfile.txt' 2>&1

  echo
  echo "=== suppression d'un fichier (nécessite allow-delete) ==="
  kubectl exec "$POD" -n eks-129 -- rm /data/newfile.txt 2>&1

  echo
  echo "Explication : un objet S3 est immuable. Mettre à jour une clé, c'est un nouveau"
  echo "PutObject de l'objet entier, donc Mountpoint ne peut pas faire un append à la fin"
  echo "ni modifier des octets au milieu d'un fichier déjà envoyé - les deux opérations"
  echo "échouent explicitement avec Operation not permitted, plutôt que de corrompre les"
  echo "données en silence. Pour la même raison, la réécriture et la suppression sont"
  echo "interdites par défaut : elles s'activent via les mount options allow-overwrite et"
  echo "allow-delete, et il faut les activer en connaissance de cause."
} > /var/work/tests/artifacts/5/writesemantics.txt

cat /var/work/tests/artifacts/5/writesemantics.txt
```

Les quatre échecs ci-dessus sont le même `EPERM`, et tous les quatre se règlent via les
réglages de montage, contrairement au `rename` de la tâche 4. Un contraste utile :
`mkdir /data/sub` passe EN SILENCE et sans erreur, car un répertoire dans S3 est virtuel -
aucun objet n'est créé pour lui, et `aws s3api list-objects-v2` ne montrera pas de
nouvelle clé. En revanche, écrire dans un préfixe imbriqué inexistant
(`echo x > /data/sub2/nested.txt`) échoue avec `nonexistent directory` : il faut d'abord un
`mkdir`. C'est exactement ce « presque un système de fichiers » contre lequel le
chapitre 25 met en garde.

## Tâche 6. Pourquoi il n'y a pas de backup via AWS Backup, mais du versioning

AWS Backup pour EKS (chapitres 41-42) protège les données via des snapshots CSI de volumes
EBS. Un volume Mountpoint n'a pas d'EBS sous le capot du tout : les fichiers dans `/data`
sont des objets d'un bucket S3, pas des blocs sur un disque, donc le PVC `s3-pvc` n'a pas
de snapshot au sens où en a un volume `gp3` (chapitre 23). Ce qui protège les données ici,
c'est S3 lui-même - principalement le versioning du bucket, que terraform a activé à
l'avance (`aws_s3_bucket_versioning`) :

```bash
mkdir -p /var/work/tests/artifacts/6

{
  echo "=== aws s3api get-bucket-versioning --bucket $BUCKET ==="
  aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo
  echo "Explication : le PVC s3-pvc est monté via Mountpoint S3 CSI, pas via EBS CSI. Les"
  echo "données se trouvent déjà dans S3 sous forme d'objets, pas sur un périphérique bloc,"
  echo "donc ce volume n'a pas de snapshot via AWS Backup for EKS (ce mécanisme fonctionne"
  echo "via EBS VolumeSnapshot, chapitre 41). La protection contre une réécriture ou une"
  echo "suppression accidentelle d'objets sur un tel bucket, c'est le versioning (activé"
  echo "par terraform) et les politiques de lifecycle de S3 lui-même, pas un backup du"
  echo "volume entier."
} > /var/work/tests/artifacts/6/backup.txt

cat /var/work/tests/artifacts/6/backup.txt
```

## Vérification rapide

```bash
check_result
```
