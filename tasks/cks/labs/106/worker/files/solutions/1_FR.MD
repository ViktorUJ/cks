[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - solution de référence : AppArmor et seccomp

> Les commandes Kubernetes (`kubectl`) exécutez-les sur la machine de travail (`worker`). Tout ce qui concerne
> le nœud lui-même (AppArmor, kubelet, `crictl`), faites-le **directement sur le nœud** : entrez par `ssh` une
> seule fois et devenez root (`sudo -i`) - c'est plus rapide que d'envoyer chaque commande par un
> `ssh control-plane '...'` distinct, et c'est ainsi qu'il faut travailler à l'examen. Le namespace
> `security-106` est créé dans la tâche 3.
>
> ```bash
> ssh control-plane
> sudo -i
> # ... commandes sur le nœud ...
> exit   # de root
> exit   # du nœud, retour au worker
> ```
>
> La vérification lit les artefacts sur la **machine de travail** (`/var/work/tests/artifacts/<numéro>/`), ils sont
> nécessaires uniquement pour le lab - à l'examen, il n'y en a pas. Nous les enregistrons par une commande courte depuis le `worker`
> (`> fichier`), le contenu se consulte séparément via `cat <fichier>`.

## 1. Transfert et chargement de l'AppArmor profile

Le profil se trouve uniquement sur la machine de travail. Nous le copions sur le nœud (depuis le `worker`), puis sur le nœud
nous le plaçons à sa place et le chargeons dans le noyau. Le fichier contient déjà le flag `complain`, donc
un seul `apparmor_parser -r` suffit pour le chargement initial (sans `aa-complain`, qui, comme
`aa-enforce`, analyse tous les fichiers de `/etc/apparmor.d/` et échouerait sur le `k8s-106-broken-profile`
encore cassé de la tâche 9) :

```bash
# sur le worker
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# sur le nœud
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# attendu : "k8s-106-deny-write":	"complain",
```

## 2. Passage de l'AppArmor profile en enforce

Le profile est actuellement en mode `complain` (chargé avec ce flag dans la tâche 1). Nous restons sur le nœud
(sous root) et passons précisément le profile existant en enforcing mode :

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# attendu : "k8s-106-deny-write":	"enforce",
# Le 'aa-status | grep ...' ordinaire n'affichera pas le mode du profil : dans la sortie texte, les profils
# sont regroupés sous des titres ('N profiles are in enforce mode.'), les noms sont sans suffixe.
# Pour vérifier un profil concret, utilisez 'aa-status --pretty-json' (ou '--json').
exit
exit
```

N'utilisez pas `aa-enforce`/`aa-complain` ni d'autres outils de modification de profils du
paquet `apparmor-utils`, écrits en Python, pour CE profil tant que la
tâche 9 n'est pas faite : en interne, ils appellent `apparmor.read_profiles()`, qui au démarrage analyse
(parse) **tous** les fichiers de `/etc/apparmor.d/`, y compris le `/etc/apparmor.d/k8s-106-broken-profile`
de la tâche 9, pas encore chargé et délibérément cassé - et ils échouent avec une erreur du
parser sur un fichier ÉTRANGER, sans même essayer d'arriver jusqu'à votre profil. `apparmor_parser`
(un binaire, et non un wrapper Python), appelé directement avec UN fichier concret, n'analyse
que celui-ci et n'est pas soumis à ce problème - c'est précisément pourquoi nous modifions le flag du profil
(nous retirons `complain` de `flags=(...)`) à la main via `sed`, puis rechargeons précisément
ce fichier via `apparmor_parser -r`.

`aa-status` est un outil distinct de consultation de l'état, et non de modification des profils, et cet avertissement
ne le concerne pas. Le mode d'un profil concret est affiché par `aa-status --pretty-json` (vérifié sur
le nœud du lab, apparmor 3.0.4 ; `--json` donne la même chose sur une seule ligne, par exemple
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`). L'alternative est le fichier du noyau
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles` : là, le format est
`name (enforce|complain)`.

## 3. Pod avec Localhost AppArmor et refus d'écriture

Nous créons le namespace et le Pod. `emptyDir` garantit la présence de `/work` ; le profile autorise
le lancement du processus, mais interdit l'écriture dans ce répertoire. Le node selector lie le Pod au
nœud sur lequel le profile est réellement chargé.

```yaml
# apparmor-writer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-106
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

```bash
# sur le worker
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# attendez STATUS Running (répétez get), puis exécutez exec

# Evidence : le profil est réellement assigné au processus PID 1, et pas seulement écrit dans le Pod YAML.
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# Contrôle positif AVANT le refus : une opération read autorisée précisément sur le même /work
# où le denial sera vérifié - sans cette étape, le refus d'écriture ne pourrait pas être distingué
# d'un mount/mountPath qui ne fonctionne pas du tout (dans ce cas, même la lecture serait indisponible).
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Contrôle négatif : le denial doit être précisément un refus d'écriture d'AppArmor.
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# on attend un code non nul : Permission denied / Operation not permitted
```

