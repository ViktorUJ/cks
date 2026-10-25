[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossaire du cours CKS

[← Contenu du cours](README_FR.md) · [Aide-mémoire](CHEATSHEET_FR.md) · [Index de dépannage (RU)](TROUBLESHOOTING_INDEX_RU.md)

Référence alphabétique des termes CKS, conservés en anglais et expliqués en français. La colonne « Chapitres » renvoie aux explications ; « Lab/Tâche » indique les applications pratiques confirmées et reste vide pour les termes purement théoriques. Les exemples prêts à utiliser figurent dans l’[aide-mémoire](CHEATSHEET_FR.md).

| Terme | Description | Chapitres | Lab/Tâche |
|--------|----------|-------|--------------|
| **4C** | Un modèle des couches Cloud, Cluster, Conteneur et Code pour évaluer la sécurité Kubernetes. | [02](02/fr.md) | |
| **Admission control** | Une étape de traitement des requêtes du serveur API après authentification et autorisation, avant que l'objet ne soit stocké dans etcd. | [01](01/fr.md), [20](20/fr.md) | labs/107 (Tâche 6) |
| **Admission policy** | Règle qui autorise, modifie ou rejette une demande Kubernetes API. | [01](01/fr.md), [20](20/fr.md) | labs/107 (Tâche 6), labs/108 |
| **Admission scan** | Une vérification lors de la création de la charge de travail qui utilise les résultats d'analyse ou les attestations associées. | [28](28/fr.md) | |
| **Admission verification** | Vérification obligatoire de l'origine ou de la signature de l'image avant que le serveur API ne conserve un Pod. | [26](26/fr.md) | labs/111 (Tâche 9a) |
| **aescbc** | Un fournisseur de chiffrement de données Kubernetes API utilisant AES-CBC avec un remplissage PKCS#7 ; sa clé est stockée en configuration protégée. Il n'a pas d'authentification de texte chiffré intégrée (pas de HMAC/AEAD) et est considéré comme une option faible/héritée par rapport à `aesgcm` ou KMS v2 car CBC est vulnérable aux attaques padding-oracle. | [21](21/fr.md) | labs/109 (Tâche 2) |
| **aesgcm** | Un fournisseur AEAD AES-GCM pour le cryptage des données API ; les clés nécessitent une rotation programmée. | [21](21/fr.md) | |
| **allow-list / allowlist** | Une liste explicite des actions, sources ou destinations autorisées ; tout ce qui n'est pas répertorié est refusé. | [12](12/fr.md), [15](15/fr.md), [17](17/fr.md) | labs/112 (Tâche 9) |
| **anonymous authentication** | Mappage d'une demande sans informations d'identification sur `system:anonymous` ; généralement désactivé pour les modèles API et kubelet. | [12](12/fr.md) | labs/104 (Tâche 5) |
| **AppArmor** | MAC Linux basé sur le chemin qui limite les opérations de processus à celles autorisées par un profil. | [03](03/fr.md), [16](16/fr.md) | labs/106 (Tâches 1-2) |
| **apparmor_parser** | Un utilitaire pour vérifier, charger, remplacer et décharger les profils AppArmor. | [16](16/fr.md) | labs/106 (Tâche 1) |
| **Artifact** | Résultat d’un build : image OCI, SBOM, chart ou informations de provenance, par exemple. | [25](25/fr.md) | labs/111 |
| **Artifact repository** | Stockage contrôlé des artefacts : registry, dépôt de paquets ou dépôt de charts. | [25](25/fr.md) | |
| **attack surface** | Toutes les interfaces, composants et points d’entrée par lesquels une attaque ou une mauvaise configuration est possible. | [02](02/fr.md), [14](14/fr.md), [24](24/fr.md) | labs/105 |
| **Attribution** | Association d'un événement à un processus, un conteneur, un Pod, une identité, un nœud et une heure. | [30](30/fr.md) | labs/112 (Tâche 6) |
| **audience** | Le destinataire prévu d'un jeton ServiceAccount ; un service ne doit accepter que les jetons avec sa propre audience. | [11](11/fr.md) | labs/104 (Tâche 2) |
| **audit / enforce / warn** | Modes PSA indépendants : enregistrer une violation, rejeter un Pod ou renvoyer un avertissement. | [19](19/fr.md), [31](31/fr.md) | labs/107 (Tâches 1, 3-4) |
| **audit backend** | Un backend de fichier local ou un backend de webhook recevant des événements sélectionnés par une stratégie d'audit. | [32](32/fr.md) | labs/112 (Tâches 4, 8) |
| **audit event** | Un enregistrement de serveur API d'une requête Kubernetes API. | [32](32/fr.md) | labs/112 (Tâche 4) |
| **audit policy** | Règles ordonnées définissant le niveau d'audit et les étapes d'événement exclues. | [32](32/fr.md) | labs/112 (Tâche 4) |
| **auditID** | Un identifiant reliant toutes les étapes d'audit d'une seule demande API. | [32](32/fr.md) | |
| **Base image** | Image dans une instruction `FROM` qui fournit le système de fichiers initial d'une étape de construction. | [24](24/fr.md) | labs/111 (Tâche 3) |
| **Bound ServiceAccount token** | Un jeton TokenRequest API de courte durée lié à un ServiceAccount et un Pod. | [11](11/fr.md) | labs/104 (Tâche 2) |
| **BPF filter** | Un programme de filtrage exécuté par le noyau pour un appel système en mode filtre seccomp. | [17](17/fr.md) | labs/106 (Tâches 4-5) |
| **break-glass access** | Accès privilégié temporaire contrôlé en cas d’urgence ou d’incident. | [10](10/fr.md), [15](15/fr.md) | |
| **Build context** | Ensemble des fichiers transmis au builder ; `.dockerignore` permet de le réduire. | [24](24/fr.md) | |
| **CAP_SYS_ADMIN** | Une capacité Linux trop large, dangereuse pour les charges de travail ordinaires. | [03](03/fr.md) | labs/106 (Tâche 5) |
| **capability** | Un privilège individuel Linux tiré des pouvoirs root ; une ligne de base sécurisée supprime `ALL` et restaure uniquement ce qui est nécessaire. | [03](03/fr.md), [18](18/fr.md) | labs/107 (Tâche 2) |
| **CEL** | Langage d'expression commun, utilisé par le ValidatingAdmissionPolicy intégré. | [20](20/fr.md) | labs/107 (Tâche 6), labs/108, labs/111 (Tâche 9a), labs/112 (Tâche 9) |
| **cgroup** | Un groupe de processus avec des limites et une prise en compte de CPU, de la mémoire, de PIDs et d'autres ressources. | [03](03/fr.md) | |
| **CI gate** | Une vérification obligatoire qui bloque l'étape suivante du pipeline sur un code de sortie non nul. | [27](27/fr.md), [28](28/fr.md) | |
| **Cilium** | Une plateforme de sécurité et Kubernetes CNI basée sur eBPF. | [06](06/fr.md), [23](23/fr.md) | labs/102, labs/110 (Tâche 4) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | Une stratégie Cilium à l’échelle du cluster ; sa vaste portée nécessite un déploiement particulièrement prudent. | [06](06/fr.md) | |
| **CiliumNetworkPolicy (CNP)** | Une ressource de stratégie Cilium avec espace de noms avec des règles L3/L4/L7. | [06](06/fr.md) | labs/102 (Tâche 3) |
| **cipher suite** | Un ensemble d'algorithmes cryptographiques TLS compatibles avec le certificat et les clients. | [09](09/fr.md) | labs/103 (Tâche 5) |
| **CIS Kubernetes Benchmark** | Recommandations CIS pour une configuration sécurisée des composants et nœuds Kubernetes. | [01](01/fr.md), [07](07/fr.md) | labs/103 (Tâches 1, 7) |
| **CKS** | Spécialiste de la sécurité certifié Kubernetes, une certification de sécurité pratique Kubernetes. | [01](01/fr.md), [33](33/fr.md) | |
| **Clair** | Un scanner et indexeur de vulnérabilités basé sur un service pour les images de conteneurs. | [28](28/fr.md) | |
| **complain** | Un mode AppArmor qui enregistre les violations de stratégie sans les bloquer. | [16](16/fr.md) | |
| **condition** | Expression booléenne Falco sur les champs d'événement qui détermine si une règle se déclenche. | [29](29/fr.md) | labs/112 (Tâches 3, 7, 9) |
| **Constraint** | Une instance de modèle Gatekeeper avec des paramètres, une portée correspondante et une action. | [20](20/fr.md) | |
| **ConstraintTemplate** | Un modèle Rego et un schéma de paramètres pour un nouveau type de contrainte Gatekeeper. | [20](20/fr.md) | |
| **container escape** | Échapper à l’isolation attendue du conteneur pour accéder au nœud ou à d’autres ressources de locataire. | [03](03/fr.md) | |
| **Container runtime sandbox** | Un environnement d'exécution ajoutant une limite d'isolation entre une charge de travail et le noyau hôte. | [22](22/fr.md) | labs/110 (Tâches 1-3) |
| **Confidential computing / TEE** | Une zone CPU isolée matériellement (Intel SGX, AMD SEV) protégeant les données en mémoire même de l'hyperviseur et du fournisseur de cloud ; Kubernetes l'expose via un `RuntimeClass` spécial (conteneurs confidentiels), tandis que la garantie matérielle se situe en dehors du Kubernetes API. | [30](30/fr.md) | |
| **context** | Une combinaison nommée de cluster, d'utilisateur et d'espace de noms dans kubeconfig. | [33](33/fr.md) | |
| **Correlation** | Relier les événements provenant de différentes sources dans une seule chronologie des incidents. | [30](30/fr.md) | labs/112 (Tâche 6) |
| **Cosign** | Un outil Sigstore pour signer et vérifier les artefacts OCI. | [26](26/fr.md) | labs/111 (Tâches 7, 9a, 9c) |
| **CRI** | Interface d'exécution du conteneur ; `crictl` accède au runtime via un socket CRI. | [14](14/fr.md), [30](30/fr.md) | labs/112 (Tâche 6) |
| **CRI socket** | Point de terminaison de communication d'exécution kubelet, tel que `/run/containerd/containerd.sock`. | [14](14/fr.md) | |
| **CVE** | Un identifiant pour une vulnérabilité connue publiquement. | [13](13/fr.md), [28](28/fr.md) | labs/111 (Tâche 1) |
| **CycloneDX** | Un format OWASP pour l'inventaire des composants et l'analyse de sécurité dans un SBOM. | [25](25/fr.md), [28](28/fr.md) | labs/111 (Tâche 7) |
| **daemon.json** | Le fichier de configuration du démon Docker, généralement `/etc/docker/daemon.json`. | [14](14/fr.md) | |
| **DaemonSet** | Une charge de travail Kubernetes maintenant un agent Pod sur chaque nœud sélectionné. | [29](29/fr.md) | |
| **defense in depth** | Couches de protection indépendantes qui réduisent l’impact d’une défaillance d’un contrôle. | [01](01/fr.md), [02](02/fr.md) | labs/104 (Tâche 3) |
| **deny-list** | Une stratégie dont l'action par défaut autorise les appels système tandis que des appels système spécifiques sont refusés. | [17](17/fr.md) | |
| **Digest** | L'identifiant SHA-256 immuable d'un manifeste d'image ou d'un artefact particulier, contrairement à une balise mutable. | [09](09/fr.md), [24](24/fr.md), [25](25/fr.md), [26](26/fr.md) | labs/111 (Tâches 3-5, 9c) |
| **distroless** | Une image d'exécution minimale sans gestionnaire de packages et généralement sans shell. | [24](24/fr.md), [31](31/fr.md) | labs/111 (Tâche 7) |
| **docker group** | Un groupe avec un accès au socket Docker qui doit être traité comme équivalent root. | [14](14/fr.md) | labs/105 (Tâche 6) |
| **Docker socket** | `/var/run/docker.sock`, le démon local Docker API ; l'accès est presque équivalent à root sur l'hôte. | [14](14/fr.md) | labs/105 (Tâche 6) |
| **drop-in** | Un fichier de configuration distinct étendant une configuration de base, par exemple systemd ou SSH. | [15](15/fr.md) | |
| **eBPF** | Un mécanisme de noyau Linux pour les programmes restreints ; Cilium l'utilise pour le chemin de données et Falco pour les événements. | [06](06/fr.md), [29](29/fr.md) | labs/112 (Tâche 1) |
| **egress policy** | Une NetworkPolicy spécifiant les connexions sortantes Pod autorisées. | [04](04/fr.md), [05](05/fr.md) | labs/101 (Tâches 2, 4, 6) |
| **encryption at rest** | Chiffrement des données stockées dans etcd, sur disque, dans les instantanés et dans les sauvegardes. | [21](21/fr.md) | labs/109 |
| **EncryptionConfiguration** | Configuration du fournisseur de chiffrement lue par kube-apiserver. | [21](21/fr.md) | labs/109 (Tâche 2) |
| **enforce** | Un mode AppArmor ou PSA qui bloque réellement les violations de stratégie. | [16](16/fr.md), [19](19/fr.md) | labs/106 (Tâche 1), labs/107 (Tâche 1) |
| **Entity** | Un groupe d'adresses Cilium prédéfini, tel que `world`, `cluster` ou `host`. | [06](06/fr.md) | |
| **envelope encryption** | Chiffrer un objet avec un DEK, lui-même protégé par un KEK externe. | [21](21/fr.md) | |
| **evidence** | Un artefact vérifiable confirmant un résultat : un objet API, un journal, un profil, un rapport d'analyseur ou un test réseau. | [33](33/fr.md) | |
| **exemption** | Un contournement étroit de PSA pour un espace de noms, un nom d'utilisateur ou RuntimeClass approuvé ; il n'accorde aucune autorisation RBAC. | [19](19/fr.md) | |
| **Exfiltration** | Transfert non autorisé de données au-delà d'une limite de confiance. | [02](02/fr.md), [30](30/fr.md) | |
| **failurePolicy** | Action du serveur API lorsqu'un webhook/une stratégie n'est pas disponible ou des erreurs : généralement `Fail` ou `Ignore`. | [20](20/fr.md) | labs/107 (Tâche 6) |
| **Falco** | Un moteur de règles d'événements de sécurité d'exécution utilisant les événements du noyau et les métadonnées du conteneur/Kubernetes. | [29](29/fr.md), [30](30/fr.md) | labs/112 (Tâches 1-3, 6-7, 9) |
| **Falco rule override** | Une modification locale d'une condition de règle Falco ou d'exceptions sans modifier l'ensemble de règles du fournisseur. | [29](29/fr.md), [30](30/fr.md) | labs/112 (Tâche 7) |
| **falco_rules.local.yaml** | Le fichier préféré pour les remplacements locaux et les règles Falco personnalisées. | [29](29/fr.md), [30](30/fr.md) | labs/112 (Tâches 3, 7, 9) |
| **False positive** | Un constat inapplicable à une ressource particulière ; cela nécessite une exception étroite et documentée. | [27](27/fr.md) | |
| **fixed version** | Version du composant dans laquelle le fournisseur a corrigé un CVE. | [13](13/fr.md), [28](28/fr.md) | |
| **footprint** | Packages, processus, ports, sockets et configuration qui augmentent la surface d'attaque d'un nœud. | [14](14/fr.md) | labs/105 (Tâches 1-2) |
| **Gatekeeper** | Un moteur de stratégie Kubernetes basé sur OPA avec les modèles `ConstraintTemplate` et `Constraint`. | [20](20/fr.md), [26](26/fr.md) | |
| **Grype** | Un scanner d'écosystème Anchore pour les images de conteneurs et les SBOM. | [28](28/fr.md) | |
| **gVisor** | Un environnement d'exécution sandbox avec un noyau d'espace utilisateur ; son runtime OCI et son gestionnaire CRI sont souvent appelés `runsc`. | [03](03/fr.md), [22](22/fr.md) | labs/110 (Tâches 1-3) |
| **handler** | Le nom d'exécution dans la configuration CRI ; il doit correspondre à `RuntimeClass.spec.handler`. | [22](22/fr.md) | labs/110 (Tâche 1) |
| **Hardware root of trust** | Une chaîne de confiance cryptographique enracinée dans un périphérique physique (TPM/vTPM), utilisée pour vérifier l'intégrité de la chaîne de démarrage des nœuds (BIOS/UEFI → chargeur de démarrage → noyau → runtime) ; la vérification se situe en dehors du Kubernetes API. | [30](30/fr.md) | |
| **host endpoint** | Un point de terminaison de réseau de nœuds, plutôt qu'un Pod ordinaire dans le plan de données CNI. | [05](05/fr.md) | |
| **host firewall** | Filtrage du trafic sur le nœud lui-même, par exemple avec `ufw`, `iptables` ou `nftables`. | [15](15/fr.md) | labs/105 (Tâche 3) |
| **host namespace** | Espace de noms de nœud partagé par un Pod via `hostPID`, `hostNetwork` ou `hostIPC`. | [18](18/fr.md) | labs/101 (Tâche 7) |
| **Host PID** | Le processus conteneur PID dans l'espace de noms du nœud PID, nécessaire pour `/proc` et `strace`. | [30](30/fr.md) | labs/112 (Tâche 6) |
| **HSM (Hardware Security Module)** | Un périphérique physique de stockage de clé cryptographique (par exemple pour une clé privée CA kube-apiserver ou une clé principale KMS) qui empêche l'extraction logicielle de la clé privée. | [21](21/fr.md), [30](30/fr.md) | |
| **Hubble** | Observabilité des flux réseau Cilium. | [06](06/fr.md) | labs/102 (Tâche 5) |
| **identity** | Un identifiant de point de terminaison Cilium dérivé de l'étiquette ; distinct du fournisseur `identity`. | [06](06/fr.md), [21](21/fr.md) | labs/102 |
| **ImagePolicyWebhook** | Un plugin d'admission déléguant les décisions d'image à un backend externe via `ImageReview`. | [26](26/fr.md) | |
| **IMDS** | Métadonnées d'instance Service, point de terminaison des métadonnées d'instance du fournisseur de cloud. | [05](05/fr.md) | labs/101 (Tâche 5) |
| **IMDSv2** | La variante AWS IMDS nécessitant un jeton temporaire pour les demandes de métadonnées. | [05](05/fr.md) | |
| **Immutable infrastructure** | Une approche qui remplace un artefact de production par une nouvelle version vérifiée au lieu de le modifier au moment de l'exécution. | [02](02/fr.md), [31](31/fr.md) | |
| **include** | Une directive chargeant un fichier externe : SSH `Include`, AppArmor `#include` ou `include:` en configuration de contrôle. | [15](15/fr.md), [16](16/fr.md), [27](27/fr.md) | labs/105 (Tâche 5) |
| **Ingress** | Le trafic entrant dans un Pod ou l'objet Kubernetes API achemine un HTTP/HTTPS externe vers un Service ; le contexte détermine le sens. | [04](04/fr.md), [08](08/fr.md) | labs/101 (Tâche 2), labs/103 (Tâche 4) |
| **IngressClass** | Sélection d'une implémentation Ingress, telle que le contrôleur NGINX Ingress. | [08](08/fr.md) | |
| **Inner packet** | Flux Pod-to-Pod d'origine visible avant le chiffrement ou après le déchiffrement. | [23](23/fr.md) | labs/110 (Tâche 5) |
| **ipBlock** | Une règle d'entrée/sortie pour un CIDR ou une IP individuelle ; `except` exclut les adresses et les sous-réseaux. | [04](04/fr.md), [05](05/fr.md) | labs/101 (Tâche 6) |
| **IPsec ESP** | Une charge utile protégée au niveau IP assurant la confidentialité et l’intégrité entre les associations de sécurité. | [23](23/fr.md) | |
| **Kata Containers** | Un runtime lançant un sandbox Pod dans une VM légère avec un noyau invité. | [03](03/fr.md), [22](22/fr.md) | |
| **KEK/DEK** | Clé de cryptage de clé et clé de cryptage de données dans le cryptage d'enveloppe. | [21](21/fr.md) | |
| **kernel module** | Un module de noyau chargeable, unidirectionnel Falco capture les événements. | [29](29/fr.md) | labs/105 (Tâche 7) |
| **Keyless signing** | Signature avec un certificat de courte durée après l'authentification OIDC au lieu d'une clé de signature locale persistante. | [26](26/fr.md) | labs/111 (Tâche 7) |
| **Kill chain** | La séquence des phases d'attaque depuis l'accès initial à un objectif, comme l'exfiltration. | [02](02/fr.md), [30](30/fr.md) | labs/112 (Tâche 6) |
| **kube-bench** | Un outil de vérification de configuration utilisant les profils de référence CIS Kubernetes. | [07](07/fr.md), [33](33/fr.md) | labs/103 (Tâches 1, 7) |
| **kube-linter** | Un linter de graphiques Kubernetes YAML et Helm avec vérifications des meilleures pratiques. | [27](27/fr.md) | labs/111 (Tâche 2) |
| **kubelet** | L'agent de nœud Kubernetes ; son point de terminaison sécurisé écoute généralement sur le port `10250`. | [05](05/fr.md), [07](07/fr.md) | labs/103 (Tâche 2), labs/105 (Tâche 8) |
| **kubesec** | Un scanner de manifeste Kubernetes signalant un score et des contrôles de sécurité. | [27](27/fr.md) | labs/111 (Tâches 2, 4) |
| **Kyverno** | Un moteur de stratégie natif Kubernetes avec des règles YAML : `validate`, `mutate`, `generate` et `verifyImages`. | [20](20/fr.md), [26](26/fr.md), [31](31/fr.md) | labs/108, labs/111 (Tâche 9a), labs/112 (Tâche 9) |
| **L3/L4** | Couche réseau et protocole/port de transport dans une stratégie Cilium. | [06](06/fr.md) | labs/102 (Tâche 2) |
| **L7** | La couche de protocole, telle que la méthode/chemin HTTP ou DNS (le filtrage Kafka Cilium est obsolète). | [06](06/fr.md) | labs/102 (Tâche 3) |
| **lateral movement** | Un attaquant passant d’une charge de travail compromise à d’autres systèmes, données ou identités. | [02](02/fr.md), [04](04/fr.md) | |
| **least privilege** | Accorder à une identité uniquement les autorisations, la portée et la durée minimales nécessaires. | [02](02/fr.md), [10](10/fr.md), [15](15/fr.md) | labs/104 (Tâche 1) |
| **legacy annotation** | Annotation bêta AppArmor obsolète, lue pour la migration mais non utilisée pour le nouveau Pods. | [16](16/fr.md) | |
| **level** | Détails des données dans un événement d'audit : `None`, `Metadata`, `Request` ou `RequestResponse`. | [32](32/fr.md) | labs/112 (Tâche 4) |
| **Linkerd identity** | Une identité Linkerd mTLS, généralement dérivée d'un ServiceAccount. | [23](23/fr.md) | |
| **live-restore** | Un mode Docker permettant aux conteneurs de fonctionner au redémarrage du démon. | [14](14/fr.md) | |
| **Localhost** | Type Kubernetes pour un profil AppArmor/seccomp préchargé sur un nœud. | [16](16/fr.md), [17](17/fr.md) | labs/106 (Tâches 2, 4) |
| **localhostProfile** | Un chemin de profil JSON relatif à la racine kubelet seccomp. | [17](17/fr.md) | labs/106 (Tâche 4) |
| **MAC** | Contrôle d'accès obligatoire, une politique d'accès appliquée en plus de UID/GID et des bits de mode. | [03](03/fr.md), [16](16/fr.md) | |
| **macro** | Fragment nommé réutilisable d'une condition Falco. | [29](29/fr.md) | labs/112 (Tâche 7) |
| **mTLS** | TLS dans lequel le client et le serveur présentent des certificats. | [23](23/fr.md) | labs/110 (Tâche 6) |
| **Multi-stage build** | Un Dockerfile avec des étapes de construction et d'exécution distinctes connectées par `COPY --from=`. | [24](24/fr.md) | |
| **Mutating admission webhook** | Un webhook ajoutant ou modifiant un objet avant validation. | [20](20/fr.md) | labs/108 (Tâche 5) |
| **namespace** | Une vue isolée d'une ressource du noyau pour un groupe de processus ; distinct d’un espace de noms Kubernetes. | [03](03/fr.md) | labs/106 (Tâche 6) |
| **namespaceSelector** | Sélection des espaces de noms Kubernetes par étiquettes pour une règle NetworkPolicy inter-espaces de noms. | [04](04/fr.md) | labs/101 (Tâche 6) |
| **network namespace** | Isolation des interfaces, des routes et de la pile réseau d'un processus. | [03](03/fr.md) | |
| **no_new_privs** | Un indicateur du noyau empêchant des privilèges supplémentaires via `exec` ; activé par `allowPrivilegeEscalation: false`. | [18](18/fr.md) | |
| **Node authorizer** | Un autorisateur pour les actions d'identité kubelet sur les objets Node et Pod dont il a besoin. | [12](12/fr.md) | |
| **Node encryption** | Protection du trafic inter-nœuds ; n’équivaut pas à l’identité d’une charge de travail particulière. | [23](23/fr.md) | labs/110 (Tâches 4-5) |
| **NodeRestriction** | Un plugin d'admission limitant davantage kubelet à son nœud et au Pods qui lui est attribué. | [12](12/fr.md) | |
| **Notary Project / Notation** | Un écosystème de signature OCI avec une politique de confiance X.509 ; L’application de Kubernetes nécessite l’intégration de l’admission. | [26](26/fr.md) | |
| **OCI** | Un standard ouvert pour les formats d'images de conteneurs et d'artefacts utilisés par les registres et les outils de signature. | [25](25/fr.md), [26](26/fr.md) | labs/111 |
| **OPA** | Open Policy Agent, un moteur de stratégie exécutant des règles déclaratives Rego. | [20](20/fr.md), [27](27/fr.md) | |
| **Outer packet** | Un paquet chiffré entre les adresses IP des nœuds sur le réseau physique. | [23](23/fr.md) | labs/110 (Tâche 5) |
| **partial credit** | Crédit pour les parties indépendantes et correctement exécutées d'une tâche. | [33](33/fr.md) | |
| **PeerAuthentication** | Une stratégie Istio entrante mTLS ; `STRICT` rejette le texte en clair. | [23](23/fr.md) | labs/110 (Tâche 6) |
| **Performance-based** | Un format d'examen exigeant des résultats dans un environnement de travail plutôt que de sélectionner des réponses à des tests. | [01](01/fr.md), [33](33/fr.md) | |
| **PID namespace** | Isolation de la liste des processus et du processus PIDs. | [03](03/fr.md) | |
| **Pod UID** | Le UID immuable d'une instance Pod spécifique, plus fiable que son nom pour la corrélation. | [30](30/fr.md) | |
| **podSelector** | Sélection de Pods par étiquettes dans l'espace de noms NetworkPolicy. | [04](04/fr.md) | labs/101 (Tâches 2, 6) |
| **PolicyReport** | Rapport sur les résultats des vérifications de politiques, si le moteur de politiques installe cette API. | [31](31/fr.md) | |
| **private key** | La partie secrète d’une paire de clés asymétriques ; utilisé selon le protocole/outil pour l'identité TLS (chapitres 07 à 08) ou une clé de signature Cosign (laboratoire 111). Les deux nécessitent un accès restreint, généralement `0600`. | [07](07/fr.md), [08](08/fr.md) | labs/111 (Tâche 9a) |
| **profiling** | Points finaux de diagnostic des performances des processus ; désactiver avec `--profiling=false` sauf si nécessaire. | [07](07/fr.md), [12](12/fr.md) | labs/103 (Tâche 3) |
| **projected volume** | Un volume combinant les jetons, ConfigMaps, API descendant et d'autres sources dans des fichiers Pod. | [11](11/fr.md) | labs/104 (Tâche 2) |
| **provenance** | Métadonnées sur la source, les entrées, le générateur et le processus de construction d'un artefact (attestation). L'origine vérifiable est distincte de la vérification simple de la signature : `cosign sign`/`verify` prouve une signature/identité, et non l'intégralité de l'historique de construction ; Sigstore fournit `cosign attest`/`verify-attestation` pour la provenance. | [09](09/fr.md), [25](25/fr.md), [26](26/fr.md) | |
| **provider** | Mécanisme de chiffrement et de déchiffrement des ressources API spécifiées. | [21](21/fr.md) | labs/109 (Tâche 2) |
| **PSA** | Pod Security Admission, le contrôleur d'admission de validation intégré pour PSS. | [19](19/fr.md), [31](31/fr.md) | labs/107 (Tâches 1, 3-4) |
| **PSP** | PodSecurityPolicy, le prédécesseur du PSA supprimé dans Kubernetes 1.25. | [19](19/fr.md) | |
| **PSS** | Normes de sécurité Pod : les profils `privileged`, `baseline` et `restricted` prédéfinis. | [19](19/fr.md) | labs/107 |
| **purl** | URL du package, un identifiant du package comprenant son écosystème et sa version. | [25](25/fr.md) | |
| **re-encryption** | Réécriture des anciens objets API via un nouveau fournisseur ou une nouvelle clé de chiffrement. | [21](21/fr.md) | labs/109 (Tâche 2) |
| **read-only kubelet port** | Un ancien port kubelet non authentifié qui doit être désactivé avec `0`. | [07](07/fr.md), [09](09/fr.md), [12](12/fr.md) | labs/103 (Tâche 2) |
| **read-only root filesystem** | Un mode empêchant les changements de couche d'image ; les écritures autorisées vont aux volumes. | [18](18/fr.md), [31](31/fr.md), [33](33/fr.md) | labs/107 (Tâche 5), labs/112 (Tâche 5) |
| **Registry allowlist** | Une politique autorisant les images uniquement à partir d’identités de registre/référentiel explicitement répertoriées. Spécifiez la correspondance exacte par rapport au préfixe : l'atelier 112 montre que prefix/`startsWith` peut admettre des sosies (`library/busybox-evil` pour `library/busybox`), il utilise donc une correspondance exacte. | [26](26/fr.md) | labs/112 (Tâche 9) |
| **release cadence** | La fréquence des versions mineures et des correctifs. | [13](13/fr.md) | |
| **remediation** | Supprimer un risque en mettant à jour un artefact, une dépendance ou une image de base et en vérifiant le résultat. | [28](28/fr.md) | |
| **Rendered manifest** | Le YAML final après `helm template` ou `kustomize build`, à analyser avant déploiement. | [27](27/fr.md) | |
| **RoleBinding** | Liaison avec espace de noms d'un rôle ou d'un clusterRole à un sujet, tel qu'un ServiceAccount. | [10](10/fr.md), [11](11/fr.md) | labs/104 (Tâche 1) |
| **Rootless Podman** | Un mode Podman dans lequel un utilisateur ordinaire effectue la construction/l'exécution, plutôt qu'un démon root. | [24](24/fr.md) | |
| **rotation** | Renommer et supprimer les anciens fichiers journaux par taille, nombre ou âge. | [21](21/fr.md), [32](32/fr.md) | labs/112 (Tâche 4) |
| **rule** | Un détecteur nommé Falco avec une condition, une sortie et une priorité. | [29](29/fr.md) | labs/112 (Tâches 3, 7, 9) |
| **runtime detection** | Détection du comportement suspect d'un processus en cours d'exécution à l'aide des appels système/eBPF et des métadonnées d'exécution. | [01](01/fr.md), [29](29/fr.md), [30](30/fr.md) | labs/112 |
| **Runtime mutation** | Modification du système de fichiers ou de la configuration d'un conteneur en cours d'exécution. | [31](31/fr.md) | labs/112 (Tâche 5) |
| **runtime overhead** | Correction de CPU/mémoire supplémentaire prise en compte par le planificateur pour Pods d'un RuntimeClass choisi. | [22](22/fr.md) | |
| **RuntimeClass** | Une ressource Kubernetes à l'échelle du cluster sélectionnant un gestionnaire CRI et des contraintes de surcharge/planification facultatives. | [19](19/fr.md), [22](22/fr.md) | labs/110 (Tâche 1) |
| **RuntimeDefault** | Profil fourni par le runtime de conteneur choisi pour AppArmor ou seccomp. | [16](16/fr.md), [17](17/fr.md), [18](18/fr.md) | labs/106 (Tâche 3), labs/107 (Tâche 2) |
| **sandbox pool** | Nœuds dédiés avec runtime, label, taint et capacité préparés. | [22](22/fr.md) | labs/110 |
| **sandboxed runtime** | Un environnement d'exécution avec une limite d'isolation plus forte, tel que gVisor ou Kata Containers. | [03](03/fr.md), [22](22/fr.md) | labs/110 (Tâches 1-3) |
| **SCMP_ACT_ERRNO** | Une action seccomp renvoyant une erreur pour un appel système sans l'exécuter. | [17](17/fr.md) | labs/106 (Tâche 4) |
| **SCMP_ACT_LOG** | Une action seccomp permettant un appel système et demandant la journalisation du noyau. | [17](17/fr.md) | |
| **seccomp** | Un mécanisme Linux filtrant les appels système d'un processus. | [03](03/fr.md), [17](17/fr.md), [18](18/fr.md) | labs/106 (Tâches 3-5, 7) |
| **SECCOMP audit record** | Un enregistrement de noyau/d'audit d'un événement lié à seccomp. | [17](17/fr.md) | |
| **Secret mount** | Monter temporairement un identifiant pour une commande de build sans l'écrire dans la couche finale. | [24](24/fr.md) | |
| **security advisory** | L'avis principal du fournisseur concernant les versions concernées, les conditions d'exploitation, les mesures d'atténuation et une version corrigée. | [13](13/fr.md) | |
| **SecurityContext** | Champs Kubernetes définissant l'identité et les restrictions d'un processus ou Pod. | [18](18/fr.md), [33](33/fr.md) | labs/106, labs/107 (Tâche 2) |
| **self-signed certificate** | Un certificat signé par sa propre clé plutôt que par une autorité de certification de confiance ; adapté aux tests mais non fiable par défaut. | [08](08/fr.md) | labs/103 (Tâche 4) |
| **SELinux** | MAC basé sur des étiquettes avec application de type, complétant les autorisations d'accès ordinaires. | [03](03/fr.md) | |
| **ServiceAccount (SA)** | Une identité avec espace de noms pour Pods et les processus dans Kubernetes API. | [11](11/fr.md), [23](23/fr.md) | labs/104 (Tâches 2-3) |
| **severity** | Classe de gravité d'un résultat : `LOW`, `MEDIUM`, `HIGH` ou `CRITICAL`. | [28](28/fr.md) | labs/111 (Tâche 1) |
| **SHA-256 checksum** | Un résumé de fichier de 256 bits vérifiant l'égalité octet par octet avec un artefact publié. | [09](09/fr.md) | labs/103 (Tâche 6) |
| **shim** | Un processus containerd ou un binaire connectant containerd à un environnement d'exécution particulier. | [22](22/fr.md) | labs/110 (Tâche 1) |
| **Sidecar** | Un proxy ou un autre conteneur d'assistance à côté d'une application qui intercepte ou sert le trafic. | [23](23/fr.md) | labs/110 (Tâche 6) |
| **SLSA** | Un modèle de maturité pour les pratiques de sécurité de la chaîne d'approvisionnement logicielle. | [25](25/fr.md) | |
| **Software supply chain** | Chemin d’accès de la source, des dépendances, des systèmes de build et des artefacts vers une charge de travail en cours d’exécution. | [25](25/fr.md) | labs/111 |
| **SPDX** | Un standard ouvert décrivant les packages, les licences et leurs relations dans un SBOM. | [25](25/fr.md), [28](28/fr.md) | labs/111 (Tâche 6) |
| **SSRF** | Server-Side Request Forgery, une vulnérabilité obligeant un serveur à demander une adresse choisie par un attaquant. | [05](05/fr.md) | labs/101 (Tâche 5) |
| **stage** | Étape de création de l'événement d'audit : `RequestReceived`, `ResponseStarted`, `ResponseComplete` ou `Panic`. | [32](32/fr.md) | labs/112 (Tâche 4) |
| **static analysis** | Vérification des fichiers Docker, des manifestes et des politiques sans exécuter de charge de travail. | [27](27/fr.md) | labs/111 (Tâche 2) |
| **static Pod** | Un Pod à partir d'un manifeste local de nœud, géré par kubelet sans planification via le Kubernetes API. | [07](07/fr.md), [09](09/fr.md), [12](12/fr.md), [32](32/fr.md), [33](33/fr.md) | labs/103, labs/104 (Tâche 5), labs/112 (Tâche 4) |
| **sudoers** | Une politique de commandes qu'un utilisateur peut exécuter en tant qu'autre utilisateur ; modifier avec `visudo`. | [15](15/fr.md) | |
| **SUID/SGID** | Bits de fichiers spéciaux exécutant un programme avec le UID effectif du propriétaire ou le GID du groupe. | [15](15/fr.md) | |
| **support window** | Les branches de version prises en charge reçoivent des correctifs de sécurité. | [13](13/fr.md) | |
| **Syft** | Un outil générant des SBOM à partir d'images, de systèmes de fichiers ou d'archives. | [25](25/fr.md) | labs/111 (Tâche 7) |
| **syscall** | Un appel système par lequel un processus demande une opération au noyau. | [03](03/fr.md), [17](17/fr.md), [29](29/fr.md) | labs/106 (Tâches 4-5) |
| **system:unauthenticated** | Le groupe du sujet anonyme ; les liaisons nécessitent la même révision que celles de `system:anonymous`. | [12](12/fr.md) | |
| **systemd unit** | Une définition d'un service, d'un socket, d'un minuteur ou d'une autre entité gérée par systemd. | [14](14/fr.md) | labs/105 (Tâche 1) |
| **TLS minimum version** | Version minimale de TLS qu'un serveur négociera avec un client. | [09](09/fr.md) | labs/103 (Tâche 5) |
| **TLS Secret** | Un `kubernetes.io/tls` Secret contenant `tls.crt` et `tls.key`. | [08](08/fr.md) | labs/103 (Tâche 4) |
| **TLS termination** | Terminer la négociation TLS et déchiffrer le trafic au niveau d’un contrôleur d’entrée. | [08](08/fr.md) | labs/103 (Tâche 4) |
| **toFQDNs** | Une règle de sortie Cilium utilisant les noms DNS et les réponses DNS observées. | [06](06/fr.md) | labs/102 (Tâche 4) |
| **TokenRequest API** | Un API émettant des jetons ServiceAccount de courte durée. | [11](11/fr.md) | labs/104 (Tâche 2) |
| **Transparent encryption** | Cryptage du chemin de données sans application, Service ou modification d'URL ; Cilium l'applique sur les nœuds. | [23](23/fr.md) | labs/110 (Tâche 4) |
| **triage** | Classer rapidement une découverte ou un événement par source, risque, portée et action suivante. | [33](33/fr.md) | |
| **Trivy** | Un scanner pour les images, les SBOM, les systèmes de fichiers, les secrets et la configuration/IaC. | [28](28/fr.md), [33](33/fr.md) | labs/111 (Tâches 1, 5, 8) |
| **Unconfined** | Pas de filtre seccomp pour un conteneur ; une exception temporaire, pas une référence. | [17](17/fr.md) | labs/106 (Tâche 5) |
| **Unix socket** | Un point de terminaison IPC du système de fichiers local ; ses autorisations déterminent qui peut accéder à un démon API. | [14](14/fr.md) | labs/105 (Tâche 6) |
| **userns-remap** | Une fonctionnalité de démon Docker (`dockerd --userns-remap`) remapping le conteneur UID/GID sur l'hôte au sein de Docker lui-même ; distinct des espaces de noms utilisateur Kubernetes Pod (`hostUsers: false`) testés dans le laboratoire 106. | [14](14/fr.md) | |
| **Validating admission webhook** | Un webhook qui autorise ou rejette un objet. | [20](20/fr.md) | |
| **ValidatingAdmissionPolicy** | Validation CEL intégrée dans le serveur API sans webhook externe ; appliqué via une reliure. | [20](20/fr.md) | labs/107 (Tâche 6) |
| **version skew** | Différence de version autorisée entre les composants Kubernetes ; kubelet ne doit pas être plus récent que le serveur API. | [13](13/fr.md) | |
| **webhook collector** | Un point de terminaison HTTPS recevant des événements d'audit pour un stockage et une analyse centralisés. | [32](32/fr.md) | labs/112 (Tâche 8) |
| **WireGuard** | Un protocole VPN avec des paires de clés homologues ; la clé publique identifie l'homologue autorisé. | [23](23/fr.md) | labs/110 (Tâches 4-5) |
| **Workload identity** | Une identité de charge de travail cryptographiquement vérifiable, généralement liée à ServiceAccount/espace de noms dans un maillage. | [23](23/fr.md) | labs/110 (Tâche 6) |
| **Writable layer** | Un calque mutable ajouté par le runtime sur des calques d’images en lecture seule. | [31](31/fr.md) | |
| **Zero trust** | Rejeter la confiance implicite basée sur le réseau, l'espace de noms ou l'emplacement. | [02](02/fr.md) | |
