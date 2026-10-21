[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 105 - System Hardening de l'OS et sécurité du Docker daemon

## Objectif

Dans ce lab CKS, vous allez réduire la surface d'attaque de deux hôtes Linux. Sur le
control-plane Kubernetes, il faut désactiver les services superflus, fermer un port ouvert, configurer le firewall,
protéger le kubeconfig et interdire le root login direct par SSH. Sur un `docker-host` distinct,
il faut éliminer trois réglages dangereux du Docker daemon : la TCP API sans TLS, l'accès à
`docker.sock` via le groupe `docker` et l'accès de l'utilisateur `developer` à ce socket.

Cet environnement de lab a été créé volontairement non sécurisé. Ne transposez pas la configuration d'origine
en production : la Docker API sur TCP/2375 sans TLS donne un accès root distant à quiconque peut
se connecter au port.

## Vérifiez-vous avant de commencer

<details>
<summary>1. En quoi `systemctl disable` diffère-t-il de `systemctl stop`, et pourquoi la tâche 1 nécessite-t-elle les deux ?</summary>

`stop` arrête le processus déjà lancé tout de suite, mais n'affecte pas le démarrage automatique au prochain démarrage du système. `disable` retire le service du démarrage automatique (l'unit-file n'est plus lié au target), mais n'arrête pas le processus déjà en cours. Pour fermer complètement la surface d'attaque, il faut les deux - sinon le service continuera de fonctionner maintenant, ou redémarrera après un reboot.
</details>

<details>
<summary>2. Pourquoi une TCP Docker API sans TLS (`-H tcp://0.0.0.0:2375`) équivaut-elle à un accès root distant ?</summary>

Le Docker daemon fonctionne avec les droits root, et son API n'a pas de built-in authentication sans TLS client certificates. Quiconque peut se connecter à ce port par le réseau peut lancer un container arbitraire avec `--privileged` et la host filesystem montée - et obtenir un contrôle total de l'hôte, en contournant SSH et tout autre mécanisme de contrôle d'accès.
</details>

<details>
<summary>3. Pourquoi `chmod 600` pour le kubeconfig est-il important, même si le fichier n'est de toute façon accessible qu'à root via le système de fichiers ?</summary>

`/etc/kubernetes/admin.conf` contient un client certificate avec les droits `cluster-admin` - si le mode du fichier est trop large (par exemple, `644`, lisible par tous), N'IMPORTE QUEL utilisateur de ce nœud, même sans sudo, peut lire la credential et obtenir un accès administratif complet au cluster à distance, sans avoir besoin d'une escalade de privilèges sur le nœud lui-même.
</details>

<details>
<summary>4. Pourquoi un core dump d'un processus peut-il faire fuiter un secret, même si le secret lui-même n'a jamais été écrit sur le disque ?</summary>

Un core dump est une image de la mémoire du processus au moment du crash, qui **peut** inclure des valeurs déchiffrées de variables, des clés privées et des tokens conservés en clair. Il n'est pas garanti que ce soit toute la mémoire du processus : l'ensemble des mappings dépend de `/proc/<pid>/coredump_filter`, et certaines zones peuvent être exclues, par exemple via `MADV_DONTDUMP`. C'est pourquoi, même si l'application n'écrit jamais explicitement le secret dans un fichier, un crash dump peut enregistrer sur le disque, dans un fichier lisible, les secrets présents dans les mappings inclus.
</details>

## Lien avec le cours

- [Chapitre 14. Minimisation du footprint de l'OS de l'hôte et sécurité du runtime-daemon](../../course/14/fr.md)
- [Chapitre 15. Least-privilege sur l'hôte et minimisation de l'accès externe](../../course/15/fr.md)
- [CKA : systemd, services et Linux](../../../cka/course/00-5-linux/fr.md)
- [CKA : conteneurs et runtime](../../../cka/course/00-4-containers/fr.md)

## Infrastructure

L'environnement est déployé via Terragrunt dans AWS `eu-central-1` :

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.10.0.0/16` avec deux sous-réseaux publics |
| `ssh-keys` | clé SSH pour les connexions internes |
| `k8s-1` | cluster kubeadm mono-nœud avec Kubernetes `1.36.0`, containerd, Calico ; c'est le control-plane cible |
| `docker-host` | un Ubuntu 22.04 distinct avec Docker et une configuration volontairement non sécurisée |
| `worker` | machine de travail avec `kubectl`, la configuration SSH et `check_result` |

`worker` a un accès SSH au control-plane par son Kubernetes node name et à un hôte
distinct par le nom `docker-host`. Docker n'est pas le runtime du cluster Kubernetes : sa
configuration de la tâche 6 est isolée sur `docker-host`.

## Déploiement

```bash
TASK=105 make run_cks_task
```

Connectez-vous au `worker` (le contexte kubectl est déjà configuré), regardez le nom du nœud
control-plane et entrez sur les hôtes :

```bash
kubectl get no
ssh <nom-du-nœud-de-la-sortie>
ssh docker-host
```

Commandes utiles :

```bash
time_left
check_result
```

Enregistrez les artefacts de vérification dans `/var/work/tests/artifacts/<numéro>/`. Il n'est pas nécessaire de créer
de manifests Kubernetes pour ce lab.

## Tâches

---
| **1** | **Désactiver un service superflu** |
| :---: | :--- |
| Ce qu'on fait | Sur le control-plane, désactivez et arrêtez `cks-lab105-unused.service`. Le service n'est pas nécessaire au fonctionnement de Kubernetes et ne doit pas démarrer après un reboot. |
| Critères d'acceptation | `systemctl is-enabled cks-lab105-unused.service` renvoie `disabled`, `systemctl is-active` - `inactive` ; dans `/var/work/tests/artifacts/1/service.txt` se trouve la ligne `disabled inactive`. |

<details>
<summary>💡 Indice pour la tâche 1</summary>

Ordre des commandes : `sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - les deux étapes sont nécessaires, aucune ne remplace l'autre (voir la question 1 de la section d'auto-vérification ci-dessus). L'artefact doit contenir précisément la ligne « disabled inactive » (dans cet ordre, séparées par un espace) - vérifiez le format avant d'enregistrer.
</details>

