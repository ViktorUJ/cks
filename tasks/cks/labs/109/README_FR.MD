[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 109 - Chiffrement des Secret dans etcd et accès minimal

## Objectif

Dans ce lab CKS, vous allez démontrer qu'un Secret Kubernetes sans encryption at rest est stocké dans
etcd sous forme d'octets lisibles (base64 n'est pas du chiffrement), activer `aescbc` via
`EncryptionConfiguration`, le brancher au `kube-apiserver` static, réécrire les anciens
Secret et restreindre l'accès aux données par RBAC et `automountServiceAccountToken`.

`aescbc` n'est choisi ici que pour s'exercer à la mécanique d'examen de
`EncryptionConfiguration` et de re-encryption. La documentation actuelle de Kubernetes considère
AES-CBC comme faible et ne le recommande pas en raison du risque d'attaques padding-oracle ; `aesgcm` exige aussi
une rotation automatisée de la clé. Pour la production, choisissez le provider d'après la documentation
à jour et le threat model ; avec un key manager externe, KMS v2 est préférable
(voir le [chapitre 21](../../course/21/fr.md)).

## Threat model

Encryption at rest protège contre un storage compromise : supposons qu'un attaquant ait obtenu un accès read-only à un snapshot d'etcd ou à la couche de stockage, par exemple via un backup ou un volume snapshot, mais n'ait pas d'accès autorisé à l'API. La tâche 1 démontre précisément ce risque initial via une lecture raw d'etcd.

Après l'activation de encryption at rest, les tâches 2–4 réduisent le blast radius d'un tel accès : les données lues directement ne doivent pas révéler le Secret. Ce n'est pas une protection universelle ni un substitut au contrôle d'accès à l'API.

Si l'attaquant a un accès légitime à l'API avec des droits de lecture des Secret, encryption at rest ne protège pas de cette menace : l'API renverra la valeur après déchiffrement. C'est pourquoi la tâche 5 restreint séparément RBAC et automount, réduisant le blast radius de l'identity d'un workload ayant de tels droits.

## Vérifiez-vous avant de commencer

<details>
<summary>1. Pourquoi base64 dans `Secret.data` n'est-il pas du chiffrement ?</summary>

base64 n'est qu'un encodage, réversible sans clé : quiconque a accès aux octets eux-mêmes (par exemple, via une lecture raw d'etcd) peut décoder la valeur instantanément, sans aucune opération cryptographique. Le chiffrement exige une clé pour la transformation inverse - base64 n'a pas du tout cette propriété.
</details>

<details>
<summary>2. Pourquoi le provider `identity` doit-il venir EN DERNIER dans la liste des providers, et non en premier ?</summary>

Les providers dans `EncryptionConfiguration` sont essayés dans l'ordre pour LIRE les enregistrements existants, et le premier provider est utilisé pour ÉCRIRE les nouvelles données. Si `identity` (c'est-à-dire « sans chiffrement ») est en premier, tous les nouveaux enregistrements seront écrits NON chiffrés, malgré la présence de `aescbc` dans la liste. Avec `identity` en dernier, on peut lire les anciens enregistrements plaintext (pas encore migrés), mais on garantit que tous les nouveaux enregistrements sont chiffrés par le premier provider.
</details>

<details>
<summary>3. Pourquoi ne peut-on pas simplement supprimer l'ancienne clé de chiffrement immédiatement après avoir ajouté la nouvelle ?</summary>

Les enregistrements existants dans etcd restent chiffrés avec l'ANCIENNE clé tant qu'ils ne sont pas réécrits explicitement (re-encryption). Si vous retirez l'ancienne clé de l'`EncryptionConfiguration` active avant que tous les enregistrements aient été réécrits avec la nouvelle, l'API server ne pourra pas déchiffrer les anciens enregistrements restants via la provider chain actuelle - ils deviendront illisibles jusqu'à ce que l'ancienne clé soit remise dans la configuration. Retirer la clé de la config ne détruit pas physiquement le key material : si l'ancienne clé conservée est de nouveau ajoutée à la provider chain, l'accès est rétabli. Une perte irréversible de données ne se produit que si le key material lui-même est réellement perdu ou détruit (par exemple, la clé n'a été enregistrée nulle part avant la suppression). L'ordre : ajouter la nouvelle clé en premier → réécrire tous les Secret → confirmer que tous les enregistrements utilisent la nouvelle clé → conserver l'ancienne clé dans un endroit fiable pour le rollback → ce n'est qu'ensuite qu'on la retire de la config.
</details>

