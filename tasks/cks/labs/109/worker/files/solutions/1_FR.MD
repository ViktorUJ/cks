[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - solution de référence : encryption at rest pour Secret

> Nous travaillons comme à l'examen : les commandes `kubectl` s'exécutent sur la machine de travail, et les opérations sur le
> nœud (etcd, fichiers et manifest du control-plane) - sur le control-plane lui-même : entrez-y avec
> `ssh control-plane`, exécutez les commandes et sortez (`exit`). C'est **uniquement un cluster pédagogique
> mono-nœud** ; en production, on ne donne pas aux utilisateurs d'accès direct à etcd.

## Où trouver des exemples dans la documentation

Toutes les commandes ci-dessous sont tirées de la documentation officielle de Kubernetes - à l'examen, il faut les y trouver
et non les retenir par cœur :

| Ce qu'il faut | Page et section |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Lire l'enregistrement raw d'etcd et voir le préfixe `k8s:enc:aescbc:v1:` (la commande `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted)                             |
| Un exemple d'`EncryptionConfiguration` avec `aescbc` et `identity`                                                                                                                                                                                                                                                       | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file)                            |
| Le flag `--encryption-provider-config` et le montage du fichier dans le static Pod de kube-apiserver                                                                                                                                                                                                                | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file)                      |
| Réécrire tous les Secret (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)                                                                                                                                                                                                             | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted)                                  |
| Rotation de la clé (étapes 1-7) et suppression de l'ancienne clé                                                                                                                                                                                                                                       | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key)                                                        |
| Où obtenir les chemins des certificats d'etcd, si on ne s'en souvient pas : « `trusted-ca-file`, `cert-file` et `key-file` peuvent être obtenus à partir de la description du Pod etcd » (`kubectl -n kube-system describe pod etcd-<node>` ou `/etc/kubernetes/manifests/etcd.yaml`)       | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)                                                               |
| Role/RoleBinding et ServiceAccount (`automountServiceAccountToken`)                                                                                                                                                                                                                                                        | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

Chemins des certificats dans un cluster kubeadm : `/etc/kubernetes/pki/etcd/ca.crt`,
`/etc/kubernetes/pki/etcd/server.crt`, `/etc/kubernetes/pki/etcd/server.key` ; l'endpoint par défaut est
`https://127.0.0.1:2379`, donc sur le control-plane le flag `--endpoints` n'est pas nécessaire.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. Enregistrer la preuve du plaintext avant d'activer le chiffrement

`Secret.data` dans l'API est encodé en base64, et non chiffré. Le bootstrap a créé un
canary sûr avant l'apparition de l'EncryptionConfiguration. D'abord, nous regardons l'enregistrement raw d'etcd avec la commande de la
documentation, puis nous enregistrons la preuve sous forme de chaîne dans le fichier `/var/work/109/plaintext-proof.txt`
sur le control-plane (`/tmp/plaintext-proof.txt`), puis nous la copions sur la machine de travail dans
`/var/work/109/plaintext-proof.txt` (le répertoire a été créé par le bootstrap) : la vérification lit le fichier sur la machine de travail.

Entrez sur le control-plane et exécutez dessus (dans cette commande tout vient de la documentation, sauf la clé dans
etcd : `/registry/secrets/<namespace>/<name>`) :

```bash
ssh control-plane
sudo -i
```

```bash
# sur le control-plane : enregistrement raw d'etcd, la sortie de hexdump -C montre le plaintext
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# enregistrer la preuve (uniquement la valeur, via strings) - également sur le control-plane
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # de root
exit   # du control-plane
```

```bash
# sur la machine de travail : copier la preuve
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

À cette étape, le fichier ne contient pas `k8s:enc:`. C'est la preuve de l'état **avant** la configuration ;
après le re-encryption, la nouvelle sortie doit devenir du ciphertext et le marker disparaîtra.

## 2. Créer l'EncryptionConfiguration

`aescbc` n'est choisi que pour la mécanique pédagogique de CKS. Kubernetes considère AES-CBC comme faible à cause du
risque d'attaques padding-oracle et ne le recommande pas comme default de production. Pour un key
manager externe, utilisez KMS v2 ; ne choisissez un provider local qu'avec un threat model à jour
et une procédure de rotation.

Nous générons une clé AES-256 de 32 octets, l'encodons en base64 et créons la configuration sur le control-plane.
`aescbc` vient en premier : c'est avec lui que les nouveaux Secret seront écrits. Avec `identity` en dernier, l'API
server peut lire l'ancien enregistrement plaintext uniquement jusqu'à la migration. Un exemple du fichier se trouve sur la page de la
documentation (lien au début de la solution).

```bash
ssh control-plane
sudo -i
```

```bash
# sur le control-plane (root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # de root
exit   # du control-plane
```

La vraie clé ne doit pas être placée dans Git, un ticket, le log du terminal ni le Terraform state.
En cas de perte de la clé, le Secret chiffré d'un snapshot devient illisible.

## 3. Brancher la configuration au kube-apiserver static

Nous enregistrons d'abord le manifest **en dehors** du répertoire `/etc/kubernetes/manifests/` : le kubelet lit comme static
Pod chaque fichier non caché de ce répertoire, y compris `*.bak`. Une copie du manifest d'origine à l'intérieur du
répertoire est un second static Pod du même nom ; le kubelet peut continuer à lancer précisément cette copie
(l'ancienne configuration sans `--encryption-provider-config`), et la modification du fichier principal ne
prendra silencieusement pas effet, et le chiffrement restera désactivé avec un API server en apparence sain.
Sur le control-plane, ouvrez précisément le manifest existant du static Pod
et ajoutez **aux** `command`, `volumeMounts` et `volumes` existants ces éléments ;
ne remplacez pas tout le fichier par un modèle.

```bash
ssh control-plane
sudo -i
```

```bash
# sur le control-plane (root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