Un exit code non nul et le texte « permission denied » ne démontrent PAS à eux seuls que c'est précisément
cette règle AppArmor qui a agi - une erreur DAC/filesystem ordinaire aurait l'air identique du
point de vue du shell. Reliez le refus précisément à ce profile via le kernel audit log ; nous le consultons
sur le nœud juste après la tentative ci-dessus :

```bash
# sur le nœud
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# on attend une entrée de la forme : ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod : création du fichier ; lors de l'écriture dans un fichier existant, ce sera "w")
exit
exit
```

Si `/proc/1/attr/current` n'est pas disponible dans le runtime concret, consignez-le et appuyez-vous
sur l'assignation du Localhost profile avec le kernel `apparmor="DENIED"` pour ce profile ;
un seul code non nul sans cette evidence est insuffisant, car il peut être donné par un mount ou une
permission Unix ordinaire.

## 4. RuntimeDefault pour un Pod ordinaire

`RuntimeDefault` est un baseline portable, qui choisit le profil standard de
containerd/runtime. Le champ est indiqué explicitement au niveau du Pod.

```yaml
# runtime-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
# sur le worker
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp et démonstration du blocage de `unshare`

Le fichier se trouve uniquement sur la machine de travail, dans `/opt/lab106-fixtures/cks-106-deny-unshare.json`.
Nous le copions sur le nœud (depuis le `worker`) et le plaçons dans le kubelet seccomp root (sur le nœud) :

```bash
# sur le worker
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# sur le nœud
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

Dans l'API, nous indiquons le chemin relatif au seccomp root : `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` ici est une exception dangereuse délibérée uniquement pour le lab (la vérification du contrôle sans seccomp est faite par le checker). Sans le custom
filter, `unshare -n` avec cette capability peut fonctionner ; seccomp doit renvoyer `EPERM`.
Ce n'est pas une hardened combination. `allowPrivilegeEscalation: false` active `no_new_privs`, mais
ne retire pas les capabilities déjà accordées au processus, c'est pourquoi nous n'utilisons pas ce champ comme
« compensation » de `SYS_ADMIN`. En production, une telle capability est supprimée s'il n'y a pas de
nécessité démontrée. Dans Kubernetes, la capability s'écrit `SYS_ADMIN`, sans le préfixe `CAP_`.

Nous utilisons `unshare -n` (network namespace, `CLONE_NEWNET`), et PAS `unshare -m` (mount
namespace). Les deux opérations nécessitent la même `CAP_SYS_ADMIN`, mais BusyBox `unshare -m`
après un `unshare(2)` réussi exécute en plus un syscall `mount(2)` indépendant
pour la forced private propagation - et le profil AppArmor par défaut de containerd (`RuntimeDefault`,
que reçoit ce Pod, puisqu'aucun `appArmorProfile` explicite n'est défini ici) contient
`deny mount,` sans aucune condition sur les flags, indépendamment des capabilities/seccomp. C'est pourquoi
`unshare -m true` peut échouer avec `EPERM` à cause d'AppArmor, même si seccomp ne
limite pas du tout `unshare` - un tel probe mélangerait deux security controls différents. `unshare -n`
n'appelle que le syscall `unshare(2)` lui-même, sans `mount()` collatéral.

```yaml
# localhost-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      if unshare -n true 2>/tmp/unshare.err; then
        echo 'unshare unexpectedly succeeded' >/tmp/unshare-result
        exit 1
      fi
      grep -Eqi 'operation not permitted|permission denied' /tmp/unshare.err
      echo 'unshare denied by seccomp' >/tmp/unshare-result
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

```bash
# sur le worker
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# on attend un code non nul : Operation not permitted / Permission denied
```

## 7. User namespaces : `hostUsers: false` et `uid_map`

`hostUsers: false` demande au kubelet d'allouer au Pod un user namespace distinct : le root (UID 0)
à l'intérieur du conteneur est mappé sur une plage d'UID de l'hôte non privilégiée. Nous ne définissons pas
`runAsUser`, afin que le processus démarre réellement en UID 0 **à l'intérieur** du namespace - c'est précisément ce
cas qui montre la traduction, et non l'absence de privilèges dès le départ.

```yaml
# userns-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-probe
  namespace: security-106
spec:
  hostUsers: false
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# sur le worker
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

Le host PID du conteneur ne coïncide pas avec le PID dans le conteneur et n'est pas non plus visible directement via
`kubectl`. Nous prenons l'ID du conteneur sur le worker et obtenons le PID via `crictl inspect` sur le nœud
où le Pod s'exécute réellement :

```bash
# sur le worker
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - copiez le <ID> sans le préfixe containerd://

# sur le nœud
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# par exemple : 15205 - c'est le <host PID>
```

`/proc/<host PID>/uid_map` sur le nœud décrit la traduction : trois nombres - `<container-uid-start>
<host-uid-start> <length>`. Pour `hostUsers: false`, la première ligne doit commencer par `0`
(container UID 0), mais le host-uid-start doit être **non nul** - c'est
la plage non privilégiée de l'hôte, et `length` est le bloc standard per-Pod de `65536` UID.

```bash
# sur le nœud (sous root)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (le host-uid-start est différent pour chaque Pod, l'essentiel est qu'il ne soit pas 0)
exit
exit
```

