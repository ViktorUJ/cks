[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - solution de référence : System Hardening de l'OS et Docker

> Comment travailler : on se connecte une seule fois au nœud par `ssh` et on exécute les commandes directement dessus (sous
> `sudo -i`, pour ne pas écrire `sudo` avant chaque commande) - c'est plus rapide que d'envoyer
> chaque commande par un `ssh` distinct, et c'est ainsi qu'il convient de travailler à l'examen. Le nom du
> nœud control-plane se voit avec `kubectl get no` :
>
> ```bash
> kubectl get no
> ssh <nom-du-nœud-de-la-sortie>
> sudo -i
> ```
>
> Vérifications et artefacts : le checker lit les artefacts sur la **machine de travail** (`worker`), dans
> `/var/work/tests/artifacts/<numéro>/`, c'est pourquoi après les modifications sur le nœud nous sortons (`exit`, `exit`) et
> enregistrons l'artefact par une commande courte depuis le `worker`. Pour cela, définissez une fois le nom du nœud :
>
> ```bash
> CP=<nom-du-nœud-de-la-sortie>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> Les artefacts ne sont nécessaires que pour la vérification du lab : à l'examen, il n'y en a pas, les commandes sur le
> nœud et une vérification rapide du résultat suffisent. Les commandes enregistrent la sortie dans un fichier (`>`), le contenu se consulte
> séparément via `cat <fichier>` - le résultat attendu est indiqué dans les commentaires `# ...` sous le bloc.
>
> Pour le Docker-host, on entre de la même façon : `ssh docker-host`, puis `sudo -i`.

## 1. Désactiver un service systemd inutile

Le service `cks-lab105-unused.service` n'est pas nécessaire à Kubernetes et augmente la surface
d'attaque. Nous l'arrêtons et interdisons son démarrage automatique.

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

Artefact (sur le `worker`) :

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. Fermer le TCP/8080 inutile

Le port 8080 est ouvert volontairement par le service `cks-lab105-port.service` ; il n'est nécessaire ni au
control-plane ni au kubelet. Nous arrêtons et désactivons le service - les deux actions sont obligatoires,
sinon le listener reviendra après un reboot, même si le port est fermé maintenant.

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # sortie vide - le port est fermé
exit
exit
```

Artefacts (sur le `worker`) :

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# le port a déjà été vérifié sur le nœud (`ss -ltn | grep 8080` - vide), nous consignons le résultat :
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. Limiter le trafic entrant avec UFW

Nous déterminons d'abord la topologie et les sources nécessaires. C'est un control-plane mono-nœud,
qui exécute aussi des workloads. Le worker doit avoir un accès SSH et API ; le Pod CIDR et le
nœud lui-même, un accès API. Il n'y a pas ici de flows kubelet/CNI inter-nœuds. Nous n'ouvrons pas `22`/`6443` à
`Anywhere`.

Sur le `worker`, nous relevons visuellement les valeurs nécessaires :

```bash
kubectl get no -o wide                                      # INTERNAL-IP du nœud
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # IP du worker
```

Nous les notons dans le preflight (remplacez par vos valeurs ; la ligne `role=` est obligatoire) :

```bash
WORKER_IP=<ip-worker>; NODE_IP=<internal-ip-du-nœud>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

Baseline AVANT UFW : nous vérifions que TCP/10250 (kubelet HTTPS) est réellement accessible maintenant - sans
cela, le « bloqué » après UFW ne démontre rien, le port pouvait être indisponible pour une autre
raison (security group, routing). Le checker effectue séparément sa propre comparaison avec son baseline, mais votre
enregistrement est aussi nécessaire :

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - le port est accessible (n'importe quel 1xx-5xx convient, y compris 401/403)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

Si le baseline est inaccessible (curl a renvoyé `000`), corrigez d'abord la connectivité, sinon le résultat
après UFW ne sera pas convaincant.

Les règles UFW se configurent sur le nœud. D'abord, nous autorisons le recovery et les sources nécessaires, et ce n'est qu'ensuite
que nous changeons le default. Les valeurs `WORKER_IP`/`NODE_IP`/`POD_CIDR` sont prises dans `preflight.txt`
(remplacez par les vôtres) :

```bash
ssh "$CP"
sudo -i
WORKER_IP=<worker_ip>; NODE_IP=<node_ip>; POD_CIDR=<pod_cidr>
ufw allow from "$WORKER_IP" to any port 22 proto tcp comment 'CKS105 worker SSH recovery'
ufw allow from "$WORKER_IP" to any port 6443 proto tcp comment 'CKS105 worker API'
ufw allow from "$NODE_IP" to any port 6443 proto tcp comment 'CKS105 node API'
ufw allow from "$POD_CIDR" to any port 6443 proto tcp comment 'CKS105 Pod API'
ufw allow in on lo comment 'CKS105 loopback'
ufw default allow outgoing
ufw default deny incoming
ufw --force enable
ufw status verbose
exit
exit
```

Artefacts (sur le `worker`). `ufw show added` est la représentation normalisée des règles que
vous avez réellement ajoutées (la forme/l'ordre d'origine des commandes n'est PAS garanti : UFW les normalise à
l'affichage). La vérification compare précisément cette liste avec l'allowlist attendu - enregistrez-la
aussi, c'est l'evidence la plus fiable de l'exact allow-set. Gérez le firewall uniquement via `ufw` :
NE modifiez PAS `/etc/ufw/before*.rules` ni `/etc/ufw/after*.rules` à la main, ce sont des
framework-files avec les default-règles communes, et non un endroit pour des source-scoped rules ; le checker
compare leur hash avec le bootstrap-baseline propriété du checker et remarquera la modification directe.

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# À exécuter depuis une SSH/console session encore ouverte en cas de perte de l'API :
sudo ufw disable
sudo ufw status verbose
# corriger les allow rules étroites, vérifier source IP/CIDR
sudo ufw --force enable
# Si les règles sont complètement endommagées, uniquement via la console/recovery channel :
sudo ufw --force reset
EOF
```

Nous vérifions que le cluster est sain (depuis le `worker`) :

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# Le workload à l'intérieur du cluster doit continuer à résoudre le DNS et à atteindre l'API server
# (UFW ne doit pas casser le trafic Pod -> CoreDNS ni Pod -> API) :
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # doit renvoyer l'Address du service kubernetes
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # n'importe quel code, sauf 000

# Le flow indésirable worker -> kubelet ne doit pas donner de HTTP response.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - transport deny
```

Retest E2E complet obligatoire APRÈS `ufw reload` : démontre que le ruleset survit au
reload, et ne fonctionne pas seulement en mémoire juste après `ufw enable`. Sans cette étape, on peut
obtenir par hasard un faux PASS juste après enable :

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# Nous répétons les deux mêmes vérifications du workload après le reload :
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# Le même contrat qu'avant le reload : le worker n'atteint toujours pas le kubelet.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

Vérification declared vs effective : `ufw show added` est la liste déclarative, reconstruite
à partir des métadonnées `### tuple ###`, que ufw écrit lui-même dans `user.rules` lors de l'ajout d'une règle
via la CLI. L'état réel du noyau après `ufw reload` est ce que montre
`ufw show user-rules`. Comparez non seulement la QUANTITÉ de lignes, mais aussi leur CONTENU
(source/port/proto) : `ufw-user-input` doit montrer le loopback (all, lo) et quatre règles tcp
dpt:22/6443 avec les adresses source exactes, et `ufw6-user-input` - EXACTEMENT une ligne, le même
loopback ACCEPT pour v6 (`ufw allow in on lo` est une règle par interface sans IP explicite,
c'est pourquoi ufw crée toujours aussi bien la version v4 que la version v6). Toute ligne AUTRE ou supplémentaire à cet endroit est
un bypass parasite :

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

Dans la sortie doivent figurer `Status: active`, `Default: deny (incoming)` et les source-scoped rules,
aussi bien dans `ufw status verbose` que dans la liste déclarative `ufw show added`. Ne fermez pas
la SSH session d'origine tant que `/readyz`, nodes, calico-node, le workload (y compris le Pod DNS avant et
après le reload) et les deux vérifications négatives de `10250` (avant et après `ufw reload`, avec le même
contrat CURL_EXIT/HTTPCODE) n'ont pas donné le résultat attendu.

## 4. Protéger le kubeconfig de l'administrateur

`/etc/kubernetes/admin.conf` contient la credential de cluster-admin. Seul root
peut le lire.

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

Artefact (sur le `worker`) :

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. Interdire le root login direct par SSH

Nous modifions la configuration, vérifions la syntaxe avant le reload et appliquons sans couper la session
actuelle.

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

La session actuelle n'est pas coupée par `reload ssh`. Mais pendant le redémarrage de sshd, une nouvelle
connexion au control-plane peut recevoir `Connection refused` pendant 1-2 secondes - c'est
normal et ne signifie pas que la configuration est cassée (elle a déjà été vérifiée par `sshd -t`), il suffit de
répéter la commande.

`sshd -T` sans connection context n'applique pas du tout les blocs `Match` - le man de `sshd(8)`
dit explicitement que `Match` en test mode ne s'applique que lorsque `-C` est passé. C'est pourquoi
nous vérifions via `-C`, en simulant une connexion root réelle depuis le worker (les adresses sont prises dans
`preflight.txt` de la tâche 3) :

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

Artefact (sur le `worker`, après une pause de quelques secondes) :

```bash
# WORKER_IP et NODE_IP - les mêmes valeurs que dans la tâche 3
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. Fermer l'accès non sécurisé au Docker daemon sur `docker-host`

TCP/2375 n'a ni TLS ni authentification : l'accès à celui-ci est pratiquement égal à un accès root à
l'hôte. Nous supprimons le systemd override de lab avec le TCP listener, définissons le propriétaire du unix-socket
via un socket override et retirons `developer` du groupe `docker`.

Nous appliquons les modifications via un `daemon-reload` complet + restart des **deux** units - c'est une
étape obligatoire, et pas simplement « relire la config » : sans un vrai restart, on peut par hasard
« réussir » la vérification si Docker a simplement cessé de répondre (alors TCP/2375 est fermé non pas parce que
`-H tcp://` a été retiré, mais parce que le daemon ne fonctionne pas du tout).

Sur le `docker-host` :

```bash
ssh docker-host
sudo -i
rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf
install -d -m 0755 /etc/systemd/system/docker.socket.d
printf '[Socket]\nSocketGroup=root\nSocketMode=0660\n' > /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf
gpasswd -d developer docker || true
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service
chown root:root /var/run/docker.sock && chmod 660 /var/run/docker.sock
```

Positive control : Docker après le restart FONCTIONNE réellement (il ne se contente pas de ne plus écouter sur 2375 - il doit
fonctionner pleinement via le unix-socket) :

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

Persistent config check : l'unit effective ne contient pas `-H tcp://`, et le socket override définit réellement
les valeurs nécessaires (et ne coïncide pas simplement temporairement avec elles) :

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

Le contrat de la tâche est plus large que le port 2375 : la Docker API ne doit écouter en TCP sur aucun port, et
`docker.socket` ne doit pas contenir de TCP `ListenStream` :

```bash
ss -ltnp | grep dockerd                        # sortie vide (le socket TCP de systemd de docker.socket est détecté par la ligne suivante)
systemctl cat docker.socket | grep ListenStream # uniquement /run/docker.sock (et une réinitialisation vide)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

Artefacts (sur le `worker`) :

```bash
# le port 2375 a déjà été vérifié sur docker-host (`ss -ltnp | grep dockerd` - vide), nous consignons le résultat :
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

Après avoir exécuté toutes les étapes, lancez `check_result`.

## 7. Interdire le chargement du module `sctp`

`sctp` est chargé, mais n'est nécessaire ni à kubeadm, ni à containerd, ni à Calico sur ce nœud. Nous essayons de
décharger le module déjà chargé, puis dans tous les cas nous bloquons le rechargement
aussi bien par `blacklist` que par un override `install`. Les deux directives agissent au niveau de
`modprobe` (alias resolution et un `modprobe sctp` explicite) et éliminent le chemin de chargement habituel ;
elles ne remplacent pas un kernel-level enforcement (`insmod` insère le module directement via syscall
et ne lit pas `modprobe.d`, et `modprobe --ignore-install` peut contourner `install` avec un
accès root égal) - pour ce lab, l'important est d'éliminer précisément le chemin attendu d'autochargement, et non de
modéliser une protection contre un utilisateur qui a déjà root sur le nœud.

**`modprobe -r sctp` peut ne pas fonctionner sur un cluster déjà actif** - c'est attendu et ce n'est
pas une erreur de l'étudiant. Les modules de protocole du noyau (y compris `sctp`) reçoivent une référence persistante
par network-namespace (`try_module_get` dans l'initialisation pernet) pour chaque netns
qui existait déjà au moment du chargement du module - sur ce nœud, des Pods fonctionnent déjà
(calico, coredns, kube-system), donc `sctp` peut rester à l'état `in use` avec un
refcount non nul et un `/sys/module/sctp/holders` VIDE (c'est-à-dire qu'il n'est pas tenu par un autre module :
il n'y a rien à décharger récursivement). On ne peut pas corriger cela sans arrêter tous ces Pods, ce qui n'entre
pas dans la tâche. Ce qui compte, et ce qui est vérifié, c'est ce qui est sous le contrôle de l'étudiant :
le module ne peut pas être chargé DE NOUVEAU.

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # peut être vide ou non - les deux variantes sont admissibles
modprobe --show-config | grep sctp      # install sctp /bin/true et blacklist sctp
exit
exit
```

Artefact (sur le `worker`) : l'état actuel (`absent` ou `present`) et l'override dans la configuration
effective de modprobe :

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (ou lsmod: present - les deux variantes sont admissibles, voir ci-dessus)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` et sysctl sûrs

D'abord, nous corrigeons sysctl - `protectKernelDefaults: true` fera **échouer le kubelet au
démarrage** si les valeurs actuelles du noyau ne coïncident pas avec ses attentes, c'est pourquoi les sysctl
doivent être appliqués avant le redémarrage du kubelet.

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

Maintenant, nous activons `protectKernelDefaults` dans la configuration du kubelet et redémarrons le service :

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

Le nœud doit rester `Ready` (depuis le `worker`) :

```bash
kubectl get no
```

Si le kubelet ne démarre pas après cette étape, vérifiez précisément l'ordre : les sysctl doivent
être appliqués (`sysctl --system`), et pas seulement écrits dans le fichier, avant que le kubelet
ne les vérifie au démarrage.

## 9. Trouver et neutraliser un binaire SUID superflu

`find` montrera à la fois les binaires SUID système (`sudo`, `passwd`, `mount` - nous n'y touchons pas) et
le `/usr/local/bin/cks-lab105-suid-tool` de lab, qui n'est nécessaire à aucun composant
Kubernetes sur ce nœud.

`/var/lib/containerd` est exclu de la sortie : ses chemins de snapshot overlayfs sont le contenu des
couches de container image, et non des binaires installés sur l'hôte, et ils changent lors de tout
pull/extract d'image pendant le lab, indépendamment des actions de l'étudiant.

L'artefact `suid-before.txt` doit être enregistré **avant** la correction (sur le `worker`) :

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

Nous retirons le bit SUID uniquement du fichier de lab (sur le control-plane) et nous nous assurons que les
binaires SUID système ne sont pas touchés - `sudo`/`passwd` doivent conserver le bit SUID, sinon la fonctionnalité
de base de l'OS est cassée :

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

Artefact `suid-after.txt` (sur le `worker`) :

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

Après avoir exécuté toutes les étapes, lancez `check_result`.

## 10. Désactiver les core dumps et protéger les processus SUID

Un core dump peut contenir des secrets et des clés de la mémoire du processus au moment du crash - il faut
l'interdire aussi bien pour les processus ordinaires que pour les processus SUID. `fs.suid_dumpable` est ajouté au même
fichier `/etc/sysctl.d/99-kubernetes.conf` déjà créé dans la tâche 8 - nous ne créons pas de configuration
distincte en conflit.

Sur Ubuntu, `ulimit -c 0` et `fs.suid_dumpable=0` **ne garantissent pas** l'absence de core dump :
`man 5 core` documente explicitement que `RLIMIT_CORE` est ignoré par le noyau si
`kernel.core_pattern` dirige le dump vers un handler userspace via pipe (`|program`).
Ubuntu est configuré ainsi par défaut - le crash est intercepté par Apport et enregistré dans
`/var/lib/apport/coredump/` INDÉPENDAMMENT du `ulimit -c` du processus. La seule façon fiable
est de redéfinir `kernel.core_pattern` lui-même vers un handler délibérément inopérant.

Nous limitons aussi la taille du core dump au niveau des limites de processus - c'est un mécanisme distinct de
`suid_dumpable`/`core_pattern` (soft limit pour les crashs ordinaires avec l'écriture classique
basée sur fichier, si elle est un jour rétablie).

Sur le control-plane :

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` s'applique aux nouvelles login-sessions via PAM, et non aux shells déjà ouverts ;
nous vérifions précisément dans une nouvelle session :

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

Artefact `coredump.txt` (sur le `worker`). Il inclut un controlled crash probe : nous confirmons
qu'après un vrai `SIGSEGV`, AUCUN NOUVEAU core dump conservé n'apparaît dans les répertoires d'Apport
(`/var/lib/apport/coredump`, `/var/crash`) :

```bash
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo su - ubuntu -c 'ulimit -c'" \
  > /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  >> /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" '
before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
sh -c "kill -SEGV \$\$" || true
sleep 2
after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
if [ "$after_count" -le "$before_count" ]; then
  echo "crash-probe: no new retained core dump"
else
  echo "crash-probe: NEW core dump appeared after SIGSEGV"
fi
' >> /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

Après avoir exécuté toutes les étapes, lancez `check_result`.