## Infrastructure

L'environnement est déployé par Terragrunt dans AWS `eu-central-1` :

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.10.0.0/16` avec des sous-réseaux publics |
| `ssh-keys` | clés SSH pour le worker et le control-plane |
| `k8s-1` | control-plane kubeadm mono-nœud : Kubernetes **1.36.0**, containerd, **Calico** |
| `worker` | machine de travail avec `kubectl` ; sur le control-plane (`ssh control-plane`) est installé l'`etcdctl` 3.6.0 standard, comme à l'examen |

Le control-plane accepte volontairement les Pods ordinaires - aucun worker Kubernetes distinct n'est créé.
Avant les tâches, le bootstrap crée le namespace `encryption-109` et un `legacy-secret`
inoffensif. Ce Secret a été créé **avant** l'EncryptionConfiguration, il sert donc
de preuve contrôlée de l'état plaintext.

Les opérations sur le nœud s'effectuent sur le control-plane lui-même, comme à l'examen : entrez-y
(`ssh control-plane`), travaillez là-bas et sortez (`exit`) ; `kubectl` - depuis la machine de travail. L'enregistrement raw
d'etcd se lit avec l'`etcdctl` standard de la documentation Kubernetes avec les certificats kubeadm de
`/etc/kubernetes/pki/etcd/` (`ca.crt`, `server.crt`, `server.key`). Les exemples de commandes tout prêts sont
dans la section « Où trouver des exemples dans la documentation » de la solution de référence.

## Déploiement

```bash
TASK=109 make run_cks_task
```

Connectez-vous à la machine de travail. Le contexte `cluster1-admin@cluster1` est déjà configuré.

```bash
time_left
check_result
```

## Tâches

---
| **1** | **Démontrer le Secret plaintext initial** |
| :---: | :--- |
| Ce qu'on fait | • Avant d'activer le chiffrement, demandez l'enregistrement raw `/registry/secrets/encryption-109/legacy-secret` avec l'`etcdctl get ... --print-value-only` standard<br/>• Entrez sur le control-plane (`ssh control-plane`) et travaillez dessus, comme à l'examen : passez la sortie par `strings` et enregistrez le résultat dans un fichier sur le control-plane (`/tmp/plaintext-proof.txt`), puis copiez-le sur la machine de travail avec la commande `scp` vers `/var/work/109/plaintext-proof.txt` |
| Critères d'acceptation | • Le fichier contient la sortie complète de `strings` de l'enregistrement raw d'origine (coïncide avec l'instantané du bootstrap, y compris le marker `cks-109-legacy-plaintext`) et ne contient pas `k8s:enc:`<br/>• Une chaîne saisie à la main n'est pas acceptée<br/>• C'est la preuve de l'état initial : `Secret.data` est du base64, pas de l'encryption at rest |

<details>
<summary>💡 Indice pour la tâche 1</summary>

Cette tâche doit être réalisée EN PREMIER, avant la tâche 2 : dès que vous activez EncryptionConfiguration et réécrivez le Secret, la preuve plaintext disparaît et vous ne pourrez plus l'enregistrer post-hoc. La commande `etcdctl` avec les flags `--cacert/--cert/--key` se prend dans la documentation officielle de Kubernetes (la section « Verify that newly written data is encrypted » de la page Encrypting Confidential Data at Rest) ; les chemins des certificats kubeadm : `/etc/kubernetes/pki/etcd/ca.crt`, `server.crt`, `server.key`. Les liens exacts figurent dans la section « Où trouver des exemples dans la documentation » de la solution de référence.
</details>

---
| **2** | **Créer l'EncryptionConfiguration pour Secret** |
| :---: | :--- |
| Ce qu'on fait | • Sur le control-plane, créez `/etc/kubernetes/enc/encryption-config.yaml`, owner `root:root`, mode `0600`<br/>• Format : `apiserver.config.k8s.io/v1`, `EncryptionConfiguration`<br/>• Pour `secrets`, définissez comme premier provider `aescbc` avec une clé base64 nommée de **32 octets aléatoires**, puis `identity: {}` |
| Critères d'acceptation | • Fichier `root:root` mode `0600` dans un répertoire `root:root` mode `0700`<br/>• Le provider actif principal pour `secrets` est le **premier** `aescbc` avec une named base64 key correcte de 32 octets<br/>• `identity` n'est admissible qu'en dernier, comme fallback temporaire pour le plaintext legacy<br/>• Un symlink vers le fichier/répertoire est interdit |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Générez la clé via `head -c 32 /dev/urandom | base64` - précisément 32 OCTETS (et non 32 caractères de la chaîne base64, qui sera plus longue à cause de l'encodage). Vérifiez-vous : `echo -n "<votre-clé-base64>" | base64 -d | wc -c` doit renvoyer exactement `32`.
</details>

---
| **3** | **Brancher la config au kube-apiserver static** |
| :---: | :--- |
| Ce qu'on fait | • Modifiez avec soin `/etc/kubernetes/manifests/kube-apiserver.yaml` : ajoutez le flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`, un `volumeMount` read-only `/etc/kubernetes/enc` et le volume `hostPath` correspondant `/etc/kubernetes/enc`<br/>• Enregistrez un backup du manifest avant la modification |
| Critères d'acceptation | • Le manifest en fonctionnement contient le flag, le mount et le hostPath<br/>• Après le restart du static Pod, `kubectl get --raw='/readyz'` renvoie `ok` |

