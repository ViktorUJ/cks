[Русская версия](ADR_RU.md) · [Eng version](ADR.md) · [Versión en español](ADR_ES.md) · [Deutsche Version](ADR_DE.md) · [ქართული ვერსია](ADR_GE.md) · [繁體中文版](ADR_TW.md) · [日本語版](ADR_JP.md)

# Décisions d'architecture du cours EKS (ADR)

[Sommaire du cours](README_FR.md) · [Glossaire](GLOSSARY_FR.md)

## Comment l'utiliser

Un ADR (Architecture Decision Record) est un bref enregistrement d'une décision : pourquoi ce
choix, quelles étaient les alternatives et quel prix nous payons pour ce choix. L'objectif n'est
pas de documenter pour documenter, mais d'éviter de refaire le débat un an plus tard et de
permettre à une nouvelle personne dans l'équipe de comprendre la motivation, pas seulement le
résultat.

Les modèles ci-dessous sont déjà renseignés avec le contenu du cours : les alternatives, leurs
avantages et leur coût proviennent des chapitres, ils ne sont pas inventés ici. Mais **le
contexte, le statut, la date et la décision elle-même sont rédigés par l'ingénieur** pour son
projet : le cours ne connaît ni votre parc de clusters, ni vos exigences de conformité, ni la
disponibilité de l'équipe plateforme.

Une « alternative rejetée » ne signifie pas qu'elle est « mauvaise ». Dans presque tous les
embranchements du cours, les deux alternatives sont valables, et celle qui est rejetée devient la
bonne avec d'autres données d'entrée : c'est pour cela qu'il existe le champ « conditions de
réexamen ».

## Modèle vide

```markdown
## ADR-NN. Titre court de la décision

Statut : proposé / accepté / rejeté / remplace ADR-NN
Date : YYYY-MM-DD

**Contexte.** Quelle est la tâche, quelles sont les contraintes, quelles questions faut-il trancher.

**Alternatives examinées.**

| Alternative | Ce qu'elle apporte | Ce que cela coûte | Quand elle convient |
|---|---|---|---|
|  |  |  |  |

**Conséquences de la décision retenue.**

- Ce que nous obtenons :
- Ce que cela coûte :

**Décision.** Ce qui a été choisi et dans quel périmètre (tout le parc, un cluster, un pilote).

**Conditions de réexamen.** Déclencheurs concrets qui rouvrent cet enregistrement.

**Références.** Chapitres du cours et documents internes au projet.
```

## ADR-01. Calcul : EKS Auto Mode contre sa propre stack Karpenter

Statut : _à renseigner par l'ingénieur_
Date : _à renseigner par l'ingénieur_

**Contexte.** Répondre avant de choisir :

- existe-t-il une exigence de sécurité sur l'image de nœud (AMI attestée, bootstrap personnalisé) ;
- un accès au nœud est-il nécessaire pour le débogage ou pour des agents de nœud déployés via DaemonSet ;
- faut-il un CNI autre que VPC CNI et contrôler le contrôleur Karpenter lui-même, pas seulement le NodePool ;
- le coût est-il critique : le supplément de gestion au-delà d'EC2 est-il acceptable ;
- une équipe est-elle prête à opérer les nœuds, ou l'objectif est-il réellement de minimiser l'exploitation.

**Alternatives examinées.**

| Alternative | Ce qu'elle apporte | Ce que cela coûte | Quand elle convient |
|---|---|---|---|
| EKS Auto Mode | nœuds comme appliance : Bottlerocket, SELinux enforcing, racine en lecture seule, rotation au plus tous les 21 jours, Karpenter, IPAM, network policy, EBS CSI, ELB et Pod Identity intégrés | supplément de gestion au-delà d'EC2 (non couvert par les remises Reserved et Savings Plans), pas de SSH ni de SSM, impossible de modifier les NodePool et NodeClass par défaut, CNI tiers impossible | l'objectif est de minimiser l'exploitation des nœuds, sans exigences sur l'image ni l'accès au nœud |
| Stack personnalisée : managed node groups ou self-managed avec son propre Karpenter | son propre launch template et AMI, accès au nœud, tout CNI, maîtrise complète de la version et de la configuration de Karpenter | les nœuds, addons, mises à niveau et gestion des interruptions sont à votre charge, vous ne payez qu'EC2 | une exigence non couverte par Auto Mode existe, ou l'économie ne supporte pas le supplément |