Le kubelet remarquera la modification et redémarrera le static Pod. Avant de continuer, attendez l'API
server, sinon une erreur de YAML/chemin peut laisser le control-plane inaccessible.

```bash
# toujours sur le control-plane : vérifier que le flag est arrivé dans le manifest en fonctionnement, puis sortir
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # de root
exit   # du control-plane
```

```bash
# sur la machine de travail : l'API server redémarre pendant environ une minute ; répétez jusqu'à ce que la commande
# renvoie "readyz check passed" (avant cela, il y aura "connection refused")
kubectl get --raw='/readyz?verbose'
```

## 4. Réécrire les anciens Secret et vérifier le ciphertext

La configuration ne change pas les enregistrements déjà conservés. D'abord, nous créerons un Secret après l'activation du
provider, puis nous réécrirons tous les Secret existants via l'API. En production, avant cela
on fait un snapshot protégé et on utilise une procédure contrôlée avec retry.

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

Les enregistrements raw se lisent sur le control-plane, comme dans la tâche 1 :

```bash
ssh control-plane
sudo -i
```

```bash
# sur le control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# les deux enregistrements commencent par k8s:enc:aescbc:v1:...
exit   # de root
exit   # du control-plane
```

L'API renvoie le plaintext à un client autorisé - c'est normal et ne démontre pas le
chiffrement at rest. Ici, la preuve est que raw etcd contient `k8s:enc:aescbc:v1:` pour
l'ancien et le nouvel enregistrement et ne contient plus le legacy marker.

Maintenant, le migration fallback n'est plus nécessaire. Nous supprimons `identity`, redémarrons de force le
kube-apiserver static via CRI et revérifions la santé et la lecture. Ne le faites qu'
après un snapshot et la confirmation du ciphertext de tous les types de ressources concernés.

```bash
ssh control-plane
sudo -i
```

```bash
# sur le control-plane (root) : retirer identity et redémarrer le kube-apiserver static
vim /etc/kubernetes/enc/encryption-config.yaml   # supprimer la ligne "- identity: {}"
crictl stop $(crictl ps --name kube-apiserver -q)
exit   # de root
exit   # du control-plane
```

```bash
# sur la machine de travail
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

État final de ce lab : l'encrypted provider est le premier et le seul, `identity`
est supprimé. Le fallback temporaire ne doit pas être laissé comme « assurance » permanente.

## 5. Restreindre l'accès à l'API et désactiver le token automount

Encryption at rest ne remplace pas RBAC : un sujet avec `get` sur Secret verra le plaintext via l'API.
Nous créerons un ServiceAccount auquel est accessible exactement un Secret, et un Pod de diagnostic sans
service-account token monté.

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` réduit la credential surface disponible du Pod, mais ne
limite pas le RBAC du ServiceAccount lui-même si l'application obtient d'autres credentials.

## En complément : à quoi ressemble KMS v2 et la rotation complète de la clé

### KMS v2 : envelope encryption sans clé locale dans la config

`aescbc` ci-dessus ne sert qu'à la mécanique pédagogique. En production, KMS v2 connecte
un KMS-plugin pris en charge via un Unix socket local dans `EncryptionConfiguration`.
Pour KMS v2, l'API server utilise un seed/DEK chiffré au niveau de l'API server et
dérive les clés de chiffrement des enregistrements individuels. Le plugin protège le seed via un KEK externe ;
c'est en cela que KMS v2 diffère de KMS v1 per-resource. Etcd conserve le ciphertext des ressources et
les métadonnées nécessaires au déchiffrement. Le KEK reste dans le KMS externe, et non dans etcd ni dans Git. Le schéma de
configuration dépend de la version de Kubernetes et du plugin, mais en principe il faut le provider `kms`,
un nom stable de key et l'endpoint du socket. Ne copiez pas l'endpoint d'exemple d'un cluster tiers :
comparez le format de KMS v2 et les exigences de health/ACL avec la documentation de votre version de Kubernetes.

### Cycle de vie complet de la rotation de la clé aescbc

La transition `identity -> aescbc` de la tâche 4 est une migration, et non la rotation d'une clé déjà
chiffrée. Avant la rotation, faites un snapshot chiffré d'etcd et conservez
l'ancienne clé pour le rollback. Ajoutez la nouvelle clé **en premier**, et laissez temporairement l'ancienne
en second : les providers sont lus dans l'ordre, et les nouveaux enregistrements sont écrits avec la première clé.

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

Après le redémarrage de l'API server, réécrivez les ressources et vérifiez précisément le nom de la nouvelle key dans le ciphertext
raw, et pas seulement le prefix général `k8s:enc` :

```bash
# sur la machine de travail
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# sur le control-plane (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # de root
exit   # du control-plane
```

Quand la migration de tous les Secret est confirmée, le backup fait, l'API lit les données et `/readyz`
renvoie `ok`, supprimez l'ancienne key de la liste, redémarrez l'API server et répétez les
vérifications. Ne supprimez pas l'ancienne key plus tôt : les enregistrements non réécrits avec le nouveau provider deviendront
illisibles. Pour KMS v2, l'ordre est le même : d'abord le nouveau KEK/plugin primary, puis le
re-encryption, la vérification et ce n'est qu'après la migration qu'on retire l'ancien KEK de l'exploitation.
