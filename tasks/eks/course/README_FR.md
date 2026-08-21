[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# Amazon EKS : manuel pratique d'exploitation en production

Cours pratique sur Amazon EKS, associé aux travaux pratiques dans
`tasks/eks/labs`. Le cours s'adresse aux ingénieurs qui **ont déjà passé la
CKA** (ou maîtrisent Kubernetes au niveau administrateur) et passent à la
gestion d'un cluster AWS administré.

Il n'existe pas de certification EKS distincte. Le cours n'est donc pas conçu
pour un examen, mais pour l'exploitation réelle : ce dont l'ingénieur est
responsable lorsque le control plane est géré par AWS, alors que les nœuds, le
réseau, les accès, les coûts et les mises à jour restent à votre charge.

> **Prérequis.** Pods, Deployment, Service, Ingress, RBAC, PV/PVC, probes,
> kubectl et le débogage des charges de travail constituent les bases du cours
> CKA et ne sont pas repris ici. Si vous ne maîtrisez pas encore ces sujets,
> commencez par le [cours CKA + CKAD](../../cka/course/README_FR.md).

> **Versions.** Le cours couvre les versions actuelles d'EKS (Kubernetes `1.33`
> à `1.36`). EKS possède son propre cycle de vie des versions : 14 mois de
> standard support, plus 12 mois d'extended support (26 mois par version
> mineure). Le chapitre sur les mises à jour est donc lié au processus plutôt
> qu'à un numéro précis. Les TP du cours sont déployés avec la version indiquée
> dans le fichier `env.hcl` de chaque TP.

## Organisation du cours

Chaque sujet correspond à un dossier numéroté. Il contient des fichiers
localisés. La langue principale est le russe (`ru.md`), à partir duquel les
traductions seront réalisées, comme dans les cours CKA et Istio. Le sélecteur
de langue apparaît en première ligne de chaque fichier après la première
traduction.

Le cours nécessite **votre propre compte AWS** : presque tous les sujets ne
peuvent être vérifiés que sur un cluster actif, et certains (interruptions
spot, NAT et trafic, mises à jour, coûts) ne peuvent pas être reproduits dans
un kind local. Les TP sont déployés via Terragrunt et supprimés par une seule
commande afin de ne pas dépenser inutilement.

En plus des chapitres et des TP, le cours comprend des documents de référence
pratiques. Ils ne se lisent pas d'un bout à l'autre, mais selon les besoins :

