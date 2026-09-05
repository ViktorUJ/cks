[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossaire du cours KCSA

Les termes anglais sont conservés dans leur forme d'origine, car ils sont nécessaires pour lire les énoncés et les réponses du KCSA. La description explique leur sens en français, mais ne remplace pas l'entraînement aux termes dans les MCQ anglais (multiple choice question, question à choix multiple).

| Terme | Description | Confusion courante | Chapitres |
|---|---|---|---|
| `4C model` | Modèle des couches Cloud, Cluster, Container et Code pour analyser la protection cloud native. | Ne se limite pas à l'infrastructure cloud. | [03](03/fr.md) |
| `ABAC` | Autorisation selon les attributs de la requête et du sujet. | N'est pas RBAC avec des rôles. | [10](10/fr.md) |
| `Access control` | Restriction de l'accès à une ressource selon des règles et l'identité. | Est plus large que la seule authentication. | [10](10/fr.md) |
| `admission` | Étape de validation ou de modification d'une requête API après authentication et authorization. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [07](07/fr.md) |
| `Admission control` | Étape API après authentication et authorization qui admet ou modifie un objet. | Ne confirme pas l'identity et n'accorde pas de droits. | [11](11/fr.md), [17](17/fr.md) |
| `Admission policy` | Règle déclarative de validation des objets lors de l'admission. | N'est pas une audit policy. | [17](17/fr.md) |
| `Admission webhook` | Webhook externe participant à l'admission mutating ou validating. | N'est pas un webhook réseau de l'application. | [17](17/fr.md) |
| `Alert` | Signal exigeant une attention ou une réaction selon une règle. | Ne remplace pas les logs et métriques primaires. | [18](18/fr.md) |
| `Allowlist` | Liste explicite de sources, actions ou objets autorisés. | N'équivaut pas à l'absence de règles deny. | [09](09/fr.md), [17](17/fr.md) |
| `Anomaly detection` | Détection d'un écart par rapport au comportement attendu. | Une anomalie ne prouve pas à elle seule une attaque. | [18](18/fr.md) |
| `API server` | Composant qui reçoit les requêtes Kubernetes API et coordonne l'accès à l'état. | Ne stocke pas l'état à la place de etcd. | [07](07/fr.md) |
| `Artifact` | Résultat du développement ou de la build, par exemple une image, un package ou un SBOM. | N'est pas nécessairement une container image. | [06](06/fr.md), [17](17/fr.md) |
| `Attack surface` | Ensemble des points par lesquels un système peut être attaqué. | N'est pas une vulnérabilité unique trouvée. | [02](02/fr.md), [16](16/fr.md) |
| `Attack vector` | Chemin ou méthode concrète de réalisation d'une attaque. | Est plus étroit qu'attack surface. | [15](15/fr.md), [16](16/fr.md) |
| `audit` | Mode PSA qui consigne les violations dans l'audit sans refuser la requête. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `Audit backend` | Emplacement configuré de stockage ou de transmission des événements d'audit de l'API Server. | L'API Server crée les événements, le backend les enregistre ou les reçoit. | [14](14/fr.md) |
| `audit event` | Enregistrement de `kube-apiserver` sur le traitement d'une requête Kubernetes API. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [14](14/fr.md) |
| `audit level` | Niveau de détail d'un événement Kubernetes audit, par exemple `Metadata` ou `RequestResponse`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [20](20/fr.md) |
| `Audit logging` | Enregistrement des événements de requêtes vers Kubernetes API. | Ne remplace pas la runtime detection des processus. | [14](14/fr.md) |
| `Audit policy` | Configuration définissant quels événements API enregistrer et avec quel niveau de détail. | N'est pas une admission policy. | [14](14/fr.md) |
| `auditID` | Identifiant reliant les événements des différentes étapes d'une même requête. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [14](14/fr.md) |
| `Authentication` | Établissement de l'identité de l'auteur d'une requête. | Ne répond pas à la question de savoir si l'action est autorisée. | [10](10/fr.md) |
| `Authorization` | Vérification qu'un sujet déjà identifié peut effectuer une action. | N'établit pas l'identity. | [10](10/fr.md) |
| `Authorization mode` | Mécanisme configuré de décision concernant les droits API. | N'est pas une méthode d'authentication. | [10](10/fr.md) |
| `Availability` | Disponibilité de données ou d'un service pour un utilisateur autorisé. | N'équivaut ni à confidentiality ni à integrity. | [02](02/fr.md), [16](16/fr.md) |
| `Backup` | Copie de données destinée à la restauration après perte ou altération. | Le backup doit aussi être protégé comme les données d'origine. | [07](07/fr.md), [12](12/fr.md) |
| `Base64` | Encodage réversible d'octets pour une représentation textuelle. | N'est pas de l'encryption. | [12](12/fr.md) |
| `baseline` | Profil bloquant les chemins courants d'escalade de privilèges. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `Baseline profile` | Niveau PSS qui bloque des configurations dangereuses connues tout en préservant la compatibilité. | N'est pas le restricted profile le plus strict. | [11](11/fr.md) |
| `Bearer token` | Token dont la présentation confère les droits de son détenteur. | N'est pas un mot de passe pouvant être placé sans risque dans le code. | [10](10/fr.md) |
| `bind` | Permission RBAC spéciale permettant de lier une Role/ClusterRole sans posséder soi-même toutes les permissions du rôle lié. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [10](10/fr.md) |
| `blast radius` | Étendue des conséquences de la compromission d'un composant. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [16](16/fr.md) |
| `Bound ServiceAccount token` | Token de courte durée lié à un ServiceAccount et à un Pod. | N'est pas l'ancien token Secret de longue durée. | [10](10/fr.md) |
| `Build provenance` | Provenance contenant des informations sur la build d'un artifact. | N'équivaut ni à une signature ni à un SBOM. | [17](17/fr.md), [19](19/fr.md) |
| `CA` | Autorité de certification à laquelle est confiée l'émission ou la vérification de certificats. | N'est pas une clé privée. | [18](18/fr.md) |
| `capability` | Privilège Linux distinct pouvant être accordé ou retiré indépendamment de l'UID 0. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [09](09/fr.md) |
| `CEL` | Common Expression Language - langage d'expressions intégré à Kubernetes API pour des conditions et règles sans exécuter de code arbitraire. | N'est pas un langage généraliste pour du code arbitraire. | [17](17/fr.md) |
| `Certificate` | Document contenant une clé publique et une identité, signé par une CA de confiance. | Ne contient pas la clé privée. | [18](18/fr.md) |
| `Certificate authority` | Nom complet de CA en tant que partie de confiance de la PKI. | N'est pas n'importe quel certificat TLS. | [18](18/fr.md) |
| `CIA triad` | Trois objectifs de sécurité : confidentiality, integrity et availability. | N'est ni un modèle de menace ni un control. | [02](02/fr.md), [15](15/fr.md) |
| `Cilium` | CNI et ensemble d'outils réseau capables d'appliquer NetworkPolicy. | N'est pas la ressource API NetworkPolicy elle-même. | [13](13/fr.md) |
| `CIS Kubernetes Benchmark` | Ensemble de recommandations pour une configuration Kubernetes sécurisée. | C'est un framework de recommandations, pas un control prêt à l'emploi. | [05](05/fr.md), [19](19/fr.md) |
| `CKS` | Certified Kubernetes Security Specialist, certification pratique performance-based sur la sécurité Kubernetes. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `Cloud` | Couche externe du modèle 4C : infrastructure, IAM et services du fournisseur. | N'est pas synonyme de Kubernetes cluster. | [03](03/fr.md), [04](04/fr.md) |
| `Cloud IAM` | Gestion des identités et droits sur les ressources cloud. | Ne remplace pas Kubernetes RBAC. | [04](04/fr.md) |
| `Cluster-admin` | ClusterRole intégrée dotée de droits illimités sur toutes les ressources du cluster. | Ne doit pas être utilisée comme identity quotidienne. | [10](10/fr.md), [16](16/fr.md) |
| `ClusterRole` | Ensemble d'actions API autorisées sans limite de namespace, pour les ressources du cluster ou tous les namespace. | N'est pas une Role limitée à un namespace. | [10](10/fr.md) |
| `ClusterRoleBinding` | Liaison d'un subject à une ClusterRole à l'échelle du cluster entier. | N'est pas une RoleBinding qui ne s'applique qu'à un namespace. | [10](10/fr.md) |
| `CNI` | Standard et plugins pour connecter les conteneurs au réseau Kubernetes. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [09](09/fr.md), [13](13/fr.md) |
| `Code` | Couche 4C contenant le code source, les dépendances et les pratiques de développement. | N'est pas une image déjà construite. | [03](03/fr.md), [06](06/fr.md) |
| `Compliance` | Conformité aux exigences applicables avec des evidence démontrables. | Ne garantit pas l'absence de tous les risques. | [19](19/fr.md) |
| `Confidentiality` | Protection des données contre la divulgation à des parties non autorisées. | N'équivaut ni à integrity ni à availability. | [02](02/fr.md), [12](12/fr.md) |
| `Container` | Processus isolé avec une image et des contraintes de runtime. | N'est pas un Pod, qui peut contenir plusieurs conteneurs. | [03](03/fr.md), [09](09/fr.md) |
| `container escape` | Sortie d'un processus de l'isolation du conteneur vers les ressources du nœud de travail. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [16](16/fr.md) |
| `Container image` | Modèle immuable de fichiers et métadonnées pour exécuter un conteneur. | N'est pas un container en cours d'exécution. | [06](06/fr.md), [17](17/fr.md) |
| `Container registry` | Service de stockage et de distribution des container images. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `Container runtime` | Couche logicielle qui lance les conteneurs sur un nœud via CRI. | N'est pas kubelet. | [08](08/fr.md) |
| `context` | Sélection de cluster, user et namespace utilisée par `kubectl`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [09](09/fr.md) |
| `Control` | Mesure concrète réduisant la probabilité d'un risque ou ses conséquences. | N'est pas un framework qui structure les mesures. | [05](05/fr.md), [19](19/fr.md) |
| `Control plane` | Ensemble logique des composants gérant l'état de Kubernetes. | N'est pas un worker node. | [07](07/fr.md) |
| `Controller Manager` | Composant exécutant les contrôleurs qui rapprochent l'état de l'état désiré. | Ne choisit pas le nœud d'un Pod. | [07](07/fr.md) |
| `CRI` | Interface Kubernetes entre kubelet et container runtime. | N'est ni CNI ni CSI. | [08](08/fr.md) |
| `CronJob` | Ressource Kubernetes qui crée un Job selon une planification. | Un attaquant peut l'utiliser pour persister dans le cluster, et non uniquement à sa fin prévue. | [16](16/fr.md) |
| `CVE` | Identifiant d'une vulnérabilité publiquement connue. | Un CVE n'équivaut pas à une exploitation prouvée. | [06](06/fr.md), [16](16/fr.md) |
| `Data flow` | Chemin de transfert des données entre les participants du système. | N'est pas une trust boundary, mais peut la traverser. | [15](15/fr.md) |
| `Default deny` | Politique initiale refusant le trafic non explicitement autorisé. | N'équivaut pas à interdire tout accès API. | [13](13/fr.md) |
| `default-deny` | Approche où le trafic dans une direction choisie est refusé jusqu'à ce qu'une politique explicite l'autorise. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [13](13/fr.md) |
| `Defense in depth` | Combinaison de couches de protection indépendantes. | Ne signifie pas dupliquer le même control. | [02](02/fr.md), [05](05/fr.md) |
| `Denial of Service` | Atteinte à la disponibilité par épuisement ou surcharge des ressources. | N'est pas tout fonctionnement lent du système. | [16](16/fr.md) |
| `Deployment` | Ressource Kubernetes de gestion des ReplicaSet et des mises à jour de Pod. | N'est pas une limite de sécurité distincte. | [02](02/fr.md), [09](09/fr.md) |
| `Detection` | Détection d'un événement ou écart déjà observé. | N'empêche pas l'objet avant sa création. | [14](14/fr.md), [18](18/fr.md) |
| `Digest` | Identifiant cryptographique du contenu précis d'un artifact. | Ne prouve ni l'auteur, ni la sécurité, ni l'origine. | [06](06/fr.md), [17](17/fr.md) |
| `distractor` | Proposition de réponse plausible mais incorrecte. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [20](20/fr.md) |
| `Distroless` | Image runtime minimale sans shell ni package manager habituels. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `DNS` | Service de résolution de noms pour les services et adresses externes. | N'est pas un mécanisme de network segmentation. | [09](09/fr.md) |
| `DoS` | Refus de service dû à l'épuisement ou à la surcharge des ressources. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [16](16/fr.md) |
| `Egress` | Trafic réseau sortant d'un Pod sélectionné. | N'est pas le trafic ingress vers un Pod. | [13](13/fr.md), [18](18/fr.md) |
| `Encryption` | Protection cryptographique des données utilisant une clé. | N'équivaut pas à un encoding réversible. | [04](04/fr.md), [12](12/fr.md) |
| `Encryption at rest` | Chiffrement de données enregistrées, par exemple dans etcd. | Ne protège pas une lecture API effectuée par un sujet disposant des droits. | [07](07/fr.md), [12](12/fr.md) |
| `Encryption in transit` | Chiffrement des données pendant leur transfert sur le réseau. | Ne remplace ni authorization ni segmentation. | [04](04/fr.md), [18](18/fr.md) |
| `EncryptionConfiguration` | Configuration de l'API Server pour chiffrer les ressources API dans etcd. | N'est pas une politique RBAC. | [12](12/fr.md) |
| `Endpoint` | Adresse ou point d'accès réseau à un service ou composant. | N'est pas Kubernetes EndpointSlice dans tous les contextes. | [04](04/fr.md), [09](09/fr.md) |
| `enforce` | Mode PSA qui rejette un `Pod` enfreignant les règles. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `envelope encryption` | Approche où les données sont chiffrées par une clé de données, elle-même protégée par une clé KMS. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [12](12/fr.md) |
| `escalate` | Permission RBAC spéciale de créer ou modifier une Role/ClusterRole avec des permissions supérieures à celles du caller. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [10](10/fr.md) |
| `Etcd` | Stockage de l'état du Kubernetes control plane. | N'est pas API Server. | [07](07/fr.md), [12](12/fr.md) |
| `Evidence` | Preuve vérifiable du fonctionnement d'un control ou d'un processus. | N'équivaut pas à l'exigence de compliance elle-même. | [14](14/fr.md), [19](19/fr.md) |
| `Exploit` | Code ou technique qui exploite une vulnérabilité. | Toute vulnerability ne possède pas un exploit connu. | [16](16/fr.md) |
| `External Secrets Operator` | Opérateur qui synchronise les secrets depuis un stockage externe. | Après la synchronisation, les risques du Kubernetes Secret subsistent. | [12](12/fr.md) |
| `Falco` | Outil de runtime detection du comportement des conteneurs et nœuds. | Ne remplace pas l'audit logging des requêtes API. | [16](16/fr.md), [18](18/fr.md) |
| `Firewall` | Control réseau filtrant le trafic à une frontière définie. | N'est pas NetworkPolicy à l'intérieur de Kubernetes. | [04](04/fr.md) |
| `FQDN` | Nom de domaine complet d'une cible réseau. | N'est ni une adresse IP ni une identity. | [09](09/fr.md), [18](18/fr.md) |
| `Framework` | Structure d'évaluation des risques, exigences ou de l'exhaustivité des controls. | N'est pas en soi un control technique. | [05](05/fr.md), [19](19/fr.md) |
| `Grafana` | Outil de visualisation de tableaux de bord et d'alertes à partir de données d'observabilité. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [18](18/fr.md) |
| `gVisor` | Sandbox runtime ajoutant une isolation entre un workload et le noyau du nœud. | Ne remplace ni PSS, ni RBAC, ni NetworkPolicy. | [05](05/fr.md) |
| `hard multi-tenancy` | Isolation de tenants avec des frontières fortes, souvent infrastructurelles. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [05](05/fr.md) |
| `Hash` | Résultat d'une fonction de hachage servant à vérifier l'identité des données. | N'est pas une signature vérifiant l'auteur. | [06](06/fr.md), [17](17/fr.md) |
| `HIPAA` | Régime de protection des informations médicales aux États-Unis. | N'est pas une ressource Kubernetes. | [19](19/fr.md) |
| `hostPath` | Volume montant un chemin du système de fichiers d'un nœud de travail dans un `Pod`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [09](09/fr.md) |
| `Hubble` | Outil d'observation des flux réseau Cilium. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [18](18/fr.md) |
| `Identity` | Représentation du sujet au nom duquel une action est effectuée. | N'équivaut pas à l'ensemble des permissions. | [10](10/fr.md), [18](18/fr.md) |
| `Image digest` | Digest qui fige le contenu précis d'une image. | N'est pas un tag mutable. | [06](06/fr.md), [17](17/fr.md) |
| `Image policy` | Règle d'admission d'une image selon sa source, sa signature ou ses propriétés. | N'est pas un rapport de scanner. | [17](17/fr.md) |
| `image registry` | Stockage de container images et de metadata associées. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [17](17/fr.md) |
| `Image tag` | Étiquette d'image lisible par une personne et susceptible de changer. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `impersonate` | Permission Kubernetes classique d'impersonation d'une autre identity ; dans v1.36 existe aussi la beta ConstrainedImpersonation avec des verbs plus restreints. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [10](10/fr.md) |
| `Incident response` | Préparation et actions de détection, confinement et restauration après un incident. | Ne se limite pas à la collecte des logs. | [14](14/fr.md), [16](16/fr.md) |
| `Ingress` | Trafic réseau entrant vers un Pod sélectionné. | N'est pas l'objet Ingress de routage HTTP. | [13](13/fr.md), [18](18/fr.md) |
| `Integrity` | Propriété des données de rester exactes et non modifiées sans autorisation. | N'équivaut pas à confidentiality. | [02](02/fr.md), [19](19/fr.md) |
| `iptables` | Mode de mise en œuvre de la redirection de trafic `Service` dans `kube-proxy`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [08](08/fr.md) |
| `IPVS` | Mode de répartition `Service` dans `kube-proxy`, obsolescent depuis Kubernetes v1.35. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [08](08/fr.md) |
| `Isolation` | Limitation de l'influence d'un sujet ou workload sur un autre. | Est plus large qu'une seule network segmentation. | [05](05/fr.md), [13](13/fr.md) |
| `KCNA` | Kubernetes and Cloud Native Associate, certification d'introduction générale au cloud native. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `KCSA` | Kubernetes and Cloud Native Security Associate, certification conceptuelle sur la sécurité cloud native et Kubernetes. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `kill chain` | Modèle de séquence des étapes d'une attaque, de l'accès initial à l'impact. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [15](15/fr.md), [19](19/fr.md) |
| `KMS` | Service ou plugin de gestion des clés de chiffrement. | N'est pas lui-même un encryption provider des données. | [12](12/fr.md) |
| `KMS v2` | API actuellement recommandée pour intégrer API Server avec KMS ; KMS v1 est deprecated depuis v1.28 et désactivé par défaut depuis v1.29. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [12](12/fr.md) |
| `kube-apiserver` | Nom complet du processus API Server comme composant du control plane. | N'est ni kubelet API ni kube-proxy. | [07](07/fr.md) |
| `kube-bench` | Outil comparant la configuration des composants Kubernetes aux vérifications CIS Benchmark. | N'évalue pas la logique métier de l'application et ne remplace pas un audit complet. | [05](05/fr.md), [19](19/fr.md) |
| `Kube-proxy` | Composant de nœud configurant les règles du noyau (`iptables`, `nftables`, IPVS) pour le routage vers un `Service` ; n'est pas lui-même un userspace traffic proxy. | N'applique pas NetworkPolicy ; il ne transmet pas les paquets, le noyau le fait. | [08](08/fr.md) |
| `Kubeconfig` | Fichier avec l'adresse du cluster, une CA de confiance et les credentials du client. | N'est pas une configuration inoffensive sans secrets. | [09](09/fr.md) |
| `Kubelet` | Agent de nœud lançant les Pod via le container runtime. | N'est pas scheduler. | [08](08/fr.md) |
| `Kubelet API` | Interface HTTPS de Kubelet pour les opérations et diagnostics sur le nœud. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [08](08/fr.md) |
| `Kubernetes API` | Interface de gestion des ressources du cluster via API Server. | N'est pas kubelet API. | [07](07/fr.md), [10](10/fr.md) |
| `L3/L4/L7` | Niveaux de contrôle : réseau IP, ports de transport et protocole applicatif. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [13](13/fr.md) |
| `lateral movement` | Passage d'un attaquant d'une ressource compromise à une autre. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [15](15/fr.md), [16](16/fr.md) |
| `Least privilege` | Attribution des seuls droits minimaux nécessaires. | Ne signifie pas l'absence de droits pour tous. | [02](02/fr.md), [10](10/fr.md) |
| `level` | Volume de données dans un événement : `None`, `Metadata`, `Request` ou `RequestResponse`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [14](14/fr.md) |
| `LimitRange` | Limites et valeurs par défaut pour les conteneurs d'un namespace. | Ne définit pas le budget total du namespace, contrairement à ResourceQuota. | [11](11/fr.md), [16](16/fr.md) |
| `Log backend` | Récepteur ou stockage de journaux. | N'est pas lui-même la source de tous les événements. | [14](14/fr.md), [18](18/fr.md) |
| `Logging` | Collecte d'enregistrements discrets d'événements. | N'équivaut ni à monitoring ni à l'observability complète. | [14](14/fr.md), [18](18/fr.md) |
| `MCQ` | Multiple choice question - question à choix multiple, format de l'examen KCSA. | N'est pas une tâche hands-on de CKS. | [01](01/fr.md), [20](20/fr.md) |
| `Metric` | Mesure numérique d'un état ou comportement dans le temps. | Ne contient pas le contexte complet d'un log. | [18](18/fr.md) |
| `MITM` | man-in-the-middle, interception ou substitution d'un échange réseau. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [16](16/fr.md) |
| `MITRE ATT&CK` | Base de tactiques et techniques du comportement des attaquants. | N'est pas un preventive control. | [15](15/fr.md), [19](19/fr.md) |
| `MITRE ATT&CK for Containers` | Base de tactiques et techniques décrivant le comportement des attaquants en environnement de conteneurs. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [15](15/fr.md) |
| `mock exam` | Examen d'entraînement imitant le format et la limite de temps. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [20](20/fr.md) |
| `Monitoring` | Observation des indicateurs et seuils connus du système. | Est plus étroit qu'observability. | [18](18/fr.md) |
| `most appropriate` | Indication de choisir la réponse la plus directe et appropriée parmi celles qui sont acceptables par le sens. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [20](20/fr.md) |
| `mTLS` | TLS avec vérification mutuelle des parties de la connexion. | Ne définit pas une allowlist de flux réseau. | [18](18/fr.md) |
| `Multi-stage build` | Build avec un builder stage séparé et un final stage minimal. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `multi-tenancy` | Utilisation d'une même plateforme par plusieurs équipes ou organisations, avec séparation des accès et ressources. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [13](13/fr.md) |
| `multiple choice` | Question avec des propositions parmi lesquelles il faut choisir la plus correcte. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `Mutating admission webhook` | Webhook pouvant modifier un objet avant son enregistrement. | N'est pas validating webhook, qui se contente d'accepter ou refuser. | [17](17/fr.md) |
| `MutatingAdmissionPolicy` | Declarative admission policy CEL intégrée, modifiant les objets API concernés sans webhook séparé. | N'est pas un mutating admission webhook externe. | [17](17/fr.md) |
| `Namespace` | Domaine logique Kubernetes pour les ressources, droits et quotas. | N'est pas en soi une barrière réseau. | [05](05/fr.md), [13](13/fr.md) |
| `Network segmentation` | Séparation des chemins réseau entre zones ou workload. | N'est pas synonyme de l'isolation globale. | [13](13/fr.md), [18](18/fr.md) |
| `NetworkPolicy` | Ressource API décrivant les ingress et egress autorisés d'un Pod. | Ne remplace ni kube-proxy, ni RBAC, ni TLS. | [13](13/fr.md) |
| `nftables` | Mode `kube-proxy` ; sur Linux pris en charge, recommandé en remplacement d'IPVS deprecated. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [08](08/fr.md) |
| `Node` | Machine de travail ou de control plane Kubernetes. | N'est pas un Pod. | [07](07/fr.md), [08](08/fr.md) |
| `Node authorization` | Mécanisme d'authorization des requêtes API du kubelet. | N'est pas un Node object. | [08](08/fr.md), [10](10/fr.md) |
| `Observability` | Capacité à comprendre l'état d'un système à partir de logs, métriques et traces. | Ne se limite pas à un seul tableau de monitoring. | [18](18/fr.md) |
| `OIDC` | Protocole d'identification permettant à API Server de faire confiance à un issuer externe. | N'est pas une authorization OAuth générique de Kubernetes. | [10](10/fr.md) |
| `OPA` | Policy engine généraliste, souvent appliqué via Gatekeeper. | N'est pas la ValidatingAdmissionPolicy intégrée. | [17](17/fr.md) |
| `OpenID Connect` | Nom complet d'OIDC comme couche d'identification au-dessus d'OAuth 2.0. | Ne remplace pas une décision RBAC. | [10](10/fr.md) |
| `OWASP Kubernetes Top 10` | Catalogue OWASP de classes courantes de risques Kubernetes (Open Worldwide Application Security Project, projet ouvert de sécurité des applications web). | N'est pas une liste de champs YAML obligatoires. | [05](05/fr.md) |
| `PeerAuthentication` | Ressource Istio définissant le mode de réception mTLS pour un service mesh ou une partie de celui-ci. | `STRICT` exige mTLS mais ne remplace ni authorization ni NetworkPolicy. | [18](18/fr.md) |
| `performance-based` | Format qui évalue une action pratique réalisée dans un environnement, et pas seulement une réponse choisie. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `persistence` | Capacité de l'attaquant à conserver l'accès après suppression du point d'entrée initial. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [16](16/fr.md) |
| `PKI` | Infrastructure de clés, certificats et chaînes de confiance. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [18](18/fr.md) |
| `Pod` | Plus petite unité Kubernetes déployable, avec un ou plusieurs conteneurs. | N'est pas un container individuel. | [09](09/fr.md), [11](11/fr.md) |
| `Pod Security Admission` | Mécanisme admission intégré d'application des Pod Security Standards. | N'est pas le PSP supprimé. | [11](11/fr.md) |
| `Pod Security Standards` | Ensemble des niveaux privileged, baseline et restricted pour les configurations de Pod. | N'est pas un admission plugin concret. | [11](11/fr.md) |
| `Policy` | Règle définissant le comportement souhaité ou permis. | Toute policy n'est pas techniquement enforce-ée d'elle-même. | [13](13/fr.md), [17](17/fr.md) |
| `policy engine` | Mécanisme appliquant des règles aux objets API, souvent dans l'admission path. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [05](05/fr.md) |
| `Private key` | Clé cryptographique secrète utilisée pour la signature ou l'authentication. | Ne doit pas être publiée avec le certificate. | [09](09/fr.md), [18](18/fr.md) |
| `privileged` | Mode de conteneur avec des droits très étendus vis-à-vis de l'hôte. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [09](09/fr.md), [11](11/fr.md) |
| `proctored` | Examen dont le respect des règles est contrôlé par un surveillant. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `proctoring` | Procédure d'examen surveillée selon les règles du fournisseur. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [20](20/fr.md) |
| `Prometheus` | Système de collecte et de stockage de métriques. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [18](18/fr.md) |
| `Provenance` | Enregistrement de l'origine d'un artifact, de ses sources et de son processus de création. | N'équivaut ni à digest, ni à signature, ni à SBOM. | [17](17/fr.md), [19](19/fr.md) |
| `PSA` | Pod Security Admission, admission controller intégré appliquant PSS. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `PSP` | Mécanisme PodSecurityPolicy supprimé depuis Kubernetes v1.25. | N'est pas le remplacement actuel de PSA. | [11](11/fr.md) |
| `PSS` | Pod Security Standards, trois profils de sécurité standard pour `Pod`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `Public key` | Partie publique d'une paire de clés, pour vérifier une signature ou chiffrer. | Ne doit pas être conservée comme une private key. | [18](18/fr.md) |
| `RBAC` | Authorization par rôles et liaisons des sujets aux droits. | N'est pas authentication. | [10](10/fr.md) |
| `RCE` | remote code execution, exécution de code à distance via une vulnérabilité. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [16](16/fr.md) |
| `Registry` | Registre servant à stocker et fournir des container images. | Ne confirme pas automatiquement la sécurité d'une image. | [06](06/fr.md), [17](17/fr.md) |
| `ResourceQuota` | Limite de consommation globale des ressources dans un namespace. | Ne définit pas les limites d'un container, contrairement à LimitRange. | [13](13/fr.md), [16](16/fr.md) |
| `restricted` | Profil strict de least privilege pour les workloads applicatifs. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `Risk` | Combinaison de la probabilité d'un événement indésirable et de ses conséquences. | N'est ni une threat ni une vulnerability. | [15](15/fr.md), [19](19/fr.md) |
| `Role` | Ensemble d'actions API autorisées dans un namespace. | N'accorde pas de droits sans RoleBinding. | [10](10/fr.md) |
| `Role / ClusterRole` | Ensemble de règles dans un namespace / à l'échelle du cluster. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [10](10/fr.md) |
| `RoleBinding` | Liaison d'un subject à une Role ou ClusterRole dans un namespace. | N'est pas l'authentication elle-même. | [10](10/fr.md) |
| `RoleBinding / ClusterRoleBinding` | Liaison d'un rôle à un utilisateur, groupe ou `ServiceAccount`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [10](10/fr.md) |
| `Runtime class` | Sélection d'une classe runtime pour exécuter un Pod. | N'est pas de la runtime detection. | [05](05/fr.md), [09](09/fr.md) |
| `Runtime detection` | Détection du comportement des processus après le lancement d'un workload. | Ne remplace pas l'audit logging des requêtes API. | [16](16/fr.md), [18](18/fr.md) |
| `runtime socket` | Socket Unix par lequel un client contrôle le container runtime. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [08](08/fr.md) |
| `Sandbox` | Frontière d'exécution renforcée pour un workload non fiable. | Ne remplace pas least privilege. | [05](05/fr.md) |
| `SAST` | Analyse statique du code sans exécuter l'application. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `SBOM` | Inventaire des composants et dépendances d'un artifact logiciel. | N'équivaut ni à signature ni à provenance. | [06](06/fr.md), [17](17/fr.md) |
| `SCA` | Analyse des dépendances et de leurs risques connus. | N'est pas un runtime scanner. | [06](06/fr.md) |
| `Scheduler` | Composant sélectionnant le nœud d'un nouveau Pod. | Ne lance pas les conteneurs sur le nœud. | [07](07/fr.md) |
| `Secret` | Objet Kubernetes API pour de petites données sensibles. | Base64 dans `data` n'est pas de l'encryption. | [12](12/fr.md) |
| `Secret scanning` | Recherche de credentials et autres secrets dans le code, l'historique et les artifacts. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `SecurityContext` | Paramètres de privilèges et contraintes d'un processus ou Pod. | Ne remplace ni PSS, ni RBAC, ni NetworkPolicy. | [09](09/fr.md), [11](11/fr.md) |
| `Segmentation` | Division d'un système en zones aux interactions limitées. | C'est une manière d'obtenir isolation, pas son synonyme complet. | [13](13/fr.md), [15](15/fr.md) |
| `Service identity` | Identité de service : compte d'un composant ou workload avec lequel il accède à l'API. | N'est pas l'identité d'un opérateur humain. | [07](07/fr.md) |
| `Service mesh` | Couche d'infrastructure pour la connectivité, l'identity des services et souvent mTLS. | Ne remplace pas NetworkPolicy. | [18](18/fr.md) |
| `ServiceAccount` | Identité Kubernetes pour les processus dans un Pod. | Ne donne pas de droits sans RBAC. | [10](10/fr.md), [12](12/fr.md) |
| `Shared responsibility` | Répartition des responsabilités de protection entre le fournisseur et le client. | Ne signifie pas que le fournisseur protège les workloads du client. | [04](04/fr.md) |
| `SIEM` | Système de centralisation et corrélation des événements de sécurité. | N'est pas la source des événements d'audit API Server. | [14](14/fr.md), [18](18/fr.md) |
| `Signature` | Preuve cryptographique reliant des données à une clé de signature. | N'équivaut ni à digest, ni à SBOM, ni à provenance. | [06](06/fr.md), [17](17/fr.md) |
| `SLSA` | Framework d'exigences de supply chain avec tracks Build et Source indépendants. | N'est pas un nom universel pour une reproducible build. | [17](17/fr.md), [19](19/fr.md) |
| `SLSA v1.2` | Cadre d'exigences avec tracks Build et Source indépendants ; le niveau est indiqué avec le track. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [17](17/fr.md), [19](19/fr.md) |
| `snapshot` | Copie de sauvegarde cohérente de l'état d'`etcd` à un moment donné. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [07](07/fr.md) |
| `SOC 2` | Vérification des controls d'une organisation de services selon les Trust Services Criteria. | N'est pas un Kubernetes security standard. | [19](19/fr.md) |
| `soft multi-tenancy` | Séparation d'équipes de confiance dans un cluster partagé au moyen de controls logiques. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [05](05/fr.md) |
| `Software supply chain` | Chemin du code, des dépendances, de la build et de la livraison jusqu'au runtime. | Ne se limite pas à container registry. | [06](06/fr.md), [17](17/fr.md) |
| `SPIFFE` | Standard d'identités de workload pour les systèmes distribués. | N'est pas un certificat TLS en soi. | [18](18/fr.md) |
| `stage` | Moment de traitement de la requête : `RequestReceived`, `ResponseStarted`, `ResponseComplete` ou `Panic`. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [14](14/fr.md) |
| `STRIDE` | Framework de modélisation des menaces selon six catégories. | N'est pas un journal d'attaques réelles. | [15](15/fr.md), [19](19/fr.md) |
| `Subject` | Utilisateur, groupe ou ServiceAccount au nom duquel agit une requête. | N'est ni une Role ni une permission. | [10](10/fr.md) |
| `Supply chain` | Chaîne de création et de livraison d'un artifact logiciel. | N'équivaut pas à une seule étape de build. | [17](17/fr.md), [19](19/fr.md) |
| `Syscall` | Appel système d'un processus vers le noyau de l'OS. | N'est pas un appel Kubernetes API. | [16](16/fr.md), [18](18/fr.md) |
| `Tag` | Référence lisible par une personne à une version d'image. | Peut être mutable et n'équivaut pas à digest. | [06](06/fr.md) |
| `Threat` | Cause ou scénario possible d'un événement indésirable. | N'est ni une vulnerability ni un risk évalué. | [15](15/fr.md), [16](16/fr.md) |
| `Threat model` | Description des actifs, frontières, flux et menaces d'un système. | N'est pas une liste de CVE. | [15](15/fr.md), [19](19/fr.md) |
| `TLS` | Protocole de chiffrement et d'authentication d'une connexion. | Ne remplace ni NetworkPolicy ni authorization. | [07](07/fr.md), [18](18/fr.md) |
| `TLS termination` | Point où un composant termine TLS et déchiffre la connexion. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [18](18/fr.md) |
| `Token` | Credentials présentés pour l'authentication. | N'équivaut pas automatiquement à un accès RBAC limité. | [10](10/fr.md) |
| `Trace` | Chemin lié d'une requête à travers des services distribués. | N'est pas un enregistrement de log isolé. | [18](18/fr.md) |
| `Trust boundary` | Endroit où changent la confiance, les droits ou le contrôle des données. | Ne coïncide pas nécessairement avec un namespace. | [15](15/fr.md) |
| `Trusted image` | Image avec une origine vérifiable et un ensemble de contrôles de confiance. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [06](06/fr.md) |
| `Trusted registry` | Registry qu'une politique autorise à fournir des images. | Ne prouve pas l'absence de CVE dans une image. | [06](06/fr.md), [17](17/fr.md) |
| `ValidatingAdmissionPolicy` | Declarative admission policy CEL intégrée pour la validation des objets API ; cluster-scoped, appliquée avec une `ValidatingAdmissionPolicyBinding` distincte. | Ne se trouve pas « dans un namespace » - le namespace scope est défini via binding/`matchResources`. | [17](17/fr.md) |
| `version-light` | Caractéristique d'un examen dont les concepts clés ne sont pas liés à une unique version de Kubernetes. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [01](01/fr.md) |
| `Vulnerability` | Faiblesse qu'une threat ou un exploit peut utiliser. | N'est ni une threat ni un risk. | [06](06/fr.md), [16](16/fr.md) |
| `Vulnerability scanner` | Outil de recherche de vulnérabilités connues à partir des données de composants. | N'empêche pas le comportement runtime. | [06](06/fr.md), [17](17/fr.md) |
| `warn` | Mode PSA qui affiche un avertissement au client sans refuser la requête. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [11](11/fr.md) |
| `Webhook` | Gestionnaire HTTP appelé par Kubernetes ou un autre composant. | Tout webhook ne concerne pas admission. | [10](10/fr.md), [17](17/fr.md) |
| `webhook backend` | Backend envoyant les événements audit à un collector HTTPS ou à un SIEM. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [14](14/fr.md) |
| `Workload` | Application exécutée et ressource Kubernetes qui la gère. | N'est pas une unique container image. | [03](03/fr.md), [09](09/fr.md) |
| `Zero trust` | Approche sans confiance implicite dans le réseau, l'identity ou l'emplacement. | Ne signifie pas interdire toutes les interactions. | [02](02/fr.md), [18](18/fr.md) |
| `frontière de confiance` | Point de transition entre participants ou contextes ayant des niveaux de confiance différents. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [15](15/fr.md) |
| `modèle de menace` | Description des actifs, participants, flux, frontières de confiance, menaces et controls d'un système. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [15](15/fr.md) |
| `flux de données` | Transfert d'une requête, d'un état ou de données entre composants. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [15](15/fr.md) |
| `identité de service (service identity)` | Compte d'un composant avec lequel il accède à Kubernetes API. | Précisez le terme selon le contexte, ne le remplacez pas par une notion proche. | [07](07/fr.md) |

## Pièges lexicaux

- [Authentication](10/fr.md) établit l'identity, [authorization](10/fr.md) vérifie le droit et [admission control](11/fr.md) évalue l'admissibilité de l'objet après les deux premières étapes.
- [Audit logging](14/fr.md) traite les événements API, tandis que [runtime detection](18/fr.md) traite le comportement d'un processus après son lancement.
- [Encryption](12/fr.md) exige une clé pour protéger les données, [Base64](12/fr.md) n'est qu'un encoding réversible.
- [Digest](06/fr.md) fige le contenu, [signature](17/fr.md) relie les données à une clé, [SBOM](17/fr.md) énumère les composants et [provenance](17/fr.md) décrit l'origine.
- [Isolation](13/fr.md) couvre plusieurs frontières, [segmentation](13/fr.md) les divise en zones et chemins.
- [Control](05/fr.md) réduit le risque, [framework](19/fr.md) aide à choisir et évaluer les controls.
- [Vulnerability](16/fr.md) est une faiblesse, [threat](15/fr.md) est un scénario possible, [risk](19/fr.md) est l'évaluation de la probabilité et des conséquences.
- [Logging](18/fr.md) enregistre les événements, [monitoring](18/fr.md) suit les indicateurs connus, [observability](18/fr.md) permet d'expliquer l'état à partir de plusieurs signaux.
- [CIA triad](02/fr.md) réunit [confidentiality](12/fr.md), [integrity](19/fr.md) et [availability](16/fr.md).

[Sommaire et parcours de préparation](README_FR.md)