<details>
<summary>💡 Indice pour la tâche 3</summary>

Trois modifications distinctes sont nécessaires à la fois : le flag `--encryption-provider-config` lui-même, `volumeMounts` (dans le conteneur) ET `volumes` (hostPath au niveau du Pod spec) - en oublier un seul des trois conduira soit à un CrashLoopBackOff (le flag pointe vers un fichier que le conteneur ne voit pas), soit au fait que le flag ne sera simplement pas transmis. Enregistrez le backup **en dehors** de `/etc/kubernetes/manifests`, par exemple `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`. Le kubelet lit les fichiers supplémentaires non cachés du répertoire des static manifests ; un `kube-apiserver.yaml.bak` voisin peut être pris pour un second static Pod et bloquer l'application de la nouvelle configuration.
</details>

---
| **4** | **Re-encrypt et démontrer le ciphertext** |
| :---: | :--- |
| Ce qu'on fait | • Une fois l'API server prêt, créez dans `encryption-109` le Secret `encrypted-secret` avec le literal `token=cks-109-fresh-ciphertext`<br/>• Réécrivez tous les Secret existants auparavant via l'API (`kubectl get secrets --all-namespaces -o json | kubectl replace -f -`)<br/>• Vérifiez les deux Secret via l'API et raw etcd<br/>• Ce n'est qu'après cette vérification que vous supprimez le fallback temporaire `identity`, redémarrez le kube-apiserver static et revérifiez `/readyz` et la lecture des deux Secret |
| Critères d'acceptation | • `legacy-secret` et `encrypted-secret` se lisent via l'API avec les valeurs d'origine<br/>• Le raw value de chacun commence par `k8s:enc:aescbc:v1:`<br/>• Le legacy marker n'est plus visible dans raw etcd<br/>• Les payload/UID d'origine de tout le bootstrap Secret corpus sont conservés, tous les enregistrements sont chiffrés avec la première clé active<br/>• La clé du fichier final est capable de déchiffrer le ciphertext des deux canary Secret<br/>• Dans la configuration finale, il n'y a pas d'`identity`, API healthy |

<details>
<summary>💡 Indice pour la tâche 4</summary>

L'ordre est critique : créer `encrypted-secret` → réécrire TOUS les Secret existants via `kubectl replace` → vérifier raw etcd pour LES DEUX (legacy et encrypted) → SEULEMENT ENSUITE retirer `identity` de la config. Si vous retirez `identity` avant que `legacy-secret` soit réécrit, l'API server ne pourra plus lire l'ancien enregistrement plaintext via la provider chain, et `legacy-secret` deviendra inaccessible.
</details>