Nous enregistrons la ligne `uid_map` dans l'artefact (sur le `worker`) :

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

Si `host-uid-start` vaut `0`, le user namespace ne s'est pas appliqué (par exemple, à cause d'un
containerd/runc incompatible ou de l'absence de `hostUsers: false` dans le Pod réellement appliqué) -
ce n'est pas du hardening, mais un root ordinaire sur l'hôte. Pour comparaison : un Pod ordinaire sans
`hostUsers: false` a aussi le fichier `/proc/<host-PID>/uid_map`, mais le processus reste dans le
host (initial) user namespace. C'est pourquoi le mapping commence par UID 0 -> host UID 0 (en général
une ligne de la forme `0 0 4294967295`, par exemple `cat /proc/1/uid_map` sur le nœud), et non par
un host UID per-Pod non privilégié. Pour `userns-probe` avec `hostUsers: false`, nous attendons le
contraire : `0 <host-uid-non-nul> <plage-per-pod>`.

## 8. `seccompDefault: true` sur le kubelet

Les Pod précédents avec un profil seccomp (tâches 4–6) indiquaient explicitement `seccompProfile`. Ici, nous vérifions le node-level baseline :
si le développeur oublie ce champ, le kubelet doit appliquer `RuntimeDefault` lui-même, et ne pas
laisser le processus `Unconfined`. Nous modifions la configuration du kubelet sur le nœud :

```bash
# sur le nœud
ssh control-plane
sudo -i
grep -q '^seccompDefault:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^seccompDefault:.*/seccompDefault: true/' /var/lib/kubelet/config.yaml \
  || echo 'seccompDefault: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

```bash
# sur le worker : le nom du Node dans l'API n'est pas l'alias 'control-plane' de /etc/hosts, mais le vrai nom du nœud (ip-10-...)
kubectl get nodes     # Ready
```

Nous créons un Pod sans une seule mention de `seccompProfile`, ni au niveau du Pod ni au niveau du conteneur :

```yaml
# no-seccomp-field.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-seccomp-field
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# sur le worker
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- le kubelet a appliqué RuntimeDefault lui-même, sans le champ dans le manifest

# Vérifiez-vous via la configuration RÉELLEMENT APPLIQUÉE du kubelet, et non via le texte du fichier sur
# le disque : un drop-in ou un flag de ligne de commande pourraient redéfinir la valeur sans
# changer config.yaml lui-même :
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

Sans `seccompDefault: true`, le même manifest donnerait `Seccomp: 0` (`Unconfined`) - c'est facile à
vérifier en annulant le flag et en recréant le Pod, si l'on veut s'assurer de la différence.

## 9. Débogage d'un profil AppArmor cassé

`/etc/apparmor.d/k8s-106-broken-profile` est déjà sur le disque, mais n'a jamais été chargé : il
lui manque une virgule après la règle `deny /work/** w`. D'abord, nous trouvons l'erreur sans charger dans le
noyau. `-p`/`--preprocess` ne convient PAS ici - c'est un preprocessing (développe
`#include` sur stdout), et non un safe dry-run/syntax-check. Nous utilisons `-Q`/`--skip-kernel-load`
(compilation/vérification complète sans chargement dans le noyau) ou `-d`/`--debug`
(une seule fois - uniquement un syntax check).

L'artefact `apparmor-debug.txt` doit contenir l'erreur **d'origine** du parser, c'est pourquoi
nous l'enregistrons avant la correction (sur le `worker`) :

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

Nous utilisons `sudo` aussi pour la vérification compile-only `-Q` : sur le nœud du lab (apparmor 3.0.4, Ubuntu),
sans privilèges, le parser tente à chaque lancement de configurer le policy cache dans
`/var/cache/apparmor` et échoue avec « Failed setting up policy cache (/var/cache/apparmor):
Permission denied » AVANT la vérification de la syntaxe - vous obtiendrez une erreur trompeuse de droits au lieu de
la vraie erreur de syntaxe, et `apparmor-debug.txt` ne contiendra pas le texte nécessaire
« syntax error ». Vérifié sur le nœud lui-même, y compris sur un profil délibérément cassé.
L'alternative sans `sudo` est d'ajouter `-K`/`--skip-cache` (`apparmor_parser -Q -K ...`) : sans
mise en cache, le parser arrive jusqu'à l'analyse du profil. `sudo` a été choisi dans ce lab pour un workflow
unifié avec le `-r` suivant, qui nécessite de toute façon des privilèges.

Nous corrigeons sur le nœud : une règle AppArmor doit se terminer par une virgule. Ensuite, nous chargeons le
profil corrigé dans le noyau - précisément avec `-r -v` (reload + verbose), et non `-Q`/`-p`, qui
ne chargent rien :

```bash
# sur le nœud
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# attendu : "k8s-106-broken-profile":	"enforce",
```

Vérification finale que le fichier est maintenant valide sans erreurs :

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

Maintenant, sur le `worker`, ajoutez la confirmation du chargement APRÈS la correction au même artefact :

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

À la fin, exécutez (sur le `worker`) :

```bash
check_result
```
