[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 - gVisor RuntimeClass, Cilium WireGuard et Istio mTLS

## Objectif

Dans ce lab CKS, vous allez assembler trois couches indépendantes de protection du workload : le runtime sandboxed
**gVisor** via `runsc`, le chiffrement inter-nœuds Cilium WireGuard et le mTLS service-to-service
d'Istio. À la fin, vous ne verrez pas seulement les réglages, mais vous les démontrerez par des résultats
observables : la différence du kernel view de gVisor, des paquets WireGuard sans HTTP marker et le résultat
différent d'un appel depuis le mesh et depuis un client plaintext hors du mesh.

## Vérifiez-vous avant de commencer

<details>
<summary>1. En quoi le userspace kernel de gVisor diffère-t-il fondamentalement du guest kernel d'une machine virtuelle ?</summary>

gVisor (`runsc`) implémente son propre sous-ensemble de syscalls Linux EN USERSPACE, en interceptant les appels système du conteneur et en les traitant lui-même, sans les transmettre directement au noyau de l'hôte - le processus du conteneur voit un autre « noyau » (un autre `uname -r`, un autre comportement de certains syscalls). Un guest kernel (par exemple, Kata Containers) exécute un noyau Linux COMPLET à l'intérieur d'une VM légère - un isolement plus fort, mais avec l'overhead d'une virtualisation complète, que gVisor n'a pas.
</details>

<details>
<summary>2. Qu'authentifie exactement un WireGuard peer, et pourquoi ce n'est PAS la même chose que l'identity d'un ServiceAccount ?</summary>

WireGuard authentifie les NŒUDS (nodes) du cluster via des clés cryptographiques générées par Cilium pour chaque nœud - le chiffrement se fait au niveau du tunnel node-to-node. Cela protège le trafic ENTRE les nœuds contre l'écoute au niveau réseau, mais n'a aucun rapport avec l'identity d'un Pod/ServiceAccount concret à l'intérieur de ce trafic - Cilium WireGuard ne vérifie pas « qui » est l'émetteur au niveau applicatif, seulement « quel nœud ».
</details>

<details>
<summary>3. Pourquoi un `curl` réussi avec le code 200 à l'intérieur du mesh ne démontre-t-il PAS que le plaintext client a réellement été bloqué ?</summary>

Une réponse réussie À L'INTÉRIEUR du mesh démontre seulement que la connexion mTLS entre les deux sidecars fonctionne - c'est un positive control. Pour démontrer que STRICT bloque réellement le trafic NON-mesh, il faut un negative control distinct : un client SANS sidecar, qui essaie d'accéder au même service et reçoit un refus. Un seul test réussi ne suffit pas - il faut les deux : allowed pour la mesh identity, denied pour le plaintext.
</details>

## Lien avec le cours

- [Chapitre 22. Container Runtime Sandbox](../../course/22/fr.md)
- [Chapitre 23. Chiffrement Pod-to-Pod et mTLS](../../course/23/fr.md)

## Infrastructure

Terragrunt crée Kubernetes `1.36.0` dans `eu-central-1` :

| Composant | Rôle |
|---|---|
| `k8s-1` control-plane | un workload node containerd ordinaire, Cilium et `tcpdump` pour capturer un paquet inter-nœuds |
| `k8s-1` worker `gvisor` | un nœud distinct avec containerd, `runsc` installé et le CRI handler `runsc` |
| CNI | **Cilium** (installé via Cilium CLI avec le Helm release `cilium`) ; WireGuard est volontairement désactivé jusqu'à la tâche 4 |
| `worker` | machine de travail avec `kubectl`, `cilium`, `istioctl`, `check_result` et des SSH aliases vers les nœuds |

Matrice vérifiée le 2026-08-31 (comparez-la avant chaque build) : Kubernetes du cours
`1.36.0` ; Cilium data plane - une lab-build prise en charge, dont la compatibilité avec
Kubernetes `1.36` doit être confirmée d'après la requirements matrix à jour ; Cilium CLI `0.19.7`
(compatible avec Cilium `1.17+`) ; Istio `1.30.4` (la branche `1.30` prend officiellement en charge Kubernetes
`1.32–1.36`). La version de l'examen ne détermine pas ici la compatibilité du lab tooling ; d'après les données de LF,
elle est actuellement `v1.34` et se vérifie séparément avant l'examen.

Après le bootstrap, deux workload placement labels sont disponibles :

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Le control-plane est disponible pour les Pods ordinaires sans tolerations. Le nœud gVisor est en plus marqué du taint
`sandbox.runtime/gvisor=true:NoSchedule` : seuls y arrivent les Pods qui tolèrent ce taint
(les Pods avec `RuntimeClass gvisor` reçoivent le toleration nécessaire de `scheduling.tolerations` de la classe).

Les namespaces `sandbox-110` et `market` existent déjà. `market` a le label
`istio-injection=enabled` posé à l'avance ; l'Istio control plane n'est pas installé. Pour accéder au
nœud sandbox depuis le worker, utilisez l'alias `k8s110_node_gvisor`, et pour le control-plane,
`k8s110_controlPlane_1`.

## Déploiement

```bash
TASK=110 make run_cks_task
```

Connectez-vous à la machine de travail et choisissez le contexte prêt :

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Créez le répertoire des preuves avant de commencer à travailler :

```bash
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## Tâches

---
| **1** | **Configurer le runtime de containerd et créer le RuntimeClass pour runsc** |
| :---: | :--- |
| Ce qu'on fait | • Sur `k8s110_node_gvisor`, le binaire `runsc` est déjà installé, mais le bootstrap a volontairement retiré de `/etc/containerd/config.toml` la section `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` avec `runtime_type = "io.containerd.runsc.v1"` - c'est une situation d'examen typique avec un config.toml cassé.<br/>• Rétablissez cette section (la sauvegarde se trouve dans `/etc/containerd/config.toml.bak`, ou ajoutez-la à la main) et exécutez `sudo systemctl restart containerd`.<br/>• Créez le `RuntimeClass` `gvisor` avec le `handler: runsc` exact.<br/>• Dans `scheduling`, définissez le `nodeSelector` `sandbox.runtime/gvisor: "true"`, afin qu'un Pod avec cette classe n'arrive jamais sur un nœud ordinaire, et les `tolerations` pour le taint du nœud gVisor (`sandbox.runtime/gvisor=true:NoSchedule`), sinon le Pod n'y arrivera pas. |
| Critères d'acceptation | • Sur le nœud, `containerd` est actif et `config.toml` contient une section `runtimes.runsc` opérationnelle avec `runtime_type = "io.containerd.runsc.v1"`<br/>• `kubectl get runtimeclass gvisor` existe, le handler est égal à `runsc`, dans `scheduling` il y a `nodeSelector` et `tolerations` pour le taint du nœud gVisor<br/>• Dans `/var/work/tests/artifacts/1/runsc-runtime.txt` se trouve la ligne exacte `RuntimeClass gvisor: handler runsc` |

<details>
<summary>💡 Indice pour la tâche 1</summary>

La sauvegarde `/etc/containerd/config.toml.bak` est le chemin de restauration le plus rapide, mais vérifiez son contenu avant de la recopier (`diff` avec le fichier actuel), pour comprendre ce qui manque exactement. Après la restauration de la section `runtimes.runsc`, exécutez obligatoirement `systemctl restart containerd` - la simple modification du fichier n'applique pas les changements au processus déjà en fonctionnement.
</details>

---
| **2** | **Pod dans le sandbox gVisor** |
| :---: | :--- |
| Ce qu'on fait | • Dans `sandbox-110`, créez un Pod `gvisor-sandbox` avec `runtimeClassName: gvisor`, le conteneur `app` et l'image `busybox:1.36`.<br/>• Indiquez dans le Pod explicitement le `nodeSelector` `sandbox.runtime/gvisor: "true"` et les `tolerations` pour le taint du nœud gVisor (la même chose que dans le `scheduling` du RuntimeClass ; sans eux, Kubernetes les ajoutera lui-même depuis le RuntimeClass, mais dans le manifest cela ne se verra pas).<br/>• Lancez dans le conteneur un HTTP server sur `8080`, renvoyant la chaîne `CKS110-WIREGUARD-MARKER`.<br/>• Créez un Service `gvisor-echo` sur `8080`, sélectionnant ce Pod.<br/>• Désactivez l'automount du ServiceAccount token.<br/>• Enregistrez dans un artefact la sortie de `uname -r` et de `dmesg` du Pod : `dmesg` à l'intérieur du sandbox gVisor commence par la ligne `Starting gVisor...` au lieu du vrai log du noyau du nœud - c'est une preuve directe de l'isolation, distincte de la différence de `uname -r`. |
| Critères d'acceptation | • Le Pod est `Running` sur un nœud `sandbox.runtime/gvisor=true`, le Service le sélectionne, et `/var/work/tests/artifacts/2/gvisor-kernel.txt` contient la ligne `gvisor uname -r: <valeur réelle>` et la ligne `Starting gVisor` de la sortie de `dmesg` |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Si le Pod ne démarre pas (reste bloqué en `ContainerCreating` avec l'événement `FailedCreatePodSandBox`, par exemple `no runtime for "runsc" is configured`), c'est très probablement que la tâche 1 n'est pas entièrement terminée - le RuntimeClass doit réellement pointer vers un handler containerd opérationnel. Dans le `busybox:1.36` utilisé, il y a un applet `httpd` - utilisez `httpd -f -p 8080 -h /www` pour un HTTP server minimal (la présence de l'applet peut se vérifier via `busybox --list | grep '^httpd$'`).
</details>

---
| **3** | **Comparaison avec un Pod runc ordinaire** |
| :---: | :--- |
| Ce qu'on fait | • Créez `runc-baseline` dans `sandbox-110` : `busybox:1.36`, conteneur `app`, `sleep 3600`.<br/>• Sans `runtimeClassName`, avec le nodeSelector `lab.cks.io/role: control-plane` et sans SA token.<br/>• Comparez son `uname -r` avec celui du gVisor Pod et enregistrez les deux résultats dans `/var/work/tests/artifacts/3/runtime-comparison.txt`. |
| Critères d'acceptation | • Le Pod baseline est `Running` sur le control-plane et n'a pas de `runtimeClassName`<br/>• Sa release diffère de la gVisor release<br/>• Dans l'artefact, il y a les deux lignes `gvisor uname -r:` et `runc uname -r:` avec des valeurs réelles |

<details>
<summary>💡 Indice pour la tâche 3</summary>

Ce Pod est placé exprès sur un AUTRE nœud (control-plane, pas le nœud gvisor) via le nodeSelector `lab.cks.io/role: control-plane` - ce n'est pas simplement « n'importe quel Pod ordinaire », mais une comparaison contrôlée avec un emplacement connu. Si `uname -r` s'avère identique pour les deux Pods, vérifiez si `gvisor-sandbox` utilise réellement `runtimeClassName: gvisor`.
</details>

---
| **4** | **Activer le Cilium transparent encryption** |
| :---: | :--- |
| Ce qu'on fait | • Enregistrez d'abord les versions de Kubernetes, du Cilium agent et de Cilium CLI dans `/var/work/tests/artifacts/4/tool-versions.txt` et assurez-vous que le data plane prend en charge Kubernetes `1.36`.<br/>• Activez WireGuard dans le Helm release existant, créé par `cilium install` : `cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`.<br/>• Redémarrez les agents (`kubectl -n kube-system rollout restart daemonset/cilium`) : Helm ne change que le ConfigMap, et le template du DaemonSet reste identique.<br/>• Vérifiez `cilium-config` (`enable-wireguard: "true"`) et la disponibilité des deux Cilium agents.<br/>• Un patch direct du ConfigMap n'est admissible que comme baseline-probe pédagogique de courte durée avec un rollback confirmé obligatoire. Ne cherchez pas la commande `cilium encrypt enable` : le CLI client `cilium` n'a pas cette sous-commande.<br/>• Enregistrez l'agent-side `cilium-dbg encrypt status` et `cilium-dbg debuginfo --output json` dans `/var/work/tests/artifacts/4/cilium-encrypt-status.txt` (`cilium-dbg status` n'a pas le flag `--all-encryption`). |
| Critères d'acceptation | • La version evidence existe et coïncide avec l'image réelle du DaemonSet `kube-system/cilium`<br/>• Les Cilium agents (DaemonSet) sont entièrement Ready<br/>• Status montre WireGuard et ne montre pas IPsec en même temps<br/>• Le JSON de Debuginfo contient une evidence de peer/allowed-IP (ou remote-node) de l'état inter-nœuds<br/>• Le ConfigMap `kube-system/cilium-config` contient `enable-wireguard: "true"` comme effective-configuration appliquée depuis les Helm values<br/>• Le réglage survit au restart d'un agent Pod (le checker redémarre le Pod et revérifie le statut) |

<details>
<summary>💡 Indice pour la tâche 4</summary>

Utilisez les Helm values du release existant `cilium` comme source-of-truth durable pour activer WireGuard, et non des commandes éphémères - une modification faite en dehors des Helm values peut ne pas survivre au restart de l'agent ou à la mise à jour du Helm release, et le test vérifie précisément que le réglage survit au restart. `cilium-dbg` est appelé À L'INTÉRIEUR du Pod de l'agent via `kubectl exec`, et non comme un binaire local distinct sur le worker. `cilium-dbg status` N'A PAS de flag `--all-encryption` - pour une evidence détaillée de peer/allowed-IP, utilisez `cilium-dbg debuginfo --output json`.
</details>

---
| **5** | **Démontrer l'absence de plaintext entre les nœuds** |
| :---: | :--- |
| Ce qu'on fait | • Construisez une preuve AVANT/APRÈS sur le même flow inter-nœuds.<br/>• **Baseline (WireGuard désactivé) :** sur le control-plane, lancez `tcpdump` sur l'IP du nœud distant (`host <remote-node-ip>`, sans filtre préalable par `udp port 51871`) ; désactivez temporairement WireGuard (`enable-wireguard: "false"` dans `cilium-config`, `rollout restart daemonset/cilium`) ; exécutez la requête `runc-baseline -> gvisor-echo` ; enregistrez ce baseline-capture et assurez-vous qu'on y voit le plaintext `CKS110-WIREGUARD-MARKER`.<br/>• **Après (WireGuard activé) :** rétablissez `enable-wireguard: "true"`, attendez Ready et répétez LA MÊME requête avec LE MÊME scope de capture (`host <remote-node-ip>`, sans filtre par port).<br/>• La capture est effectuée sur le control-plane (dans un fichier sur le nœud), puis copié par `scp` sur la machine de travail dans `/var/work/tests/artifacts/5/wireguard-tcpdump.txt` : on doit maintenant y voir uniquement WireGuard UDP/`51871`, sans plaintext marker. |
| Critères d'acceptation | • La capture finale (post-change) avec le même peer/interface scope contient UDP/`51871`, mais **ne** contient **pas** `CKS110-WIREGUARD-MARKER`<br/>• L'appel entre des nœuds différents reçoit avec succès le marker dans la réponse HTTP<br/>• Le checker répète lui-même la capture post-change avec le même peer/interface scope (sans se limiter d'avance à `udp port 51871`), et désactive et rétablit aussi lui-même temporairement WireGuard pour obtenir sa propre confirmation baseline que le même flow à l'état plaintext expose réellement le marker sur le wire |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Capturez le trafic sur l'interface réseau physique RÉELLE du nœud (par exemple `eth0`), et non sur l'interface virtuelle du Pod/veth ni sur l'interface interne de Cilium `cilium_wg0` - `cilium_wg0`, par conception du tunnel WireGuard, transporte du trafic DÉJÀ DÉCHIFFRÉ (c'est son rôle), donc une capture sur `any` y verra le marker même si le chiffrement fonctionne correctement sur le NIC physique. Déterminez l'interface physique concrète via `ip route get <remote-node-ip>` et utilisez précisément celle-ci. Si la capture se fait « à l'intérieur » du chemin du Pod avant le chiffrement de WireGuard, vous verrez du HTTP plaintext que le chiffrement node-to-node soit activé ou non. Lancez `tcpdump` EN ARRIÈRE-PLAN AVANT d'exécuter la requête HTTP, et non après. Un filtre de capture UNIQUEMENT sur `udp port 51871` exclut d'avance le TCP plaintext du résultat et ne démontre donc PAS son absence - utilisez `host <remote-node-ip>` sans filtre de port, afin qu'un même scope puisse réellement montrer la différence avant/après l'activation de WireGuard. Le checker exécute son propre `tcpdump` simultanément avec sa requête (y compris une baseline-probe avec désactivation temporaire de WireGuard et un rétablissement vérifié ensuite) - votre artifact est utile sur le plan pédagogique, mais n'est pas la seule preuve : si le chiffrement ne fonctionne réellement pas au moment de la vérification, le live capture du checker le détectera indépendamment du contenu de votre fichier.
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| Ce qu'on fait | • Installez Istio `1.30.4` figé depuis l'`istioctl` préparé (le minimal profile suffit) et enregistrez la version du control plane.<br/>• Dans `market`, créez un Deployment `market-api` et un Service `market-api` : l'application écoute sur `8080`, nommez `http` le service port. `market-api` doit fonctionner sur le nœud gVisor : `nodeSelector` `lab.cks.io/role: gvisor` et un toleration pour son taint (`sandbox.runtime/gvisor=true:NoSchedule`).<br/>• Créez un Deployment injected `market-client` dans `market` et un Pod plaintext `mesh-outside` dans `default` ; les trois workloads doivent être Running - **sans** `PeerAuthentication` STRICT.<br/>• **Baseline :** la même requête plaintext outside vers `market-api` doit recevoir HTTP 200 (mTLS n'est pas encore exigé) ; enregistrez cette réponse baseline séparément.<br/>• Appliquez un `PeerAuthentication` `market-strict` dans le namespace `market` avec `mtls.mode: STRICT` et répétez LA MÊME requête outside : le plaintext client sans sidecar ne doit pas recevoir d'application response réussie, et la requête in-mesh doit recevoir HTTP 200.<br/>• Enregistrez status/headers/exit code dans `artifacts/6/market-inside.txt` et `market-outside.txt` (à la fin des deux fichiers, ajoutez la ligne `exit_code=<code de sortie de curl>`) ; ne vous fiez pas au texte exact d'une socket error. |
| Critères d'acceptation | • Le namespace conserve `istio-injection=enabled`<br/>• `PeerAuthentication market-strict` a `STRICT`<br/>• À l'intérieur du mesh, il y a HTTP 200, et l'appel plaintext depuis hors du mesh ne reçoit pas de réponse HTTP réussie (curl échoue, pas de 2xx, `exit_code` dans le fichier est non-zero) - indépendamment du texte exact de l'erreur<br/>• Les deux preuves sont enregistrées, `market-inside.txt` contient `exit_code=0`<br/>• Ne remplacez pas le plaintext client par un sidecar : c'est précisément l'absence de sidecar qui démontre le refus de STRICT.<br/>• Le checker répète en outre lui-même AVANT/APRÈS : il bascule temporairement la même policy en `PERMISSIVE`, répète la même requête plaintext et exige 200 - cela démontre que le refus précédent a été causé précisément par STRICT mTLS, et non par un problème indépendant de DNS/network<br/>• Ensuite, le checker rétablit `STRICT` |

<details>
<summary>💡 Indice pour la tâche 6</summary>

Le Service port DOIT s'appeler précisément `http` (et non `market-api` ou autre chose) - Istio utilise la named port convention pour déterminer le protocole et traiter correctement le trafic via le sidecar. `market-client` est créé APRÈS que le namespace a reçu `istio-injection=enabled` - si le Deployment a été créé AVANT ce label, le sidecar ne sera pas ajouté automatiquement, et il faudra recréer le Pod (et non le Deployment) pour l'injection.
</details>

## Vérification

```bash
check_result
```

La vérification contient `0 Init` et six tests obligatoires. Les tests 1-3 vérifient
`RuntimeClass`, le placement et la différence réelle de `uname` ; les tests 4-5 vérifient le status de
WireGuard, la requête inter-nœuds et l'absence du marker dans tcpdump ; le test 6 réexécute les deux
appels mTLS et vérifie les artefacts. Si les Istio Pods sont encore en cours de création, attendez
`kubectl get pods -n market` avec `2/2 Running` sur le workload injected.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=110 make delete_cks_task
```
