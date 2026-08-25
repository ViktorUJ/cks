[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glossaire du cours EKS

[Sommaire du cours](README_FR.md)

Référence alphabétique unifiée des termes du cours. Les termes AWS et Kubernetes restent en anglais, tandis que leur description est en français. La colonne « Chapitres » indique où chaque terme est présenté. Recherche dans la page : Ctrl+F.

| Terme | Description | Chapitres |
|--------|-------------|----------|
| **ABAC / RBAC** | Accès par tags avec `aws:PrincipalTag`, par opposition à l’accès par rôles et politiques qui définissent des actions et ressources précises. | [0.2](00-2-iam/fr.md) |
| **Access entry** | Entrée de configuration d’accès reliant un principal IAM à `username` et `kubernetesGroups`; `STANDARD` concerne les personnes et services, les types `EC2_LINUX`, `EC2_WINDOWS`, `FARGATE_LINUX`, `HYBRID_LINUX` et `EC2` concernent les nœuds. | [01](01/fr.md), [05](05/fr.md), [47](47/fr.md) |
| **access entry de type `EC2_LINUX`** | Entrée autorisant l’ARN du rôle de nœud dans le cluster. | [45](45/fr.md) |
| **access point** | Point d’entrée EFS dans un sous-répertoire avec ses droits et identité POSIX; fondement du provisionnement dynamique et de l’isolation des répertoires. | [24](24/fr.md) |
| **Access policy** | Politique AWS gérée de droits Kubernetes associée à une access entry; elle contient des verbs et resources, non des droits IAM, et n’est pas modifiable. | [05](05/fr.md), [47](47/fr.md) |
| **Access scope** | Portée d’une access policy : `cluster` ou liste de `namespace`. | [05](05/fr.md) |
| **ACM (AWS Certificate Manager)** | Certificats hébergés par le load balancer; la clé n’est pas exportée et le renouvellement est automatique. | [27](27/fr.md), [29](29/fr.md) |
| **actions / conditions** | Annotations d’actions personnalisées (redirect, fixed-response, weighted forward) et de conditions de routage supplémentaires. | [27](27/fr.md) |
| **Admission webhook** | Gestionnaire externe appelé par l’apiserver avant l’écriture dans etcd; mutating modifie l’objet, validating l’accepte ou le rejette. | [22](22/fr.md) |
| **ADOT** | AWS Distro for OpenTelemetry : distribution OTel AWS comprenant SDK, agents et Collector. | [36](36/fr.md) |
| **ALIAS** | Enregistrement Route 53 vers une ressource AWS, par exemple ELB; utilisable à l’apex où CNAME est interdit et non facturé comme requête distincte. | [29](29/fr.md) |
| **Allocatable** | Ressources restant aux pods après `kube-reserved`, `system-reserved` et le seuil d’éviction; le scheduler s’y base. | [14](14/fr.md) |
| **`allowVolumeExpansion`** | Indicateur StorageClass autorisant l’agrandissement d’un volume par extension du PVC. | [23](23/fr.md) |
| **Amazon EKS** | Kubernetes géré sur AWS : AWS exploite le control plane, vous exploitez les nœuds et l’infrastructure associée. | [01](01/fr.md) |
| **Amazon Managed Grafana (AMG)** | Grafana géré; AMP y est connecté comme data source et les utilisateurs y accèdent via IAM Identity Center. | [33](33/fr.md) |
| **Amazon Managed Service for Prometheus (AMP)** | Backend compatible Prometheus géré : workspace, remote-write, PromQL et rétention côté AWS. | [33](33/fr.md) |
| **amazon-cloudwatch-observability** | Add-on EKS géré qui installe CloudWatch agent et active Container Insights with enhanced observability. | [33](33/fr.md) |
| **AMI (Amazon Machine Image)** | Modèle de disque d’instance : noyau, système de fichiers et logiciels; les nœuds utilisent un AMI optimisé EKS avec `kubelet`, `containerd` et bootstrap compatibles. | [0.4](00-4-ec2/fr.md), [10](10/fr.md) |
| **API Priority and Fairness** | Mécanisme Kubernetes répartissant le quota de requêtes simultanées entre types de requêtes; le client reçoit `429` lorsque ce quota est épuisé. | [02](02/fr.md) |
| **app-of-apps** | `Application` parent déployant un ensemble d’applications enfants. | [44](44/fr.md) |
| **Application** | CRD Argo CD liant une source Git à un cluster cible et un namespace. | [44](44/fr.md) |
| **Application Load Balancer (ALB)** | Load balancer L7 HTTP/HTTPS avec routage host/path, terminaison TLS, WAF et authentification; LBC le crée depuis un Ingress EKS. | [27](27/fr.md) |
| **ApplicationSet** | Contrôleur Argo CD qui génère des `Application` depuis un modèle; generators cluster, git et matrix produisent respectivement par cluster, répertoire/fichier Git et combinaison des deux. | [44](44/fr.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`, adresse d’une ressource. | [0.1](00-1-aws/fr.md) |
| **`AssumeRoleWithWebIdentity`** | Opération STS échangeant un web identity token contre des identifiants temporaires de rôle IAM. | [16](16/fr.md) |
| **auditID** | Identifiant unique d’une requête dans l’audit log, commun à tous les stages d’une opération; il n’existe pas d’ID commun avec CloudTrail. | [21](21/fr.md) |
| **`authenticationMode`** | Mode d’authentification du cluster : `CONFIG_MAP`, `API_AND_CONFIG_MAP`, `API`; la migration ne va que vers `API`. | [04](04/fr.md), [05](05/fr.md), [47](47/fr.md) |
| **`authenticationSource`** | Source des identifiants de volume : `driver` (rôle du pilote) ou `pod` (rôle du service account du pod). | [25](25/fr.md) |
| **Availability Zone (AZ)** | Ensemble isolé de centres de données d’une région; domaine de défaillance de base pour répartir les réplicas. | [0.1](00-1-aws/fr.md), [40](40/fr.md) |
| **AWS Backup** | Service centralisé de sauvegarde AWS pour EKS, EBS, EFS, S3 et d’autres ressources, au moyen de plans et coffres communs. | [41](41/fr.md) |
| **aws cli v2** | CLI AWS principale; configuration dans `~/.aws/config`, profil choisi avec `--profile` ou `AWS_PROFILE`. | [0.5](00-5-tools/fr.md) |
| **AWS Control Tower** | Landing zone prête à l’emploi : controls préventifs, détectifs et proactifs, détection du drift et account factory. | [0.1](00-1-aws/fr.md) |
| **`aws eks get-token`** | Plugin `exec` kubeconfig qui génère un token STS présigné pour accéder au cluster. | [47](47/fr.md) |
| **AWS Gateway API Controller** | Contrôleur `aws-application-networking-k8s`, GatewayClass `amazon-vpc-lattice`, traduisant Gateway API en objets VPC Lattice. | [28](28/fr.md) |
| **AWS Load Balancer Controller (Gateway API)** | Implémentation avec `controllerName` `gateway.k8s.aws/alb` pour ALB L7 et `gateway.k8s.aws/nlb` pour NLB L4. | [28](28/fr.md) |
| **AWS Load Balancer Controller (LBC)** | Contrôleur du cluster créant un NLB pour un Service LoadBalancer et un ALB pour Ingress; installé avec Helm et nécessitant un rôle IAM. | [26](26/fr.md) |
| **AWS Organizations** | Service de gestion multi-comptes : hiérarchie d’OU, politiques SCP et facturation consolidée. | [0.1](00-1-aws/fr.md), [32](32/fr.md) |
| **AWS PrivateLink** | Accès privé aux services AWS ou inter-comptes par interface endpoint. | [31](31/fr.md) |
| **AWS RAM (Resource Access Manager)** | Service de partage de ressources, notamment subnets, Transit Gateway, VPC Lattice service network et règles Route 53 Resolver. | [0.1](00-1-aws/fr.md), [32](32/fr.md) |
| **`aws sts get-caller-identity`** | Commande « qui suis-je » : compte, ARN et userId. | [0.5](00-5-tools/fr.md) |
| **AWS X-Ray** | Backend de traces géré : stockage, service map, analyse de latence et recherche de traces. | [36](36/fr.md) |
| **`aws-auth` ConfigMap** | Mécanisme legacy de mapping dans `kube-system`, avec les champs `mapRoles` et `mapUsers`. | [05](05/fr.md), [45](45/fr.md), [47](47/fr.md) |
| **aws-for-fluent-bit** | Image Fluent Bit assemblée par AWS, avec plugins de sortie intégrés vers les services AWS. | [34](34/fr.md) |
| **`aws-vault`** | Stockage d’identifiants dans le keychain et exécution de commandes dans une session temporaire. | [0.5](00-5-tools/fr.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | Désactive le SNAT de nœud pour l’egress des pods (`true`) afin que l’extérieur voie leur adresse réelle; l’accès Internet passe alors par NAT gateway. | [07](07/fr.md) |
| **`AWSTraceHeader`** | Attribut système de message SQS pour l’en-tête de trace X-Ray; transporte le contexte au travers d’une frontière asynchrone. | [36](36/fr.md) |
| **backend-protocol-version** | Protocole applicatif de target group : `HTTP1`, `HTTP2` ou `GRPC`; nécessaire au proxy gRPC et HTTP/2 d’ALB vers les pods. | [27](27/fr.md) |
| **backup plan** | Plan de sauvegarde : calendrier, rétention, lifecycle vers cold storage et ressources associées. | [41](41/fr.md) |
| **backup vault** | Coffre de recovery points avec clé KMS et politique d’accès; Vault Lock y est activé. | [41](41/fr.md) |
| **BackupStorageLocation (BSL)** | Emplacement de stockage des sauvegardes Velero, généralement un bucket S3. | [42](42/fr.md) |
| **bake period** | Pause entre la mise à niveau du control plane et celle des nœuds; les nœuds restent en N-1 et le rollback reste possible. | [39](39/fr.md) |
| **Basic / Enhanced scanning** | Modes de recherche de CVE ECR : basic analyse les paquets OS, enhanced analyse OS et langages via Amazon Inspector en continu. | [20](20/fr.md) |
| **behavior / stabilizationWindowSeconds** | Section HPA qui lisse la vitesse et les oscillations du scaling à l’aide de fenêtres de stabilisation et policies. | [35](35/fr.md) |
| **bin packing** | Placement des pods sur les nœuds en fonction de leurs requests. | [14](14/fr.md) |
| **cluster blue/green** | Nouveau cluster à la version cible à côté de l’ancien, avec migration des workloads et bascule du trafic. | [03](03/fr.md), [38](38/fr.md) |
| **bootstrap.sh** | Script de configuration de kubelet sur AL2 depuis user data. | [45](45/fr.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | Champ d’accès de création : à `true` par défaut, le créateur obtient les droits administrateur du cluster. | [04](04/fr.md), [05](05/fr.md) |
| **Bottlerocket** | OS minimal pour conteneurs : racine read-only, mises à jour atomiques, gestion API et conteneurs control/admin au lieu de SSH ouvert. | [10](10/fr.md) |
| **Burstable (série T)** | Part CPU de base complétée par des CPU credits; inadapté aux nœuds de production. | [0.4](00-4-ec2/fr.md) |
| **Capacity** | Capacité totale d’une instance en CPU, mémoire et pods. | [14](14/fr.md) |
| **Capacity Blocks** | Réservation de capacité GPU/Trainium pour l’entraînement. | [0.4](00-4-ec2/fr.md) |
| **capacity type** | Type de capacité de nœud (`spot`/`on-demand`); labels `karpenter.sh/capacity-type` et `eks.amazonaws.com/capacityType`. | [13](13/fr.md) |
| **CapacityProvisioned** | Annotation de pod indiquant la combinaison vCPU/mémoire réellement attribuée après arrondi, qui détermine le coût. | [15](15/fr.md) |
| **cert-manager** | Contrôleur émettant les certificats dans le cluster sous forme de `Secret`; la source est un ClusterIssuer ou Issuer. | [29](29/fr.md) |
| **CFS throttling** | Ralentissement d’un conteneur qui dépasse sa CPU limit. | [14](14/fr.md) |
| **chargeback** | Coût réellement imputé au budget de l’équipe. | [43](43/fr.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | CRD Cilium avec règles L7 et FQDN et portée cluster-wide. | [08](08/fr.md), [30](30/fr.md) |
| **CloudTrail** | Journal d’appels API AWS; il enregistre les opérations EKS comme ressource AWS, pas les événements internes Kubernetes. | [21](21/fr.md) |
| **CloudWatch Application Signals** | APM au-dessus d’OTel, avec SLO, latence et erreurs, activé par l’add-on `amazon-cloudwatch-observability`. | [36](36/fr.md) |
| **CloudWatch Logs** | Stockage de logs AWS avec log groups, log streams, requêtes Logs Insights et facturation de l’ingestion et du stockage. | [34](34/fr.md) |
| **CloudWatch Logs Insights** | Langage de requêtes de logs (`fields`, `filter`, `sort`, `stats`), principal outil d’analyse des audit logs. | [21](21/fr.md) |
| **Cluster Autoscaler (CA)** | Autoscaler de nœuds au-dessus d’Auto Scaling group; modifie `desiredSize` selon les pods non placés et la sous-utilisation. | [11](11/fr.md) |
| **cluster creator admin** | Principal IAM ayant créé le cluster et recevant automatiquement l’accès administrateur. | [47](47/fr.md) |
| **Cluster endpoint** | Adresse de l’API Kubernetes. Le endpoint public est exposé à Internet et limité par CIDR; le privé est accessible depuis le VPC et limité par le cluster security group. | [01](01/fr.md), [02](02/fr.md) |
| **Cluster insights** | Vérifications EKS automatiques : `UPGRADE_READINESS` pour l’upgrade et `ROLLBACK_READINESS` pour le rollback, disponible sept jours. | [03](03/fr.md), [38](38/fr.md) |
| **Cluster security group** | Security group créé automatiquement pour le cluster et attaché à ses interfaces ainsi qu’aux nœuds managed node groups. | [02](02/fr.md), [45](45/fr.md) |
| **cluster version rollback** | Retour du control plane EKS au minor précédent après un in-place upgrade, dans les sept jours, en conservant etcd, workloads et volumes. | [03](03/fr.md), [39](39/fr.md) |
| **ClusterIssuer / Issuer** | Objets cert-manager décrivant une source de certificats pour l’ensemble du cluster ou un namespace. | [29](29/fr.md) |
| **ClusterMesh** | Réseau Pod de plusieurs clusters Cilium via `clustermesh-apiserver`; requiert des `cluster-id` uniques et PodCIDR non chevauchants. | [08](08/fr.md) |
| **CMK (customer managed key)** | Votre clé KMS, qui permet de contrôler sa policy et d’auditer le déchiffrement dans CloudTrail, contrairement à une AWS owned key. | [18](18/fr.md) |
| **CNI chaining** | Mode où VPC CNI attribue les adresses et configure l’interface, tandis que Cilium ajoute politiques et observabilité; `aws-node` reste actif. | [08](08/fr.md), [30](30/fr.md) |
| **`cni-metrics-helper`** | Composant qui scrape `awscni_*` depuis les pods `aws-node` et envoie des agrégats à CloudWatch. | [06](06/fr.md) |
| **composite recovery point** | Point de récupération EKS composé qui regroupe l’état du cluster et les backups de volumes. | [41](41/fr.md) |
| **Compute Savings Plans** | Engagement de dépense horaire sur un à trois ans contre remise, flexible entre familles d’instances, région et Fargate/Lambda. | [43](43/fr.md) |
| **Compute SP / EC2 Instance SP** | Plan flexible couvrant EC2, Fargate et Lambda, ou plan plus avantageux mais limité à une famille dans une région. | [0.4](00-4-ec2/fr.md) |
| **configurationValues** | Champ d’add-on pour une configuration déclarative sans modifier directement les manifests. | [37](37/fr.md) |
| **connection draining** | Écoulement des connexions actives lors de la désinscription d’une target; `deregistration_delay.timeout_seconds` vaut 300 par défaut. | [40](40/fr.md) |
| **conntrack** | Table de connexions du noyau du nœud; les nouvelles connexions sont supprimées lorsqu’elle est pleine. | [46](46/fr.md) |
| **Consolidated billing** | Facture unique de l’organisation; remises de volume et Savings Plans s’appliquent à tous les comptes. | [0.1](00-1-aws/fr.md) |
| **Consolidation** | Compactage volontaire pour réduire le coût; policies `WhenEmpty` et `WhenEmptyOrUnderutilized`, avec `consolidateAfter`. | [11](11/fr.md), [12](12/fr.md) |
| **Container Insights** | Monitoring EKS dans CloudWatch : l’agent collecte les métriques de nœuds et pods, avec tableaux de bord et alarmes. | [33](33/fr.md) |
| **ContainerResource** | Type de métrique HPA calculant l’utilisation d’un seul conteneur du pod, utile lorsqu’un sidecar dilue la métrique applicative. | [35](35/fr.md) |
| **context propagation** | Transmission de `trace id` entre services par en-têtes W3C Trace Context afin de ne pas rompre la trace. | [36](36/fr.md) |
| **continuous profiling** | Collecte continue des hotspots CPU et mémoire du code, par exemple CodeGuru Profiler, Pyroscope ou Parca. | [36](36/fr.md) |
| **Control plane** | API server, scheduler, controller manager et etcd; dans EKS, ils résident dans le compte AWS hors de votre VPC et ne figurent pas dans `kubectl get pods -n kube-system`. | [01](01/fr.md) |
| **control plane logging** | Livraison des logs EKS `api`, `audit`, `authenticator`, `controllerManager` et `scheduler` vers CloudWatch Logs. | [34](34/fr.md) |
| **add-ons cœur** | `vpc-cni`, `kube-proxy`, `coredns`, noyau obligatoire installé dans chaque cluster. | [37](37/fr.md) |
| **cost allocation** | Répartition des coûts AWS sur les objets Kubernetes, tels que namespace, Deployment et label, d’après la consommation ou les requests. | [43](43/fr.md) |
| **cost allocation tags** | Tags AWS de ventilation de facture; les tags user-defined doivent être activés dans Billing. | [43](43/fr.md) |
| **Cost and Usage Report** | Facturation AWS détaillée dans S3; Athena permet à OpenCost/Kubecost de comparer l’allocation à la facture réelle et ses remises. | [43](43/fr.md) |
| **Cost Anomaly Detection** | Service AWS de détection ML des hausses anormales de dépenses, avec alertes email ou SNS. | [43](43/fr.md) |
| **crash-consistent / application-consistent** | Snapshot sans arrêter les écritures, ou snapshot coordonné au niveau applicatif; AWS Backup pour EKS ne fournit que le premier. | [41](41/fr.md) |
| **Cross-account ENI** | Interfaces créées par EKS dans vos subnets pour relier control plane, nœuds, kubelet API, webhooks et OIDC. | [02](02/fr.md) |
| **trafic cross-AZ** | Transfert de données entre Availability Zones, généralement facturé dans les deux sens. | [31](31/fr.md) |
| **cross-zone load balancing** | Mode répartissant le trafic vers les targets de toutes les zones; charge plus uniforme mais davantage de trafic cross-AZ. | [31](31/fr.md) |
| **Custom networking** | Mode où ENI secondaires et adresses de pods viennent du subnet et des security groups `ENIConfig`, un par AZ, avec sélection par label `ENI_CONFIG_LABEL_DEF`. | [07](07/fr.md) |
| **custom.metrics.k8s.io** | API de métriques personnalisées d’objets du cluster pour HPA, notamment Pods et Object. | [35](35/fr.md) |
| **Data Firehose** | Buffer et routeur de flux géré vers S3, OpenSearch et d’autres destinations. | [34](34/fr.md) |
| **Data plane** | Vos nœuds et tout ce qui s’exécute sur eux. | [01](01/fr.md) |
| **Delegated administrator** | Compte d’organisation qui administre GuardDuty/Security Hub et voit les findings de tous les membres; désigné par région. | [0.1](00-1-aws/fr.md), [21](21/fr.md) |
| **`deletionProtection`** | Indicateur interdisant la suppression du cluster. | [04](04/fr.md) |
| **deprecated / removed API** | `apiVersion` est d’abord déprécié puis supprimé; ensuite les manifests qui l’emploient ne peuvent plus être appliqués. | [38](38/fr.md) |
| **describe-addon-versions** | Opération EKS API exposant les versions d’add-on, leur compatibilité avec le minor Kubernetes et `defaultVersion`. | [37](37/fr.md) |
| **`describe-target-health`** | Commande affichant l’état et la raison pour les targets d’un target group. | [46](46/fr.md) |
| **Digest** | Hash `sha256` du contenu d’une image, immuable; déployer par digest garantit l’artefact exact, contrairement à un tag mobile. | [20](20/fr.md) |
| **Disruption budget** | Limite de vitesse des interruptions volontaires : part/nombre de nœuds, fenêtres `schedule`/`duration` et `reasons`. | [12](12/fr.md) |
| **DNS-01** | Vérification ACME de propriété de domaine par enregistrement TXT; cert-manager le crée dans Route 53. | [29](29/fr.md) |
| **Drift** | Écart d’un nœud par rapport à l’état souhaité, comme un nouvel AMI ou des `requirements` modifiés; traité avant consolidation. | [12](12/fr.md) |
| **Dual-stack** | VPC et subnets IPv4/IPv6 (`/56` et `/64`); IPv6 évite l’épuisement d’adresses des pods. | [0.3](00-3-vpc/fr.md) |
| **EBS / instance store** | Volume réseau dans une AZ, ou NVMe local éphémère. | [0.4](00-4-ec2/fr.md) |
| **pilote EBS CSI** | `aws-ebs-csi-driver`, add-on géré avec provisioner `ebs.csi.aws.com`, gérant le cycle de vie EBS. | [23](23/fr.md) |
| **EC2NodeClass** | CRD `karpenter.k8s.aws/v1` contenant AMI, rôle IAM, subnets, SG, disques et IMDS. | [12](12/fr.md) |
| **ECR** | Registre d’images OCI géré AWS, privé par compte-région à `<account-id>.dkr.ecr.<region>.amazonaws.com`, ou public à `public.ecr.aws`. | [20](20/fr.md) |
| **EFS** | Amazon Elastic File System, NFS régional géré à capacité élastique et mode ReadWriteMany. | [24](24/fr.md) |
| **pilote EFS CSI** | `aws-efs-csi-driver`, add-on géré avec provisioner `efs.csi.aws.com`, au-dessus d’un système de fichiers existant. | [24](24/fr.md) |
| **EKS audit log** | Log control plane `audit`, événements JSON d’audit Kubernetes indiquant qui, quelle action, quelle ressource, origine et résultat; écrit dans CloudWatch Logs. | [21](21/fr.md) |
| **EKS authenticator** | Webhook du control plane validant le token STS présigné et mappant l’identité IAM à un sujet Kubernetes. | [47](47/fr.md) |
| **EKS Auto Mode** | Mode où AWS gère des nœuds appliance Bottlerocket, le scaling Karpenter et réseau, DNS, EBS CSI et ELB intégrés. | [01](01/fr.md), [09](09/fr.md) |
| **EKS Cluster State** | Manifests des objets Kubernetes et configuration du cluster. | [41](41/fr.md) |
| **EKS Pod Identity** | Attribution d’un rôle IAM au pod via un agent de nœud et l’API EKS, sans fournisseur OIDC du cluster ni trust policy propre au cluster. | [17](17/fr.md), [47](47/fr.md) |
| **EKS Pod Identity Agent** | Add-on `eks-pod-identity-agent` en `DaemonSet` sur les nœuds, distribuant des identifiants temporaires par endpoint local. | [17](17/fr.md) |
| **AMI optimisé EKS** | Image AWS avec composants de nœud aux versions appropriées : AL2023, Bottlerocket, Windows et AL2 en fin de vie. | [10](10/fr.md) |
| **eksctl** | CLI officielle d’EKS, qui utilise CloudFormation et une approche impérative. | [0.5](00-5-tools/fr.md) |
| **enableNetworkPolicy** | Paramètre de l’add-on VPC CNI géré activant l’application du NetworkPolicy standard. | [30](30/fr.md) |
| **Encryption at rest** | Chiffrement des couches ECR : SSE-S3 AES-256 par défaut, ou SSE-KMS avec `aws/ecr` ou une customer managed key; défini à la création et immuable. | [20](20/fr.md) |
| **endpoint service** | Publication de son service derrière NLB comme cible PrivateLink pour des consommateurs d’autres VPC et comptes. | [31](31/fr.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | Indicateurs booléens du mode d’accès, `true` et `false` par défaut. | [02](02/fr.md) |
| **enforcer** | Composant CNI transformant NetworkPolicy en filtres de trafic réels; absent par défaut dans EKS tant qu’il n’est pas activé. | [30](30/fr.md) |
| **Enhanced subnet discovery** | Subnets tagués `kubernetes.io/role/cni=1` sans `ENIConfig`. | [07](07/fr.md) |
| **ENI** | Elastic network interface; le nombre d’ENI et d’adresses IPv4 par ENI dépend du type d’instance. | [0.3](00-3-vpc/fr.md), [06](06/fr.md) |
| **Envelope encryption** | Chiffrement à deux clés : DEK chiffre les données, KEK KMS chiffre DEK; EKS l’applique aux secrets etcd avec Kubernetes KMS provider v2. | [18](18/fr.md) |
| **ephemeral ports** | Plage haute `1024-65535` du trafic de retour, à autoriser explicitement dans les NACL. | [46](46/fr.md) |
| **eviction threshold** | Réserve de mémoire sous laquelle kubelet évince des pods. | [14](14/fr.md) |
| **plugin exec kubeconfig** | Section `exec` appelant `aws eks get-token`; aucun token permanent n’est écrit et `client-go` met les identifiants en cache jusqu’à `status.expirationTimestamp`. | [0.5](00-5-tools/fr.md) |
| **Expander** | Stratégie Cluster Autoscaler de choix d’un node group : `least-waste`, `priority`, `most-pods` ou `random`. | [11](11/fr.md) |
| **Extended support** | Phase après standard support, d’environ douze mois, où la version reste supportée contre un coût horaire supérieur; activée par défaut. | [03](03/fr.md), [38](38/fr.md) |
| **External Secrets Operator (ESO)** | Contrôleur lisant un secret AWS et créant un `Secret` natif via `SecretStore`/`ClusterSecretStore` et `ExternalSecret`. | [18](18/fr.md) |
| **external-dns** | Contrôleur synchronisant les enregistrements DNS du provider avec Ingress et Service Kubernetes; il utilise Route 53 sur AWS. | [29](29/fr.md) |
| **external.metrics.k8s.io** | API de métriques externes, telles que queues et topics, pour HPA de type External. | [35](35/fr.md) |
| **externalTrafficPolicy** | Politique Service : `Cluster` route vers tout nœud avec SNAT, `Local` vers les pods locaux en conservant le client IP. | [26](26/fr.md) |
| **`failed to assign an IP address to container`** | VPC CNI n’a pas pu attribuer une IP au pod : il manque des adresses sur le nœud ou dans le subnet. | [46](46/fr.md) |
| **failurePolicy** | Réaction à un webhook indisponible : `Fail` bloque l’admission, `Ignore` laisse passer l’objet. | [22](22/fr.md) |
| **Fargate** | Exécution d’un pod dans une micro-VM dédiée sans nœud; pas de DaemonSet, privilèges, `HostNetwork`, GPU ni accès au nœud. | [09](09/fr.md) |
| **fargate-scheduler** | Scheduler EKS coexistant avec kube-scheduler et dirigeant les pods correspondant au profil vers Fargate. | [15](15/fr.md) |
| **profil Fargate** | Objet de cluster avec selectors, pod execution role et subnets privés, définissant quels pods vont sur Fargate; il faut le recréer pour le modifier. | [15](15/fr.md) |
| **Finding** | Alerte GuardDuty, transmise à Security Hub et EventBridge pour alerte et réaction. | [21](21/fr.md) |
| **Fluent Bit** | Forwarder de logs léger en C, exécuté en DaemonSet sur chaque nœud; lit, enrichit et transmet les logs. | [34](34/fr.md) |
| **Forbidden (403)** | Échec d’autorisation : RBAC ne permet pas l’action. | [47](47/fr.md) |
| **game day** | Exercice qui vérifie concrètement DR et scénarios d’incident. | [48](48/fr.md) |
| **Gatekeeper** | Policy engine sur OPA, avec règles Rego, `ConstraintTemplate` et `Constraint`. | [22](22/fr.md) |
| **Gateway** | Point d’entrée avec listeners de protocole, port et TLS, possédé par l’équipe plateforme; mappé à Service Network dans VPC Lattice. | [28](28/fr.md) |
| **Gateway API** | Standard Kubernetes de gestion du trafic succédant à Ingress, avec ressources typées et rôles séparés. | [28](28/fr.md) |
| **gateway endpoint** | Type de VPC endpoint pour S3 et DynamoDB, inscrit dans la route table et gratuit. | [25](25/fr.md), [31](31/fr.md) |
| **GatewayClass** | Modèle d’implémentation avec `controllerName`, définissant quel contrôleur traite Gateway, analogue à IngressClass. | [28](28/fr.md) |
| **GitOps** | Modèle où l’état souhaité est dans Git et un agent réconcilie continuellement le cluster avec lui. | [44](44/fr.md) |
| **GitOps Toolkit** | Ensemble de contrôleurs Flux, dont source, kustomize, helm et image. | [44](44/fr.md) |
| **Golden image** | Image personnalisée reproductible, construite sur un AMI optimisé à l’aide d’un image builder. | [10](10/fr.md) |
| **graceful node shutdown** | Fonction kubelet qui arrête les pods avec leur grace period lors de l’arrêt de l’OS. | [40](40/fr.md) |
| **Grafana Loki** | Stockage de logs indexant seulement les labels de flux; logs compressés en chunks, requêtes LogQL et labels à faible cardinalité. | [34](34/fr.md) |
| **`granted` (`assume`)** | Changement rapide de profils SSO et connexion à la console. | [0.5](00-5-tools/fr.md) |
| **Graviton** | Processeurs AWS arm64, suffixe `g`, nécessitant des images multi-architecture. | [0.4](00-4-ec2/fr.md) |
| **GuardDuty EKS Protection** | Analyse des EKS audit logs par un flux GuardDuty autonome, sans devoir activer control plane logging. | [21](21/fr.md) |
| **GuardDuty Runtime Monitoring** | Observation du comportement de nœud par agent eBPF `aws-guardduty-agent`; ne prend pas en charge Fargate ni Hybrid Nodes. | [21](21/fr.md) |
| **Hard multi-tenancy** | Tenants dans des clusters ou comptes distincts, frontière forte au prix de la complexité. | [22](22/fr.md) |
| **HashiCorp Vault** | Stockage de secrets externe à AWS, alternatif à Secrets Manager, avec authentification Kubernetes, JWT/OIDC ou IAM et plusieurs mécanismes de livraison. | [18](18/fr.md) |
| **head-based et tail-based sampling** | Décision d’échantillonnage à l’entrée avant le résultat, ou à la passerelle après assemblage de la trace; le second exige tous les spans sur le même Collector. | [36](36/fr.md) |
| **helmfile** | Description déclarative de releases Helm, versions et values dans un fichier. | [0.5](00-5-tools/fr.md) |
| **hop limit (`httpPutResponseHopLimit`)** | Nombre de sauts réseau de la réponse IMDS; à 1, un pod ne peut atteindre IMDS mais le nœud le peut. | [19](19/fr.md) |
| **hosted zone** | Conteneur d’enregistrements DNS d’un domaine dans Route 53, public ou privé et associé à un VPC. | [29](29/fr.md) |
| **HPA (HorizontalPodAutoscaler)** | Contrôleur modifiant le nombre de réplicas d’un Deployment selon une métrique. | [35](35/fr.md) |
| **HTTPRoute** | Règles de routage host, path et headers vers backend, référant Gateway via `parentRefs`; mappé à VPC Lattice Service. | [28](28/fr.md) |
| **hub-and-spoke** | Topologie avec Transit Gateway central et VPC d’équipes connectés. | [32](32/fr.md) |
| **Hubble** | Sous-système d’observabilité Cilium : carte de flux et verdict par flux. | [08](08/fr.md), [30](30/fr.md) |
| **IAM Access Analyzer** | Détecte les entités de confiance externes dans les policies resource-based et trust policies. | [0.2](00-2-iam/fr.md) |
| **IAM auth policy** | Politique IAM autorisant le trafic inter-services; ressource `IAMAuthPolicy` du contrôleur. | [28](28/fr.md) |
| **IAM database authentication** | Connexion RDS/Aurora au moyen d’un token temporaire `aws rds generate-db-auth-token` au lieu d’un mot de passe. | [18](18/fr.md) |
| **IAM Identity Center** | Connexion unique et attribution d’accès au moyen de permission sets. | [0.1](00-1-aws/fr.md) |
| **IAM OIDC identity provider** | Objet IAM qui enregistre l’URL issuer du cluster et est référencé par les trust policies des rôles; un par cluster. | [16](16/fr.md) |
| **IAM role** | Identité sans clés permanentes, assumée temporairement. | [0.2](00-2-iam/fr.md) |
| **IAM user / group** | Identité long-lived et ensemble de telles identités, à éviter en production. | [0.2](00-2-iam/fr.md) |
| **capacité idle** | Écart entre capacité de nœuds payée et réellement consommée, signal de requests excessifs ou de mauvais bin packing. | [43](43/fr.md) |
| **image automation** | Contrôleurs Flux qui committent les nouveaux tags d’images dans Git. | [44](44/fr.md) |
| **IMDS** | Instance Metadata Service à `169.254.169.254`, source de métadonnées et credentials du rôle de nœud; IMDSv1 est sans token, IMDSv2 est basé sur session (`PUT`+token). | [0.2](00-2-iam/fr.md), [0.4](00-4-ec2/fr.md), [19](19/fr.md) |
| **paramètre immutable** | Paramètre de cluster non modifiable après création, tel que `ipFamily`, `serviceIpv4Cidr`, VPC, nom ou rôle IAM. | [04](04/fr.md) |
| **In-place upgrade** | Mise à niveau du même cluster vers le minor suivant : control plane, add-ons puis nœuds. | [03](03/fr.md), [38](38/fr.md) |
| **in-tree cloud provider** | Code AWS intégré aux composants Kubernetes, créant par défaut un Classic Load Balancer pour Service LoadBalancer. | [26](26/fr.md) |
| **provisioner in-tree** | `kubernetes.io/aws-ebs` intégré, déprécié, sans `gp3` ni snapshots; `gp2` par défaut dans EKS l’utilise encore. | [23](23/fr.md) |
| **IngressClass alb** | Classe du contrôleur `ingress.k8s.aws/alb`; AWS Load Balancer Controller traite les Ingress `ingressClassName: alb`. | [27](27/fr.md) |
| **IngressGroup** | Regroupement de plusieurs Ingress par `group.name` dans un ALB commun; `group.order` fixe la priorité des règles. | [27](27/fr.md) |
| **INPUT / FILTER / OUTPUT** | Trois sections de pipeline Fluent Bit : lecture, traitement et envoi. | [34](34/fr.md) |
| **`InsufficientCidrBlocks`** | Erreur EC2 API signalant l’absence de blocs continus malgré des adresses formellement libres. | [07](07/fr.md) |
| **Interface endpoint** | VPC endpoint PrivateLink : ENI dans un subnet, facturé à l’heure et au volume de données. | [31](31/fr.md) |
| **Internet Gateway** | Passerelle gratuite vers Internet pour les adresses publiques. | [0.3](00-3-vpc/fr.md) |
| **involuntary disruption** | Interruption non contrôlée : panne de nœud/AZ, OOM ou interruption Spot; elle se traite par répartition, non par PDB. | [40](40/fr.md) |
| **ipamd** | Démon dans `aws-node` qui gère le pool d’adresses du nœud, attache des adresses secondaires et crée des ENI via EC2 API. | [06](06/fr.md) |
| **`ipFamily`** | Famille d’adresses du cluster, définie uniquement à la création. | [07](07/fr.md) |
| **IRSA** | IAM Roles for Service Accounts : attribution d’un rôle IAM à un pod via un `ServiceAccount` lié et fédération OIDC. | [0.2](00-2-iam/fr.md), [16](16/fr.md), [47](47/fr.md) |
| **Karpenter** | Autoscaler de nœuds qui crée directement des instances EC2 pour les pods non placés et sélectionne leur type dans une plage autorisée. | [11](11/fr.md) |
| **KEDA** | Extension d’autoscaling événementiel qui fournit les métriques à HPA et le pilote. | [35](35/fr.md) |
| **`kms:CreateGrant`** | Droit requis pour monter un volume EBS chiffré avec son CMK, car le chiffrement EBS passe par des grants. | [23](23/fr.md) |
| **krew** | Gestionnaire de plugins avec index, `search`, `install` et `upgrade`, prenant aussi en charge les index privés. | [0.5](00-5-tools/fr.md) |
| **kube-prometheus-stack** | Helm chart réunissant Prometheus Operator, Prometheus, Grafana, Alertmanager, node-exporter et kube-state-metrics. | [33](33/fr.md) |
| **`kube-reserved` / `system-reserved`** | Ressources réservées par kubelet pour Kubernetes et l’OS. | [14](14/fr.md) |
| **kube-state-metrics** | Composant exposant l’état des objets Kubernetes, par exemple Pending, réplicas et restarts, en métriques. | [33](33/fr.md) |
| **Kubecost** | Produit basé sur OpenCost avec UI, rapports et recommandations; EKS propose un bundle optimisé. | [43](43/fr.md) |
| **`kubectl plugin list`** | Liste de ce que kubectl voit dans `PATH`. | [0.5](00-5-tools/fr.md) |
| **`kubeProxyReplacement`** | Mode Cilium où eBPF remplace kube-proxy pour Service/NodePort; `true` active ce remplacement. | [08](08/fr.md) |
| **Kustomization / HelmRelease** | CRD Flux indiquant quoi appliquer depuis quelle source et où. | [44](44/fr.md) |
| **Kyverno** | Policy engine dont les policies sont des ressources YAML `ClusterPolicy`/`Policy` avec règles validate, mutate, generate et verifyImages; réaction : `Enforce`/`Audit`. | [22](22/fr.md) |
| **Landing zone** | Structure multi-comptes préconfigurée, incluant management, shared services, environnements et équipes, notamment via Control Tower. | [0.1](00-1-aws/fr.md), [32](32/fr.md) |
| **Launch template** | Modèle d’instance versionné : AMI, type, disque, SG, user data et IMDS; un managed node group l’emploie toujours. | [10](10/fr.md) |
| **Launch template / Auto Scaling group** | Modèle de lancement versionné, puis groupe d’instances `min`, `desired`, `max` sur plusieurs subnets AZ. | [0.4](00-4-ec2/fr.md) |
| **Lifecycle policy** | Règles de suppression automatique d’images selon l’âge ou le nombre. | [20](20/fr.md) |
| **limits** | Plafond de consommation du conteneur. | [14](14/fr.md) |
| **log group / log stream** | Groupe, généralement par application, et flux en son sein, généralement par pod, dans CloudWatch Logs. | [34](34/fr.md) |
| **Managed / inline policy** | Politique réutilisable et versionnée, ou politique intégrée directement dans un rôle. | [0.2](00-2-iam/fr.md) |
| **Managed addon (EKS managed addon)** | Composant de cluster géré par AWS, comme VPC CNI, CoreDNS, kube-proxy ou CSI, dont EKS pilote la version via son API. | [0.5](00-5-tools/fr.md), [01](01/fr.md), [37](37/fr.md) |
| **managed collector (scraper)** | Collecteur AMP géré et sans agent qui scrape les métriques EKS et écrit dans un workspace via remote-write. | [33](33/fr.md) |
| **managed fields / server-side apply** | Mécanisme par lequel un add-on déclare et applique ses champs, base de la résolution de conflits. | [37](37/fr.md) |
| **Managed node group** | Groupe EC2 géré par EKS : AWS gère ASG et launch template, met à jour avec drain, mais vous gérez l’OS et le contenu du nœud. | [01](01/fr.md), [09](09/fr.md) |
| **Management account** | Compte racine payeur, qui ne doit pas héberger les workloads. | [0.1](00-1-aws/fr.md) |
| **`matchLabelKeys`** | Clés de labels de pod ajoutées au `labelSelector` des contraintes de répartition; `pod-template-hash` limite le skew à une révision. | [40](40/fr.md) |
| **max-pods** | Limite de pods par nœud : `ENI * (IP par ENI - 1) + 2`, plafonnée à 110 ou 250 dans les managed node groups. | [0.4](00-4-ec2/fr.md), [06](06/fr.md), [46](46/fr.md) |
| **maxSkew** | Écart admis du nombre de pods entre le domaine le plus rempli et le moins rempli. | [40](40/fr.md) |
| **`memory_limiter`** | Processeur Collector limitant la mémoire : au seuil, il refuse des données plutôt que d’atteindre `OOMKilled`; il est placé en premier. | [36](36/fr.md) |
| **metric_relabel_configs** | Section scrape config (dans ServiceMonitor : `metricRelabelings`) qui retire métriques et labels à forte cardinalité (`drop` sur `__name__`, `labeldrop`) avant stockage et remote-write, afin de maîtriser volume et coût. | [33](33/fr.md) |
| **Metrics API (`metrics.k8s.io`)** | API Kubernetes des métriques courantes de ressources, utilisée par `kubectl top` et HPA sur resource metrics. | [33](33/fr.md), [35](35/fr.md) |
| **metrics-server** | Composant qui collecte CPU et mémoire auprès de kubelet et les expose dans Metrics API, sans historique ni stockage. | [33](33/fr.md) |
| **mount target** | Interface réseau EFS dans le subnet d’une AZ, point d’entrée des nœuds de cette zone. | [24](24/fr.md) |
| **Mountpoint for Amazon S3** | Client exposant les objets d’un bucket par une interface de fichiers, fondement du CSI driver. | [25](25/fr.md) |
| **Mountpoint S3 CSI driver** | `aws-mountpoint-s3-csi-driver`, add-on géré avec provisioner `s3.csi.aws.com`; provisionnement statique uniquement. | [25](25/fr.md) |
| **must have** | Élément sans lequel la mise en production est dangereuse et doit être bloquée. | [48](48/fr.md) |
| **NACL** | Filtre stateless au niveau du subnet, avec règles entrantes et sortantes indépendantes. | [46](46/fr.md) |
| **namespace restore** | Restauration ciblée de jusqu’à cinq namespaces dans un cluster existant, sans ressources cluster-scoped sauf PV liés. | [42](42/fr.md) |
| **NAT Gateway** | Service AWS géré de traduction d’adresses, donnant aux subnets privés une sortie Internet; facturé à l’heure et au Go traité. | [0.3](00-3-vpc/fr.md), [31](31/fr.md) |
| **`ndots:5`** | Paramètre resolv.conf des pods qui fait essayer les domaines de recherche pour les noms. | [46](46/fr.md) |
| **nested (child) recovery point** | Point de récupération imbriqué dans un composite, représentant l’état du cluster ou un volume distinct. | [41](41/fr.md) |
| **Network ACL** | Filtre stateless de subnet, avec allow et deny par numéro de règle. | [0.3](00-3-vpc/fr.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | Mode d’application des policies au démarrage : `standard` avec default allow temporaire, ou `strict` avec default deny. | [08](08/fr.md), [30](30/fr.md) |
| **NetworkPolicy** | Objet Kubernetes déclarant ingress et egress permis aux pods; sans enforcer, il ne bloque rien. | [30](30/fr.md) |
| **nice to have** | Élément qui augmente la maturité et peut être finalisé après la mise en production. | [48](48/fr.md) |
| **NLB (Network Load Balancer)** | Load balancer L4 TCP/UDP à haute performance et IP statiques; LBC le crée depuis un Service LoadBalancer. | [26](26/fr.md) |
| **node instance role** | Rôle IAM assumé par un nœud EC2, utilisé par kubelet pour appeler les API AWS. | [45](45/fr.md) |
| **Node Termination Handler (NTH)** | Composant AWS de traitement des interruptions de nœuds managed et self-managed sans Karpenter, en modes IMDS ou Queue Processor. | [13](13/fr.md) |
| **nodeadm** | Initialiseur de nœud AL2023/Bottlerocket, entrant par manifeste YAML `NodeConfig` (`apiVersion: node.eks.aws/v1alpha1`) et remplaçant `bootstrap.sh`. | [10](10/fr.md), [45](45/fr.md) |
| **NodeClaim** | Demande Karpenter pour un nœud concret, reliant `NodePool` et le `Node` réel. | [12](12/fr.md) |
| **NodeCreationFailure** | Health issue d’un managed node group : les nœuds ne se sont pas joints au cluster dans les quinze minutes. | [45](45/fr.md) |
| **NodeLocal DNSCache** | Cache DNS local au nœud, réduisant la charge de CoreDNS et le throttling par ENI. | [46](46/fr.md) |
| **NodePool** | CRD `karpenter.sh/v1` définissant `requirements`, `limits`, `weight`, labels/taints et policy de disruption des nœuds. | [12](12/fr.md) |
| **NodePool et NodeClass** | Objets décrivant quels nœuds créer et comment; dans Auto Mode les valeurs par défaut sont immuables, mais vous pouvez en ajouter. | [09](09/fr.md) |
| **non-destructive restore** | Mode où les objets existants ne sont pas écrasés mais ignorés; les exclusions sont visibles par SNS. | [42](42/fr.md) |
| **NotReady avec kubelet actif** | Indique généralement que CNI n’est pas prêt et n’attribue pas d’IP aux pods. | [45](45/fr.md) |
| **OIDC issuer URL** | Endpoint OIDC public du cluster, `oidc.eks.<region>.amazonaws.com/id/`, avec clés publiques de signature des projected tokens. | [16](16/fr.md) |
| **On-demand / Spot** | Paiement à l’usage, ou capacité remise et interruptible avec préavis de deux minutes. | [0.4](00-4-ec2/fr.md) |
| **OOMKilled** | Conteneur tué par le noyau parce qu’il dépasse sa memory limit. | [14](14/fr.md) |
| **OpenCost** | Standard et moteur open source neutre de fournisseur pour l’allocation de coûts, projet CNCF, basé sur Prometheus et les prix AWS. | [43](43/fr.md) |
| **OpenSearch Service** | OpenSearch géré pour recherche plein texte et dashboards, facturé par cluster et nœuds. | [34](34/fr.md) |
| **OpenTelemetry (OTel)** | Standard CNCF d’API, SDK et protocole communs, séparant l’instrumentation du backend. | [36](36/fr.md) |
| **OpenTelemetry Collector** | Collecteur où receivers reçoivent, processors traitent et exporters envoient la télémétrie aux backends. | [36](36/fr.md) |
| **OpenTelemetry Operator** | Opérateur effectuant l’auto-instrumentation par injection d’agent dans un pod. | [36](36/fr.md) |
| **OpenTofu** | Fork open source de terraform compatible avec les modules du cours, sélectionné par `terraform_binary = "tofu"`. | [0.5](00-5-tools/fr.md) |
| **OTLP** | Protocole de transmission de télémétrie entre application et Collector, puis entre Collectors. | [36](36/fr.md) |
| **OU** | Groupe de comptes auquel des politiques sont appliquées. | [0.1](00-1-aws/fr.md) |
| **ownership** | Responsabilité explicitement attribuée à un domaine ou un point de checklist. | [48](48/fr.md) |
| **Permissions boundary** | Plafond de permissions d’un rôle ou utilisateur, qui n’accorde pas de droits lui-même. | [0.2](00-2-iam/fr.md) |
| **Placement group** | Contrôle du placement d’instances : `cluster`, `partition` ou `spread`. | [0.4](00-4-ec2/fr.md) |
| **`placementGroupSelector`** | Champ `NodeClass` choisissant un placement group par nom ou id; le groupe est créé d’avance et le pod le sélectionne via `nodeSelector` sur le label `eks.amazonaws.com/placement-group-id`. | [09](09/fr.md), [12](12/fr.md) |
| **Platform version** | Niveau de patch et fonctionnalités du control plane EKS dans un minor Kubernetes, au format `eks.<n>`, mis à jour automatiquement par AWS. | [01](01/fr.md), [02](02/fr.md) |
| **pluto / kube-no-trouble (kubent)** | Outils de recherche des API dépréciées, respectivement dans Git/Helm et le cluster vivant. | [38](38/fr.md) |
| **Pod execution role** | Rôle IAM utilisé par `kubelet` Fargate pour s’enregistrer et extraire les images ECR; son log router intégré écrit aussi avec ce rôle. | [15](15/fr.md) |
| **Pod Identity association** | Enregistrement EKS liant `cluster + namespace + ServiceAccount` à un rôle IAM, créé par `aws eks create-pod-identity-association`. | [17](17/fr.md), [37](37/fr.md) |
| **pod readiness gate** | Condition additionnelle de disponibilité du pod; LBC garde `target-health.elbv2.k8s.aws` à false tant que la target n’est pas `healthy`. | [40](40/fr.md) |
| **Pod Security Admission (PSA)** | Admission controller intégré appliquant Pod Security Standards à un namespace par labels; il remplace Pod Security Policies. | [19](19/fr.md) |
| **Pod Security Standards** | Profils privileged, baseline et restricted, ce dernier étant strict et adapté à la production. | [19](19/fr.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | `strict` sans source NAT, ou `standard` où le trafic hors VPC utilise l’ENI primaire et les règles SG du nœud. | [46](46/fr.md) |
| **PodDisruptionBudget (PDB)** | Objet limitant le nombre de pods évincés simultanément lors de disruptions volontaires, via `minAvailable` ou `maxUnavailable`. | [40](40/fr.md) |
| **`pods.eks.amazonaws.com`** | Service principal dans la trust policy Pod Identity, commun aux clusters et comptes; EKS Auth API délivre les credentials via `AssumeRoleForPodIdentity`. | [17](17/fr.md) |
| **Policy** | JSON avec `Version`, `Statement`, `Effect`, `Action`, `Resource` et `Condition`, identity-based ou resource-based. | [0.2](00-2-iam/fr.md) |
| **Policy engine** | Admission webhook avec vos règles, tel que Kyverno ou Gatekeeper, validant ou modifiant les objets avant etcd. | [22](22/fr.md) |
| **`pollingInterval` et `cooldownPeriod`** | Période d’interrogation KEDA et délai avant la descente à zéro; le second s’applique seulement à scale-to-zero. | [35](35/fr.md) |
| **Prefix delegation** | Mode où un slot ENI reçoit un préfixe `/28` de 16 adresses; activé par `ENABLE_PREFIX_DELEGATION` et nécessitant Nitro. | [07](07/fr.md), [46](46/fr.md) |
| **preserve_client_ip** | Attribut de target group NLB qui contrôle la conservation de l’IP client en mode `ip`. | [26](26/fr.md) |
| **preStop** | Hook exécuté avant SIGTERM, utilisé pour attendre avant l’arrêt. | [40](40/fr.md) |
| **Principal** | Entité qui exécute une requête : utilisateur, rôle ou service AWS. | [0.2](00-2-iam/fr.md) |
| **private / public endpoint** | Mode d’accès à l’API server du cluster. | [45](45/fr.md) |
| **Private hosted zone** | Zone Route 53 créée et associée par EKS à votre VPC pour résoudre le nom du endpoint en adresse privée. | [02](02/fr.md) |
| **Projected service account token** | JWT compatible OIDC avec identité SA, audience `sts.amazonaws.com` et durée de vie, monté dans le pod et échangé par STS. | [16](16/fr.md) |
| **prometheus-adapter** | Adaptateur publiant les métriques Prometheus dans les API custom et external. | [35](35/fr.md) |
| **provisioningMode: efs-ap** | Mode StorageClass où le pilote crée un access point par PVC. | [24](24/fr.md) |
| **`publicAccessCidrs`** | Liste CIDR autorisée à atteindre le endpoint public; `0.0.0.0/0` par défaut. | [02](02/fr.md) |
| **Pull through cache** | Règle ECR mettant en cache à la demande dans votre ECR privé les images de registres externes (Docker Hub, Quay, `registry.k8s.io` et autres). | [20](20/fr.md) |
| **modèle pull** | L’agent du cluster tire lui-même depuis Git; push est un pipeline externe. | [44](44/fr.md) |
| **classe QoS** | `Guaranteed`, `Burstable` ou `BestEffort`, qui définit l’ordre d’éviction en cas de manque de mémoire. | [14](14/fr.md) |
| **ReadWriteMany (RWX)** | Access mode permettant le montage en écriture par plusieurs pods sur plusieurs nœuds simultanément. | [24](24/fr.md) |
| **Rebalance recommendation** | Signal précoce de risque accru de reprise, reçu avant le préavis de deux minutes et laissant du temps pour déplacer la charge. | [13](13/fr.md) |
| **recovery point** | Point de récupération, résultat d’un backup job réussi. | [41](41/fr.md) |
| **ReferenceGrant** | Ressource Gateway API dans le namespace cible autorisant les références cross-namespace par `backendRefs` et `certificateRefs`. | [28](28/fr.md) |
| **Replication configuration** | Règles ECR qui copient les images vers d’autres régions et comptes; le compte destinataire autorise la source à `ecr:CreateRepository` et `ecr:ReplicateImage` dans sa registry policy. | [20](20/fr.md) |
| **Repository creation template** | Modèle de chiffrement, lifecycle, immutability et policy pour les repositories créés par ECR à partir du pull through cache; sans lui, le repository reçoit les valeurs par défaut, dont `MUTABLE`. | [20](20/fr.md) |
| **Repository policy / registry policy** | Policies resource-based pour un repository ou tout le registry, avec prise en charge de `aws:PrincipalOrgID`. | [20](20/fr.md), [32](32/fr.md) |
| **requests** | Ressources servant au placement et à la décision d’autoscaler, réservées au pod. | [14](14/fr.md) |
| **resolveConflicts** | Comportement de l’add-on en conflit de champs : `NONE`, `OVERWRITE` ou `PRESERVE`. | [37](37/fr.md) |
| **Resource Modifiers** | ConfigMap Velero de patches JSON appliqués aux objets lors du restore avec `--resource-modifier-configmap`. | [42](42/fr.md) |
| **ResourceQuota / LimitRange** | Limite de consommation totale du namespace et valeurs par défaut/plafonds par conteneur. | [22](22/fr.md) |
| **restore hook** | Init container ou commande exec exécutée par Velero lors du restore d’un pod. | [42](42/fr.md) |
| **restore job** | Tâche AWS Backup lancée avec `start-restore-job` et suivie par `list-restore-jobs` ou `describe-restore-job`. | [42](42/fr.md) |
| **retention policy** | Durée de conservation des logs d’un log group, après laquelle les entrées sont supprimées; aucune expiration par défaut. | [34](34/fr.md) |
| **right-sizing** | Ajustement des requests/limits à la consommation réelle afin de compacter les nœuds. | [14](14/fr.md), [43](43/fr.md) |
| **rollback readiness** | Préparation au rollback de version, dont la fenêtre et l’ordre sont connus. | [48](48/fr.md) |
| **rollback readiness insights** | Type de cluster insights `ROLLBACK_READINESS` vérifiant la préparation au rollback, avec statuts PASSING/WARNING/ERROR/UNKNOWN. | [39](39/fr.md) |
| **utilisateur root** | Propriétaire de compte aux permissions illimitées, à utiliser seulement lors de la configuration initiale. | [0.1](00-1-aws/fr.md) |
| **Route 53 Resolver** | DNS VPC intégré à l’adresse « CIDR plus 2 », upstream de CoreDNS. | [0.3](00-3-vpc/fr.md) |
| **Route table** | Table de routes d’un subnet; subnet public et privé ne diffèrent que par leur route par défaut. | [0.3](00-3-vpc/fr.md) |
| **RPO** | Volume maximal acceptable de perte de données, défini par la fréquence de backup. | [42](42/fr.md) |
| **RTO** | Durée cible de restauration du service après incident. | [42](42/fr.md) |
| **S3 Express One Zone** | Classe de stockage zonale avec faible latence et IOPS élevés, supportant `append`, contrairement aux buckets general purpose. | [25](25/fr.md) |
| **S3 Object Lock** | Protection WORM d’un bucket S3 : versions immuables pendant une rétention Governance ou Compliance, protégeant les backups Velero. | [42](42/fr.md) |
| **sampling** | Enregistrement d’une fraction, et non de toutes les traces, pour contrôler volume et coût. | [36](36/fr.md) |
| **sampling rules** | Règles X-Ray définissant la part de requêtes enregistrées par reservoir et fixed rate. | [36](36/fr.md) |
| **Savings Plans / RI** | Remise de 30 à 70 % contre engagement d’un ou trois ans. | [0.4](00-4-ec2/fr.md) |
| **scale-to-zero** | Réduction d’un Deployment à zéro replica lorsqu’il est inactif; KEDA le permet, HPA non. | [35](35/fr.md) |
| **ScaledJob** | CRD KEDA qui scale le nombre de Job parallèles selon des unités de travail. | [35](35/fr.md) |
| **ScaledObject** | CRD KEDA décrivant la cible de scaling et les triggers d’un Deployment. | [35](35/fr.md) |
| **scaler** | Source de métrique KEDA, par exemple `aws-sqs-queue`, `aws-cloudwatch`, `prometheus`, `kafka` ou `cron`. | [35](35/fr.md) |
| **Schedule** | Objet Velero de backup périodique par cron, qui définit le RPO. | [42](42/fr.md) |
| **SCP (Service Control Policy)** | Politique restrictive d’OU ou de compte qui fixe le maximum de permissions sans rien accorder par elle-même. | [0.1](00-1-aws/fr.md), [0.2](00-2-iam/fr.md) |
| **Secondary CIDR** | Bloc IPv4 supplémentaire d’un VPC, habituellement pris dans `100.64.0.0/10` pour EKS. | [07](07/fr.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | Driver montant un secret AWS sous forme de fichiers dans un volume de nœud, par `SecretProviderClass`, avec synchronisation `Secret` optionnelle. | [18](18/fr.md) |
| **Security group** | Pare-feu stateful appliqué à une ENI, avec seulement allow et une autre SG possible comme source. | [0.3](00-3-vpc/fr.md), [46](46/fr.md) |
| **`SecurityGroupPolicy`** | Ressource attachant une SG aux pods par selector; un pod avec branch ENI n’hérite plus des règles SG du nœud. | [46](46/fr.md) |
| **self-heal** | Retour automatique du drift à l’état décrit dans Git. | [44](44/fr.md) |
| **self-managed addon** | Composant installé par Helm ou manifeste; l’ingénieur assume entièrement cycle de vie et compatibilité. | [37](37/fr.md) |
| **Self-managed node** | Instance EC2 que vous créez et joignez vous-même, avec access entry `EC2_LINUX`; vous gérez tout son cycle de vie. | [09](09/fr.md) |
| **service map** | Carte des services et de leurs liens, avec latence et taux d’erreur sur les arêtes. | [36](36/fr.md) |
| **Service Network** | Frontière VPC Lattice pour un ensemble de services; les VPC consommateurs lui sont associés pour accéder aux services. | [28](28/fr.md) |
| **Service Quotas** | Limites de services par compte et région, augmentables sur demande. | [0.1](00-1-aws/fr.md) |
| **`serviceIpv4Cidr`** | Plage d’adresses Service, virtuelle et indépendante du VPC. | [06](06/fr.md) |
| **ServiceMonitor, PodMonitor** | CRD Prometheus Operator décrivant déclarativement les endpoints à scraper. | [33](33/fr.md) |
| **Session tags** | Tags de session ajoutés par Pod Identity, notamment cluster, namespace et SA, servant à l’ABAC; les policies utilisent `aws:PrincipalTag/kubernetes-namespace` et `aws:PrincipalTag/eks-cluster-name`, et exigent `sts:TagSession`. | [17](17/fr.md) |
| **shared costs** | Coûts communs de cluster, tels que control plane, namespaces système et idle, répartis selon une règle ou affichés séparément. | [43](43/fr.md) |
| **Shared responsibility** | AWS est responsable de la sécurité du cloud, vous de la sécurité dans le cloud. | [0.1](00-1-aws/fr.md), [01](01/fr.md) |
| **shared services account** | Compte hébergeant des ressources communes, comme ECR, zones DNS privées et observabilité. | [32](32/fr.md) |
| **shared VPC** | Modèle où le propriétaire partage ses subnets via RAM et d’autres comptes y lancent leurs ressources, dont les nœuds EKS. | [32](32/fr.md) |
| **showback** | Les équipes voient leur coût sans transfert d’argent. | [43](43/fr.md) |
| **SNAT** | Remplacement de l’adresse source par celle du nœud pour l’egress des pods; désactivable par `AWS_VPC_K8S_CNI_EXTERNALSNAT`. | [06](06/fr.md) |
| **Soft multi-tenancy** | Tenants dans un même cluster, isolés par namespace, RBAC, quotas, NetworkPolicy et policies, avec control plane partagé. | [22](22/fr.md) |
| **span** | Opération individuelle dans une trace, telle qu’un traitement, appel ou requête de base de données, avec temps et attributs. | [36](36/fr.md) |
| **split-horizon DNS** | Même nom avec réponses différentes hors et dans le VPC, grâce à une paire de zones public et private. | [29](29/fr.md) |
| **Spot interruption notice** | Notification reçue deux minutes avant arrêt ou terminaison d’une instance Spot, délai fixe pour l’arrêt propre. | [13](13/fr.md) |
| **instance Spot** | Capacité EC2 libre remise, que AWS peut reprendre à tout moment en cas de demande on-demand. | [13](13/fr.md) |
| **pool Spot** | Couple « type d’instance + Availability Zone » dont la capacité est reprise par pool. | [13](13/fr.md) |
| **ssl-redirect** | Annotation activant la redirection HTTP vers HTTPS au port de listener indiqué. | [27](27/fr.md) |
| **SSM Session Manager** | Accès à une instance sans SSH, par l’agent SSM. | [45](45/fr.md) |
| **Staging labels** | Labels de versions de secret dans Secrets Manager : `AWSCURRENT`, `AWSPENDING` et `AWSPREVIOUS`. | [18](18/fr.md) |
| **Stakater Reloader** | Contrôleur déclenchant un rolling restart de Deployment à la modification d’un `Secret` ou `ConfigMap` monté. | [18](18/fr.md) |
| **Standard support** | Phase de support du minor EKS, environ quatorze mois, sans supplément de coût de version. | [03](03/fr.md), [38](38/fr.md), [48](48/fr.md) |
| **State** | Fichier de correspondance entre code Terraform et ressources réelles, stocké dans S3 avec versioning et verrouillage. | [0.5](00-5-tools/fr.md), [04](04/fr.md) |
| **stdout/stderr** | Flux de sortie standards du conteneur; par convention Kubernetes, l’application y écrit ses logs plutôt que dans des fichiers. | [34](34/fr.md) |
| **STS** | Service d’identifiants temporaires, notamment `sts:AssumeRole` et `sts:AssumeRoleWithWebIdentity`. | [0.2](00-2-iam/fr.md) |
| **Subnet CIDR reservation** | Réservation d’un bloc continu dans un subnet pour des préfixes. | [07](07/fr.md) |
| **subnet IP exhaustion** | Le subnet ne possède plus d’adresses libres pour ENI et pods. | [46](46/fr.md) |
| **sync waves** | Ordre d’application des ressources Argo CD par vagues au sein des phases sync. | [44](44/fr.md) |
| **Tag immutability** | Mode repository `IMMUTABLE` interdisant d’écraser un tag; `MUTABLE`, par défaut, l’autorise. | [20](20/fr.md) |
| **target EKS cluster** | Cluster existant recevant le restore, ou cluster créé par AWS Backup lors du restore avec `newCluster=true`. | [42](42/fr.md) |
| **target-type** | Type de target NLB : `instance` via NodePort ou `ip` directement vers l’IP du pod; `ip` requiert VPC CNI et est obligatoire sur Fargate. | [26](26/fr.md), [27](27/fr.md) |
| **`terminationGracePeriod`** | Limite de drain de nœud; si elle est présente, drift progresse même avec PDB bloquants et `do-not-disrupt`. | [12](12/fr.md) |
| **terminationGracePeriodSeconds** | Temps entre SIGTERM et SIGKILL pour terminer le pod, 30 par défaut. | [40](40/fr.md) |
| **terragrunt** | Surcouche terraform : backend partagé, `env.hcl`, `dependency`, `run-all` et modules DRY. | [0.5](00-5-tools/fr.md) |
| **Thanos** | Composants ajoutant à Prometheus un stockage long terme en objet : `sidecar`, `store gateway`, `compactor`, `querier` et `ruler`. | [33](33/fr.md) |
| **throughput mode** | Mode de débit EFS : Elastic, Bursting ou Provisioned. | [24](24/fr.md) |
| **topology aware routing** | Préférence pour les endpoints de la zone cliente, activée par `trafficDistribution: PreferClose` dans Service. | [31](31/fr.md) |
| **topologySpreadConstraints** | Champ de pod répartissant uniformément les réplicas par domaines avec `maxSkew`, `topologyKey`, `whenUnsatisfiable` et `minDomains`. | [40](40/fr.md) |
| **trace** | Chemin complet d’une requête à travers les services, avec un `trace id` commun. | [36](36/fr.md) |
| **Transit Gateway** | Routeur-hub régional avec routage transitif entre VPC, VPN et Direct Connect, partageable via RAM. | [32](32/fr.md) |
| **TriggerAuthentication** | CRD KEDA contenant les paramètres d’accès du trigger; pour AWS, provider `aws` par IRSA ou Pod Identity. | [35](35/fr.md) |
| **Trust policy** | Politique de confiance de rôle avec principal `Federated`, action `Action` `sts:AssumeRoleWithWebIdentity` et conditions `StringEquals` sur `sub` et `aud`. | [0.2](00-2-iam/fr.md), [16](16/fr.md), [47](47/fr.md) |
| **registre TXT** | Mécanisme external-dns qui marque ses enregistrements d’un marqueur TXT; propriétaire défini par `--txt-owner-id`. | [29](29/fr.md) |
| **Unauthorized (401)** | Échec d’authentification : l’identité n’est pas prouvée ou mappée. | [47](47/fr.md) |
| **`unhealthyPodEvictionPolicy`** | Champ PDB : `IfHealthyBudget` ne permet pas d’évincer les pods non sains si l’application est déjà perturbée, `AlwaysAllow` l’autorise toujours. | [40](40/fr.md) |
| **upgrade insights** | Type d’insights signalant la préparation à l’upgrade et les API supprimées. | [38](38/fr.md) |
| **Upgrade policy (`supportType`)** | Champ de configuration avec `STANDARD` et `EXTENDED`, qui définit le comportement à la fin du standard support. | [03](03/fr.md) |
| **`useCachedMetrics` et `fallback`** | Mise en cache sur l’intervalle de polling et nombre de réplicas de secours en cas de source indisponible; ensemble, ils réduisent le risque de throttling API et de `<unknown>` dans `TARGETS`. | [35](35/fr.md) |
| **User data** | Script ou configuration exécuté au premier démarrage d’une instance, lançant bootstrap et configurant `kubelet`. | [0.4](00-4-ec2/fr.md), [10](10/fr.md) |
| **ValidatingAdmissionPolicy** | Validation CEL intégrée à apiserver depuis Kubernetes 1.30+, sans webhook externe, avec `ValidatingAdmissionPolicyBinding` (cible et réaction `Deny`/`Warn`/`Audit`). | [22](22/fr.md) |
| **Vault Lock** | Protection WORM du vault contre la suppression de backups, en modes governance et compliance. | [41](41/fr.md) |
| **Velero** | Backup/restore Kubernetes-native : objets dans S3 via BackupStorageLocation et volumes par CSI snapshots ou File System Backup. | [42](42/fr.md) |
| **velero-plugin-for-aws** | Plugin Velero officiel AWS, object store S3 pour BSL et volume snapshotter pour snapshots EBS. | [42](42/fr.md) |
| **Version skew** | Retard kubelet admissible selon la policy upstream, expliquant l’ordre control plane puis nœuds. | [03](03/fr.md), [37](37/fr.md) |
| **version skew policy** | Règle Kubernetes : les nœuds ne doivent pas être plus récents que le control plane; elle impose l’ordre du rollback. | [38](38/fr.md), [39](39/fr.md) |
| **VersionRollback** | Type de mise à jour dans la réponse `update-cluster-version` lors d’un rollback. | [39](39/fr.md) |
| **VictoriaLogs** | Base de logs sans dépendance, sans schéma ni index à configurer, avec stockage colonnaire, requêtes LogsQL et option cluster (`vlinsert`, `vlstorage`, `vlselect`). | [34](34/fr.md) |
| **VictoriaMetrics** | Remplacement du stockage de métriques : `vmagent` pour la collecte, `vmsingle` ou le cluster `vminsert`/`vmstorage`/`vmselect`, `vmalert` pour les règles, `-retentionPeriod` et MetricsQL. | [33](33/fr.md) |
| **volume node affinity conflict** | Événement scheduler lorsque `nodeAffinity` du volume désigne une zone sans nœud compatible. | [23](23/fr.md) |
| **`volumeBindingMode`** | Moment du provisionnement : `Immediate` à la création du PVC, ou `WaitForFirstConsumer` au placement du pod. | [23](23/fr.md) |
| **VolumeSnapshot / Content / Class** | Objets CSI de snapshots : demande, snapshot AWS et classe. | [23](23/fr.md) |
| **voluntary disruption** | Éviction délibérée des pods, par drain, upgrade de nœuds ou consolidation; PDB la protège. | [40](40/fr.md) |
| **VPC** | Réseau isolé régional; son CIDR principal `/16` à `/28` est immuable et n’est extensible que par secondary CIDR. | [0.3](00-3-vpc/fr.md) |
| **VPC CNI** | Plugin réseau AWS attribuant aux pods de vraies adresses privées des subnets VPC; DaemonSet `aws-node` dans `kube-system`. | [06](06/fr.md) |
| **VPC CNI network policy** | Implémentation eBPF intégrée de `NetworkPolicy`, avec contrôleur control plane et `aws-network-policy-agent` dans `aws-node`; activée par le paramètre d’add-on `enableNetworkPolicy`. | [08](08/fr.md), [30](30/fr.md) |
| **VPC endpoint** | Accès privé à un service AWS : gateway pour S3/DynamoDB ou interface PrivateLink. | [0.3](00-3-vpc/fr.md), [31](31/fr.md) |
| **VPC endpoint (PrivateLink)** | Point d’entrée privé vers un service AWS dans le VPC, obligatoire pour ECR, S3, STS, EKS et autres dans un data plane privé. | [19](19/fr.md) |
| **VPC Flow Logs** | Journal de flux acceptés et rejetés; `action = REJECT` dans CloudWatch Logs Insights sert au SecOps et au diagnostic. | [0.3](00-3-vpc/fr.md) |
| **VPC Lattice** | Service réseau applicatif géré pour communication east-west entre VPC et comptes, sans sidecars ni peering. | [28](28/fr.md) |
| **VPC peering** | Connexion directe un-à-un de deux VPC, non transitive et exigeant des CIDR non chevauchants. | [32](32/fr.md) |
| **wafv2-acl-arn** | Annotation attachant une Web ACL AWS WAF v2 à un ALB pour filtrer les requêtes. | [27](27/fr.md) |
| **warm pool** | Réserve d’adresses IPv4 déjà attribuées sur le nœud, pour démarrer rapidement les pods. | [06](06/fr.md) |
| **`WARM_PREFIX_TARGET`** | Réserve de préfixes par nœud; `WARM_IP_TARGET` et `MINIMUM_IP_TARGET` sont prioritaires. | [07](07/fr.md) |
| **workspace** | Stockage de métriques AMP isolé avec endpoint remote-write et API compatible Prometheus. | [33](33/fr.md) |
| **X-Amzn-Trace-Id** | En-tête X-Ray avec `Root`, `Parent`, `Sampled`; le propagator ADOT le mappe à `traceparent` W3C. | [36](36/fr.md) |
| **ZoneId (`euc1-az1`)** | Nom stable d’une Availability Zone, identique dans tous les comptes. | [0.1](00-1-aws/fr.md) |
| **add-on `adot`** | Add-on EKS géré déployant ADOT Operator afin de gérer les Collectors. | [36](36/fr.md) |
| **Compte** | Espace de ressources isolé et unité de facturation; son numéro à 12 chiffres apparaît dans ARN et trust policies. | [0.1](00-1-aws/fr.md) |
| **adresse privée secondaire** | Adresse IPv4 supplémentaire de l’ENI d’un nœud, attribuée à un pod. | [06](06/fr.md) |
| **diversification** | Multiples types d’instances dans plusieurs AZ, afin que la reprise d’un pool n’élimine pas une part critique des nœuds. | [13](13/fr.md) |
| **domaine de préparation** | Axe opérationnel vérifié séparément : control plane, nœuds, sécurité, réseau, stockage, observabilité, exploitation ou incidents. | [48](48/fr.md) |
| **drift** | Écart entre l’état réel et celui décrit dans le code ou Git. | [04](04/fr.md), [44](44/fr.md) |
| **dépendance entre stacks** | Passage des outputs d’un stack aux inputs d’un autre, par exemple le bloc Terragrunt `dependency`. | [04](04/fr.md) |
| **instance EC2** | Machine virtuelle; pour EKS, c’est un nœud avec containerd et kubelet. | [0.4](00-4-ec2/fr.md) |
| **cache local** | Cache Mountpoint sur le volume du nœud, `cache: emptyDir`/`ephemeral`, accélérant les relectures; `metadata-ttl` règle le cache de métadonnées. | [25](25/fr.md) |
| **scaling des nœuds et des pods** | Niveaux distincts : CA et Karpenter scalent les nœuds, HPA, VPA et KEDA scalent les pods. | [11](11/fr.md) |
| **micro-VM** | Machine virtuelle dédiée à un seul pod, avec noyau, CPU, mémoire et interface réseau propres; frontière d’isolation Fargate. | [15](15/fr.md) |
| **stockage objet** | Modèle clé-valeur : objet immuable, octets et métadonnées, sous une clé texte, remplacé intégralement par `PutObject`. | [25](25/fr.md) |
| **fenêtre de rollback (7 jours)** | Période après l’upgrade où le rollback est disponible; passée cette période, rollback et insights ne le sont plus. | [39](39/fr.md) |
| **plugin kubectl** | Fichier `kubectl-<nom>` dans `PATH`, accessible par `kubectl <nom>`. | [0.5](00-5-tools/fr.md) |
| **subnet** | Partie d’un CIDR VPC située dans une Availability Zone. | [0.3](00-3-vpc/fr.md) |
| **remplacement complet** | `aws-node` est supprimé et Cilium devient le seul CNI avec IPAM ENI ou cluster-pool overlay/VXLAN. | [08](08/fr.md) |
| **préfixe** | Partie d’une clé avant `/`, dont Mountpoint émule un répertoire; S3 ne contient pas de vrais répertoires. | [25](25/fr.md) |
| **upgrade forcé** | Montée automatique de version après extended support; un tel cluster ne peut pas être rollback. | [38](38/fr.md) |
| **Provider** | Plugin terraform, comme `aws`, `kubernetes` ou `helm`. | [0.5](00-5-tools/fr.md) |
| **livraison progressive** | Déploiement canary ou blue-green d’applications, via Argo Rollouts ou Flagger. | [44](44/fr.md) |
| **checklist de production** | Liste systématique de contrôles par domaines, dont chaque point est fermé ou déclaré risque connu. | [48](48/fr.md) |
| **Profil** | Ensemble nommé de paramètres : région, rôle et SSO. | [0.5](00-5-tools/fr.md) |
| **Région** | Zone géographique, telle que `eu-central-1`, à laquelle les ressources sont rattachées. | [0.1](00-1-aws/fr.md) |
| **mode external** | Valeur de l’annotation `aws-load-balancer-type` qui confie la réconciliation Service au LBC externe plutôt qu’au provider in-tree. | [26](26/fr.md) |
| **modes d’accès EBS** | `ReadWriteOnce` pour un nœud et `ReadWriteOncePod` pour un pod; `ReadWriteMany` n’est possible qu’en Multi-Attach `io2`, avec `volumeMode: Block`, dans une seule AZ et sans système de fichiers. Le partage de fichiers requiert EFS ou FSx. | [23](23/fr.md) |
| **réconciliation** | Boucle continue de comparaison de l’état souhaité Git avec l’état réel du cluster. | [44](44/fr.md) |
| **provisionnement statique** | PV décrit manuellement avec `bucketName`; le pilote ne crée pas dynamiquement de buckets. | [25](25/fr.md) |
| **Stack** | Unité d’infrastructure appliquée indépendamment avec son propre state. | [0.5](00-5-tools/fr.md), [04](04/fr.md) |
| **stratégie de rotation** | `single user` modifie le mot de passe d’un seul utilisateur; `alternating users` alterne deux utilisateurs et nécessite un secret superuser. | [18](18/fr.md) |
| **stratégie Spot** | Choix de pool : `capacity-optimized(-prioritized)` ou `lowest-price`; les stratégies orientées capacité sont moins interrompues. | [0.4](00-4-ec2/fr.md) |
| **Tag** | Paire clé/valeur; les contrôleurs EKS localisent des ressources avec les tags et un cost allocation tag activé ventile la facture. | [0.1](00-1-aws/fr.md) |
| **type d’instance** | `famille + génération + suffixe . taille`, par exemple `m7g.xlarge`. | [0.4](00-4-ec2/fr.md) |
| **types de logs control plane** | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`, écrits dans CloudWatch Logs uniquement après activation. | [02](02/fr.md) |
| **capacité EKS gérée pour Argo CD** | Argo CD comme EKS Capability : contrôleurs dans le control plane AWS, cibles EKS seulement par ARN et accès via access entries. | [44](44/fr.md) |
| **filtre kubernetes** | FILTER Fluent Bit qui ajoute namespace, pod, conteneur, labels et annotations aux enregistrements. | [34](34/fr.md) |
| **sharding Argo CD** | Répartition des clusters connectés entre les réplicas application-controller. | [44](44/fr.md) |
| **`--force`** | Flag contournant les vérifications insights ERROR/WARNING/UNKNOWN, mais non les préconditions d’upgrade. | [39](39/fr.md) |
| **`/var/log/containers`** | Répertoire de nœud de liens vers les fichiers de logs des conteneurs, depuis lequel le collecteur les lit. | [34](34/fr.md) |