**Conséquences de la décision retenue.**

- Ce que nous obtenons : un modèle unique d'exploitation des nœuds par cluster et une frontière
  de responsabilité prévisible entre AWS et l'équipe.
- Ce que cela coûte : dans Auto Mode, vous restez responsable des conteneurs, de la configuration
  du cluster et du VPC, des volumes issus des PVC et des équilibreurs de charge ; les NodePool
  personnalisés n'héritent pas des limitations des NodePool par défaut, donc les limites et les
  types d'instances doivent être définis manuellement, sinon le pool croît sans plafond.

**Décision.** _à renseigner pour votre projet_

**Conditions de réexamen.** Une exigence d'image de nœud attestée est apparue ; un agent de nœud
qui ne fonctionne pas en sidecar est devenu nécessaire ; Cilium est nécessaire comme CNI
principal ; les disruption budgets ont commencé à bloquer les mises à jour au-delà de la durée de
vie du nœud ; le parc a atteint un volume où les pics dus au remplacement des nœuds et le
supplément de gestion deviennent visibles sur la facture.

**Références.** [chapitre 9](09/fr.md) - types de calcul, sections 9.6-9.8 ;
[chapitre 10](10/fr.md) - launch template et AMI personnalisées ; [chapitre 12](12/fr.md) - NodePool et
perturbation ; [chapitre 43](43/fr.md) - analyse des coûts.

## ADR-02. Identité des pods : IRSA contre EKS Pod Identity

Statut : _à renseigner par l'ingénieur_
Date : _à renseigner par l'ingénieur_

**Contexte.** Répondre avant de choisir :

- combien de clusters y a-t-il et les rôles sont-ils transférés entre eux ;
- des charges de travail sur Fargate ou sur des nœuds Windows existent-elles ;
- une identité hors EKS (EC2, ECS, Lambda) utilisant les mêmes rôles est-elle nécessaire ;
- le cross-account est-il nécessaire et sous quelle forme ;
- quelle est la platform version des clusters existants.

**Alternatives examinées.**

| Alternative | Ce qu'elle apporte | Ce que cela coûte | Quand elle convient |
|---|---|---|---|
| IRSA | fédération OIDC via STS, fonctionne hors EKS, cross-account direct, prend en charge Fargate et les nœuds Windows | un IAM OIDC provider par cluster, la trust policy doit être réécrite pour chaque cluster, session tags manuels | Fargate, Windows, identité hors EKS, cross-account par fédération |
| EKS Pod Identity | une trust policy unique sur `pods.eks.amazonaws.com` pour tous les clusters, liaison par association dans l'API EKS sans annotations, session tags et ABAC prêts à l'emploi | uniquement les nœuds Linux Amazon EC2, pas de Fargate, Windows, Outposts ni EKS Anywhere, un addon agent et une platform version minimale sont requis | nouveaux clusters sur nœuds EC2, parc de clusters avec rôles réutilisables |

**Conséquences de la décision retenue.**

- Ce que nous obtenons : une méthode unique pour accorder des permissions aux pods et une source
  de vérité claire indiquant où le rôle est lié à un ServiceAccount.
- Ce que cela coûte : un parc hybride impose de conserver les deux modèles ; lors d'une
  configuration simultanée sur le même ServiceAccount, IRSA l'emporte, car web identity apparaît
  dans la chaîne SDK avant le fournisseur de conteneur, et l'association Pod Identity est
  silencieusement ignorée.