---
| **2** | **Fermer un port ouvert inutile** |
| :---: | :--- |
| Ce qu'on fait | Sur le control-plane, éliminez le listener TCP/8080 créé par `cks-lab105-port.service`. Désactivez et arrêtez le service (les deux actions sont obligatoires - voir la question 1 de la section d'auto-vérification) ; il n'est nécessaire ni au control-plane, ni au kubelet. |
| Critères d'acceptation | `ss -ltn` n'affiche pas TCP/8080 ; `systemctl is-enabled cks-lab105-port.service` renvoie `disabled`, `systemctl is-active` - `inactive` ; `/var/work/tests/artifacts/2/service.txt` contient la ligne `disabled inactive` ; `/var/work/tests/artifacts/2/port-8080.txt` contient `tcp/8080: closed`. |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Trouvez d'abord quel processus tient le port (`sudo ss -ltnp | grep 8080`), pour vous assurer que c'est bien `cks-lab105-port.service` et pas autre chose. Fermer le port via le firewall (tâche 3) ne suffit pas pour cette tâche - le test vérifie que le listener LUI-MÊME est absent, et pas simplement bloqué de l'extérieur.
</details>

---
| **3** | **Limiter le trafic entrant avec le firewall** |
| :---: | :--- |
| Ce qu'on fait | • Avant d'activer UFW, notez le rôle du nœud, la worker source IP, la node InternalIP et le `spec.podCIDR`.<br/>• **Baseline obligatoire avant le firewall :** enregistrez un baseline-probe de TCP/10250 (kubelet HTTPS endpoint) depuis le worker - un `curl` avec des `CURL_EXIT`/`HTTPCODE` réels, démontrant l'accessibilité réseau du port (n'importe quel 1xx-5xx, y compris 401/403, compte comme accessibilité - l'API kubelet a réellement répondu). Sans cette étape, le « bloqué » après le hardening ne peut pas être distingué d'une panne étrangère (security group, routing) qui bloquait le port avant même UFW. En plus de votre enregistrement, le checker le compare de façon indépendante à son propre bootstrap-baseline, enregistré AVANT la remise du lab dans le répertoire protégé `/var/lib/cks-lab105-checker` (`0711 root:root`, séparé de `/var/work/tests`, qui est par défaut inscriptible par tous).<br/>• Topologie : un control-plane mono-nœud + workload node. Il faut exactement cinq règles : loopback, SSH recovery depuis le worker, API `6443/tcp` depuis le worker, depuis le nœud lui-même et depuis le Pod CIDR. etcd/scheduler/controller-manager utilisent des flows locaux, il n'y a pas de flows CNI/kubelet inter-nœuds dans cette topologie.<br/>• Gérez le firewall uniquement avec la commande `ufw` (allow/deny/reject/limit/route, puis enable/reload). Ne modifiez pas à la main `/etc/ufw/before*.rules`, `after*.rules`, `user.rules`, `user6.rules` : les framework-files (before/after) sont comparés par hash au bootstrap-baseline, et `user.rules`/`user6.rules` (où ufw écrit vos règles) sont vérifiés via l'état réel du noyau (`ufw show user-rules`), et pas seulement via le fichier.<br/>• Ajoutez les source-scoped allow rules avant `ufw default deny incoming`. N'utilisez pas de `ALLOW Anywhere` larges et n'ajoutez aucune autre règle en plus de ces cinq (loopback + 4 source-scoped), y compris deny/reject/route.<br/>• Activez UFW et enregistrez dans `/var/work/tests/artifacts/3/` : `ufw status`, `ufw show added` (représentation normalisée des règles ajoutées - pas nécessairement dans la forme/l'ordre d'origine des commandes), le preflight (y compris le baseline TCP/10250) et les commandes de recovery.<br/>• **Retest obligatoire après `ufw reload` :** exécutez `sudo ufw reload` et répétez TOUTES les mêmes vérifications (readyz, node Ready, calico-node Ready, Pod DNS, Pod→API, worker→kubelet:10250 deny, effective UFW rule count). Une règle qui ne fonctionne qu'en mémoire juste après enable, mais ne survit pas au reload, n'est pas considérée comme une solution correcte. |
| Critères d'acceptation | • **Baseline TCP/10250 :** le bootstrap-baseline propriété du checker (enregistré avant la remise du lab dans `/var/lib/cks-lab105-checker`, répertoire `0711 root:root` hors de `/var/work/tests`, fichier `0444 root:root`) confirme l'accessibilité initiale de TCP/10250 ; votre propre baseline-probe avant UFW est enregistré et montre une accessibilité réseau réelle (`CURL_EXIT=0`, HTTP `1xx-5xx`). Si le port est déjà inaccessible au baseline, le résultat de la tâche est `inconclusive`, et non PASS.<br/>• **UFW et ensemble exact de règles :** UFW active, default-deny ; `ufw show added` contient EXACTEMENT cinq lignes : loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`, sans une seule règle superflue de N'IMPORTE QUELLE action (`allow`/`deny`/`reject`/`limit`/`route`) et sans qu'il en manque une des cinq.<br/>• **Framework-files :** le hash de `/etc/ufw/before*.rules`/`after*.rules` ne diffère pas du bootstrap-baseline propriété du checker (les règles sont ajoutées uniquement via `ufw`, les framework-files ne sont pas modifiés à la main).<br/>• **État réel du noyau :** `sudo ufw show user-rules` (les chains réelles `ufw-user-*` via `iptables -L`) coïncide sémantiquement avec les cinq règles attendues - on vérifie non seulement la quantité, mais le source/interface/protocol/port de CHAQUE règle, aussi bien après `enable` qu'après `reload`. `ufw6-user-input` reste avec EXACTEMENT une ligne - la version v6 du loopback ACCEPT (`ufw allow in on lo` crée à la fois une règle v4 et une règle v6, puisque c'est une règle par interface sans IP explicite ; pas « complètement vide »). Cela détecte la modification directe de `user.rules`/`user6.rules` sans tuple metadata (qui ne se reflète ni dans `ufw show added` ni dans le hash de `before/after`) et l'élargissement d'une règle déjà déclarée (par exemple, `node_ip`→`6443/tcp`, discrètement remplacée par `node_ip`→`any`) sans changer le nombre de lignes.<br/>• **Santé du cluster :** `/readyz=ok` ; le nœud attendu et tous les Pod `calico-node` restent `Ready` ; `health-probe` reste Ready, résout le DNS et atteint le Kubernetes Service.<br/>• **Blocage du kubelet :** après UFW, le worker n'atteint pas le kubelet `10250` (`HTTPCODE=000`, transport deny) - précisément comme une régression par rapport au baseline démontré.<br/>• **Retest après reload :** **toutes les mêmes vérifications passent de nouveau après un `sudo ufw reload` explicite** : readyz/node/calico-node/DNS/Pod→API restent sains, worker→kubelet:10250 reste bloqué par le même contrat de deny qu'avant le reload, et le nombre réel de règles dans le noyau coïncide de nouveau avec le déclaratif.<br/>• **Artefacts :** l'artefact contient les commandes de recovery (`ufw disable`, vérification, correction et réactivation). |

<details>
<summary>💡 Indice pour la tâche 3</summary>

L'erreur la plus dangereuse ici est d'exécuter `ufw enable` (default-deny) AVANT d'avoir ajouté l'allow-règle pour SSH depuis la worker IP. L'ordre doit être : d'abord tous les `ufw allow from <IP> to any port <port>` nécessaires, ensuite seulement `ufw --force enable`. Gardez la session SSH actuelle ouverte pendant tout le travail avec le firewall - si vous perdez l'accès, une seconde session de recovery ne se connectera pas (voir l'avertissement ci-dessous). N'oubliez pas le baseline-probe de TCP/10250 AVANT d'activer UFW - sans lui, le « bloqué » après le hardening ne démontre rien : le port pouvait être inaccessible auparavant pour une tout autre raison (par exemple, un AWS security group), et UFW n'y serait alors pour rien ; de plus, le checker a son propre baseline, enregistré avant la remise du lab dans un répertoire protégé distinct, il ne sera donc pas possible de falsifier cet enregistrement après coup. Vérifiez l'allow-set strictement via `sudo ufw show added` (et pas seulement `ufw status`) - il doit y avoir EXACTEMENT cinq lignes, aucune en trop (aucun `ALLOW Anywhere` large, aucun port supplémentaire, et cela vaut pour N'IMPORTE QUELLE action - `allow`, `deny`, `reject`, `limit`, `route`, pas seulement les nouvelles allow) et aucune manquante. Gérez le firewall uniquement via la commande `ufw` - ne modifiez pas à la main `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules` : les framework-files sont comparés par hash, et l'état réel de `user.rules`/`user6.rules` est vérifié par le checker directement via les vraies règles iptables dans les chains `ufw-user-*` (`sudo ufw show user-rules`), de sorte que même une modification de `user.rules` sans les bons commentaires `### tuple ###` sera détectée après `ufw reload`. Et n'oubliez pas d'exécuter `sudo ufw reload` à la fin et de répéter toutes les vérifications - une règle qui ne fonctionne que juste après `enable`, mais ne survit pas à `reload`, n'est pas comptée.
</details>

