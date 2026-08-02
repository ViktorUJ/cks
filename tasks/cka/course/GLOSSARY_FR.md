[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossaire du cours CKA + CKAD

[← Sommaire du cours](README_FR.md) · [CKA](CKA_FR.md) · [CKAD](CKAD_FR.md)

Référentiel alphabétique unique des termes du cours. Le terme est en anglais (comme
dans Kubernetes), la description en français, et la colonne « Chapitres » indique où
le terme est abordé (avec les liens vers les chapitres). Recherche dans la page - Ctrl+F.

| Terme | Description | Chapitres |
|--------|----------|-------|
| **A record / AAAA record** | enregistrement DNS nom → IPv4 / nom → IPv6. | [0.2](00-2-dns/fr.md) |
| **accessModes** | modes d'accès : RWO, ROX, RWX, RWOP. | [25](25/fr.md) |
| **activeDeadlineSeconds** | durée d'exécution maximale de la tâche. | [10](10/fr.md) |
| **Adapter** | conteneur qui convertit la sortie de l'application au format voulu. | [22](22/fr.md) |
| **admin.conf** | kubeconfig de l'administrateur après init. | [35](35/fr.md) |
| **Admission control** | vérification/modification de la requête après authn+authz. | [21](21/fr.md) |
| **aggregation layer** | extension de l'API via un extension-apiserver à soi (par ex. metrics-server). | [41](41/fr.md) |
| **APIService** | objet qui enregistre une API agrégée (`metrics.k8s.io` et autres). | [41](41/fr.md) |
| **allow logic** | les politiques ne font qu'autoriser ; l'interdiction n'existe pas comme règle séparée. | [34](34/fr.md) |
| **allowPrivilegeEscalation** | autorisation/interdiction de l'élévation de privilèges. | [20](20/fr.md) |
| **allowVolumeExpansion** | si l'extension du volume est autorisée. | [25](25/fr.md), [26](26/fr.md) |
| **Ambassador** | conteneur intermédiaire pour les connexions sortantes de l'application. | [22](22/fr.md) |
| **Annotation** | paire clé-valeur pour des données supplémentaires, pas pour la sélection. | [06](06/fr.md) |
| **API deprecation** | déclaration d'une version d'API comme obsolète, avec suppression ultérieure. | [29](29/fr.md) |
| **apiVersion** | version du groupe d'API de l'objet (alpha/beta/stable). | [29](29/fr.md) |
| **Application container** | conteneur principal du Pod, celui qui porte la charge utile. | [04](04/fr.md) |
| **apply** | créer ou mettre à jour un objet d'après un manifeste (idempotent, 3-way merge). | [03](03/fr.md) |
| **args** | remplace le CMD de l'image (les arguments). | [17](17/fr.md) |
| **Authn** | établir qui est l'émetteur de la requête. | [21](21/fr.md) |
| **Authz** | vérifier que l'émetteur a le droit (RBAC). | [21](21/fr.md) |
| **automountServiceAccountToken** | monter ou non le token du SA dans le Pod. | [21](21/fr.md) |
| **averageUtilization** | pourcentage moyen d'utilisation de la ressource visé. | [16](16/fr.md) |
| **backendRefs** | services cibles (avec des poids pour le canary). | [33](33/fr.md) |
| **backoffLimit** | nombre de tentatives en cas d'échec. | [10](10/fr.md) |
| **Bare pod** | Pod créé directement, sans contrôleur ; il n'est pas recréé. | [04](04/fr.md) |
| **base** | manifestes sources communs. | [43](43/fr.md) |
| **Base image** | image de base (`FROM`) sur laquelle commence le build. | [23](23/fr.md) |
| **base64** | encodage des valeurs d'un Secret ; ce n'est PAS du chiffrement. | [19](19/fr.md) |
| **behavior** | réglage fin de la vitesse de scale up/down. | [16](16/fr.md) |
| **Binding** | liaison d'un PV adapté à un PVC (un pour un). | [25](25/fr.md) |
| **Blue** | version en service actuelle ; **Green** - la nouvelle, prête à recevoir le trafic. | [09](09/fr.md) |
| **Blue/Green** | deux environnements complets (l'actuel et le nouveau) avec bascule instantanée du trafic. | [09](09/fr.md) |
| **bootstrap token** | token temporaire pour le join des nœuds (valable ~24 heures). | [35](35/fr.md) |
| **bridge (cni0)** | commutateur logiciel du nœud qui relie les Pods qui s'y trouvent. | [0.7](00-7-netns/fr.md), [30](30/fr.md) |
| **CA** | autorité de certification ; racine de confiance, elle signe les certificats. | [0.3](00-3-tls/fr.md), [39](39/fr.md) |
| **Calico / Cilium / Flannel** | plugins CNI populaires. | [30](30/fr.md), [40](40/fr.md) |
| **Canary** | publication d'une nouvelle version pour une petite part du trafic, avec montée progressive. | [09](09/fr.md) |
| **CIDR** | notation `adresse/N`, où `N` est le nombre de bits du réseau ; plus N est grand, plus le réseau est petit. | [0.1](00-1-net/fr.md), [30](30/fr.md) |
| **CNAME** | enregistrement DNS : alias qui pointe vers un autre nom. | [0.2](00-2-dns/fr.md) |
| **capabilities** | droits séparés issus de la « toute-puissance » de root (drop/add). | [20](20/fr.md) |
| **cgroups** | contrôleurs du noyau qui limitent les ressources du conteneur (cpu, memory, pids, io) ; base des requests/limits. | [0.4](00-4-containers/fr.md), [14](14/fr.md) |
| **cgroup v1 / v2** | ancienne (une hiérarchie par contrôleur) / moderne (hiérarchie unique) versions de cgroups ; v2 par défaut depuis Fedora 31, Ubuntu 22.04, Debian 11, RHEL 9 (cgroup v2 GA dans K8s depuis 1.25). | [0.4](00-4-containers/fr.md) |
| **cgroup driver** | qui configure les cgroups (`systemd` ou `cgroupfs`) ; kubelet et runtime doivent concorder (`SystemdCgroup=true`). | [0.4](00-4-containers/fr.md), [35](35/fr.md) |
| **cert-manager** | opérateur d'émission et de renouvellement automatiques des certificats. | [32](32/fr.md) |
| **cert-manager / Prometheus Operator** | opérateurs populaires. | [41](41/fr.md) |
| **change-cause** | annotation indiquant la raison du changement, pour l'historique. | [08](08/fr.md) |
| **Chart** | paquet : templates de manifestes + values + métadonnées. | [42](42/fr.md) |
| **CKA** | Certified Kubernetes Administrator, examen d'administration du cluster. | [01](01/fr.md) |
| **CKAD** | Certified Kubernetes Application Developer, examen sur l'exécution des applications. | [01](01/fr.md) |
| **Client certificate** | pièce d'identité de l'utilisateur ; CN → le nom, O → le groupe. | [39](39/fr.md) |
| **Cluster Autoscaler** | modifie le nombre de nœuds du cluster. | [16](16/fr.md) |
| **Karpenter** | choisit et démarre des nœuds du type voulu pour les Pods Pending (plus souple que Cluster Autoscaler). | [16](16/fr.md) |
| **Cluster API** | gestion déclarative du cycle de vie des clusters. | [35](35/fr.md), [35B](35-3-design/fr.md) |
| **managed / self-managed** | control plane opéré par le fournisseur (EKS/GKE/AKS) / par vous-même. | [35B](35-3-design/fr.md) |
| **node pool** | groupe de nœuds identiques (profil, zone, spot/on-demand). | [35B](35-3-design/fr.md) |
| **IaC** | infrastructure as code (Terraform/OpenTofu, Ansible). | [35B](35-3-design/fr.md) |
| **GitOps** | git comme source de vérité pour l'état du cluster (Argo CD/Flux). | [35B](35-3-design/fr.md) |
| **cluster-admin / admin / edit / view** | ClusterRole intégrés. | [38](38/fr.md) |
| **Cluster-scoped object** | au niveau du cluster (Node, PV, StorageClass, ClusterRole). | [06](06/fr.md) |
| **ClusterIP** | type par défaut : IP virtuelle interne, accessible seulement dans le cluster. | [07](07/fr.md) |
| **ClusterRole** | permissions sur le cluster / sur les ressources cluster-scoped / pour la réutilisation. | [38](38/fr.md) |
| **ClusterRoleBinding** | liaison d'un rôle à un sujet sur tout le cluster. | [38](38/fr.md) |
| **CNCF** | Cloud Native Computing Foundation, l'organisation derrière Kubernetes et ces certifications. | [01](01/fr.md) |
| **CNI** | interface et plugin du réseau des Pods (Calico, Cilium et autres). | [02](02/fr.md), [30](30/fr.md), [40](40/fr.md) |
| **command** | remplace l'ENTRYPOINT de l'image (ce qui est lancé). | [17](17/fr.md) |
| **completions** | combien de terminaisons réussies sont nécessaires. | [10](10/fr.md) |
| **componentstatuses** | statut global des composants (en cours de dépréciation). | [45](45/fr.md) |
| **concurrencyPolicy** | politique en cas de chevauchement des exécutions d'un CronJob (Allow/Forbid/Replace). | [10](10/fr.md) |
| **Conditions** | états du nœud (Ready, MemoryPressure, DiskPressure, PIDPressure). | [45](45/fr.md) |
| **ConfigMap** | objet contenant de la configuration non secrète (clés-valeurs ou fichiers). | [18](18/fr.md) |
| **configMapGenerator / secretGenerator** | génération de ConfigMap/Secret (avec un hash dans le nom). | [43](43/fr.md) |
| **configMapKeyRef** | prendre une seule clé d'un ConfigMap dans une variable d'environnement. | [18](18/fr.md) |
| **container runtime** | environnement d'exécution des conteneurs (containerd), dialogue via CRI. | [02](02/fr.md) |
| **containerd / CRI-O** | implémentations de CRI (runtimes). | [40](40/fr.md) |
| **context** | ensemble cluster + user + namespace. | [39](39/fr.md) |
| **Context (kubeconfig)** | ensemble cluster + utilisateur + namespace ; se change avec `use-context`. | [03](03/fr.md) |
| **Control plane** | couche de pilotage du cluster (le cerveau) : apiserver, etcd, scheduler, controller-manager. | [02](02/fr.md) |
| **Controller** | programme doté d'une boucle de réconciliation (aligne le réel sur le spec). | [41](41/fr.md) |
| **cordon** | marquer le nœud unschedulable (les nouveaux Pods n'y vont plus). | [36](36/fr.md) |
| **cordon / drain** | marquer le nœud unschedulable / en évacuer les Pods (chapitre 36). | [13](13/fr.md), [36](36/fr.md) |
| **CoreDNS** | serveur DNS du cluster (Deployment dans kube-system derrière le Service kube-dns). | [31](31/fr.md) |
| **Corefile** | configuration de CoreDNS (dans le ConfigMap `coredns`). | [31](31/fr.md) |
| **CrashLoopBackOff** | le conteneur plante et redémarre en boucle. | [04](04/fr.md), [44](44/fr.md) |
| **containerd / CRI-O** | container runtime de haut niveau avec lesquels travaille kubelet. | [0.4](00-4-containers/fr.md), [40](40/fr.md) |
| **CRD** | définition d'un nouveau type d'objets dans l'API. | [41](41/fr.md) |
| **CreateContainerConfigError** | le ConfigMap/Secret référencé par le Pod est absent. | [44](44/fr.md) |
| **CRI** | interface kubelet ↔ environnement d'exécution. | [0.4](00-4-containers/fr.md), [40](40/fr.md) |
| **crictl** | CLI pour manipuler les conteneurs via CRI sur le nœud. | [40](40/fr.md), [45](45/fr.md) |
| **CronJob** | crée des Jobs selon une planification cron. | [10](10/fr.md) |
| **CSI** | standard de raccordement des stockages à Kubernetes. | [26](26/fr.md), [40](40/fr.md) |
| **CSI driver** | implémentation de CSI (provisioner dans la StorageClass). | [40](40/fr.md) |
| **CSR** | demande de signature de certificat via l'API du cluster. | [39](39/fr.md) |
| **certSANs** | noms/adresses supplémentaires dans le certificat de l'apiserver (par ex. le DNS du répartiteur pour la HA). | [35](35/fr.md) |
| **certificatesDir** | répertoire de la PKI du cluster (par défaut `/etc/kubernetes/pki`). | [35](35/fr.md) |
| **Custom Resource** | instance d'un type défini par un CRD. | [41](41/fr.md) |
| **custom-columns** | tableau de sortie personnalisé. | [47](47/fr.md) |
| **DaemonSet** | contrôleur qui maintient un Pod sur chaque nœud (éligible). | [11](11/fr.md) |
| **data / binaryData** | données texte / binaires d'un ConfigMap. | [18](18/fr.md) |
| **Declarative approach** | gestion via des manifestes (`kubectl apply -f`). | [01](01/fr.md), [03](03/fr.md) |
| **default / kube-system / kube-public / kube-node-lease** | namespaces système. | [06](06/fr.md) |
| **default deny** | politique qui bloque tout dans une direction (aucune règle d'autorisation). | [34](34/fr.md) |
| **default SA** | ServiceAccount par défaut présent dans chaque namespace. | [21](21/fr.md) |
| **Default StorageClass** | classe par défaut pour les PVC sans classe explicite. | [26](26/fr.md) |
| **default-deny + DNS** | piège : la politique egress coupe la résolution de noms (chapitre 34). | [34](34/fr.md), [46](46/fr.md) |
| **Deployment** | contrôleur au-dessus du ReplicaSet : réplicas + mises à jour + rollbacks + historique. | [05](05/fr.md) |
| **Desired state** | ce que vous avez décrit dans le manifeste. | [01](01/fr.md) |
| **Destructive operations** | etcd restore, drain : à vérifier avec une attention particulière. | [48](48/fr.md) |
| **distroless / scratch** | images de base minimales, sans le superflu / totalement vide. | [23](23/fr.md) |
| **dnsConfig** | réglage fin du DNS du Pod (y compris `options ndots`), fonctionne avec n'importe quel dnsPolicy. | [31](31/fr.md) |
| **dnsPolicy** | comment le Pod obtient son DNS (ClusterFirst et autres). | [31](31/fr.md) |
| **Dockerfile** | instructions de build de l'image. | [0.4](00-4-containers/fr.md), [23](23/fr.md) |
| **Downward API** | accès du Pod aux informations sur lui-même (`fieldRef`, `resourceFieldRef`). | [17](17/fr.md) |
| **drain** | évacuer les Pods d'un nœud (proprement) et les déplacer sur d'autres. | [36](36/fr.md) |
| **Dynamic provisioning** | création automatique d'un PV en réponse à un PVC. | [26](26/fr.md) |
| **eBPF** | technologie du noyau Linux sur laquelle est construit Cilium. | [30](30/fr.md) |
| **EmptyDir** | volume du Pod pour échanger des fichiers entre conteneurs. | [22](22/fr.md), [24](24/fr.md) |
| **encryption at rest** | chiffrement des Secret dans etcd. | [19](19/fr.md) |
| **External CA mode** | dans `pki/` il n'y a que `ca.crt` sans la clé : kubeadm produit les CSR, la signature et le renouvellement sont à votre charge. | [35](35/fr.md) |
| **endpoint 2379** | port client d'etcd. | [37](37/fr.md) |
| **Endpoints** | liste des adresses des Pods derrière un Service ; vide = rien de rattaché (chapitre 7). | [07](07/fr.md), [46](46/fr.md) |
| **Endpoints / EndpointSlice** | liste des IP des Pods prêts derrière un Service. | [07](07/fr.md) |
| **ENTRYPOINT/CMD** | quoi lancer et avec quels arguments, défini dans l'image. | [17](17/fr.md) |
| **env** | variables d'environnement du conteneur. | [17](17/fr.md) |
| **envFrom + configMapRef** | toutes les clés d'un ConfigMap comme variables d'environnement. | [18](18/fr.md) |
| **Ephemeral volume** | vit aussi longtemps que le Pod (survit au redémarrage du conteneur, mais pas à la suppression du Pod). | [24](24/fr.md) |
| **ephemeral container** | conteneur temporaire pour déboguer un Pod en cours d'exécution (`kubectl debug`). | [04](04/fr.md), [29](29/fr.md) |
| **etcd** | stockage clé-valeur distribué de tout l'état du cluster. | [02](02/fr.md), [37](37/fr.md) |
| **etcdctl** | CLI pour travailler avec etcd ; les snapshots exigent `ETCDCTL_API=3`. | [37](37/fr.md) |
| **Events** | chronologie des actions sur un objet dans la sortie de `describe`/`get events`. | [29](29/fr.md), [44](44/fr.md) |
| **eviction** | expulsion des Pods par kubelet quand les ressources du nœud manquent. | [14](14/fr.md) |
| **exec** | exécuter une commande/un shell à l'intérieur du conteneur. | [29](29/fr.md) |
| **exec form** | commande sous forme de liste, sans shell (correct pour les signaux). | [17](17/fr.md) |
| **expandtab** | réglage de vim (des espaces au lieu des tabulations) pour le YAML. | [0.8](00-8-vim/fr.md), [47](47/fr.md) |
| **External Secrets / Vault / SOPS / Sealed Secrets** | outils de véritable protection des secrets. | [19](19/fr.md) |
| **ExternalName** | alias DNS (CNAME) vers un domaine externe. | [07](07/fr.md) |
| **FailedScheduling** | événement du planificateur lors d'un Pending. | [44](44/fr.md) |
| **failureThreshold / successThreshold** | nombre d'échecs/de succès pour changer d'état. | [27](27/fr.md) |
| **filters** | transformations (rewrite, redirect, en-têtes). | [33](33/fr.md) |
| **Flat network** | tout Pod voit tout autre Pod par IP directement, sans NAT. | [30](30/fr.md) |
| **Fluent Bit/Fluentd** | agents de collecte de logs (généralement en DaemonSet). | [28](28/fr.md) |
| **Service FQDN** | `<service>.<namespace>.svc.cluster.local`. | [31](31/fr.md) |
| **fsGroup** | groupe propriétaire des volumes montés (niveau du Pod). | [20](20/fr.md) |
| **Gateway** | point d'entrée : listeners (ports, protocoles, TLS) ; appartient à l'opérateur du cluster. | [33](33/fr.md) |
| **Gateway API** | standard moderne de routage du trafic dans Kubernetes. | [33](33/fr.md) |
| **FQDN** | nom de domaine complet avec tous ses niveaux (par ex. `backend.default.svc.cluster.local`). | [0.2](00-2-dns/fr.md), [31](31/fr.md) |
| **GatewayClass** | implémentation (contrôleur) de Gateway API, l'analogue de StorageClass. | [33](33/fr.md) |
| **globalDefault** | PriorityClass appliquée aux Pods sans priorité explicite. | [15](15/fr.md) |
| **HA (high availability)** | tolérance aux pannes du control plane : plusieurs nœuds, la perte de l'un ne casse pas le pilotage. | [35A](35-2-ha/fr.md) |
| **--control-plane-endpoint** | adresse stable du control plane (répartiteur de charge) pour la HA ; se définit au `kubeadm init`. | [35A](35-2-ha/fr.md), [35](35/fr.md) |
| **stacked / external etcd** | etcd sur les nœuds control plane eux-mêmes (par défaut) / sur des nœuds dédiés. | [35A](35-2-ha/fr.md) |
| **quorum (etcd)** | majorité des nœuds etcd nécessaire pour écrire (raft) ; d'où un nombre impair (3/5). | [35A](35-2-ha/fr.md), [37](37/fr.md) |
| **leader election** | choix de l'instance active du scheduler/controller-manager en HA (les autres en réserve). | [35A](35-2-ha/fr.md) |
| **SPOF** | point de défaillance unique ; la HA l'élimine. | [35A](35-2-ha/fr.md) |
| **--upload-certs / certificate-key** | transfert des certificats du control plane lors du join des nœuds HA. | [35A](35-2-ha/fr.md) |
| **Handshake (TLS)** | procédure d'établissement de la connexion TLS (vérification du certificat, négociation de la clé). | [0.3](00-3-tls/fr.md) |
| **Headless Service** | `clusterIP: None`, le DNS renvoie directement les IP des Pods. | [07](07/fr.md), [11](11/fr.md) |
| **Helm** | gestionnaire de paquets pour Kubernetes. | [42](42/fr.md) |
| **helm install/upgrade/rollback/uninstall** | cycle de vie d'une release. | [42](42/fr.md) |
| **helm template** | rendu local du chart en manifestes (pour vérification). | [42](42/fr.md) |
| **hostPath** | montage d'un répertoire du nœud dans le Pod (risqué, réservé aux tâches système). | [24](24/fr.md) |
| **HPA** | modifie le nombre de réplicas selon les métriques. | [16](16/fr.md) |
| **httpGet / tcpSocket / exec / grpc** | méthodes de vérification. | [27](27/fr.md) |
| **HTTPRoute** | règles de routage HTTP vers les services ; appartient au développeur. | [33](33/fr.md) |
| **IgnoredDuringExecution** | la règle est vérifiée à la planification, mais n'expulse pas un Pod déjà démarré. | [12](12/fr.md) |
| **Image** | système de fichiers de l'application empaqueté + dépendances + métadonnées de lancement. | [23](23/fr.md) |
| **ImagePullBackOff/ErrImagePull** | impossible de télécharger l'image. | [44](44/fr.md) |
| **imagePullPolicy** | quand tirer l'image (IfNotPresent/Always/Never). | [23](23/fr.md) |
| **imagePullSecrets** | secret d'accès à un registre d'images privé. | [19](19/fr.md) |
| **immutable** | ConfigMap non modifiable (seulement recréation). | [18](18/fr.md) |
| **Imperative approach** | gestion des objets par commandes (`kubectl run`, `create`). | [01](01/fr.md), [03](03/fr.md) |
| **Ingress controller** | application qui exécute les règles Ingress (nginx, Traefik, ALB). | [32](32/fr.md) |
| **Ingress resource** | déclaration des règles de routage L7 (hôtes, chemins, TLS). | [32](32/fr.md) |
| **ingress2gateway** | utilitaire de conversion automatique d'un Ingress en ressources Gateway API (donne un brouillon, à relire). | [33](33/fr.md) |
| **IngressClass** | quel contrôleur sert cet Ingress (`ingressClassName`). | [32](32/fr.md) |
| **Init container** | conteneur exécuté avant les principaux et qui doit se terminer. | [22](22/fr.md) |
| **initialDelaySeconds** | délai avant la première vérification. | [27](27/fr.md) |
| **IP address** | adresse numérique d'un équipement dans le réseau (IPv4 - 32 bits, quatre octets). | [0.1](00-1-net/fr.md) |
| **ipBlock** | autorisation par plage d'IP (trafic externe). | [34](34/fr.md) |
| **iptables / IPVS modes** | façons d'implémenter les services ; IPVS passe mieux à l'échelle. | [31](31/fr.md) |
| **Job** | contrôleur de tâche ponctuelle ; il veille à la terminaison réussie des Pods. | [10](10/fr.md) |
| **journalctl -u kubelet** | logs de kubelet, principale source des causes d'un NotReady. | [45](45/fr.md) |
| **JSONPath** | langage de sélection de champs dans la réponse de l'API (`-o jsonpath=...`). | [03](03/fr.md), [47](47/fr.md) |
| **KEDA** | autoscaling event-driven sur des événements externes (y compris jusqu'à zéro). | [16](16/fr.md) |
| **kube-apiserver** | point d'entrée unique par lequel passent toutes les requêtes ; le seul à écrire dans etcd. | [02](02/fr.md) |
| **list-watch** | suivi des changements : LIST + flux WATCH (sans interroger l'API en boucle). | [02](02/fr.md) |
| **informer** | cache local des objets du contrôleur, synchronisé via watch. | [02](02/fr.md) |
| **resourceVersion** | version de l'objet ; reprise du watch et base du verrouillage optimiste. | [02](02/fr.md) |
| **optimistic locking** | une écriture avec une version périmée est rejetée (409 Conflict) → nouvelle tentative. | [02](02/fr.md) |
| **kube-controller-manager** | ensemble de contrôleurs (boucles de réconciliation). | [02](02/fr.md) |
| **kube-proxy** | implémente les services via iptables/IPVS sur le nœud. | [02](02/fr.md), [07](07/fr.md), [31](31/fr.md) |
| **kube-scheduler** | affecte les Pods aux nœuds. | [02](02/fr.md), [12](12/fr.md) |
| **kubeadm** | outil officiel d'installation du cluster (init/join/upgrade). | [35](35/fr.md) |
| **kubeadm certs renew** | renouveler les certificats du cluster. | [39](39/fr.md) |
| **kubeadm init** | initialisation du control plane. | [35](35/fr.md) |
| **kubeadm join** | rattachement d'un nœud au cluster. | [35](35/fr.md) |
| **kubeadm reset** | nettoyage de l'état kubeadm sur le nœud. | [36](36/fr.md) |
| **kubeadm upgrade plan / apply / node** | plan / application (premier CP) / mise à jour d'un nœud. | [36](36/fr.md) |
| **kubeconfig** | fichier (`~/.kube/config`) contenant les clusters, les utilisateurs et les contextes. | [03](03/fr.md), [39](39/fr.md) |
| **kubectl** | utilitaire principal en ligne de commande pour travailler avec le cluster. | [01](01/fr.md), [03](03/fr.md) |
| **kubectl apply -k** | appliquer un répertoire Kustomize. | [43](43/fr.md) |
| **kubectl certificate approve** | approuver une CSR (la faire signer par la CA). | [39](39/fr.md) |
| **kubectl debug** | greffer un conteneur de débogage / copier un Pod / déboguer un nœud. | [29](29/fr.md) |
| **kubectl explain** | documentation intégrée sur les champs des objets. | [03](03/fr.md) |
| **kubectl kustomize / kustomize build** | rendu sans application. | [43](43/fr.md) |
| **kubectl logs** | consultation des logs d'un Pod/conteneur. | [28](28/fr.md) |
| **kubectl top** | afficher la consommation de ressources (nécessite metrics-server). | [28](28/fr.md) |
| **kubelet** | agent du nœud, il démarre et surveille les Pods ; service système. | [02](02/fr.md) |
| **Kubernetes** | système d'orchestration de conteneurs : il aligne l'état réel du cluster sur l'état souhaité. | [01](01/fr.md) |
| **kustomization.yaml** | fichier décrivant les ressources et les transformations. | [43](43/fr.md) |
| **Kustomize** | outil d'adaptation des manifestes par superposition de patches, sans templates. | [43](43/fr.md) |
| **Label** | paire clé-valeur pour sélectionner et relier les objets. | [06](06/fr.md) |
| **Labels** | paires clé-valeur sur les objets, c'est sur elles que travaillent les selectors. | [05](05/fr.md) |
| **Layer** | ensemble de modifications du système de fichiers ; les couches sont mises en cache et réutilisées. | [23](23/fr.md) |
| **Layered troubleshooting** | analyse du réseau de bas en haut : CNI → DNS → Endpoints → politique → entrée. | [46](46/fr.md) |
| **LimitRange** | valeurs par défaut et bornes de ressources pour un objet individuel dans un namespace. | [14](14/fr.md) |
| **limits** | plafond de consommation ; vérifié pendant l'exécution. | [14](14/fr.md) |
| **liveness** | le conteneur est-il vivant ; échec → redémarrage. | [27](27/fr.md) |
| **LoadBalancer** | répartiteur de charge cloud externe devant le Service. | [07](07/fr.md) |
| **localhost** | réseau commun du Pod par lequel les conteneurs se voient entre eux. | [22](22/fr.md) |
| **Manifest** | fichier YAML décrivant un objet Kubernetes. | [01](01/fr.md) |
| **matchLabels / matchExpressions** | deux formes de selector. | [06](06/fr.md) |
| **maxSurge** | combien de Pods peuvent être créés au-delà du nombre souhaité pendant un déploiement. | [08](08/fr.md) |
| **maxUnavailable** | combien de Pods peuvent être temporairement perdus pendant un déploiement. | [08](08/fr.md) |
| **medium: Memory** | placement d'un emptyDir en RAM (tmpfs). | [24](24/fr.md) |
| **metrics-server** | collecte le CPU/la mémoire des Pods ; nécessaire au HPA et à `kubectl top`. | [16](16/fr.md), [28](28/fr.md) |
| **Mi/Gi vs M/G** | unités de mémoire binaires (1024) contre décimales (1000). | [14](14/fr.md) |
| **Microsegmentation** | cloisonnement fin du trafic entre Pods/services. | [34](34/fr.md) |
| **milli-CPU** | millième de cœur (`500m` = un demi-cœur). | [14](14/fr.md) |
| **minReplicas/maxReplicas** | bornes basse et haute du nombre de réplicas. | [16](16/fr.md) |
| **Mirror Pod** | reflet d'un static pod dans l'API ; visible, mais non supprimable via kubectl. | [15](15/fr.md) |
| **Mock exam** | répétition chronométrée avec vérification automatique. | [48](48/fr.md) |
| **mTLS** | TLS mutuel : les deux parties présentent un certificat. | [0.3](00-3-tls/fr.md), [39](39/fr.md) |
| **Multi-stage build** | build dans une image, l'image finale ne contient que le résultat. | [23](23/fr.md) |
| **Mutating / Validating admission** | contrôleurs qui modifient / qui vérifient. | [21](21/fr.md) |
| **Namespace** | section du cluster ; les noms des objets y sont uniques. | [06](06/fr.md) |
| **Namespaced object** | vit dans un namespace (Pod, Deployment, Service, ...). | [06](06/fr.md) |
| **namespaceSelector** | sélection des Pods d'après les labels du namespace. | [34](34/fr.md) |
| **NAT** | substitution des adresses sur la passerelle pour que le trafic privé sorte vers l'extérieur. | [0.1](00-1-net/fr.md) |
| **netshoot** | image contenant des outils réseau pour le débogage. | [46](46/fr.md) |
| **NetworkPolicy** | règles définissant quel Pod peut parler à quel autre (pare-feu au niveau des Pods). | [34](34/fr.md) |
| **Node** | machine (VM ou physique) faisant partie du cluster. | [02](02/fr.md) |
| **Node-level work** | SSH + systemctl/journalctl/crictl/etcdctl (spécificité du CKA). | [48](48/fr.md) |
| **nodeAffinity** | sélection souple des nœuds ; `required` (strict) et `preferred` (souple). | [12](12/fr.md) |
| **NodeLocal DNSCache** | cache DNS local sur chaque nœud. | [31](31/fr.md) |
| **nodeName** | affectation stricte d'un nœud en contournant le planificateur. | [12](12/fr.md) |
| **NodePort** | ouvre un port (30000-32767) sur tous les nœuds pour l'accès externe. | [07](07/fr.md) |
| **nodeSelector** | sélection stricte et simple d'un nœud d'après ses labels. | [12](12/fr.md) |
| **NoExecute** | ne pas planifier et expulser les Pods déjà démarrés sans toleration. | [13](13/fr.md) |
| **NoSchedule** | ne pas planifier de nouveaux Pods sans toleration (les anciens restent). | [13](13/fr.md) |
| **NotReady** | statut du nœud quand kubelet ne signale plus sa disponibilité. | [45](45/fr.md) |
| **ndots** | seuil de points dans le nom : en dessous, le nom est d'abord essayé avec les suffixes search (`ndots:5` par défaut → requêtes superflues pour les noms externes). | [31](31/fr.md) |
| **namespaces (Linux)** | isolation de ce que voit un processus : PID, NET, MNT, UTS, IPC, USER (à ne pas confondre avec le namespace Kubernetes). | [0.4](00-4-containers/fr.md) |
| **network namespace** | pile réseau isolée d'un processus/conteneur (ses propres interfaces, IP, routes). | [0.7](00-7-netns/fr.md), [40](40/fr.md) |
| **nslookup/dig** | vérification de la résolution DNS depuis l'intérieur d'un Pod. | [46](46/fr.md) |
| **OCI** | standard ouvert du format des images et des conteneurs (compatibilité Docker ↔ containerd). | [0.4](00-4-containers/fr.md) |
| **OLM** | Operator Lifecycle Manager, mécanisme d'installation/mise à jour des opérateurs. | [41](41/fr.md) |
| **OOMKilled** | conteneur tué pour dépassement de la limite de mémoire. | [04](04/fr.md), [14](14/fr.md), [44](44/fr.md) |
| **Operator** | contrôleur + connaissance métier de la gestion de l'application. | [41](41/fr.md) |
| **operator Equal/Exists** | correspondance par valeur / uniquement par clé. | [13](13/fr.md) |
| **Orchestration** | gestion automatique du cycle de vie des conteneurs (démarrage, redémarrage, mise à l'échelle, placement). | [01](01/fr.md) |
| **overlay** | ensemble de modifications par-dessus la base pour un environnement donné. | [43](43/fr.md) |
| **Overlay network** | réseau avec encapsulation des paquets entre les nœuds (VXLAN). | [30](30/fr.md) |
| **parallelism** | combien de Pods un Job lance simultanément. | [10](10/fr.md) |
| **parentRefs** | rattachement d'une Route à un Gateway. | [33](33/fr.md) |
| **Partial credit** | le travail partiellement réalisé est compté. | [47](47/fr.md) |
| **patches** | modifications ponctuelles de champs (strategic merge / JSON6902). | [43](43/fr.md) |
| **pathType** | mode de correspondance du chemin : Prefix / Exact / ImplementationSpecific. | [32](32/fr.md) |
| **pause container** | conteneur technique qui maintient le network namespace du Pod. | [40](40/fr.md) |
| **Pending** | le Pod n'est pas planifié (ressources/taints/affinity/PVC). | [44](44/fr.md) |
| **periodSeconds** | intervalle entre les vérifications. | [27](27/fr.md) |
| **PersistentVolume** | objet représentant un « morceau de stockage » dans le cluster. | [25](25/fr.md) |
| **PersistentVolumeClaim** | demande de stockage faite par l'application (taille, mode). | [25](25/fr.md) |
| **Phase** | grande étape de la vie d'un Pod : Pending, Running, Succeeded, Failed, Unknown. | [04](04/fr.md) |
| **cluster PKI** | ensemble de CA et de certificats dans `/etc/kubernetes/pki/`, créé lors du `kubeadm init`. | [35](35/fr.md), [39](39/fr.md) |
| **front-proxy-ca** | CA pour l'aggregation layer (extensions de l'API server). | [35](35/fr.md) |
| **sa.key / sa.pub** | paire de clés pour signer les tokens des ServiceAccount. | [35](35/fr.md), [21](21/fr.md) |
| **pluto / kubent** | outils de recherche des API obsolètes dans les manifestes/le cluster. | [29](29/fr.md), [36](36/fr.md) |
| **kubepug (kubectl deprecations)** | vérification des API face à une version cible de K8s (cluster et fichiers). | [29](29/fr.md) |
| **kubeconform** | validateur de manifestes selon les schémas d'une version cible de K8s (CI). | [29](29/fr.md) |
| **Popeye** | sanitizer du cluster ; il détecte notamment les API obsolètes. | [29](29/fr.md) |
| **Pod** | unité d'exécution minimale : enveloppe autour d'un ou plusieurs conteneurs partageant réseau et volumes. | [04](04/fr.md) |
| **Pod CIDR / Service CIDR** | plages d'adresses des Pods / des IP virtuelles des Services ; elles ne doivent pas se chevaucher. | [0.1](00-1-net/fr.md), [30](30/fr.md) |
| **Pod connectivity** | les Pods peuvent-ils communiquer par IP (niveau CNI, chapitre 30). | [30](30/fr.md), [46](46/fr.md) |
| **Pod Security Admission** | politique intégrée avec les niveaux privileged/baseline/restricted. | [20](20/fr.md) |
| **podAffinity** | placer le Pod près des Pods correspondant à des labels. | [12](12/fr.md) |
| **podAntiAffinity** | placer le Pod loin des Pods correspondant à des labels. | [12](12/fr.md) |
| **PodDisruptionBudget** | minimum de Pods disponibles lors d'une expulsion volontaire. | [36](36/fr.md) |
| **podSelector** | à quels Pods la politique s'applique / qui autoriser. | [34](34/fr.md) |
| **policyTypes** | directions : Ingress (entrant) et/ou Egress (sortant). | [34](34/fr.md) |
| **port / targetPort / nodePort** | port du Service / port sur les Pods / port sur les nœuds. | [07](07/fr.md) |
| **port-forward** | redirection d'un port d'un Pod/Service vers la machine locale. | [29](29/fr.md), [46](46/fr.md) |
| **Preemption** | suppression de Pods moins prioritaires pour placer un Pod plus prioritaire. | [15](15/fr.md) |
| **PreferNoSchedule** | éviter souplement de planifier ici. | [13](13/fr.md) |
| **pressure-taints** | taints automatiques quand les ressources du nœud manquent (chapitre 13). | [13](13/fr.md), [45](45/fr.md) |
| **PriorityClass** | objet portant une priorité numérique pour les Pods. | [15](15/fr.md) |
| **privileged** | conteneur privilégié (≈ root sur le nœud) ; dangereux. | [20](20/fr.md) |
| **Probe** | vérification de santé du conteneur, exécutée par kubelet. | [27](27/fr.md) |
| **Progressive delivery** | canary/blue-green automatisés d'après les métriques (Argo Rollouts, Flagger). | [09](09/fr.md) |
| **projected** | volume combinant plusieurs sources (secret/configMap/downwardAPI). | [24](24/fr.md) |
| **Prometheus / Grafana** | collecte/stockage des métriques et visualisation (le vrai monitoring). | [28](28/fr.md) |
| **provisioner** | driver CSI qui crée les volumes réels. | [26](26/fr.md) |
| **PTR** | enregistrement DNS inverse : IP → nom. | [0.2](00-2-dns/fr.md) |
| **QoS class** | Guaranteed / Burstable / BestEffort ; ordre d'expulsion en cas de manque de mémoire. | [14](14/fr.md) |
| **Quorum** | majorité des nœuds etcd nécessaire au fonctionnement (HA). | [37](37/fr.md) |
| **raft** | protocole de consensus par lequel les nœuds etcd se mettent d'accord. | [02](02/fr.md) |
| **RBAC** | contrôle d'accès basé sur les rôles (chapitre 38). | [21](21/fr.md), [38](38/fr.md) |
| **readiness** | prêt à recevoir du trafic ; échec → retrait des Endpoints (sans redémarrage). | [27](27/fr.md) |
| **readOnlyRootFilesystem** | système de fichiers racine en lecture seule. | [20](20/fr.md) |
| **ReadWriteMany** | lecture-écriture depuis plusieurs nœuds (nécessite un système de fichiers réseau). | [25](25/fr.md) |
| **ReadWriteOnce** | lecture-écriture depuis un seul nœud (pas un seul Pod !). | [25](25/fr.md) |
| **reclaimPolicy** | sort du PV après suppression du PVC : Retain / Delete. | [25](25/fr.md) |
| **Reconciliation loop** | cycle continu dans lequel les contrôleurs éliminent l'écart entre l'état souhaité et l'état réel. | [01](01/fr.md) |
| **Recreate** | stratégie « tout supprimer, puis tout créer » ; avec interruption de service. | [08](08/fr.md) |
| **Registry** | dépôt d'images (Docker Hub par défaut) ; un dépôt privé exige un imagePullSecret. | [0.4](00-4-containers/fr.md), [23](23/fr.md) |
| **Release** | instance installée d'un chart (avec l'historique des révisions). | [42](42/fr.md) |
| **replicas** | nombre de Pods souhaité. | [05](05/fr.md) |
| **ReplicaSet** | contrôleur qui maintient un nombre donné de Pods d'après un selector. | [05](05/fr.md) |
| **ReplicationController** | prédécesseur obsolète du ReplicaSet. | [05](05/fr.md) |
| **Repository** | dépôt de charts. | [42](42/fr.md) |
| **requests** | minimum de ressources garanti ; utilisé lors de la planification. | [14](14/fr.md) |
| **required vs preferred** | règle de placement stricte (obligatoire) contre souple (si possible) dans les affinity. | [12](12/fr.md) |
| **ResourceQuota** | limite cumulée de ressources et du nombre d'objets par namespace. | [14](14/fr.md) |
| **restartPolicy** | politique de redémarrage des conteneurs : Always, OnFailure, Never. | [04](04/fr.md) |
| **Return to context** | après une intervention sur un nœud, reprendre sur la machine d'origine. | [48](48/fr.md) |
| **Revision** | version figée du template d'un Deployment dans l'historique. | [08](08/fr.md) |
| **revisionHistoryLimit** | combien d'anciens ReplicaSet conserver pour le rollback. | [08](08/fr.md) |
| **Role** | permissions dans un seul namespace. | [38](38/fr.md) |
| **RoleBinding** | liaison d'un rôle à un sujet dans un namespace. | [38](38/fr.md) |
| **roleRef** | quel rôle le binding référence. | [38](38/fr.md) |
| **rollback** | retour à la révision précédente (`rollout undo`). | [08](08/fr.md) |
| **RollingUpdate** | stratégie de remplacement progressif des Pods sans interruption (par défaut). | [08](08/fr.md) |
| **rollout** | processus de déploiement d'une nouvelle version d'un Deployment. | [08](08/fr.md) |
| **Routed network** | réseau qui connaît les routes vers les Pods directement (BGP). | [30](30/fr.md) |
| **rules** | ce qui est autorisé et sur quoi. | [38](38/fr.md) |
| **runAsNonRoot** | interdiction de s'exécuter en root. | [20](20/fr.md) |
| **runAsUser / runAsGroup** | UID/GID du processus du conteneur. | [20](20/fr.md) |
| **runc** | outil bas niveau de lancement des conteneurs via le noyau. | [0.4](00-4-containers/fr.md), [40](40/fr.md) |
| **Scheduler Profiles** | plusieurs configurations au sein d'un même planificateur. | [15](15/fr.md) |
| **schedulerName** | quel planificateur place le Pod. | [15](15/fr.md) |
| **scope** | portée du CRD : dans un namespace ou sur tout le cluster. | [41](41/fr.md) |
| **search domains** | suffixes dans resolv.conf qui complètent les noms courts. | [0.2](00-2-dns/fr.md), [31](31/fr.md) |
| **Secret** | objet destiné aux données sensibles (mots de passe, tokens, clés, certificats). | [19](19/fr.md) |
| **secretKeyRef / secretRef** | injection d'une clé/de tout un Secret dans env. | [19](19/fr.md) |
| **SecurityContext** | réglages de sécurité au niveau du Pod/du conteneur. | [20](20/fr.md) |
| **selector** | comment le contrôleur trouve « ses » Pods (via les labels). | [05](05/fr.md), [06](06/fr.md) |
| **Selector switch** | changement du `selector` d'un Service pour basculer instantanément le trafic vers une autre version (base du blue/green). | [09](09/fr.md) |
| **SSH** | connexion sécurisée à un nœud par le réseau ; `exit` - pour revenir. | [0.5](00-5-linux/fr.md) |
| **sudo** | exécuter une commande en tant que root ; `sudo -i` - devenir root pour la session. | [0.5](00-5-linux/fr.md) |
| **systemd / systemctl** | système de gestion des services (kubelet, containerd) et la commande associée. | [0.5](00-5-linux/fr.md), [45](45/fr.md) |
| **Service** | adresse stable et répartition de charge devant un groupe de Pods choisis par selector. | [07](07/fr.md) |
| **ServiceAccount** | identité d'un Pod/processus pour accéder à l'API. | [21](21/fr.md) |
| **shell form** | commande via `sh -c` (nécessaire pour les variables, les pipes). | [17](17/fr.md) |
| **Sidecar** | conteneur auxiliaire dans le même Pod (chapitre 22). | [04](04/fr.md), [22](22/fr.md) |
| **snapshot restore** | déploiement d'un snapshot dans un nouveau répertoire de données. | [37](37/fr.md) |
| **snapshot save** | création d'une sauvegarde d'etcd dans un fichier. | [37](37/fr.md) |
| **stabilization window** | fenêtre d'attente avant de réduire le nombre de réplicas. | [16](16/fr.md) |
| **Stable identity** | noms de Pods prévisibles (`db-0`, `db-1`) qui survivent à la recréation. | [11](11/fr.md) |
| **startup** | le démarrage est-il terminé ; bloque les autres probes jusqu'à sa réussite. | [27](27/fr.md) |
| **Stateful** | application avec état ; il lui faut une identité et son propre stockage. | [05](05/fr.md) |
| **StatefulSet** | contrôleur pour les applications avec état : noms stables, ordre, stockage propre à chaque Pod. | [11](11/fr.md) |
| **Stateless** | application sans état propre ; les Pods sont interchangeables. | [05](05/fr.md) |
| **Static Pod** | Pod démarré par kubelet directement depuis un manifeste dans `/etc/kubernetes/manifests/`, sans le planificateur. | [02](02/fr.md), [15](15/fr.md), [45](45/fr.md) |
| **staticPodPath** | dossier surveillé par kubelet (habituellement `/etc/kubernetes/manifests/`). | [15](15/fr.md) |
| **stdout/stderr** | sortie standard du conteneur, d'où Kubernetes récupère les logs. | [28](28/fr.md) |
| **StorageClass** | modèle de création des volumes : provisioner, paramètres, politique de reclaim. | [26](26/fr.md) |
| **stringData** | champ pour les valeurs en clair (encodées automatiquement). | [19](19/fr.md) |
| **subjects** | à qui les droits sont accordés : User, Group, ServiceAccount. | [38](38/fr.md) |
| **suspend** | suspension temporaire d'un CronJob. | [10](10/fr.md) |
| **swapoff** | désactivation du swap (exigence de Kubernetes). | [35](35/fr.md) |
| **Taint** | marque-restriction sur un nœud (`clé=valeur:effet`) qui repousse les Pods. | [13](13/fr.md) |
| **Task weight** | part des points, indice de priorité. | [47](47/fr.md) |
| **TCPRoute / gRPCRoute / TLSRoute** | routage pour les autres protocoles. | [33](33/fr.md) |
| **template** | template de Pod à partir duquel les réplicas sont créés. | [05](05/fr.md) |
| **Three pillars of observability** | logs, métriques, traces. | [28](28/fr.md) |
| **Three-pass strategy** | stratégie de gestion du temps : les faciles → les difficiles → la vérification. | [47](47/fr.md), [48](48/fr.md) |
| **throttling** | ralentissement du conteneur en cas de dépassement de la limite CPU. | [14](14/fr.md) |
| **TLS** | protocole de chiffrement et d'authentification du trafic (le « S » de HTTPS). | [0.3](00-3-tls/fr.md) |
| **TLS termination** | déchiffrement du HTTPS sur l'Ingress ; certificat issu d'un Secret de type tls. | [0.3](00-3-tls/fr.md), [32](32/fr.md) |
| **Toleration** | « laissez-passer » du Pod qui lui permet de rester sur un nœud portant un taint. | [13](13/fr.md) |
| **tolerationSeconds** | combien de temps le Pod tient sur un nœud avec NoExecute avant expulsion. | [13](13/fr.md) |
| **topologyKey** | label du nœud qui définit la « zone de voisinage » (hostname, zone). | [12](12/fr.md) |
| **topologySpreadConstraints** | répartition uniforme des Pods selon la topologie (`maxSkew`). | [12](12/fr.md) |
| **troubleshooting domain** | 30% du CKA, le domaine le plus lourd ; réparer les applications/le cluster/le réseau. | [48](48/fr.md) |
| **TTL** | durée de vie d'un enregistrement DNS dans le cache (en secondes). | [0.2](00-2-dns/fr.md) |
| **ttlSecondsAfterFinished** | suppression automatique d'un Job terminé au bout d'un délai donné. | [10](10/fr.md) |
| **type** | usage du Secret (Opaque, tls, dockerconfigjson et autres). | [19](19/fr.md) |
| **uncordon** | remettre le nœud dans le pool de planification. | [36](36/fr.md) |
| **updateStrategy** | stratégie de mise à jour d'un DaemonSet/StatefulSet (rolling). | [11](11/fr.md) |
| **valueFrom** | remplissage d'une variable depuis une source (champ du Pod, ressources, CM/Secret). | [17](17/fr.md) |
| **Values** | paramètres à substituer dans les templates. | [42](42/fr.md) |
| **VAR** | référence à une variable déclarée plus haut dans le manifeste. | [17](17/fr.md) |
| **veth pair** | deux interfaces virtuelles reliées - le « câble » entre le network namespace du Pod et celui du nœud. | [0.7](00-7-netns/fr.md), [30](30/fr.md) |
| **Version skew** | écart de versions toléré entre composants ; kubelet jamais plus récent que l'apiserver. | [36](36/fr.md) |
| **Volume** | stockage déclaré au niveau du Pod et monté dans les conteneurs. | [24](24/fr.md) |
| **Volume mount** | les clés d'un ConfigMap deviennent des fichiers dans un répertoire. | [18](18/fr.md) |
| **volumeBindingMode** | quand créer/lier le volume (Immediate / WaitForFirstConsumer). | [26](26/fr.md) |
| **volumeClaimTemplates** | template du StatefulSet qui crée un PVC pour chaque Pod. | [11](11/fr.md), [26](26/fr.md) |
| **volumes / volumeMounts** | déclaration du volume / son montage dans le conteneur. | [24](24/fr.md) |
| **VPA** | modifie les requests/limits des Pods. | [16](16/fr.md) |
| **webhook** | vérification/modification externe des objets (Kyverno, OPA, mesh). | [21](21/fr.md) |
| **YAML** | format de manifestes lisible par l'humain ; l'imbrication est donnée par l'indentation (espaces uniquement). | [0.6](00-6-yaml/fr.md), [03](03/fr.md) |
| **whenUnsatisfiable** | mode de topologySpread : `DoNotSchedule` (strict, → Pending) ou `ScheduleAnyway` (souple, avec tolérance au déséquilibre). | [12](12/fr.md) |
| **Worker node** | nœud de travail sur lequel s'exécutent les Pods des applications. | [02](02/fr.md) |
| **Ingress annotations** | réglages spécifiques au contrôleur (rewrite, timeout et autres). | [32](32/fr.md) |
| **Asymmetric cryptography** | paire de clés liées : privée (secrète) et publique (ouverte). | [0.3](00-3-tls/fr.md) |
| **Subnet mask** | quelle partie de l'adresse désigne le réseau et quelle partie l'hôte. | [0.1](00-1-net/fr.md) |
| **Octet** | l'un des quatre nombres d'une adresse IPv4 (8 bits, 0-255). | [0.1](00-1-net/fr.md) |
| **Port** | nombre de 0 à 65535 qui désigne l'application sur l'appareil ; la paire « IP + port » = un service. | [0.1](00-1-net/fr.md) |
| **Private / public key** | clé secrète du propriétaire (jamais transmise) / clé publique (distribuée à tous). | [0.3](00-3-tls/fr.md) |
| **Resolver** | composant qui exécute les requêtes DNS pour l'application (dans le cluster - CoreDNS). | [0.2](00-2-dns/fr.md), [31](31/fr.md) |
| **Certificate** | clé publique + données du propriétaire + signature de la CA. | [0.3](00-3-tls/fr.md), [39](39/fr.md) |
| **Ingress → Gateway API migration** | découpage d'un Ingress en Gateway (l'entrée) + HTTPRoute (les règles). | [33](33/fr.md) |
| **Native sidecar** | init container avec `restartPolicy: Always`. | [22](22/fr.md) |
| **etcd certificates** | CA/cert/key dans `/etc/kubernetes/pki/etcd/`. | [37](37/fr.md) |
| **Kubernetes network model** | exigences réseau : une IP par Pod, communication sans NAT, réseau plat. | [30](30/fr.md) |
| **PV/PVC statuses** | Available, Bound, Pending, Released. | [25](25/fr.md) |
| **Tag / digest** | version de l'image / hash immuable de son contenu. | [23](23/fr.md) |

## Paramètres, flags et codes

Les flags des commandes, les alias-helpers et les codes de réponse sont sortis du
corps de la liste alphabétique des termes.

| Paramètre / code | Description | Chapitres |
|----------------|----------|-------|
| **$do / $now** | helpers `--dry-run=client -o yaml` / suppression rapide. | [47](47/fr.md) |
| **--control-plane-endpoint** | adresse commune du control plane (pour la HA). | [35](35/fr.md) |
| **--data-dir** | répertoire de données d'etcd (nouveau lors d'un restore). | [37](37/fr.md) |
| **--from-file / --from-env-file** | fichier entier dans une clé / ligne par ligne en clés. | [18](18/fr.md) |
| **--ignore-daemonsets** | lors d'un drain, ne pas toucher aux Pods de DaemonSet (ils sont liés au nœud). | [36](36/fr.md) |
| **--pod-network-cidr** | plage d'adresses des Pods (à accorder avec le CNI). | [35](35/fr.md) |
| **--previous** | logs du conteneur précédent (celui qui a planté). | [28](28/fr.md) |
| **--set / -f** | surcharge des values en CLI / par fichier. | [42](42/fr.md) |
| **401 vs 403** | non authentifié (certificat) vs pas de droits (RBAC). | [39](39/fr.md) |
| **`--dry-run=client -o yaml`** | générer le YAML sans rien créer. | [03](03/fr.md) |