**Décision.** _à renseigner pour votre projet_

**Conditions de réexamen.** Des profils Fargate ou des nœuds Windows ont été ajoutés au parc ;
un besoin d'ABAC par session tags est apparu ; les restrictions de Pod Identity ont diminué dans
la documentation ; le même rôle est devenu nécessaire pour des charges de travail à l'intérieur
et à l'extérieur d'EKS.

**Références.** [chapitre 16](16/fr.md) - IRSA et fournisseur OIDC ; [chapitre 17](17/fr.md) - Pod
Identity, comparaison et ordre de migration.

## ADR-03. Réseau : VPC CNI contre Cilium (chaining ou remplacement complet)

Statut : _à renseigner par l'ingénieur_
Date : _à renseigner par l'ingénieur_

**Contexte.** Répondre avant de choisir :

- des politiques L7 (HTTP, gRPC, Kafka) ou par noms DNS sont-elles nécessaires, et qui les écrira ;
- une observabilité des flux entre pods au niveau de Hubble est-elle nécessaire ;
- les adresses réelles des pods dans le VPC, les security groups for pods et les Flow Logs par pod sont-ils importants ;
- la pénurie d'IPv4 ne peut-elle pas être résolue par d'autres moyens ;
- l'équipe est-elle prête à prendre en charge les mises à niveau du CNI et sa compatibilité avec la version du cluster.

**Alternatives examinées.**

| Alternative | Ce qu'elle apporte | Ce que cela coûte | Quand elle convient |
|---|---|---|---|
| VPC CNI avec NetworkPolicy intégré | addon géré, support AWS, mises à niveau standard, `NetworkPolicy` L3/L4 standard et `ClusterNetworkPolicy` d'administration, adresses VPC réelles | pas de règles L7, pas de politiques par FQDN, pas de CRD Cilium ni de Hubble | une isolation L3/L4 est nécessaire, le modèle d'adressage VPC convient |
| Cilium en mode CNI chaining | `CiliumNetworkPolicy`, politiques L7 et DNS, Hubble, tandis que l'IPAM et les intégrations VPC restent à la charge de VPC CNI | installation et maintenance de Cilium à votre charge, deuxième modèle de CRD, formation de l'équipe | des politiques L7 ou DNS, ou Hubble, sont nécessaires et le modèle d'adressage convient |
| Cilium comme remplacement complet (ENI IPAM ou cluster-pool) | son propre IPAM, overlay optionnel et sortie de la pénurie d'IPv4, ClusterMesh, remplacement de kube-proxy par eBPF | les mises à niveau et la compatibilité sont à votre charge, le support AWS est réduit, les adresses réelles des pods, SG for pods et les adresses de pods dans Flow Logs sont perdus avec l'overlay | un overlay ou un réseau multi-cluster est nécessaire, ou des exigences que le modèle ENI ne couvre pas |

**Conséquences de la décision retenue.**

- Ce que nous obtenons : une frontière explicite entre ce qui est couvert par le support AWS et ce
  dont l'équipe plateforme est responsable.
- Ce que cela coûte : il est impossible de changer de CNI en basculant un indicateur, le CNI est
  attribué au pod lors de sa création ; la transition est donc un blue/green via un nouveau pool
  de nœuds ou un nouveau cluster ; le diagnostic de défaillance passe dans les outils du CNI ; une
  fenêtre sans politiques au démarrage du pod doit aussi être prévue
  (`NETWORK_POLICY_ENFORCING_MODE` en mode `standard` applique default allow).

**Décision.** _à renseigner pour votre projet_

**Conditions de réexamen.** Un besoin de politiques L7 ou par noms DNS est apparu ; une carte des
flux entre pods est devenue nécessaire ; la pénurie d'IPv4 ne peut plus être résolue par les
moyens du chapitre 7 ; un Pod Network partagé entre plusieurs clusters est devenu nécessaire ;
kube-proxy iptables est devenu le goulot d'étranglement.