> **Recovery d'abord.** Gardez la session SSH actuelle ouverte jusqu'à la vérification complète. Si l'API
> disparaît, depuis elle exécutez `sudo ufw disable`, corrigez les allow rules et ce n'est qu'ensuite que vous
> réactivez le firewall. Si le SSH est déjà perdu, utilisez la console/recovery channel du fournisseur ;
> n'essayez pas de « guérir » la situation avec un `allow from any` large.
>
> **Limite d'applicabilité.** Cet UFW allowlist n'est conçu que pour un fixture mono-nœud.
> On ne peut pas le transposer littéralement dans un cluster multi-node : avant le default-deny, il faut inventorier
> les flux du kubelet et inter-nœuds, le CNI overlay, BGP/VXLAN/WireGuard, LoadBalancer/NodePort et
> le provider firewall/security groups pour la topologie concrète.
>
> **Lab-specific exception : UFW sur un nœud Calico.** La documentation officielle de Calico sur les
> prérequis recommande explicitement de désactiver firewalld et les autres iptables managers sur
> les nœuds Calico, car ils peuvent entrer en conflit avec les règles que Calico pose lui-même.
> UFW est un iptables/nftables manager au même titre. Ce lab conserve volontairement UFW sur le
> control-plane pour s'entraîner au host firewall hardening (une compétence distincte au programme de l'examen
> CKS), et non comme une façon recommandée de combiner Calico avec un host firewall en production - pour
> cela Calico propose son propre `HostEndpoint`/`GlobalNetworkPolicy`. C'est précisément pourquoi la tâche
> exige explicitement une séquence contrôlée baseline → `ufw enable` → retest avec
> la vérification que `calico-node` et toute la connectivité Kubernetes restent en bon état (voir
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`).

---
| **4** | **Corriger les droits du kubeconfig** |
| :---: | :--- |
| Ce qu'on fait | Sur le control-plane, protégez `/etc/kubernetes/admin.conf`, qui contient la credential de cluster-admin : le propriétaire et le groupe doivent être `root:root`, le mode - `600`. |
| Critères d'acceptation | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` renvoie `root root 600` ; la même valeur est enregistrée dans `/var/work/tests/artifacts/4/admin-conf.txt`. |

<details>
<summary>💡 Indice pour la tâche 4</summary>

Une seule commande résout tout : `sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`. Vérifiez-vous juste après - si vous utilisez vous-même ce fichier en tant qu'utilisateur `ubuntu` via `KUBECONFIG=/etc/kubernetes/admin.conf`, l'accès en lecture disparaîtra, et c'est ATTENDU - utilisez un kubeconfig distinct pour le travail quotidien.
</details>

---
| **5** | **Interdire le root login par SSH** |
| :---: | :--- |
| Ce qu'on fait | Sur le control-plane, définissez `PermitRootLogin no` dans `/etc/ssh/sshd_config`, vérifiez la syntaxe via `sshd -t` et rechargez SSH en toute sécurité. Vérifiez la valeur effective précisément pour une connexion root avec la commande `sshd -T -C "user=root,addr=<votre IP>,laddr=<IP du nœud>,lport=22"`, et pas simplement `sshd -T` sans connection context. |
| Critères d'acceptation | La valeur effective de `permitrootlogin` pour le connection context de root est `no` ; `/var/work/tests/artifacts/5/sshd.txt` contient `PermitRootLogin no`. |

<details>
<summary>💡 Indice pour la tâche 5</summary>

`sshd -T` montre la configuration EFFECTIVE, mais SANS connection context (`-C`) les blocs `Match` (`Match User`/`Match Address`/`Match Group` et similaires) ne sont pas appliqués du tout - la man-page de `sshd(8)` dit explicitement que les règles `Match` s'appliquent en test mode "only when the connection parameters are supplied via one or more `-C` options". C'est pourquoi `sshd -T` sans `-C` peut afficher `permitrootlogin no` du bloc principal de la configuration, bien qu'un bloc `Match` plus spécifique (par exemple, `Match Address <IP de l'administrateur>` ou `Match User root`) autorise le root login précisément pour la connexion réelle. Vérifiez via `sshd -T -C "user=root,addr=<IP>,laddr=<IP du nœud>,lport=22"` - cela simule une connexion root entrante RÉELLE et force `sshd` à appliquer tous les blocs `Match` correspondants avant d'afficher la valeur finale. Gardez TOUJOURS la session SSH actuelle ouverte avant `systemctl reload sshd` et vérifiez depuis une nouvelle session - pas depuis celle qui était déjà authentifiée avant le changement.
</details>

---
| **6** | **Fermer l'accès non sécurisé au Docker daemon sur `docker-host`** |
| :---: | :--- |
| Ce qu'on fait | • Sur le `docker-host` distinct, cessez de publier la Docker API sur TCP/2375 : retirez `-H tcp://...` du systemd override de lab, mais conservez l'accès uniquement via le unix-socket.<br/>• Configurez `/var/run/docker.sock` comme `root:root` avec le mode `660` ; pour que cela persiste après un restart, définissez-le via un override de `docker.socket`.<br/>• Retirez `developer` du groupe `docker`.<br/>• Après les modifications, exécutez obligatoirement `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` - cela démontre que les réglages survivent au redémarrage du daemon, et ne coïncident pas simplement temporairement avec l'état attendu.<br/>• Après le restart, confirmez que Docker fonctionne réellement (`sudo docker version`), et n'est pas simplement arrêté. |
| Critères d'acceptation | • **Docker fonctionne après le restart :** après `daemon-reload` + restart, `docker.service` et `docker.socket` sont à l'état `active`, et `sudo docker version`/`sudo docker info` se terminent avec succès (positive control - Docker fonctionne réellement, il n'est pas simplement « éteint, et donc 2375 est fermé »).<br/>• **Pas de TCP API :** il n'y a pas de listener sur TCP/2375. Après le restart, la Docker API n'a aucun TCP listener sur aucun port : le `docker.service` effective ne contient pas de TCP `-H/--host`, et `docker.socket` ne contient pas de TCP `ListenStream` ; le seul API endpoint est le Unix socket `/var/run/docker.sock`.<br/>• **Socket :** `stat -c '%U %G %a' /var/run/docker.sock` renvoie `root root 660` ; l'override persistant de `docker.service`/`docker.socket` (via `systemctl cat`) ne contient pas `-H tcp://` et définit `SocketGroup=root`/`SocketMode=0660`.<br/>• **Utilisateur `developer` :** n'appartient pas au groupe `docker`, et `sudo -u developer docker ps` se termine par une erreur d'accès.<br/>• **Artefacts :** créez `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` avec les lignes `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

<details>
<summary>💡 Indice pour la tâche 6</summary>

L'appartenance au groupe `docker` est de fait équivalente à root - tout processus ayant accès à `docker.sock` peut monter le système de fichiers de l'hôte via un container `--privileged`. Pour vous assurer que `developer` a été retiré du groupe, il ne suffit pas de vérifier `groups developer` - les changements d'appartenance à un groupe s'appliquent aux NOUVELLES sessions de login ; vérifiez précisément via `sudo -u developer docker ps` dans une commande fraîche, pas dans une session de `developer` déjà ouverte. Ne vous arrêtez pas à la première exécution réussie de la vérification - exécutez `daemon-reload` et `restart` des deux unit (`docker.socket`, `docker.service`) et répétez les vérifications DE NOUVEAU : sans cette étape, on peut réussir la tâche par hasard en arrêtant simplement temporairement Docker (alors 2375 est fermé non pas parce que `-H tcp://` a été retiré, mais parce que le daemon ne fonctionne pas du tout) - assurez-vous aussi que `sudo docker version` fonctionne après le restart, cela démontre que Docker fonctionne réellement, et n'est pas simplement « éteint ».
</details>

---
| **7** | **Interdire le chargement d'un module du noyau inutilisé (`modprobe` blacklist)** |
| :---: | :--- |
| Ce qu'on fait | • Sur le control-plane, le module `sctp` est chargé, mais n'est nécessaire ni à kubeadm, ni à containerd, ni à Calico dans ce lab. Essayez de le décharger (`sudo modprobe -r sctp`).<br/>• **Le déchargement peut ne pas fonctionner sur un cluster déjà actif, et ce n'est pas une erreur :** les modules de protocole du noyau reçoivent une référence persistante par network-namespace pour chaque netns existant au moment de leur chargement, et sur ce nœud des Pods fonctionnent déjà (calico, coredns, etc.) ; les arrêter ne fait pas partie de la tâche.<br/>• Interdisez le rechargement via `/etc/modprobe.d/60-cks-sctp.conf` avec les directives `blacklist sctp` et `install sctp /bin/true`.<br/>• Limites du threat model : les deux directives agissent au niveau de `modprobe` (alias resolution et dependency loading) - ce n'est pas une protection absolue du noyau. `insmod` insère le module directement via une kernel syscall et ne lit pas `modprobe.d`, et `modprobe --ignore-install` peut contourner l'override `install` avec l'accès au niveau de l'hôte approprié. Pour le propriétaire root du nœud, c'est attendu : le but est d'éliminer le chemin de chargement habituel (`modprobe sctp`, autochargement par alias lors de l'accès à un protocol), et non de se protéger d'un utilisateur qui a déjà root sur le nœud.<br/>• Confirmez que `modprobe --show-config` montre l'override effectif et qu'un `modprobe sctp` direct ne change pas l'état du module. |
| Critères d'acceptation | • **Fichier :** `/etc/modprobe.d/60-cks-sctp.conf` contient les deux lignes `blacklist sctp` et `install sctp /bin/true`.<br/>• **Config effective :** `modprobe --show-config \| grep sctp` affiche `install sctp /bin/true`.<br/>• **État du module :** un nouveau `modprobe sctp` direct ne change pas l'état du module (il était chargé - il reste chargé, il n'était pas chargé - il reste non chargé).<br/>• **Artefact :** `/var/work/tests/artifacts/7/sctp.txt` contient la ligne `lsmod: absent` OU `lsmod: present` (l'une des deux - l'état actuel réel) et la ligne `install sctp /bin/true`. |

<details>
<summary>💡 Indice pour la tâche 7</summary>

`blacklist sctp` seule ne bloque pas tout - elle empêche l'AUTOCHARGEMENT par alias resolution, mais un `modprobe sctp` direct fonctionnera quand même sans l'override `install`. Les deux lignes sont nécessaires : `blacklist` pour l'autochargement, `install sctp /bin/true` pour l'appel explicite à `modprobe sctp` (remplace la commande de chargement par un no-op). Essayez `sudo modprobe -r sctp` pour décharger un module déjà chargé, mais si vous obtenez `FATAL: Module sctp is in use` avec un `/sys/module/sctp/holders` vide - c'est attendu sur un cluster actif (per-netns pinning des Pods déjà lancés) et n'empêche pas de réussir la tâche ; la config empêche tout de même les chargements FUTURS, ce qui est vérifié.
</details>

---
| **8** | **`protectKernelDefaults` et sysctl sûrs pour le kubelet** |
| :---: | :--- |
| Ce qu'on fait | • Sur le control-plane, `kernel.unprivileged_bpf_disabled = 0` actuellement - les processus non privilégiés peuvent charger des programmes eBPF, ce qui élargit la kernel attack surface. Corrigez cela.<br/>• Ajoutez `vm.overcommit_memory = 1` (recommandation typique pour la stabilité de kubelet/containerd sous memory pressure).<br/>• Définissez les deux paramètres via `/etc/sysctl.d/99-kubernetes.conf`, puis appliquez `sudo sysctl --system`.<br/>• Activez `protectKernelDefaults: true` dans `/var/lib/kubelet/config.yaml` et redémarrez le kubelet.<br/>• **L'ordre est important :** avec `true`, le kubelet vérifie au démarrage que les kernel/cgroup parameters actuels correspondent aux defaults attendus et **ne démarre pas** s'ils ne correspondent pas - c'est pourquoi les sysctl doivent être appliqués **avant** le redémarrage du kubelet, et non après. |
| Critères d'acceptation | • **Valeurs live :** `sysctl kernel.unprivileged_bpf_disabled` renvoie `1` ; `sysctl vm.overcommit_memory` renvoie `1`.<br/>• **Configuration persistante :** `/etc/sysctl.d/99-kubernetes.conf` contient les deux paramètres comme lignes actives (`kernel.unprivileged_bpf_disabled = 1`, `vm.overcommit_memory = 1`) ; un commentaire, `= 1 # comment` ou un `sysctl -w` temporaire ne comptent pas.<br/>• **kubelet :** `/var/lib/kubelet/config.yaml` contient `protectKernelDefaults: true`.<br/>• **État après le redémarrage :** `systemctl is-active kubelet` renvoie `active`, et le nœud reste `Ready`. |

<details>
<summary>💡 Indice pour la tâche 8</summary>

L'ordre ici est critique et volontairement souligné dans la description de la tâche : d'abord `sysctl --system` (appliquer les valeurs), SEULEMENT ENSUITE activer `protectKernelDefaults: true` et redémarrer le kubelet. Si l'on fait dans l'ordre inverse, le kubelet au démarrage détectera un écart entre les kernel parameters et ses attentes et refusera de démarrer - le nœud restera NotReady, et vous ne pourrez pas comprendre la cause sans lire les logs du kubelet (`journalctl -u kubelet`). La vérification s'appuie sur la configuration RÉELLEMENT EN VIGUEUR du kubelet via `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"`, et non sur le texte de `config.yaml` - si la ligne du fichier est commentée ou contient une faute de frappe, `grep` pourrait quand même la trouver, bien que le kubelet continue de fonctionner avec l'ancienne valeur par défaut. Après la modification du fichier, redémarrez obligatoirement le kubelet et vérifiez précisément via `configz`.
</details>

---
| **9** | **Trouver et neutraliser un binaire SUID superflu** |
| :---: | :--- |
| Ce qu'on fait | • Sur le control-plane, exécutez `find / -xdev -perm -4000 -type f 2>/dev/null` et trouvez parmi les résultats `/usr/local/bin/cks-lab105-suid-tool` - un binaire de lab, créé spécialement avec le bit SUID et qui n'est nécessaire à aucun composant Kubernetes sur ce nœud.<br/>• Enregistrez la liste complète des fichiers SUID trouvés **avant** la correction dans `/var/work/tests/artifacts/9/suid-before.txt`.<br/>• Retirez du binaire le bit SUID (`chmod u-s`).<br/>• Enregistrez le mode de `cks-lab105-suid-tool` **après** la correction dans `/var/work/tests/artifacts/9/suid-after.txt`.<br/>• Ne touchez pas aux binaires SUID système (`passwd`, `sudo`, `mount` et similaires) : leur suppression casse le fonctionnement normal de l'OS et n'entre pas dans le cadre de la tâche. |
| Critères d'acceptation | • **Avant la correction :** `suid-before.txt` contient le chemin `/usr/local/bin/cks-lab105-suid-tool` parmi les fichiers SUID trouvés.<br/>• **Après la correction :** `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` renvoie `755` (sans le bit SUID `4`) ; `suid-after.txt` contient `755`.<br/>• **Binaires système :** les binaires SUID standard (par exemple, `/usr/bin/sudo` ou `/usr/bin/passwd`) conservent le bit SUID, intacts. |

<details>
<summary>💡 Indice pour la tâche 9</summary>

`chmod u-s` retire précisément le bit SUID, sans toucher aux autres droits (contrairement à `chmod 755`, qui écrasera aussi tous les autres bits de droits - dans ce cas, le résultat coïncide, mais `u-s` est plus sûr comme habitude générale). N'exécutez pas `find / -perm -4000` sans `-xdev` sauf nécessité absolue - sans lui, la commande scannera les systèmes de fichiers réseau/virtuels montés et peut s'exécuter très longtemps ou se bloquer. La vérification compare l'ensemble actuel des binaires SUID système avec le baseline enregistré AVANT le début du lab - il est interdit de toucher à tout autre binaire SUID système (pas seulement `sudo`/`passwd`), et remettre simplement le SUID sur `sudo` ne servira à rien si vous l'avez accidentellement (ou volontairement) retiré à autre chose. Les chemins à l'intérieur de `/var/lib/containerd` (couches de container image via overlayfs) ne sont pris en compte ni dans le baseline ni dans la vérification - ce ne sont pas des fichiers de l'hôte, et leur ensemble change naturellement lors du pull/extract d'images indépendamment de vous.
</details>

---
| **10** | **Désactiver les core dumps et protéger les processus SUID contre la capture d'un dump mémoire** |
| :---: | :--- |
| Ce qu'on fait | • Un core dump d'un processus peut contenir des secrets déchiffrés, des clés privées et des tokens qui se trouvaient en mémoire au moment du crash.<br/>• Sur le control-plane, ajoutez à `/etc/security/limits.conf` les lignes `* hard core 0` et `* soft core 0` (limitation de la taille du core dump).<br/>• Interdisez le dump pour les processus SUID/privileged : `fs.suid_dumpable = 0` dans `/etc/sysctl.d/99-kubernetes.conf` (le même fichier que dans la tâche 8 - ne créez pas un fichier distinct en conflit).<br/>• **Sur Ubuntu, cela ne suffit pas :** le crash dump par défaut n'est pas transmis directement à un fichier, mais via `kernel.core_pattern`, qui pointe vers un userspace pipe handler (Apport). Apport intercepte le crash dans `/var/lib/apport/coredump/` indépendamment de `ulimit -c`, car `RLIMIT_CORE` est ignoré par le noyau précisément pour les pipe-handlers (voir `man 5 core` : "RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program").<br/>• C'est pourquoi, définissez en plus `kernel.core_pattern = \|/bin/false` dans le même `/etc/sysctl.d/99-kubernetes.conf` - cela remplace le pipe-handler par un handler délibérément inopérant, et le noyau ne crée de dump ni dans un fichier ni via Apport. Appliquez `sudo sysctl --system`.<br/>• Confirmez : `sysctl fs.suid_dumpable` renvoie `0`, et `cat /proc/sys/kernel/core_pattern` renvoie `\|/bin/false`.<br/>• Confirmez : un nouveau login-shell (`bash -l` ou `sudo su - ubuntu -c 'ulimit -c'` - précisément avec `sudo`, un `su` ordinaire sur soi-même demande quand même un mot de passe) montre `ulimit -c` égal à `0`.<br/>• Confirmez : après un vrai crash d'un processus de test (`SIGSEGV`), aucun nouveau core dump n'apparaît ni dans `/var/lib/apport/coredump/` ni ailleurs. |
| Critères d'acceptation | • **Valeurs live :** `sysctl -n fs.suid_dumpable` renvoie `0` ; `cat /proc/sys/kernel/core_pattern` renvoie `\|/bin/false`.<br/>• **sysctl persistant :** `/etc/sysctl.d/99-kubernetes.conf` contient les lignes actives (non commentées) `fs.suid_dumpable = 0` et `kernel.core_pattern = \|/bin/false`.<br/>• **Limites :** `/etc/security/limits.conf` contient les deux lignes `* hard core 0` et `* soft core 0` ; un nouveau login-shell montre `ulimit -c` égal à `0`.<br/>• **Crash probe :** un controlled crash d'un processus de test ne crée pas de nouveau core dump retenu.<br/>• **Artefact :** `/var/work/tests/artifacts/10/coredump.txt` contient toutes les confirmations, y compris le résultat du controlled crash probe. |

<details>
<summary>💡 Indice pour la tâche 10</summary>

`ulimit -c` dans VOTRE session SSH actuelle ne changera pas après la modification de `limits.conf` - les limites PAM ne s'appliquent qu'à la création d'une NOUVELLE session/login-shell. Vérifiez via `sudo su - ubuntu -c 'ulimit -c'` (nouveau login ; `sudo` est obligatoire - `su`, même sur soi-même, demande toujours un mot de passe s'il n'est pas invoqué depuis root) ou ouvrez une nouvelle session SSH, et ne vérifiez pas `ulimit -c` dans le même shell où vous avez modifié le fichier. Les deux valeurs sont nécessaires : `hard` est le plafond absolu, `soft` est la valeur effective par défaut ; si l'on ne définit que `soft`, le processus peut lui-même relever la limite jusqu'à `hard`. Le piège clé de la tâche : `ulimit -c 0` et `fs.suid_dumpable=0` **ne désactivent pas** le core dump sur Ubuntu à eux seuls - `man 5 core` dit directement que `RLIMIT_CORE` est ignoré par le noyau si `kernel.core_pattern` pointe vers un pipe-handler (`|program`), et Ubuntu dirige par défaut le crash précisément vers un tel handler (Apport), qui intercepte le dump indépendamment de `ulimit`. La seule façon fiable est de redéfinir `kernel.core_pattern` lui-même (par exemple, en `|/bin/false`), et pas seulement les limites du processus.
</details>

## En complément : kernel et containerd/CRI hardening

C'est une courte pratique node-local au-delà des tâches 7–9, qui n'entre pas dans les critères automatiques du
fixture. Elle montre un contexte CRI plus large, non limité à un module de noyau concret.

Dans ce lab, Kubernetes utilise **containerd**, et non Docker. C'est pourquoi les mêmes principes
doivent être appliqués au CRI : vérifiez les droits de `/run/containerd/containerd.sock` et
`/etc/containerd/config.toml`, n'ajoutez pas d'utilisateurs ordinaires au groupe donnant accès
au socket, et n'autorisez `ctr`/`crictl` avec cet endpoint qu'à des administrateurs
privilégiés. Ne modifiez pas à l'aveugle le propriétaire ni le mode du CRI-socket en fonctionnement : une
configuration erronée arrêtera le kubelet et les workload.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# on attend un refus d'accès pour un utilisateur non privilégié
```

## Vérification

Sur le `worker`, exécutez :

```bash
check_result
```

La vérification contient `0 Init` et dix tests indépendants. Elle vérifie l'état des deux
hôtes par SSH et les artefacts obligatoires. Après avoir modifié `sshd_config` ou une systemd unit,
attendez la fin de `systemctl reload/restart` avant de relancer la vérification.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=105 make delete_cks_task
```