- [Glossaire du cours](GLOSSARY_FR.md) - tous les termes des chapitres avec leurs liens
- [Guide de diagnostic](RUNBOOK_FR.md) - symptôme, cause, vérification : partie 8 de la synthèse
- [Décisions d'architecture (ADR)](ADR_FR.md) - modèles de décision pour les embranchements du cours
- [Matrice de maturité EKS](SCORECARD_FR.md) - questionnaire de préparation du cluster sur huit domaines
- [Modèle de coûts](COST_MODEL_FR.md) - liste des postes et formules, à compléter avec vos tarifs

## Sommaire

### Partie 0. Fondations AWS (facultative)

Partie préparatoire destinée à celles et ceux qui ont une solide expérience de
Kubernetes mais peu d'expérience d'AWS. Si IAM, VPC et EC2 sont des outils
familiers, passez directement à la partie 1. Cette partie ne possède pas de TP
distincts : elle sert à lire les autres chapitres sans lacunes.

- 0.1. [AWS pour l'ingénieur Kubernetes : comptes, régions, AZ, quotas, tags, facturation](00-1-aws/fr.md)
- 0.2. [IAM depuis zéro : politiques, rôles, relations de confiance, STS et clés temporaires](00-2-iam/fr.md)
- 0.3. [VPC depuis zéro : sous-réseaux, routage, IGW et NAT, security groups, VPC endpoints](00-3-vpc/fr.md)
- 0.4. [EC2 et modèles de paiement : types d'instances, AMI, on-demand, spot, Savings Plans](00-4-ec2/fr.md)
- 0.5. [Outils : aws cli, eksctl, terraform et terragrunt, helm, plugins utiles](00-5-tools/fr.md)

### Partie 1. Architecture et création du cluster

1. [Introduction : ce qu'EKS prend en charge et ce qui reste à votre charge](01/fr.md)
2. [Control plane EKS : endpoint public et privé, platform versions, SLA, logs](02/fr.md)
3. [Cycle de vie des versions : standard et extended support, stratégie de mise à jour](03/fr.md)
4. [Création du cluster : eksctl, Terraform et Terragrunt, CloudFormation](04/fr.md) 🧪
5. [Accès au cluster : IAM et RBAC, access entries, migration depuis aws-auth](05/fr.md)
6. [Réseau du cluster : VPC CNI, ENI et adresses IP, planification CIDR](06/fr.md) 🧪
7. [Mise à l'échelle du plan d'adressage : prefix delegation, secondary CIDR, custom networking](07/fr.md)
8. [Alternatives à VPC CNI : Cilium, modes réseau, quand changer de CNI](08/fr.md) 🧪

### Partie 2. Nœuds et ressources de calcul

9. [Types de calcul : managed node groups, self-managed, Fargate, Auto Mode](09/fr.md) 🧪
10. [AMI et bootstrap : AL2023, Bottlerocket, launch templates, kubelet et user data](10/fr.md) 🧪
11. [Cluster Autoscaler et Karpenter : deux approches de mise à l'échelle des nœuds](11/fr.md)
12. [Karpenter : NodePool, EC2NodeClass, disruption, consolidation, drift](12/fr.md)
13. [Instances spot : interruptions, diversification, traitement des événements](13/fr.md)
14. [Densité et dimensionnement : pods par nœud, limites ENI, requests et limits dans le cloud](14/fr.md)
15. [Fargate : profils, limites, coût, cas d'utilisation](15/fr.md)

### Partie 3. Identité et sécurité

16. [IRSA : fournisseur OIDC, trust policy, annotations ServiceAccount](16/fr.md)
17. [EKS Pod Identity : agent, associations, migration depuis IRSA](17/fr.md)
18. [Secrets : chiffrement KMS, Secrets Manager et SSM via External Secrets et CSI](18/fr.md)
19. [Renforcement : IMDSv2 et hop limit, Pod Security Admission, cluster privé](19/fr.md)
20. [Images et supply chain : ECR, analyse, signatures, pull through cache](20/fr.md) 🧪
21. [Audit et détection : logs du control plane, CloudTrail, GuardDuty, surveillance runtime](21/fr.md)
22. [Politiques et multitenancy : Kyverno et Gatekeeper, isolation des équipes](22/fr.md) 🧪

### Partie 4. Stockage des données

23. [EBS CSI : gp3, StorageClass, extension, snapshots, liaison à une AZ](23/fr.md)
24. [EFS et FSx : stockage partagé pour les charges de travail entre AZ](24/fr.md)
25. [S3 dans les applications : Mountpoint for Amazon S3 CSI et modèles d'accès](25/fr.md) 🧪

### Partie 5. Réseau et trafic

26. [AWS Load Balancer Controller et Service de type LoadBalancer : NLB](26/fr.md)
27. [Ingress via ALB : target-type, annotations, TLS et ACM, WAF](27/fr.md)
28. [Gateway API dans AWS : ALB Gateway API et VPC Lattice](28/fr.md) 🧪
29. [DNS et certificats : external-dns, Route 53, cert-manager](29/fr.md)
30. [NetworkPolicy dans EKS : VPC CNI network policy et Cilium](30/fr.md)
31. [Egress et coût du trafic : NAT, VPC endpoints, PrivateLink](31/fr.md)
32. [Multicluster et multicomptes : connectivité, ressources partagées, modèles](32/fr.md)

### Partie 6. Observabilité

33. [Métriques : Container Insights, Managed Prometheus et Grafana, kube-prometheus-stack](33/fr.md)
34. [Logs : Fluent Bit, CloudWatch Logs, OpenSearch, contrôle des dépenses](34/fr.md)
35. [Mise à l'échelle automatique des applications : HPA, métriques externes, KEDA](35/fr.md) 🧪
36. [Tracing et profilage : ADOT et X-Ray](36/fr.md)

### Partie 7. Exploitation

37. [Add-ons EKS : managed addons face à Helm, versions et ordre de mise à jour](37/fr.md)
38. [Mise à jour du cluster : in-place par version, clusters blue/green, API obsolètes](38/fr.md)
39. [Retour à la version précédente du cluster : rollback readiness insights, fenêtre de 7 jours, ordre de rollback](39/fr.md)
40. [Fiabilité : multi-AZ, PDB, topology spread, arrêt correct des nœuds](40/fr.md) 🧪
41. [Sauvegarde du cluster avec AWS Backup : état du cluster, volumes persistants, composite recovery point](41/fr.md) 🧪
42. [Restauration et DR : restore vers un cluster existant ou nouveau, namespace-restore, Velero](42/fr.md) 🧪
43. [Coût : OpenCost et Kubecost, right-sizing, Savings Plans, mix spot, trafic](43/fr.md)
44. [GitOps et livraison : Argo CD et Flux, gestion d'un parc de clusters](44/fr.md) 🧪

Cette partie s'accompagne de deux documents de référence : le [modèle de coûts](COST_MODEL_FR.md),
formulaire d'estimation du chapitre 43, et les [décisions d'architecture](ADR_FR.md),
modèles ADR pour les embranchements de l'ensemble du cours.

### Partie 8. Troubleshooting

45. [Le nœud n'a pas rejoint le cluster : IAM, SG, user data, bootstrap, kubelet](45/fr.md)
46. [Pannes réseau : ENI exhausted, SG et NACL, DNS, unhealthy targets dans le load balancer](46/fr.md) 🧪
47. [Accès et IAM : access entries, IRSA et Pod Identity, webhook, kubeconfig](47/fr.md) 🧪

Les sections « Ordre de diagnostic » de ces trois chapitres sont regroupées
dans le [guide de diagnostic](RUNBOOK_FR.md) : symptôme, cause probable, point
à vérifier. En astreinte, il est plus pratique de l'ouvrir que de consulter les
trois chapitres.

### Partie 9. Conclusion

48. [Checklist de production EKS et lectures complémentaires](48/fr.md)

Les checklists du chapitre 48 sont disponibles sous la forme d'un questionnaire
avec un score et une liste de dette technique dans la [matrice de maturité
EKS](SCORECARD_FR.md).

## Pratique

Le cours possède son propre ensemble de travaux pratiques numérotés `101+`,
associés aux chapitres. Les TP sont déployés dans votre compte AWS via
Terragrunt, vérifiés automatiquement par `check_result` et supprimés par une
seule commande :

- 🧪 [Travaux pratiques EKS](../../../docs/labs.MD#eks-labs) - liste des TP et commandes de lancement

L'ensemble de TP du cours est actuellement en préparation. L'icône 🧪 dans la
table des matières signifie que le chapitre possède déjà son propre TP ; les
chapitres sans icône sont pour l'instant suivis comme théorie.

Le dépôt contient également des TP EKS plus anciens ([Karpenter](../labs/02/README_FR.MD),
[mise à l'échelle automatique avec KEDA et Prometheus](../labs/03/README_FR.MD)). Ils ne
font pas partie du cours et évoluent indépendamment, mais les sujets recoupent
les chapitres 12 et 35. Vous pouvez donc les suivre comme pratique complémentaire.

## Lectures complémentaires

- [Documentation Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/) -
  source principale pour les versions, add-ons et limites.
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) -
  recommandations officielles sur le réseau, la sécurité, la fiabilité et le coût.
- [EKS Workshop](https://www.eksworkshop.com/) - modules interactifs gratuits d'AWS.
- [AWS Backup : sauvegarde et restauration EKS](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) -
  documentation sur la sauvegarde de l'état du cluster et des volumes persistants.
- [De Spot.io à Karpenter](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) -
  notre analyse de la migration de la gestion des nœuds en production.
