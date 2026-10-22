[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 - Runtime : Falco, audit-logs et root filesystem immuable

## Objectif

Dans ce lab CKS, vous allez configurer le contrôle des événements de runtime sur le nœud et l'audit-logging de l'API
du control plane, puis rendre le workload immuable en runtime. Le travail se fait sur un seul
nœud : le `control-plane` est à la fois le workload-node ; Falco voit donc les événements
des Pods de test, et kube-apiserver se trouve dans le static Pod manifest.

## Testez-vous avant de commencer

<details>
<summary>1. Pourquoi l'audit log de Kubernetes ne peut-il pas remplacer Falco pour la détection en runtime ?</summary>

L'audit log enregistre des événements au niveau REQUEST vers l'API server (qui, quoi et quand a demandé via `kubectl`/API) - c'est de l'evidence au niveau du control plane. Falco, lui, observe les APPELS SYSTÈME (syscalls) à l'intérieur des conteneurs en fonctionnement sur le nœud - par exemple, l'ouverture d'un shell, le spawn d'un processus, l'écriture dans un fichier. Une action du type `docker exec`/`crictl exec` ou un lancement direct via `ctr` sur le nœud ne passe PAS du tout par la Kubernetes API et n'arrivera pas dans l'audit log, mais sera visible pour Falco comme un événement de syscall.
</details>

<details>
<summary>2. Quelle est la différence entre les niveaux `RequestResponse` et `Metadata` de l'audit policy, et pourquoi faut-il précisément `Metadata` pour Secret ?</summary>

`RequestResponse` enregistre le corps complet de la requête ET de la réponse, y compris le contenu de la ressource. `Metadata` n'enregistre que les métadonnées de la requête (qui, quand, quelle ressource, quel verb) SANS corps. Pour `secrets`, c'est critique : `RequestResponse` enregistrerait la valeur du secret lui-même (encodée en base64, mais néanmoins des données sensibles) dans l'audit log sous la forme d'un fichier lisible sur le disque - cela crée une nouvelle surface de fuite. `Metadata` donne une trace forensic (« qui a lu ce Secret et quand ») sans copier le secret lui-même dans le log.
</details>

<details>
<summary>3. Pourquoi `readOnlyRootFilesystem: true` n'équivaut-il pas à une protection complète contre la compromission d'un conteneur en runtime ?</summary>

`readOnlyRootFilesystem` bloque l'écriture dans le système de fichiers racine du conteneur, ce qui empêche l'attaquant de modifier les binaires de l'application ou d'installer de la persistence sur le disque du conteneur. Mais cela n'empêche PAS : (a) les writable volumes/emptyDir que le Pod monte lui-même explicitement (par exemple `/tmp`), (b) l'exécution d'actions dans la mémoire du processus (RCE sans écriture sur disque), (c) les attaques réseau depuis l'intérieur du conteneur, (d) la lecture de Secret/ConfigMap déjà montés. L'immutabilité du rootfs est une couche de protection, et non une isolation complète.
</details>

## Lien avec le cours

- [Chapitre 29. Analyse comportementale à l'exécution : Falco](../../course/29/fr.md)
- [Chapitre 30. Détection des menaces et investigation des phases de l'attaque](../../course/30/fr.md)
- [Chapitre 31. Immutabilité des conteneurs en runtime](../../course/31/fr.md)
- [Chapitre 32. Audit-logs de Kubernetes](../../course/32/fr.md)
- [Chapitre 26. Registries, signature et validation des artefacts](../../course/26/fr.md) - la tâche 9 relie l'admission-control du registry allowlist à la détection en runtime de son contournement (pas la signature verification : celle-ci est vérifiée par le lab 111).

## Infrastructure

| Composant | Rôle |
|---|---|
| `k8s-1` | Kubernetes `1.36.0` mono-nœud, containerd et Calico ; nom du nœud `control-plane` |
| `worker` | machine de travail avec `kubectl`, `check_result` et un accès SSH `ssh control-plane` |
| `runtime-112` | namespace préparé ; il contient déjà un Secret `audit-secret` |

Le bootstrap n'installe volontairement **pas** Falco et n'active **pas** l'audit backend. Il ne fait que
préparer le répertoire `/etc/kubernetes/audit`, le répertoire de logs
`/var/log/kubernetes/audit` et un Secret pour une requête contrôlée à l'API. Ne modifiez pas le CNI,
la version du cluster, le Secret ni les manifests Kubernetes en dehors des tâches 4 et 8.

## Déploiement

```bash
TASK=112 make run_cks_task
```

Sur la machine de travail :

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## Comment travailler avec le nœud

Ouvrez deux terminaux : le **terminal 1** est `ssh control-plane`, puis `sudo -i` (opérations sur le nœud :
Falco, audit, `crictl`, `/proc`), le **terminal 2** est la machine de travail (`kubectl`, `scp`, vérifications).
Les artefacts obtenus sur le nœud, enregistrez-les dans un fichier sur le `control-plane` et copiez-les sur la machine de travail
avec la commande `scp` vers `/var/work/tests/artifacts/<numéro de la tâche>/`.

## Tâches

Avant le containment, il est utile d'évaluer mentalement le blast radius : le ServiceAccount
du Pod compromis peut-il lire des Secrets, créer des workloads ou atteindre d'autres
namespaces. Il est possible et utile de le vérifier rapidement avec `kubectl auth can-i` au nom du
ServiceAccount du Pod `falco-shell` (`--as=system:serviceaccount:runtime-112:default`) comme étape supplémentaire ; elle n'est pas obligatoire, n'influe pas sur les
critères d'acceptation et n'est pas testée.

---
| **1** | **Installer et lancer Falco sur le workload-node** |
| :---: | :--- |
| Ce qu'on fait | • Sur le `control-plane`, installez le paquet Falco depuis le dépôt officiel de Falco et démarrez le service.<br/>• Utilisez le modern eBPF engine ; n'installez pas le kernel module à la main.<br/>• Activez le service via systemd. |
| Critères d'acceptation | • `falco --version` s'exécute<br/>• `systemctl is-active falco` renvoie `active`<br/>• La configuration contient `engine.kind: modern_ebpf` |

<details>
<summary>💡 Indice pour la tâche 1</summary>

Le modern eBPF engine se configure via `engine.kind: modern_ebpf` dans `/etc/falco/falco.yaml` ou dans un fichier drop-in dans `/etc/falco/config.d/` (et non via un kernel module driver distinct, nécessaire pour le legacy engine) - si après l'installation Falco ne démarre pas ou plante au démarrage, vérifiez `journalctl -u falco-modern-bpf` (le paquet installe l'unit `falco-modern-bpf.service`, et `falco.service` n'est qu'un alias vers elle : `systemctl status/restart falco` fonctionne, mais `journalctl -u falco` est vide) afin de repérer d'éventuelles erreurs de chargement de l'eBPF program, qui peuvent indiquer un noyau incompatible.
</details>

---
| **2** | **Consigner l'événement standard de shell dans un conteneur** |
| :---: | :--- |
| Ce qu'on fait | • Créez dans `runtime-112` un Pod `falco-shell` à partir de `busybox:1.36`, laissez-le Running (`sleep 3600`) et activez `stdin: true`, `tty: true`.<br/>• Ouvrez-y un `/bin/sh` interactif et attendez la règle Falco **Terminal shell in container**.<br/>• Enregistrez la ligne appropriée du journal de Falco (elle se lit sur le `control-plane`) dans un fichier sur le nœud et copiez-la par `scp` vers `/var/work/tests/artifacts/2/falco-shell.log` sur la machine de travail. |
| Critères d'acceptation | • Le Pod `falco-shell` est Running<br/>• L'artefact n'est pas vide et contient la ligne d'alerte `A shell was spawned in a container with an attached terminal` (c'est ainsi que la règle **Terminal shell in container** affiche l'événement dans la sortie texte de Falco 0.45 ; le nom de la règle n'est que dans la sortie JSON)<br/>• L'événement doit avoir été reçu par Falco, et non écrit à la main |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Créer simplement un Pod avec `stdin: true, tty: true` ne suffit pas - il faut RÉELLEMENT ouvrir une session interactive (`kubectl exec -it falco-shell -- /bin/sh`), pour que Falco enregistre précisément le spawn d'un processus shell dans le conteneur. Cherchez l'événement via `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"` sur le `control-plane` (via SSH depuis le worker), et n'essayez pas d'écrire la ligne dans le fichier à la main - le test attend le timestamp/format réel du journal.
</details>

---
| **3** | **Ajouter et déclencher une custom Falco rule** |
| :---: | :--- |
| Ce qu'on fait | • Sur le `control-plane`, ajoutez à `/etc/falco/falco_rules.local.yaml` une règle nommée `CKS112 Custom Shell Marker`.<br/>• Elle doit capturer un spawned process dans un conteneur dont le `proc.cmdline` contient `CKS112_CUSTOM_EVENT`.<br/>• Elle doit afficher la phrase exacte `CKS112 custom shell marker` avec `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name` et `command=%proc.cmdline`.<br/>• Redémarrez Falco.<br/>• Lancez dans `falco-shell` n'importe quelle commande courte dont la ligne de commande contient le marker, par exemple : `kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`.<br/>• Trouvez dans le journal de Falco sur le `control-plane` la ligne de ce déclenchement (elle contient `CKS112 custom shell marker`), enregistrez-la dans un fichier sur le nœud et copiez-la par `scp` vers `/var/work/tests/artifacts/3/falco-custom.log`. La ligne doit être une vraie ligne du journal ; une ligne écrite à la main n'est pas acceptée. |
| Critères d'acceptation | • Le fichier local de règles existe, contient le nom de la règle, la condition du marker et les identifiants d'investigation<br/>• Le service Falco est actif<br/>• L'artefact journal réel contient le marker, le container ID et le PID |

<details>
<summary>💡 Indice pour la tâche 3</summary>

Une custom rule dans `falco_rules.local.yaml` exige une `condition` utilisant `spawned_process` (ou `evt.type=execve`) avec `proc.cmdline contains "CKS112_CUSTOM_EVENT"` - sans la condition de base sur le type d'événement, la règle peut ne pas se déclencher du tout ou se déclencher sur de mauvais événements. Après avoir modifié le fichier, exécutez `systemctl restart falco` pour une confirmation déterministe de l'application des règles. Dans le Falco actuel, un reload automatique est aussi possible avec `watch_config_files: true` activé, mais dans ce lab on utilise un restart explicite.
</details>

---
| **4** | **Activer l'audit-logging : RequestResponse pour ConfigMap, Metadata pour Secret** |
| :---: | :--- |
| Ce qu'on fait | • Sur le `control-plane`, créez `/etc/kubernetes/audit/policy.yaml`. La policy doit enregistrer `RequestResponse` **uniquement dans le namespace `runtime-112`** pour le core resource `configmaps` (un exemple forensic contrôlé sur une ressource non sensible).<br/>• Pour le core resource `secrets`, utilisez uniquement `Metadata`, **pour que le corps du Secret n'arrive pas dans le journal**.<br/>• Réduisez réellement le bruit par des règles `None` explicites pour le trafic à fort volume/faible risque et `omitStages: [RequestReceived]`.<br/>• Terminez la policy par un catch-all sûr `Metadata` comme *fallback logging*, et non comme suppression de bruit.<br/>• Dans le static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml`, ajoutez `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` et la rotation (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`).<br/>• Ajoutez les hostPath volume/volumeMount nécessaires pour le répertoire de policy et le répertoire de logs. Attendez le rétablissement de l'API.<br/>• Créez un ConfigMap `audit-config` dans `runtime-112`, lisez-le (`kubectl get configmap audit-config -n runtime-112 -o json`) et enregistrez le RequestResponse event dans `/var/work/tests/artifacts/4/configmap-request-response.json`.<br/>• Lisez ensuite `kubectl get secret audit-secret -n runtime-112 -o json` et enregistrez son Metadata event dans `/var/work/tests/artifacts/4/secret-metadata.json`. Les Events sont pris dans l'audit log sur le `control-plane` : enregistrez-les sur le nœud et copiez-les par `scp`. |
| Critères d'acceptation | • Kube-apiserver healthy<br/>• Le static manifest contient les deux flags d'audit et les montages<br/>• La policy définit `RequestResponse` pour `configmaps` et `Metadata` pour `secrets`<br/>• Dans `/var/work/tests/artifacts/4/configmap-request-response.json`, il y a un RequestResponse event de ConfigMap<br/>• Dans `/var/work/tests/artifacts/4/secret-metadata.json`, il y a un événement de Secret de niveau `Metadata` **sans les champs `requestObject`/`responseObject`** (le corps du Secret n'est pas journalisé) |

<details>
<summary>💡 Indice pour la tâche 4</summary>

L'ordre des règles dans l'audit policy compte : Kubernetes applique la PREMIÈRE règle correspondante, de haut en bas, donc la règle spécifique pour `configmaps`/`secrets` dans `runtime-112` doit venir AVANT le catch-all général `Metadata` à la fin du fichier - si le catch-all est en premier, il « interceptera » toutes les requêtes avant les règles spécifiques. Après la modification du static manifest, le kubelet prendra lui-même en compte les changements (pas besoin de `kubectl apply`/restart) - mais attendez que `kubectl get --raw=/readyz` renvoie de nouveau un succès avant de continuer.
</details>

---
| **5** | **Créer un Pod avec le root filesystem en lecture seule** |
| :---: | :--- |
| Ce qu'on fait | • Créez dans `runtime-112` un Pod `immutable-app` : conteneur `app`, image `busybox:1.36`, `sleep 3600`.<br/>• Sur le conteneur, activez `securityContext.readOnlyRootFilesystem: true`.<br/>• Créez un `emptyDir` `writable-tmp` et montez-le dans `/tmp` sans `readOnly: true`. N'utilisez pas `hostPath`.<br/>• Démontrez que `touch /cks-112-write-denied` échoue et que `touch /tmp/allowed` réussit ; enregistrez le résultat du refus dans `/var/work/tests/artifacts/5/rootfs-write-denied.log`. |
| Critères d'acceptation | • Pod Running<br/>• Root filesystem read-only<br/>• `/tmp` est un `emptyDir` writable<br/>• Il n'y a pas de `hostPath` dans le Pod<br/>• L'écriture dans le rootfs est bloquée, dans `/tmp` elle est autorisée<br/>• L'artefact n'est pas vide |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Enregistrez précisément la SORTIE D'ERREUR de la commande `touch /cks-112-write-denied` (`Read-only file system` dans stderr), et pas simplement le fait que la commande s'est terminée avec un code non nul - le test vérifie le contenu du log. Ne confondez pas `emptyDir` (éphémère, vit avec le Pod) avec `hostPath` (persistant sur le nœud, interdit dans cette tâche) - les deux « résolvent » techniquement le besoin d'un répertoire writable, mais seul le premier est autorisé ici.
</details>

---
| **6** | **Chaîne minimale de containment de l'alert à l'isolation** |
| :---: | :--- |
| Ce qu'on fait | • Après l'activation de l'audit backend, lancez dans `falco-shell` un processus contrôlé de longue durée, dont la ligne de commande contient `CKS112_CUSTOM_EVENT`, par exemple : `kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`. Le processus vit 10 minutes : tant qu'il est vivant, on peut relever son `/proc/<PID>`.<br/>• **Commencez l'investigation par un nouveau Falco alert**, et non par le Pod manifest. De l'alert, extrayez le short container ID et le host PID.<br/>• Sur le `control-plane`, via `crictl ps/inspect/inspectp`, mettez en correspondance container → Pod sandbox → namespace/Pod ; via la Kubernetes API, déterminez le nœud. Enregistrez `crictl inspect` et `inspectp`.<br/>• Tant que le processus est vivant, enregistrez `/proc/<PID>/status`, `cmdline`, `cgroup` et l'arbre PID/PPID/user.<br/>• Dans l'audit log, trouvez l'événement `pods/exec` pour `runtime-112/falco-shell` et enregistrez-le sans request/response body.<br/>• Classez la phase comme `Execution`, la technique comme `Container Administration Command`, constituez `evidence-summary.txt`. Les fichiers relevés sur le `control-plane`, copiez-les par `scp` vers `/var/work/tests/artifacts/6/`.<br/>• Appliquez ensuite une `NetworkPolicy` default-deny ingress+egress `incident-quarantine`, supprimez le Pod compromis et enregistrez la vérification négative : un nouveau `kubectl exec` ne passe pas.<br/>• C'est une chaîne minimale de containment : la credential revocation/rotation et la remediation complète exigent un processus d'incident-response distinct. |
| Critères d'acceptation | • Dans `/var/work/tests/artifacts/6/` se trouvent un vrai Falco alert, CRI inspect/inspectp, trois artefacts `/proc`, process lineage, un Metadata audit event pour `pods/exec`, la synthèse finale et le résultat du containment<br/>• Le Pod `falco-shell` est absent<br/>• `incident-quarantine` sélectionne tous les Pods et ferme ingress+egress<br/>• Un nouvel exec a un non-zero exit code |

<details>
<summary>💡 Indice pour la tâche 6</summary>

L'ordre strict des actions est important pour la fiabilité de l'investigation : commencez par le Falco alert (c'est ce qui déclencherait réellement l'incident response), et PAS par le nom de Pod déjà connu - sinon vous ne faites que confirmer ce que vous savez déjà, et vous ne menez pas une vraie correlation. Rassemblez les artefacts `/proc/<PID>/*` tant que le processus est VIVANT - dès que vous supprimez le Pod (la dernière étape), `/proc` pour ce PID disparaîtra pour toujours, donc l'ordre « d'abord l'evidence, ensuite le containment » est irréversible si on l'intervertit.
</details>

---
| **7** | **Override d'une macro upstream de Falco, ajouter l'evidence de Pod/namespace à l'output, JSON dans un fichier** |
| :---: | :--- |
| Ce qu'on fait | • La règle standard de Falco **Terminal shell in container** se déclencherait aussi pour un outil légitime de CI/CD qui ouvre habituellement un shell dans un conteneur (par exemple, `kubectl debug` ou un sidecar avec un script de maintenance). Au lieu de modifier la règle elle-même, faites un override de la macro upstream, destinée précisément à cette règle.<br/>• Dans `/etc/falco/falco_rules.local.yaml`, redéfinissez `user_expected_terminal_shell_in_container_conditions` (par défaut `(never_true)` dans la règle **Terminal shell in container** elle-même - à ne pas confondre avec `user_shell_container_exclusions`, qui relève de la règle distincte **Run shell untrusted**/"Shell spawned by untrusted binary"), afin qu'elle admette le Pod précis `ci-runner` dans le namespace `runtime-112`.<br/>• Utilisez `k8s.pod.name` et `k8s.ns.name`, et non `container.name` : `container.name` est le nom du **conteneur** (dans cette tâche `app`), et non du Pod, et la correspondance par le nom du conteneur donnera presque toujours un allowlist incorrect ou trop large.<br/>• L'output standard de la règle **Terminal shell in container** ne contient pas `k8s.pod.name`/`k8s.ns.name` (vérifiez vous-même le `falco_rules.yaml` upstream - ils n'y sont pas) ; sans ces champs, une correlation fiable d'un alert précis avec un Pod précis est impossible. Via le même mécanisme `override`, ajoutez (`output: append`) à la règle `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` à la fin de l'output.<br/>• Créez dans `runtime-112` un Pod `ci-runner` à partir de `busybox:1.36` avec un `sh` interactif (`stdin: true`, `tty: true`) et confirmez que pour lui l'alert `Terminal shell in container` **n'est pas** généré, tandis que pour `immutable-app` de la tâche 5 (sans exception) l'alert continue à se déclencher.<br/>• Séparément, via `/etc/falco/config.d/cks112-output.yaml`, activez `json_output: true` et `file_output.enabled: true` avec `file_output.filename: /var/log/falco/events.log` ; redémarrez Falco.<br/>• Confirmez par un JSON structuré (`jq .output_fields`), et non par un `grep` textuel, que l'alert enregistré pour `immutable-app` contient `k8s.pod.name == "immutable-app"` et `k8s.ns.name == "runtime-112"`. |
| Critères d'acceptation | • `falco_rules.local.yaml` contient `macro: user_expected_terminal_shell_in_container_conditions` avec une condition se référant à `k8s.pod.name = "ci-runner"` et `k8s.ns.name = "runtime-112"` (pas `never_true`, pas `container.name`), et un `override: output: append` distinct, qui ajoute `%k8s.ns.name`/`%k8s.pod.name` à la règle `Terminal shell in container`<br/>• Le shell dans `ci-runner` ne crée pas d'alert pendant le temps d'observation, et le shell dans `immutable-app` en crée un<br/>• `config.d/cks112-output.yaml` contient `json_output: true` et `file_output: {enabled: true, filename: /var/log/falco/events.log}`<br/>• `/var/log/falco/events.log` contient une ligne JSON valide avec `rule == "Terminal shell in container"` et `output_fields["k8s.pod.name"] == "immutable-app"`, `output_fields["k8s.ns.name"] == "runtime-112"`<br/>• Le Pod `falco-shell` de la tâche 2 est déjà supprimé à ce stade (tâche 6) et n'est pas utilisé ici |

<details>
<summary>💡 Indice pour la tâche 7</summary>

Il est facile de confondre deux mécanismes d'override différents : l'override de `macro` change la CONDITION de déclenchement de la règle (qui exclure), et l'override d'`output` avec `append` ne change que le FORMAT de la sortie (ce qu'il faut afficher) - pour cette tâche, il faut LES DEUX, dans des blocs distincts `- macro: ...` et `- rule: ... / override: / output: append`. Vérifiez littéralement l'écriture de `user_expected_terminal_shell_in_container_conditions` - Falco a plusieurs macros de nom proche pour différentes règles (le `user_shell_container_exclusions` mentionné dans la tâche relève d'UNE AUTRE règle), utiliser une mauvaise macro ne donnera pas d'erreur de chargement, mais l'allowlist ne fonctionnera tout simplement pas.
</details>

---
| **8** | **Audit webhook backend à la place de/en plus du fichier local** |
| :---: | :--- |
| Ce qu'on fait | • Utilisez le récepteur HTTP `audit-receiver` déjà préparé par le bootstrap (Deployment + Service sur le port `8080`, image `ghcr.io/mendhak/http-https-echo:40`), qui reçoit les audit-events.<br/>• Sur le `control-plane`, créez `/etc/kubernetes/audit/webhook-config.yaml` au format kubeconfig avec `server: http://<ClusterIP du récepteur>:8080/audit` (pour le lab, HTTP est admis ; en production, le webhook exige HTTPS et client certificate - voir le chapitre 32).<br/>• Dans le static manifest `kube-apiserver.yaml`, ajoutez `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` et `--audit-webhook-batch-max-wait=1s` (délai de batch réduit pour l'observabilité dans le lab), en conservant les `--audit-policy-file` et `--audit-log-path` déjà configurés de la tâche 4 - le webhook complète, et ne remplace pas, le local file backend.<br/>• Après le rétablissement de l'API, exécutez n'importe quelle requête auditable (par exemple, `kubectl get configmap audit-config -n runtime-112`) et confirmez dans les logs d'`audit-receiver` que l'événement a été livré. |
| Critères d'acceptation | • `audit-receiver` Running avec Service<br/>• `webhook-config.yaml` est un kubeconfig valide avec `server` pointant vers ce Service<br/>• Le static manifest de kube-apiserver contient `--audit-webhook-config-file` et `--audit-webhook-batch-max-wait`, ainsi que les flags du file backend de la tâche 4 conservés<br/>• Kube-apiserver healthy après la modification<br/>• Les logs d'`audit-receiver` contiennent, dans le corps d'au moins une requête HTTP reçue, un audit event au format JSON avec le champ `objectRef` |

<details>
<summary>💡 Indice pour la tâche 8</summary>

`webhook-config.yaml` est au FORMAT KUBECONFIG (avec `clusters`/`users`/`contexts`), et non un YAML arbitraire avec un champ `server` - si la structure du fichier ne correspond pas au kubeconfig schema, kube-apiserver ne pourra pas l'analyser et ne démarrera pas du tout. N'oubliez pas que le webhook COMPLÈTE le file backend, et ne le remplace pas - si vous supprimez les flags `--audit-policy-file`/`--audit-log-path` de la tâche 4, les tests de la tâche 4 cesseront de passer.
</details>

---
| **9** | **Tâche d'intégration : contourner l'admission allowlist via containerd directement et détecter la tentative via Falco** |
| :---: | :--- |
| Ce qu'on fait | • Cette tâche relie Supply Chain Security (voir le [lab 111](../111/README_FR.MD) et le [chapitre 26](../../course/26/fr.md)) au Runtime Security de ce lab. **Différence importante avec le lab 111** : là-bas, `ImageValidatingPolicy` vérifie la **signature cryptographique** (Cosign). Ici, la policy ne vérifie que le **registry/repository allowlist** (permitted registry, sans signature/attestor) - un admission control plus simple, mais tout aussi réel, avec le même principe : il ne fonctionne que sur l'API admission path et ne voit pas les actions qui ne s'y adressent pas.<br/>• Le controlled abuse fixture de cette tâche est un lab-owned local registry, et non le Docker Hub public : le bootstrap a déjà préparé sur le `control-plane` trois images avec des digest différents dans le local containerd content store et a enregistré leurs noms dans `/etc/cks112/registry.env` (`CKS112_REGISTRY=cks112.local:5000`, `CKS112_TRUSTED_REPO=cks112/trusted`, `CKS112_UNTRUSTED_REPO=cks112/untrusted`, `CKS112_TRUSTED_IMAGE`, `CKS112_UNTRUSTED_IMAGE`, `CKS112_PREFIX_IMAGE`) - chargez (`source`) ce fichier au début de la tâche et utilisez uniquement ces valeurs.<br/>• Installez Kyverno (`install-kyverno`, comme dans le lab 111) et créez une `ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL, `apiVersion: policies.kyverno.io/v1`), qui via `image(c.image).registry()`/`.repository()` (Kyverno CEL Image library) **rejette** tout Pod dans `runtime-112` dont l'image n'est pas exactement égale à `registry: $CKS112_REGISTRY` et `repository: $CKS112_TRUSTED_REPO` - pas `startsWith`, pour ne pas laisser passer des noms proches comme `cks112/trusted-evil`. Donnez à la policy un message de refus (denial) unique, par exemple `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`.<br/>• Confirmez ce chemin : appliquez un Pod `blocked-attempt` avec l'image `$CKS112_UNTRUSTED_IMAGE` (hors de l'allowlist) et enregistrez la sortie de l'admission denial dans `9/admission-deny.txt`.<br/>• Ensuite, sur le `control-plane`, via `cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'` (l'image est déjà présente localement depuis le bootstrap, un nouveau pull n'est pas nécessaire), simulez un chemin qui ne passe pas par l'API server et que l'admission controller ne voit pas (le helper le lance lui-même via CRI en mode detached ; utilisez un ID unique pour la revérification et supprimez ensuite le conteneur via `cks112-rm <id>`).<br/>• **Avant d'écrire la règle Falco, déterminez la valeur RÉELLEMENT observée du champ `%container.image.repository` pour le `$CKS112_TRUSTED_IMAGE` de confiance sur votre stack containerd/Falco** - ce champ est formé différemment selon les versions (peut-être avec le hostname du registry, peut-être sans), donc ne présumez pas le format à l'avance : avec une règle temporaire avec un marker sûr, affichez la valeur dans le log et enregistrez-la comme `$TRUSTED_REPO` (enregistrez l'evidence dans `9/observed-trusted-repo.txt`).<br/>• Ajoutez à `falco_rules.local.yaml` une custom rule `CKS112 Runtime Bypass of Admission`, qui capture un spawned process avec `proc.cmdline` contenant `CKS112_CTR_BYPASS` **et** `container.image.repository` ne faisant pas partie de l'allowlist, et qui affiche `container.image.repository` avec les identifiants du processus. Utilisez la comparaison **exacte** `container.image.repository != "$TRUSTED_REPO"` avec la valeur observée (pas de vérification `startswith`/prefix : `not container.image.repository startswith "$TRUSTED_REPO"` laisserait passer, c'est-à-dire ne remarquerait pas, un repository comme `<observed-value>-evil`, car son nom COMMENCE simplement par la sous-chaîne autorisée - la même erreur qu'évite la Kyverno policy ci-dessus via `==`, et non `startsWith`).<br/>• Vérifiez en outre les deux cas contrôlés : le `$CKS112_TRUSTED_IMAGE` de confiance NE doit PAS déclencher la règle (uniquement sur le critère de repository ; le marker `CKS112_CTR_BYPASS` lui-même peut tout de même être vérifié séparément), et une image avec le repository `<observed-value>-evil` DOIT déclencher la règle - c'est précisément cela qui démontre que la comparaison est exacte, et non prefix-based.<br/>• Enregistrez le déclenchement dans `9/falco-bypass-attempt.log` (les fichiers relevés sur le `control-plane` sont copiés par `scp` vers `/var/work/tests/artifacts/9/`). |
| Critères d'acceptation | • Kyverno installé et Available<br/>• La `ValidatingPolicy require-trusted-registry-runtime-112` existe avec `apiVersion: policies.kyverno.io/v1`, validation action `Deny`, utilise `image(...).registry()`/`.repository()` pour une comparaison exacte (pas `startsWith`), et son `message`/`messageExpression` contient le marqueur unique `CKS112_TRUSTED_REPO_POLICY`<br/>• Le Pod `blocked-attempt` n'est pas créé (admission denial), `9/admission-deny.txt` contient précisément ce marqueur (pas n'importe quelle erreur générique d'admission)<br/>• `9/observed-trusted-repo.txt` contient la valeur réellement observée de `%container.image.repository` pour l'image de confiance<br/>• `falco_rules.local.yaml` contient la règle `CKS112 Runtime Bypass of Admission` avec une condition **exacte** (pas `startswith`/prefix) sur `container.image.repository`, utilisant précisément cette valeur observée<br/>• `9/falco-bypass-attempt.log` contient un déclenchement non vide avec `CKS112_CTR_BYPASS` et un image repository hors de l'allowlist (suffixe `-evil` à la valeur observée) - ce repository est choisi exprès comme prefix-trap : il doit être détecté, malgré le fait qu'il commence par une chaîne autorisée |

<details>
<summary>💡 Indice pour la tâche 9</summary>

L'idée clé de la tâche : `cks112-run` (une surcouche de `crictl` qui crée le conteneur directement via CRI) s'adresse à containerd, en contournant kube-apiserver et, par conséquent, TOUT admission controller (y compris Kyverno) - c'est une démonstration du fait que l'admission control ne protège que le chemin via la Kubernetes API, et non tout le nœud. Votre règle Falco doit vérifier via `and` dans une seule `condition` : un processus de conteneur (`container.id != host` - la commande de lancement sur l'hôte contient aussi le marker), le marker `CKS112_CTR_BYPASS` ET un repository hors de l'allowlist - si vous ne vérifiez que le marker, la règle se déclenchera même sur des processus de test légitimes avec un cmdline semblable.
</details>

---
| **10** | **Détecter l'accès à `/dev/mem` via une classe distincte de condition Falco et arrêter le workload** |
| :---: | :--- |
| Ce qu'on fait | • Les tâches 3, 7 et 9 utilisaient une condition sur `spawned_process`/`proc.cmdline` - détection par le lancement d'un processus. Ici, il faut une classe de Falco condition fondamentalement différente : détection par l'**ouverture d'un fichier/périphérique**.<br/>• Dans `runtime-112` existe déjà un Deployment `mem-scanner` (2 répliques), dont les deux répliques ouvrent périodiquement `/dev/mem` depuis l'intérieur du conteneur - un workload applicatif ordinaire n'a aucune raison de le faire, et un tel accès est un indicateur fort d'une configuration dangereuse ou d'une tentative de contournement de l'isolation du conteneur. Le chemin `/dev/mem` dans le conteneur est un synthetic safe fixture (le backing device est en fait le `/dev/null` de l'hôte, et non la mémoire physique réelle de l'hôte) ; pour Falco, cela n'a pas d'importance - la règle détecte le syscall `open`/`openat`/`openat2` lui-même par le nom de fichier `fd.name = /dev/mem`, indépendamment du périphérique qui se trouve réellement derrière.<br/>• Sur le `control-plane`, ajoutez à `/etc/falco/falco_rules.local.yaml` la règle `CKS112 Container access to /dev/mem` avec la condition `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`, priority `CRITICAL`, l'output doit contenir `container_id=%container.id`, `k8s_pod=%k8s.pod.name` et `k8s_ns=%k8s.ns.name`. Redémarrez Falco.<br/>• Trouvez le déclenchement dans le journal et déterminez grâce à lui le Pod **précis** (ne devinez pas d'après le nom - utilisez `k8s_pod` de l'alert lui-même) ; d'après cet alert précis, déterminez quelle réplique exacte a créé l'événement enregistré. Enregistrez la ligne de l'alerte sur le nœud et copiez-la par `scp` vers `/var/work/tests/artifacts/10/falco-devmem.log`.<br/>• Avant le containment, enregistrez le JSON du Pod détecté (`kubectl get pod <pod de l'alert> -n runtime-112 -o json`) dans `/var/work/tests/artifacts/10/detected-pod.json`.<br/>• Exécutez `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` et enregistrez l'état final (`kubectl get deployment mem-scanner -n runtime-112 -o json`) dans `/var/work/tests/artifacts/10/scaled-down.json`. |
| Critères d'acceptation | • `falco_rules.local.yaml` contient une règle nommée `CKS112 Container access to /dev/mem`, une condition sur `fd.name = /dev/mem` (pas sur `proc.cmdline`/spawned_process) et `container.id != host`, priority `CRITICAL`<br/>• Falco actif<br/>• `10/detected-pod.json` consigne le Pod réel et l'owner chain avant le containment<br/>• `10/falco-devmem.log` est une vraie ligne du journal avec cette règle et un `k8s_pod` non vide<br/>• Le Deployment `mem-scanner` est scalé à `replicas: 0`<br/>• `10/scaled-down.json` confirme `spec.replicas == 0` |

<details>
<summary>💡 Indice pour la tâche 10</summary>

Ne confondez pas cette condition avec les tâches 3/7/9 - là-bas, `spawned_process`/`execve` capture le LANCEMENT d'un processus par la ligne de commande, et ici `open`/`openat`/`openat2` capture l'OUVERTURE d'un fichier/périphérique précis, indépendamment du processus qui le fait et de ses arguments de ligne de commande. `container.id != host` écarte les processus système légitimes sur le nœud lui-même (pas dans un conteneur), qui peuvent avoir besoin d'accéder à `/dev/mem` pour d'autres raisons. Ne scalez pas le Deployment avant d'avoir trouvé l'alert - d'abord la détection via Falco, ensuite le containment, sinon vous ne démontrerez pas que vous avez trouvé le Pod précisément via le monitoring, et non en le choisissant à l'avance d'après son nom. Obtenez d'abord le Falco alert et ce n'est qu'à partir de son `k8s_pod` que vous déterminez la réplique précise qui a créé cet événement.
</details>

## Vérification

```bash
check_result
```

La vérification contient Init et dix tests indépendants. Elle vérifie l'état de Falco et de
kube-apiserver par SSH, les objets de l'API, l'evidence CRI/`/proc`, l'audit correlation, le containment
et le refus réel d'écriture dans le rootfs. Après la
modification du static Pod manifest, ne redémarrez pas le kubelet sans nécessité : le kubelet remarquera lui-même
la modification. Si l'API est temporairement indisponible, attendez `kubectl get --raw=/readyz`.
Enregistrez le backup du fichier `kube-apiserver.yaml` uniquement en dehors de `/etc/kubernetes/manifests` : le kubelet lit tout fichier sans point initial dans ce répertoire.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=112 make delete_cks_task
```