---
| **5** | **Minimiser RBAC et désactiver automount** |
| :---: | :--- |
| Ce qu'on fait | • Créez un ServiceAccount `secret-reader` dans `encryption-109` avec `automountServiceAccountToken: false`<br/>• Le Role `secret-reader-109` doit donner uniquement `get` uniquement sur le Secret `encrypted-secret`<br/>• Liez-le par un RoleBinding de même nom<br/>• Créez un Pod `secret-reader-109` avec ce ServiceAccount, `automountServiceAccountToken: false`, avec l'image `registry.k8s.io/pause:3.10` |
| Critères d'acceptation | • Le RBAC effectif du ServiceAccount avec ses groupes standard autorise `get encrypted-secret` dans `encryption-109` et interdit les autres opérations sur Secret, y compris l'accès aux Secret d'autres namespace<br/>• Role/RoleBinding exacts<br/>• Pod Running avec un seul `pause:3.10`, sans ServiceAccount token monté ni automatiquement ni manuellement et sans autres credential-bearing sources (volumes Secret/hostPath/CSI/PVC, env/envFrom de Secret)<br/>• Les volumes emptyDir/ConfigMap inoffensifs sont admissibles<br/>• `automountServiceAccountToken: false` dans le Pod et le ServiceAccount |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Utilisez `resourceNames: ["encrypted-secret"]` dans le Role - sans ce champ, `get`/`list` sur la ressource `secrets` donnerait accès à TOUS les Secret du namespace, y compris `legacy-secret`, ce qui enfreint l'exigence de least-privilege. `pause:3.10` est une image de substitution, qui n'a pas du tout besoin de la Kubernetes API, c'est pourquoi l'automount est désactivé à deux niveaux (SA et Pod) sans conséquences fonctionnelles.
</details>

## Vérification

```bash
check_result
```

La vérification contient Init et cinq tests obligatoires. Le test 4 vérifie non seulement la présence du
fichier de configuration, mais le ciphertext réel `k8s:enc:aescbc:v1:` pour l'enregistrement nouveau et ancien
d'etcd, et l'absence de l'`identity` migration-only dans la configuration finale. Avant un re-encryption de masse dans un environnement réel, il faut un snapshot, un plan de
rotation des clés et une fenêtre contrôlée ; ce lab n'est pas un runbook de production.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Suppression

```bash
TASK=109 make delete_cks_task
```

## En complément : KMS v2 et le cycle de vie complet de la rotation

**KMS v2 (walkthrough optionnel).** Un KMS-plugin externe se connecte à l'API server comme
provider `kms` dans `EncryptionConfiguration` ; son endpoint est un Unix socket local, et la clé
du provider reçoit un nom stable, par exemple `kms-v2-primary`. Dans KMS v2, l'API server obtient via le plugin un seed chiffré (wrapped sous le
**KEK** externe) et en dérive les clés de chiffrement des objets individuels. KMS v2
utilise le seed/DEK au niveau de l'API server, et non un appel distinct à KMS pour chaque Secret.
Dans etcd sont conservés le ciphertext du Secret et les données nécessaires au rétablissement de la clé. Ainsi, le KEK ne se trouve pas dans etcd ; la availability, les ACL et le backup de KMS font
partie du modèle de sécurité. Un provider minimal **illustratif** (l'endpoint doit
correspondre au plugin installé) ressemble à ceci :

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

Ajoutez le provider en premier pour les nouveaux enregistrements, montez le socket dans le `kube-apiserver` static
et attendez la health du plugin avant le re-encryption. Pour une configuration réelle, utilisez
un plugin pris en charge et le format actuel de `kms` v2 de la documentation de la version
de Kubernetes utilisée ; ce lab ne lève pas de KMS-plugin et ne fournit pas de socket opérationnel.

**Rotation complète de la clé du provider.** La migration de plaintext vers la première clé
`aescbc` réalisée dans la tâche 4 n'est pas une rotation complète de la clé. Pour celle-ci : (1) faites un snapshot protégé d'etcd et
vérifiez que l'ancienne clé est conservée et disponible pour le rollback ; (2) ajoutez la nouvelle clé
en premier dans `aescbc.keys`, en laissant l'ancienne en second, puis redémarrez l'API server ; (3)
réécrivez les Secret existants via l'API, afin qu'ils soient chiffrés avec la nouvelle première clé ;
(4) pour des enregistrements raw d'etcd, d'abord sélectionnés puis tous, confirmez le préfixe
`k8s:enc:aescbc:v1:<nom-de-la-nouvelle-clé>:` ; (5) ce n'est qu'après la migration complète, le backup et
la vérification de lecture que vous supprimez l'ancienne clé, redémarrez l'API server et revérifiez `/readyz`
et les Secret. Pour KMS v2, de façon équivalente, on change d'abord le KEK/plugin primary, on réalise le
re-encryption et ce n'est qu'ensuite qu'on retire l'ancien KEK de l'utilisation selon la procédure de KMS.