**Références.** [chapitre 8](08/fr.md) - CNI alternatifs, coût de la transition, migration ;
[chapitre 6](06/fr.md) - adressage des pods par ENI ; [chapitre 7](07/fr.md) - pénurie d'adresses ;
[chapitre 30](30/fr.md) - politiques réseau en production.

## ADR-04. Autoscaling des nœuds : Cluster Autoscaler contre Karpenter

Statut : _à renseigner par l'ingénieur_
Date : _à renseigner par l'ingénieur_

**Contexte.** Répondre avant de choisir :

- le cluster est-il en Auto Mode ou sur sa propre stack (en Auto Mode, la question est tranchée, Karpenter est déjà intégré) ;
- à quel point les charges de travail sont-elles hétérogènes et combien de node groups faudra-t-il maintenir ;
- une réaction rapide aux pics de trafic est-elle requise ;
- une uniformisation avec les clusters dans d'autres clouds au moyen d'un seul outil est-elle nécessaire ;
- CA est-il déjà installé, bien réglé et pose-t-il réellement un problème.

**Alternatives examinées.**

| Alternative | Ce qu'elle apporte | Ce que cela coûte | Quand elle convient |
|---|---|---|---|
| Cluster Autoscaler | fonctionne au-dessus de l'Auto Scaling group, méthode unique chez de nombreux fournisseurs, exploitation familière sans nouveaux CRD | réaction au niveau du groupe et non du pod ; l'ensemble de types est fixé par le launch template ; plus lent en raison de la couche ASG ; supprime les nœuds vides, mais ne consolide pas | clusters simples et prévisibles, uniformisation multi-cloud, installation fonctionnelle |
| Karpenter | appelle EC2 directement, choisit le type d'instance pour des pods précis, consolidation active, diversification de types pour spot | ses propres CRD `NodePool` et `EC2NodeClass`, responsabilité de la version et de la configuration du contrôleur, AWS-first | nouveaux clusters sur EKS, charges de travail hétérogènes, besoin de rapidité et de packing dense |

**Conséquences de la décision retenue.**

- Ce que nous obtenons : un mécanisme unique responsable de la création et de la suppression des
  nœuds, et un emplacement unique où les limites du parc sont définies.
- Ce que cela coûte : conserver les deux simultanément n'est autorisé que sur des ensembles de
  nœuds distincts et uniquement comme mode de migration temporaire, sinon ils se disputent les
  décisions de scale-down ; la migration passe par de nouveaux nœuds et non par le déplacement de
  pods sur un nœud en service.

**Décision.** _à renseigner pour votre projet_

**Conditions de réexamen.** Le zoo de node groups a grandi et est devenu ingérable ; l'inactivité
due au faible packing est devenue visible sur la facture ; la réaction aux pics de trafic ne
respecte plus le SLO ; le cluster est passé à Auto Mode ; des clusters sont apparus dans d'autres
clouds avec l'exigence d'un outil unique.

**Références.** [chapitre 11](11/fr.md) - comparaison des approches et checklist de sélection ;
[chapitre 12](12/fr.md) - NodePool, consolidation, disruption budgets ;
[chapitre 13](13/fr.md) - spot ; [chapitre 9](09/fr.md) - lien avec Auto Mode.

## ADR-05. GitOps pour un parc de clusters : hub-and-spoke contre décentralisation

Statut : _à renseigner par l'ingénieur_
Date : _à renseigner par l'ingénieur_

**Contexte.** Répondre avant de choisir :

- combien de clusters le parc compte-t-il actuellement et combien sont attendus ;
- l'autonomie du cluster est-elle requise en cas de perte du hub ou de sa liaison ;
- un tableau de bord unique pour l'ensemble du parc est-il nécessaire ;
- qui met à jour les agents et l'équipe est-elle prête à gérer la divergence de leurs versions ;
- quel est le coût du trafic de réconciliation au-delà de la frontière des clusters.

