[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 106 - AppArmor et seccomp : node-local policy et refus vérifiables

## Objectif

Dans ce lab CKS, vous allez appliquer deux mécanismes indépendants de protection du processus du conteneur au
niveau du noyau Linux. D'abord, vous passerez un profil **AppArmor** livré à l'avance de
`complain` à `enforce`, vous l'assignerez à un Pod via le champ moderne
`securityContext.appArmorProfile` et vous démontrerez le refus d'écriture. Ensuite, vous assignerez le baseline
sûr `RuntimeDefault` et un profil **seccomp Localhost** custom qui bloque l'appel
système `unshare(2)`.

C'est la suite du `SecurityContext` de base du lab CKA 106 : ici, il ne suffit pas d'écrire un
YAML. Les profils Localhost vivent sur le nœud Kubernetes, il faut donc vérifier le nœud, le
placement du Pod et le comportement réel du processus.

## Threat model

Supposons un RCE dans le conteneur. La question après le compromise n'est pas « l'attaquant a-t-il pu obtenir un shell », mais « que peut faire ce shell ensuite » et quelle est l'ampleur de son blast radius.

AppArmor dans les tâches 1–2 limite les objets et les opérations : le profil est passé en enforce, puis on démontre le refus d'écriture. Ainsi, un processus déjà compromis n'obtient pas une action illimitée simplement parce qu'il s'exécute dans un conteneur.

seccomp dans les tâches 3–5 limite l'appel système disponible : d'abord le baseline est appliqué, puis le profil custom, puis on vérifie le refus réel de `unshare(2)`. La tâche 5 contient déjà un negative control via le Pod `sysadmin-control` : avec la même capability sans seccomp filter, l'appel passe, et la comparaison montre donc précisément la frontière après le compromise.

## Vérifiez-vous avant de commencer

<details>
<summary>1. En quoi `complain` diffère-t-il de `enforce` dans AppArmor, et pourquoi `complain` ne peut-il pas être présenté comme une preuve de protection ?</summary>

En mode `complain`, AppArmor ne fait que journaliser les violations du profil, mais NE les bloque PAS - une opération qui devrait être interdite s'exécutera quand même, une entrée apparaîtra simplement dans le journal. En `enforce`, l'opération est réellement bloquée. La tâche 1 exige explicitement de passer le profil en `enforce`, car la démonstration « voici une violation dans le log » en `complain` ne prouve pas la protection - le processus a tout de même pu effectuer l'action.
</details>

<details>
<summary>2. Pourquoi `allowPrivilegeEscalation: false` ne retire-t-il pas la capability `SYS_ADMIN` déjà accordée ?</summary>

`allowPrivilegeEscalation: false` active le kernel-flag `no_new_privs`, qui interdit au processus d'obtenir de NOUVEAUX droits via `execve` (par exemple, via un binaire setuid ou des file capabilities). Cela n'affecte pas les droits que le processus a DÉJÀ dans son effective/bounding set - si le conteneur est lancé avec la capability `SYS_ADMIN` explicitement dans le manifest, cette capability reste disponible indépendamment de la valeur de `allowPrivilegeEscalation`.
</details>

<details>
<summary>3. Pourquoi `localhostProfile` dans le manifest du Pod est-il indiqué comme un chemin relatif et non absolu ?</summary>

Le kubelet résout lui-même le chemin relatif par rapport à son seccomp root (par défaut `/var/lib/kubelet/seccomp/`). Si l'on indique un chemin absolu, le kubelet cherchera le fichier PAR CE CHEMIN ABSOLU à l'intérieur du seccomp root, ce qui ne coïncidera presque jamais avec l'emplacement réel du fichier - le Pod recevra `CreateContainerError`.
</details>

## Lien avec le cours

- [Chapitre 16. AppArmor](../../course/16/fr.md)
- [Chapitre 17. seccomp](../../course/17/fr.md)
- [Chapitre 03. Container Runtime Security](../../course/03/fr.md)

## Infrastructure

L'environnement est déployé via Terragrunt dans AWS `eu-central-1`.

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.10.0.0/16` avec des sous-réseaux publics |
| `ssh-keys` | clés pour l'accès au nœud |
| `k8s-1` | cluster kubeadm mono-nœud avec Kubernetes `1.36.0`, containerd et **Calico** |
| `worker` | machine de travail avec `kubectl`, `check_result` et un accès SSH au nœud comme `control-plane` |

Pour économiser les ressources, le control-plane est le seul workload-node : le
`NoSchedule` taint lui a été retiré. Il est marqué par le label
`security.cks.io/localhost-profiles-106=true`. Tous les Pod de ce lab doivent choisir précisément
ce nœud - le plan-profil n'est pas transféré par le planificateur (scheduler) vers un autre nœud.

Le bootstrap a préparé **uniquement** :

- le label du nœud `security.cks.io/localhost-profiles-106=true` pour un placement sûr ;
- sur la machine de travail (worker), dans `/opt/lab106-fixtures/` : les sources de `k8s-106-deny-write`
  (AppArmor profile) et `cks-106-deny-unshare.json` (seccomp profile custom).

Ni l'AppArmor profile ni le seccomp profile ne sont préinstallés sur le workload-node ni
chargés dans son noyau - le transfert et le chargement initial de chacun d'eux font partie des tâches 1 et 5.
Ne changez pas le chemin du seccomp profile et ne créez pas de profile à l'intérieur d'un Pod ordinaire : le transfert des
fichiers vers le nœud, c'est vous qui l'effectuez en tant qu'administrateur du nœud via SSH, et non depuis l'intérieur du workload.

## Déploiement

```bash
TASK=106 make run_cks_task
```

Connectez-vous en SSH à la machine de travail. Le contexte est déjà configuré :

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Vérifiez l'accès au nœud et les worker-side fixtures avant de commencer à travailler :

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## Tâches

---
| **1** | **Transférer et charger l'AppArmor profile** |
| :---: | :--- |
| Ce qu'on fait | Le fichier source du profile `k8s-106-deny-write` se trouve uniquement sur la machine de travail, dans `/opt/lab106-fixtures/k8s-106-deny-write`. Copiez-le sur le nœud `control-plane` dans `/etc/apparmor.d/k8s-106-deny-write` (par exemple, via `scp`) et chargez-le dans le noyau via `sudo apparmor_parser -r`. Le profile contient déjà le flag `complain` - il n'est pas nécessaire de l'activer une seconde fois, c'est l'objet de la tâche 2. |
| Critères d'acceptation | `/etc/apparmor.d/k8s-106-deny-write` est présent sur le nœud ; `/sys/kernel/security/apparmor/profiles` contient une ligne avec le nom `k8s-106-deny-write` (dans n'importe quel mode - `complain` ou `enforce`), c'est-à-dire que le profile est réellement chargé dans le noyau, et pas simplement copié sur le disque. |

<details>
<summary>💡 Indice pour la tâche 1</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` copie le fichier sur le nœud
dans un répertoire temporaire ; déplacez-le de là avec `sudo` vers `/etc/apparmor.d/` (un utilisateur ordinaire
n'a pas les droits d'écriture directement là). Ensuite, `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` compile et charge le profile dans le noyau - sans cette
étape, le fichier sur le disque ne donne aucune protection et n'apparaîtra pas dans
`/sys/kernel/security/apparmor/profiles`.
</details>

---
| **2** | **Passer l'AppArmor profile en enforce** |
| :---: | :--- |
| Ce qu'on fait | Sur le nœud `control-plane`, passez le profile `k8s-106-deny-write`, chargé dans la tâche 1, en mode `enforce`. Le mode d'origine `complain` enregistre les violations, mais n'est pas une protection. Ne supprimez pas le profile et ne changez pas son nom. |
| Critères d'acceptation | Un nœud avec le label `security.cks.io/localhost-profiles-106=true` existe ; `/etc/apparmor.d/k8s-106-deny-write` est disponible ; `/sys/kernel/security/apparmor/profiles` contient la ligne `k8s-106-deny-write (enforce)`. Le bootstrap-baseline propriété du checker (enregistré AVANT la remise du lab, sur une copie transitoire de ce même profile alors qu'il était encore en `complain`) confirme qu'une écriture correspondant au pattern `/work/**` de ce profile passait alors réellement - sans cela, on ne peut pas démontrer que c'est précisément le passage en `enforce` qui a provoqué le refus ultérieur. |

<details>
<summary>💡 Indice pour la tâche 2</summary>

La commande `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` recharge un profil déjà existant - s'il était en `complain` et que le fichier sur disque décrit déjà `enforce`, cette commande suffit. Vérifiez-vous via `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write` - la sortie doit montrer explicitement `(enforce)`. Ne vérifiez pas cela via `aa-status` : cette commande regroupe les profils sous des titres de section (`N profiles are in enforce mode.`) et n'imprime en dessous que les noms nus des profils, SANS le suffixe `(enforce)`/`(complain)` sur chaque ligne - un tel suffixe n'existe que dans `/proc/<pid>/attr/current` et dans le fichier du noyau `/sys/kernel/security/apparmor/profiles`, et non dans la liste des profils d'`aa-status`.

N'utilisez pas `aa-enforce`/`aa-complain` pour ce profil tant que la tâche 9 n'est pas faite :
ces outils Python d'`apparmor-utils`, avant leur travail principal, analysent
(parsent) **tous** les fichiers de `/etc/apparmor.d/`, y compris le `k8s-106-broken-profile` encore cassé
de la tâche 8, et échouent avec une erreur du parser sur un fichier étranger. Modifiez le flag `complain` dans le fichier
du profil directement (`sed`) et rechargez précisément CE fichier via `apparmor_parser -r` -
ce binaire, contrairement à `aa-enforce`, n'analyse que le fichier qui lui est passé.
</details>