**Alternatives examinées.**

| Alternative | Ce qu'elle apporte | Ce que cela coûte | Quand elle convient |
|---|---|---|---|
| Hub-and-spoke | une instance Argo CD ou Flux sur le hub, aucun agent à installer dans chaque cluster, ApplicationSet avec générateurs cluster et git via matrix déploie un ensemble d'addons sur tout le parc, vue unique | le hub est un domaine de panne : les charges de travail des spokes continuent, mais l'application des commits, le self-heal et les rollbacks sont arrêtés pour tout le parc ; la réconciliation par le réseau apporte de la latence, des frais de trafic sortant et une sensibilité à la connectivité | parc petit ou moyen, où la simplicité d'exploitation et la vue unique sont privilégiées |
| Sharding du hub | les clusters sont répartis entre les répliques de l'application-controller, le nombre de répliques est dupliqué dans `ARGOCD_CONTROLLER_REPLICAS` | un seul domaine de panne demeure ; la distribution hash-based est inégale, round-robin est plus homogène | le parc dépasse les capacités d'un seul contrôleur, mais l'autonomie des clusters n'est pas requise |
| Décentralisation | le hub ne déploie que la base et un agent local, puis le cluster tire lui-même depuis Git et reste autonome si le hub est perdu | il y a autant d'agents que de clusters, ils doivent être mis à jour et configurés, il n'y a pas de vue unique, les versions des agents divergent | parc important ou exigence forte d'autonomie |
| argocd-agent | une instance Argo CD centrale voit les `Application` de tous les clusters, mais la synchronisation est tirée par l'agent côté spoke | projet `argoproj-labs`, incubateur et non cœur d'Argo CD ; la topologie reste hub-and-spoke | vous êtes prêt à utiliser un projet en incubation afin d'avoir un flux inverse |

**Conséquences de la décision retenue.**

- Ce que nous obtenons : une réponse claire à la question « qu'arrivera-t-il à la livraison si le
  hub est indisponible ».
- Ce que cela coûte : la frontière entre IaC et GitOps reste obligatoire dans toute topologie :
  l'infrastructure (VPC, cluster, node groups, IAM) passe par Terraform, et les addons ainsi que
  les charges de travail par GitOps ; les mélanger entraîne soit la recréation d'un cluster pour
  modifier un Deployment, soit un problème de poule et d'œuf avec un agent qui vit dans ce même
  cluster.

**Décision.** _à renseigner pour votre projet_

**Conditions de réexamen.** Le parc a suffisamment grandi pour qu'un seul contrôleur ne suffise
plus ; une exigence de poursuivre la réconciliation en cas de perte du hub est apparue ; le coût
du trafic sortant de réconciliation est devenu notable ; argocd-agent est sorti de l'incubation.

**Références.** [chapitre 44](44/fr.md) - topologies de parc, section 44.6 ;
[chapitre 32](32/fr.md) - parc de clusters ; [chapitre 4](04/fr.md) - IaC et Terraform ;
[chapitre 31](31/fr.md) - coût du trafic ; [chapitre 38](38/fr.md) - migration blue/green.

## Ce qui n'est délibérément pas tranché ici

Le cours ne considère pas certains embranchements comme architecturaux : la technique y est à peu
près équivalente, et c'est le contexte de l'entreprise qui décide. Le choix entre Argo CD et Flux
est une question de ce que l'équipe sait déjà utiliser et de l'interface dont elle a besoin, non
des propriétés des outils. Le choix entre son propre Prometheus et un service géré est une
question de qui assure l'astreinte et du coût du stockage, non de l'architecture de collecte des
métriques. Il en va de même pour le choix du registre d'images, de l'outil de secrets et de
l'organisation des comptes : ce sont des frontières organisationnelles. La liste récapitulative
des éléments à vérifier avant la mise en production figure dans le [chapitre 48](48/fr.md).