---
| **3** | **Localhost AppArmor Pod et blocage de l'écriture** |
| :---: | :--- |
| Ce qu'on fait | Créez le namespace `security-106` et le Pod `apparmor-writer`. Le Pod doit choisir le label du nœud de l'infrastructure, désactiver l'automount du ServiceAccount token et, au niveau du Pod, définir `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. Utilisez `busybox:1.36`, le conteneur `app`, la commande d'attente `sleep 3600` et un `emptyDir` monté dans `/work`. Après le démarrage, confirmez le profile effectif avec la commande `cat /proc/1/attr/current` (si l'interface est disponible), exécutez une opération de lecture autorisée, par exemple `cat /etc/hostname >/dev/null`, puis essayez d'écrire un fichier dans `/work` ; l'opération doit se terminer par un refus. Sur le nœud, consignez l'AppArmor denial pour le profile/process depuis `journalctl -k | grep -i apparmor` ou `dmesg | grep -i apparmor`. |
| Critères d'acceptation | Le Pod est en cours d'exécution, utilise précisément le profile Localhost et le bon nodeSelector ; le profile effectif du processus montre `k8s-106-deny-write` en enforce mode (quand `/proc/.../attr/current` est disponible) ; l'opération de lecture autorisée dans `/work` passe, et le checker écrit independently son propre fichier unique (per-run) dans `/work` et reçoit un refus AppArmor. Dans le kernel journal/audit log, il y a un événement `apparmor="DENIED"` avec ce profile se rapportant précisément à CETTE tentative (par le nom unique du fichier) - cela exclut un false pass dû à un événement denial périmé dans le journal. |

<details>
<summary>💡 Indice pour la tâche 3</summary>

`appArmorProfile` pour un profil de type `Localhost` s'indique via deux champs distincts : `type: Localhost` et `localhostProfile: k8s-106-deny-write` (le nom du profil SANS le chemin `/etc/apparmor.d/`) - c'est le même nom sous lequel le profil a été chargé dans la tâche 1. Si le Pod ne démarre pas (CreateContainerError), vérifiez que le profile est réellement déjà chargé sur le nœud NÉCESSAIRE via le nodeSelector - les profils AppArmor sont node-local, ils ne sont pas transférés automatiquement.
</details>

---
| **4** | **Baseline sûr seccomp RuntimeDefault** |
| :---: | :--- |
| Ce qu'on fait | Créez dans `security-106` le Pod `runtime-default` avec `busybox:1.36` et `sleep 3600`. Au niveau du Pod, indiquez explicitement `securityContext.seccompProfile.type: RuntimeDefault` ; le Pod doit aussi choisir le nœud préparé. Vérifiez dans le conteneur `/proc/1/status` : on attend `Seccomp: 2`. |
| Critères d'acceptation | Le Pod `Running`, dans son securityContext au niveau du Pod `RuntimeDefault` est choisi, et le processus est en seccomp filter mode. |

<details>
<summary>💡 Indice pour la tâche 4</summary>

`Seccomp: 2` dans `/proc/1/status` signifie « filter mode actif » (SECCOMP_MODE_FILTER) - c'est ce que vous devez voir. `Seccomp: 0` signifierait l'absence totale de seccomp filter (`Unconfined`). C'est la tâche la plus simple des cinq de ce groupe - si elle ne passe pas, le problème vient très probablement du nodeSelector, et non du seccompProfile lui-même.
</details>

---
| **5** | **Transférer et utiliser un Localhost seccomp profile custom** |
| :---: | :--- |
| Ce qu'on fait | Le fichier source `cks-106-deny-unshare.json` se trouve uniquement sur la machine de travail, dans `/opt/lab106-fixtures/cks-106-deny-unshare.json`. Déterminez le nœud avec le label `security.cks.io/localhost-profiles-106=true`, créez dessus le répertoire `/var/lib/kubelet/seccomp/profiles/` (s'il n'existe pas encore) et copiez-y le JSON sous le même nom. Créez ensuite le Pod `localhost-seccomp` dans `security-106` sur ce nœud. Au niveau du Pod, indiquez `seccompProfile.type: Localhost` et le chemin relatif `profiles/cks-106-deny-unshare.json` - sans `/var/lib/kubelet/seccomp/`. Le conteneur `app` doit utiliser `busybox:1.36`, recevoir la capability `SYS_ADMIN` et rester en cours d'exécution après la vérification. **Ne présentez pas cette combinaison comme un hardened baseline :** `SYS_ADMIN` reste l'une des capabilities les plus dangereuses, et `allowPrivilegeEscalation: false` ne retire pas les droits déjà accordés. C'est un capability-focused experiment, où la sécurité est démontrée par un seccomp deny concret. |
| Critères d'acceptation | Le JSON profile est transféré et existe sur le nœud au bon chemin ; le Pod avec le bon nodeSelector utilise le profile `Localhost:profiles/cks-106-deny-unshare.json` ; le JSON profile contient `SCMP_ACT_ERRNO`/`errnoRet: 1` pour `unshare` ; dans le conteneur, seul le `SYS_ADMIN` requis pour l'expérience est ajouté. |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Le chemin `profiles/cks-106-deny-unshare.json` est relatif au kubelet seccomp root `/var/lib/kubelet/seccomp/`, c'est-à-dire que le fichier réel sur le nœud doit se trouver à l'adresse `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` - c'est là qu'il faut le copier depuis la machine de travail (par exemple, `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`, puis `sudo mkdir -p` et `sudo mv` sur le nœud). N'écrivez pas dans le manifest le chemin absolu complet - le kubelet ajoutera la racine lui-même. `SYS_ADMIN` est accordé ici PRÉCISÉMENT pour l'expérience (il faut une capability permettant en principe d'appeler `unshare`), et non comme pratique recommandée - ne confondez pas le scénario pédagogique avec un baseline de production.
</details>

---
| **6** | **Démontrer le refus du syscall `unshare(2)`** |
| :---: | :--- |
| Ce qu'on fait | Dans la commande du conteneur `localhost-seccomp`, exécutez `unshare -n true`, enregistrez la confirmation réussie du refus attendu dans `/tmp/unshare-result` comme la ligne `unshare denied by seccomp`, puis maintenez le conteneur avec `sleep 3600`. Une nouvelle commande `kubectl exec ... -- unshare -n true` doit renvoyer un code non nul. Pour un attack-minded negative control, créez un Pod `sysadmin-control` sur le même nœud avec `seccompProfile.type: Unconfined` et la même unique capability `SYS_ADMIN` ; son `unshare -n true` doit se terminer avec succès. Supprimez le control Pod après la vérification. |
| Critères d'acceptation | Le Localhost Pod est en cours d'exécution ; `Seccomp: 2` ; `unshare` est bloqué par le custom profile. Dans le control Pod, le même syscall avec la même capability et sans seccomp filter passe. Cela démontre le kernel behavior, et pas seulement la présence d'un YAML. |

<details>
<summary>💡 Indice pour la tâche 6</summary>

Utilisez précisément `unshare -n true` (unshare network namespace, `CLONE_NEWNET`), et PAS
`unshare -m true`. `-m` (mount namespace) nécessite `CAP_SYS_ADMIN` tout comme `-n`, mais
BusyBox `unshare -m`, après un `unshare(2)` réussi, exécute en plus un SECOND syscall
`mount(2)` indépendant (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`
pour forcer la private propagation - c'est un comportement d'unshare, actif par défaut
si `--propagation unchanged` n'est pas passé explicitement, et même alors `mount()` est tout de même
appelé, simplement avec des flags nuls). Le profil AppArmor par défaut de containerd (`RuntimeDefault`,
que reçoit un Pod sans `securityContext.appArmorProfile` explicite) contient `deny mount,`
SANS aucune condition sur les flags - cette interdiction agit indépendamment des capabilities et du
seccomp. C'est pourquoi `unshare -m true` peut échouer avec `EPERM` à cause d'AppArmor MÊME quand
seccomp ne limite pas du tout `unshare`, ce qui rend un tel probe peu fiable comme preuve
précisément d'un refus de seccomp. `unshare -n` (`CLONE_NEWNET`) n'appelle QUE le syscall
`unshare(2)` lui-même sans aucun `mount()` ultérieur - et `localhost-seccomp` comme
`sysadmin-control` utilisent le même `SYS_ADMIN`, donc la différence de résultat
s'explique sans ambiguïté précisément par le seccomp filter, et non par un effet secondaire d'AppArmor.

L'ordre des commandes est important pour la force probante : exécutez d'abord `unshare -n true` et assurez-vous qu'il échoue avec une erreur (exit code non nul), SEULEMENT ENSUITE écrivez la ligne `unshare denied by seccomp` dans `/tmp/unshare-result` - n'écrivez pas la ligne à l'avance, en « supposant » le résultat. Le negative control (`sysadmin-control`) doit utiliser LA MÊME capability `SYS_ADMIN`, mais `seccompProfile.type: Unconfined` - si vous oubliez d'indiquer `Unconfined` explicitement, le Pod peut recevoir `RuntimeDefault` par défaut (si `seccompDefault` de la tâche 8 est activé) et le test ne montrera pas la différence.
</details>

Les Linux capabilities et le privilege escalation sont des axes différents. `allowPrivilegeEscalation: false`
active `no_new_privs` et interdit d'obtenir des droits **nouveaux** via `execve` (setuid/setgid et
file capabilities), mais ne retire pas `SYS_ADMIN`, déjà ajoutée au bounding/effective set.
Pour un workload ordinaire, utilisez `capabilities.drop: ["ALL"]` et, séparément,
`allowPrivilegeEscalation: false` ; l'expérience ci-dessus n'est volontairement pas un tel baseline.

---
| **7** | **User namespaces : `hostUsers: false` et traduction des UID via `uid_map`** |
| :---: | :--- |
| Ce qu'on fait | Les User namespaces sont GA dans Kubernetes v1.36 (voir le [chapitre 03](../../course/03/fr.md), le [chapitre 18](../../course/18/fr.md) et le Security Delta v1.36). La théorie explique que `hostUsers: false` traduit le root du conteneur en un host UID non privilégié ; ici, il faut le démontrer sur un processus vivant. Créez dans `security-106` un Pod `userns-probe` sur le nœud préparé avec `spec.hostUsers: false`, l'image `busybox:1.36`, la commande `sleep 3600` ; ne définissez pas `runAsUser` au niveau du Pod, afin que le processus démarre en UID 0 **à l'intérieur** du conteneur. Confirmez `id` dans le conteneur (`uid=0`). Déterminez le host PID du processus du conteneur via `crictl inspect` (par analogie avec le lab 112) ou via `kubectl get pod -o jsonpath` + `crictl ps`, puis sur le nœud lisez `/proc/<host PID>/uid_map`. Enregistrez les deux sorties (`id` dans le conteneur et le contenu de `uid_map`) dans `/var/work/tests/artifacts/6/userns.txt`. |
| Critères d'acceptation | Le Pod `Running`, `spec.hostUsers == false`, choisit le nœud préparé ; `id` dans le conteneur montre `uid=0(root)` ; `/proc/<host PID>/uid_map` sur le nœud contient une ligne de la forme `0 <host-uid> <length>`, où `<host-uid>` **n'est pas égal à 0** (le root du conteneur est traduit en un host UID non privilégié) et `<length>` vaut au moins `65536` (la plage standard d'UID par Pod) ; l'artefact contient les deux parties de l'evidence. |

<details>
<summary>💡 Indice pour la tâche 7</summary>

`id` À L'INTÉRIEUR du conteneur affichera `uid=0(root)` indépendamment de `hostUsers` - c'est attendu, le conteneur voit SON propre namespace, où son root est bien l'UID 0 dans ce namespace. La vraie protection ne se voit que DEPUIS L'EXTÉRIEUR : sur le nœud lui-même, dans `/proc/<host PID>/uid_map`, où l'UID 0 dans le conteneur est traduit en un grand UID non privilégié sur l'hôte. Pour trouver le host PID, utilisez `crictl inspect <container-id>` - précisément de là, et non de `kubectl get pod`, qui ne connaît que l'objet Kubernetes, et non le PID au niveau de l'hôte du processus.
</details>

---
| **8** | **`seccompDefault: true` au niveau du kubelet : baseline sans profil explicite** |
| :---: | :--- |
| Ce qu'on fait | Tous les Pod des tâches 4–6 indiquent explicitement `seccompProfile` dans le manifest. En réalité, un développeur peut oublier ce champ - alors, sans node-level baseline, le Pod reçoit `Unconfined`. Sur le nœud, activez `seccompDefault: true` dans `/var/lib/kubelet/config.yaml` et redémarrez le kubelet (`systemctl restart kubelet`). Créez un Pod `no-seccomp-field` dans `security-106` sur le nœud préparé à partir de `busybox:1.36` (`sleep 3600`), **sans indiquer du tout securityContext.seccompProfile**, ni au niveau du Pod ni au niveau du conteneur. Via `/proc/1/status` dans le conteneur, confirmez que le kubelet a appliqué `RuntimeDefault` automatiquement (`Seccomp: 2`), et n'a pas laissé `Unconfined` (`Seccomp: 0`). |
| Critères d'acceptation | La configuration effective (appliquée) du kubelet - via `/api/v1/nodes/<node>/proxy/configz`, champ `.kubeletconfig.seccompDefault` - est égale à `true` ; `systemctl is-active kubelet` renvoie `active`, le nœud reste `Ready` ; le Pod `no-seccomp-field` n'a pas de `seccompProfile` à aucun niveau de sa spécification ; `/proc/1/status` dans le conteneur montre `Seccomp: 2`. |

<details>
<summary>💡 Indice pour la tâche 8</summary>

L'exigence clé est que le Pod ne mentionne RÉELLEMENT pas du tout `seccompProfile`, ni au niveau du Pod ni au niveau du conteneur. Si vous copiez le manifest de la tâche 3 et oubliez simplement de supprimer ce champ - le test ne démontrera pas ce qu'il doit : que c'est précisément le `seccompDefault` au niveau du nœud (et non l'indication explicite dans le manifest) qui a assuré `Seccomp: 2`.

La vérification s'appuie sur la configuration RÉELLEMENT APPLIQUÉE du kubelet, et non sur le texte du fichier sur
le disque : `curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`.
Un simple grep sur `/var/lib/kubelet/config.yaml` ne démontre pas que ce fichier-là est
bien utilisé par le kubelet en cours d'exécution - un flag de ligne de commande ou un drop-in pourraient redéfinir la
valeur sans changer le fichier lui-même. Redémarrez obligatoirement le kubelet après avoir modifié le
fichier - la configuration n'est pas reprise à la volée.
</details>

---
| **9** | **Débogage et reconstruction d'un profil AppArmor cassé (`apparmor_parser -r -v`)** |
| :---: | :--- |
| Ce qu'on fait | Sur le disque se trouve déjà `/etc/apparmor.d/k8s-106-broken-profile` - un profil avec une erreur de syntaxe, qui **n'a jamais été chargé** dans le noyau. Trouvez l'erreur par vous-même via `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile` (`-Q`/`--skip-kernel-load` : exécute entièrement la vérification/compilation du profil, mais ne le charge pas dans le noyau) ou `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile` (`-d`/`--debug`, une seule fois - uniquement la vérification de la correction syntaxique), corrigez le fichier et chargez le profil dans le noyau via `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile`. Confirmez le chargement via `aa-status \| grep k8s-106-broken-profile`. Enregistrez la sortie de l'erreur **avant** la correction et la confirmation du chargement **après** dans `/var/work/tests/artifacts/8/apparmor-debug.txt`. |
| Critères d'acceptation | `apparmor-debug.txt` contient le texte de l'erreur du parser (par exemple, `syntax error`) de la tentative **avant** la correction ; le bootstrap-baseline propriété du checker (enregistré AVANT la remise du lab, indépendamment de votre artifact) confirme indépendamment que le profil d'origine contenait réellement une syntax error ; `/etc/apparmor.d/k8s-106-broken-profile` sur le disque ne contient plus l'erreur de syntaxe d'origine ; `aa-status` montre `k8s-106-broken-profile` parmi les profils chargés (dans n'importe quel mode - `enforce` ou `complain`) ; un nouvel `apparmor_parser -Q` sur le fichier corrigé se termine sans erreur. |

<details>
<summary>💡 Indice pour la tâche 9</summary>

`apparmor_parser -p` (`--preprocess`) N'EST PAS un mode safe dry-run/syntax-check - c'est
simplement un preprocessing : il développe les directives `#include` et imprime le
profil obtenu sur stdout, sans garantir à lui seul l'absence d'effets de bord et sans être
destiné précisément à vérifier la syntaxe. Utilisez `-Q`/`--skip-kernel-load`
(exécute la compilation/vérification complète, mais ne charge pas dans le noyau) ou `-d`/`--debug`
(une seule fois - uniquement la vérification de la correction syntaxique) pour trouver EN TOUTE SÉCURITÉ
l'erreur de syntaxe sans effets de bord. Ce n'est qu'après avoir corrigé le fichier que vous utilisez
`-r` (reload/load) pour le chargement réel dans le noyau. La syntaxe AppArmor exige une virgule comme
séparateur de règles à l'intérieur du bloc - étudiez la sortie du parser pour trouver quel caractère
manque et où exactement.

Exécutez `apparmor_parser` via `sudo`, même avec `-Q`/`-d` : sur le nœud du lab (apparmor 3.0.4,
Ubuntu), sans privilèges le parser à chaque lancement tente de configurer la policy cache dans
`/var/cache/apparmor` et échoue avec "Failed setting up policy cache: Permission denied" AVANT
la vérification de la syntaxe - vous obtiendrez une erreur trompeuse de droits au lieu de la vraie
erreur de syntaxe du profil. Cela a été vérifié sur le nœud lui-même (y compris sur un profil délibérément cassé).
Si vous avez besoin d'un lancement sans `sudo`, ajoutez `-K` (`--skip-cache` : pas de caching) -
`apparmor_parser -Q -K` sans privilèges arrive jusqu'à l'analyse du profil et montre la
vraie erreur. Le chargement et le reload (`-r`) nécessitent dans tous les cas des privilèges.
</details>

## Vérification

Sur la machine de travail, exécutez :

```bash
check_result
```

La vérification contient Init et neuf tests indépendants. Elle lit le state du Pod via l'API, vérifie le
profile sur le nœud par SSH et exécute des scénarios négatifs contrôlés. Si le Localhost
Pod n'est pas créé, regardez d'abord `kubectl describe pod` : la cause habituelle est un chemin absolu
au lieu d'un chemin relatif ou l'affectation du Pod à un nœud sans le profile.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=106 make delete_cks_task
```
