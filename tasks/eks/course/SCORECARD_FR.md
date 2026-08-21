[Русская версия](SCORECARD_RU.md) · [Eng version](SCORECARD.md) · [Versión en español](SCORECARD_ES.md) · [Deutsche Version](SCORECARD_DE.md) · [ქართული ვერსია](SCORECARD_GE.md) · [繁體中文版](SCORECARD_TW.md) · [日本語版](SCORECARD_JP.md)

# Matrice de maturité EKS : questionnaire de préparation

[Table des matières du cours](README_FR.md) · [Chapitre 48](48/fr.md) · [Glossaire](GLOSSARY_FR.md)

Cette fiche de travail accompagne le chapitre 48 : elle reprend les mêmes domaines de préparation,
mais sous la forme d'un questionnaire que l'équipe parcourt puis transforme en liste de dette technique.
Elle n'apporte aucun nouveau contenu.

## Comment le parcourir

- Parcourez les huit domaines à la suite, sans en omettre aucun : chaque domaine est un axe distinct
d'exploitation, et la faiblesse de l'un ne peut être compensée par la force d'un autre.
- Répondez honnêtement à chaque point : oui ou non. « Partiellement », « presque » et « configuré,
mais non vérifié » comptent comme non.
- Remplissez-le en équipe, pas seul : les responsables réseau, sécurité et coûts voient des lacunes
différentes, et le « cela semble prêt » se révèle précisément au croisement des avis.
- L'enjeu n'est pas le score. Il sert uniquement à voir le niveau ; le résultat du questionnaire est la liste
de ce qui n'est pas couvert, avec responsables et échéances.
- Marquez chaque point non couvert comme risque connu assorti d'une tâche, au lieu de l'ignorer
silencieusement pour que la fiche paraisse au vert.
- Reprenez le questionnaire chaque trimestre et après les changements majeurs : les versions vieillissent,
les charges augmentent, et ce qui était couvert hier peut être une lacune aujourd'hui.
- La fiche vit dans le dépôt à côté de l'IaC, afin que ses modifications soient visibles dans la pull request.

## Échelle des niveaux

Le questionnaire comporte 51 points au total. Un point couvert vaut un point.

| Niveau | Points | Ce que cela signifie | Que faire ensuite |
|---|---|---|---|
| Niveau 1. Instable et manuel | 0-20 | Le cluster fonctionne tant que rien ne casse : beaucoup de choses ont été faites par clics, la restauration et les limites de sécurité ne sont pas vérifiées | Couvrir les points bloquants et toute la colonne « must have » avant d'activer le trafic de production |
| Niveau 2. Maîtrisé | 21-33 | Les fondations existent : cluster issu du code, accès et calcul réfléchis, mais les vérifications et l'observabilité reposent sur quelques personnes | Finaliser la sécurité et l'exploitation : audit, retention, alertes, plan de mises à niveau |
| Niveau 3. Répétable et observable | 34-44 | Les pratiques sont établies et répétables : mise à niveau, sauvegarde et restore ont été effectués, un incident se localise avec un runbook | Mener à bien les priorités « important dans les premières semaines », attribuer un ownership à chaque domaine |
| Niveau 4. Résilience autonome | 45-51 | La préparation ne se dégrade pas entre les releases : le DR est vérifié par des exercices, le coût et le trafic sont sous contrôle, GitOps est la source de vérité | Maintenir le niveau : questionnaire trimestriel, game day, finalisation des « nice to have » |

Lorsqu'un point bloquant n'est pas couvert, le niveau ne peut pas dépasser le deuxième, quel que soit le
nombre total de points. Cette règle est détaillée dans « Calcul et utilisation du résultat ».

## 1. Cluster et control plane

Les fondations. Si la version n'est plus prise en charge ou si les sous-réseaux sont dans une seule AZ,
le reste importe peu.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | Version de Kubernetes dans le standard support | Une version hors support est un risque qu'aucune configuration ne peut couvrir | [38](38/fr.md) |
| [ ] | Un plan de mise à niveau des versions existe, plutôt qu'une réaction un mois avant la fin du support | Une mise à niveau sous contrainte de délai se fait sans fenêtre de retour arrière | [38](38/fr.md) |
| [ ] | Endpoint access est réfléchi : public ou private, source ranges adaptés au besoin | Le mode d'accès à l'API définit la surface d'attaque du cluster | [02](02/fr.md) |
| [ ] | Sous-réseaux du cluster dans trois AZ, plan IP suffisant pour la croissance des pods | Une seule AZ est un point unique de défaillance ; le manque d'IP arrête le scheduling des pods | [06](06/fr.md) |
| [ ] | Le cluster est créé à partir du code (Terraform ou eksctl), et non par clics dans la console | Un cluster manuel ne peut pas être recréé lors d'un DR ni revu dans une pull request | [04](04/fr.md) |
| [ ] | Les ressources sont étiquetées : équipe, environnement, cost allocation | Sans tags, il est impossible de répartir les coûts et la responsabilité par équipe | [43](43/fr.md) |

## 2. Calcul

Les nœuds relèvent entièrement de la responsabilité de l'ingénieur : c'est ici que se décident à la fois la
résilience et la facture.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | La stratégie de nœuds est choisie consciemment : Auto Mode, Karpenter ou managed node groups | Laisser le défaut implique des conséquences mal comprises pour le prix et la résilience | [09](09/fr.md) |
| [ ] | Un mix Spot est appliqué aux charges tolérantes aux pannes | Spot permet d'économiser là où la charge survit à une interruption | [13](13/fr.md) |
| [ ] | Les types d'instances du pool spot sont diversifiés | Spot sans diversification n'est pas une économie, mais le risque de perdre toute la capacité d'un coup | [13](13/fr.md) |
| [ ] | Les requests sont définies d'après les faits (right-sizing), et non « au jugé » | Des requests surestimées font payer du vide, des requests sous-estimées cassent la charge | [14](14/fr.md) |
| [ ] | La disruption et la consolidation de Karpenter sont configurées, le drift n'est pas ignoré | Sans consolidation, le parc de nœuds se disperse ; le drift accumule les écarts avec le code | [12](12/fr.md) |
| [ ] | La densité des pods par nœud est alignée sur les limites ENI et IP | Une densité excessive laisse des pods dans `Pending` sans raison apparente | [14](14/fr.md) |

## 3. Identité et sécurité

Le domaine le plus vaste et la source la plus fréquente de failles silencieuses. Vérifiez point par point.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | Les pods accèdent à AWS via IRSA ou Pod Identity, sans clés statiques | Une clé longue durée dans un pod fuit avec l'image ou le log | [16](16/fr.md) |
| [ ] | **Bloquant.** L'accès au cluster n'est pas réservé au cluster creator, des access entries sont créées | Un cluster auquel une seule personne accède disparaît avec cette personne | [05](05/fr.md) |
| [ ] | Les secrets proviennent de Secrets Manager ou SSM (External Secrets, CSI), pas des manifestes | Un secret dans un manifeste arrive dans git et dans chaque copie du dépôt | [18](18/fr.md) |
| [ ] | Les nœuds et les pods sont durcis : IMDSv2, hop limit, Pod Security Admission | L'accès aux métadonnées du nœud depuis un pod donne au pod les droits du nœud | [19](19/fr.md) |
| [ ] | Les images sont scannées dans ECR, la base provient de sources fiables | Une base vulnérable se propage immédiatement à tous les services | [20](20/fr.md) |
| [ ] | L'audit du control plane est activé : api, audit, authenticator dans les logs | L'audit doit être activé avant l'incident ; après coup, les logs n'existent plus | [21](21/fr.md) |
| [ ] | Les politiques Kyverno ou Gatekeeper bloquent les modèles dangereux dans les manifestes | Une revue humaine laisse passer ce qu'une politique détecte systématiquement | [22](22/fr.md) |

## 4. Stockage

Un domaine réduit mais trompeur : les défauts EBS et les sauvegardes de volumes non vérifiées frappent sans prévenir.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | La StorageClass par défaut est sur gp3, et non sur l'obsolète gp2 | gp2 reste le défaut par inertie et est moins bon en caractéristiques comme en prix | [23](23/fr.md) |
| [ ] | `volumeBindingMode: WaitForFirstConsumer` est défini | Sinon, le volume naît dans la mauvaise AZ et le pod reste à jamais `Pending` | [23](23/fr.md) |
| [ ] | Les volumes persistants sont inclus dans les sauvegardes | Un volume sans sauvegarde est une donnée qui n'existe qu'en un exemplaire | [41](41/fr.md) |
| [ ] | Les snapshots de volumes sont vérifiés par une restauration, pas seulement par leur création | Un snapshot non vérifié équivaut à l'absence de snapshot | [41](41/fr.md) |
| [ ] | L'attachement EBS à une AZ est pris en compte lors du déplacement et du scheduling des charges | Le déplacement de manifestes « tels quels » échoue précisément sur les volumes | [23](23/fr.md) |
| [ ] | Le stockage partagé est choisi consciemment : EFS ou FSx là où ReadWriteMany est nécessaire | EBS n'offre pas ReadWriteMany ; ce contournement se traite à l'étape de conception | [24](24/fr.md) |

## 5. Réseau et trafic

Les erreurs de ce domaine sont visibles depuis l'extérieur : service inaccessible, egress ouvert, trafic passant par toutes les AZ.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | Les load balancers sont créés via AWS Load Balancer Controller : NLB | Les load balancers manuels divergent de l'état du cluster | [26](26/fr.md) |
| [ ] | L'Ingress fonctionne via ALB avec un target-type choisi consciemment | Le type de cible détermine le trajet du trafic et le comportement pendant un drain | [27](27/fr.md) |
| [ ] | Les certificats TLS passent par ACM, HTTPS est terminé sur le load balancer | Les certificats manuels expirent au moment le plus inopportun | [27](27/fr.md) |
| [ ] | **Bloquant.** NetworkPolicy avec default-deny, trafic entre pods explicitement autorisé | Sans default-deny, un pod compromis voit tous ses voisins | [30](30/fr.md) |
| [ ] | Les enregistrements DNS sont gérés par external-dns, et non manuellement dans Route 53 | Un enregistrement manuel survit à la suppression du service et pointe vers le vide | [29](29/fr.md) |
| [ ] | VPC endpoints pour les services AWS, NAT par AZ, trafic egress sous contrôle | L'egress par un seul NAT est à la fois un point de défaillance et un poste de dépense | [31](31/fr.md) |

## 6. Observabilité

Sans ce domaine, un incident se diagnostique à l'aveugle. Les données ne doivent pas seulement affluer : elles
doivent être conservées le temps nécessaire et générer des alertes.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | metrics-server fonctionne | Sans lui, ni `kubectl top` ni HPA ne répondent | [33](33/fr.md) |
| [ ] | Un backend de métriques existe : Prometheus ou Container Insights | Les métriques sont nécessaires avec leur historique, pas seulement « maintenant » | [33](33/fr.md) |
| [ ] | Les logs sont exportés depuis les nœuds et les pods | Les logs restés sur un nœud disparaissent avec le nœud | [34](34/fr.md) |
| [ ] | La retention des logs est définie consciemment | Une retention sans plan, ce sont des logs perdus pendant l'analyse ou du stockage superflu | [34](34/fr.md) |
| [ ] | Des alertes sont configurées pour les symptômes clés, pas seulement des tableaux de bord | Un tableau de bord que personne ne consulte ne remplace pas une alerte | [33](33/fr.md) |
| [ ] | Un tracing existe (ADOT ou X-Ray) là où la chaîne d'appels importe | Dans les microservices, la cause de la panne n'est pas dans le service où le symptôme apparaît | [36](36/fr.md) |

## 7. Exploitation

Le domaine qui sépare « le cluster fonctionne aujourd'hui » de « le cluster survivra à une mise à niveau et à une panne ».

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | Un plan de mise à niveau du cluster et des add-ons existe, les API obsolètes sont supprimées | Une API obsolète bloque la mise à niveau au pire moment | [37](37/fr.md) |
| [ ] | La préparation au rollback est comprise : la fenêtre et la procédure sont connues | Un rollback se prépare à l'avance, pas pendant une mise à niveau ratée | [39](39/fr.md) |
| [ ] | PDB et topology spread protègent la disponibilité pendant un drain et une mise à niveau | Sans eux, une mise à niveau des nœuds retire toutes les répliques d'un service d'un coup | [40](40/fr.md) |
| [ ] | Les PDB ne bloquent pas le drain définitivement (`maxUnavailable: 0` est un signal d'alerte) | Un tel PDB arrête la mise à niveau et ressemble à un drain bloqué | [40](40/fr.md) |
| [ ] | AWS Backup est configuré pour l'état du cluster et les volumes persistants | Une sauvegarde des seuls volumes ne restaure pas le cluster lui-même | [41](41/fr.md) |
| [ ] | **Bloquant.** Un DR-restore a réellement été testé lors d'un game day | Un restore configuré mais jamais vérifié est un espoir, pas une sauvegarde | [42](42/fr.md) |
| [ ] | Le coût est visible par équipe et namespace (OpenCost ou Kubecost) | Un coût invisible n'est ni optimisé ni attribué à un responsable | [43](43/fr.md) |
| [ ] | GitOps est la source de vérité pour les manifestes (Argo CD ou Flux) | L'écart entre le cluster et git signifie que personne ne connaît l'état réel | [44](44/fr.md) |

## 8. Préparation aux incidents

Le domaine final : lorsque tout cassera, ce qui compte n'est pas l'architecture, mais la vitesse de localisation.

| Prêt | Point | Pourquoi c'est important | Chapitre |
|---|---|---|---|
| [ ] | Un runbook existe pour un nœud qui ne rejoint pas le cluster | Les causes sont diverses (IAM, SG, user data, kubelet) ; l'ordre de vérification économise des heures | [45](45/fr.md) |
| [ ] | Un runbook existe pour les pannes réseau : ENI, SG et NACL, DNS, unhealthy targets | Une panne réseau présente le même aspect pour des causes différentes | [46](46/fr.md) |
| [ ] | Un runbook existe pour les accès : 401 contre 403, IRSA et Pod Identity, kubeconfig | Une erreur d'accès bloque à la fois le travail et l'analyse de l'incident | [47](47/fr.md) |
| [ ] | L'accès SSM aux nœuds fonctionne sans SSH nu, il est possible de se connecter à un nœud | Configurer l'accès à un nœud alors qu'il est déjà en panne est trop tard | [45](45/fr.md) |
| [ ] | Le control plane logging est activé, les logs authenticator et API sont écrits | Sans ces logs, la cause d'un refus d'accès ne peut pas être reconstituée | [21](21/fr.md) |
| [ ] | Les logs du control plane sont disponibles pour l'analyse et ne sont pas supprimés trop tôt | Les logs sont nécessaires pendant l'analyse, pas pendant la configuration | [34](34/fr.md) |

## Calcul et utilisation du résultat

Comptez ainsi :

- Un point couvert vaut un point, avec un maximum de 51. Les domaines ont la même importance : le réseau
n'est pas plus important que le stockage, et un score élevé dans un domaine ne couvre pas une lacune dans un autre.
- Trois points sont marqués **bloquants** : DR-restore non testé, accès au cluster limité à une seule personne,
absence de NetworkPolicy default-deny sur le réseau.
- Si au moins un point bloquant n'est pas couvert, le niveau ne peut pas dépasser le deuxième, quelle que soit
la somme des points. Un point bloquant n'est pas « moins un point », mais un arrêt pour le trafic de production.

Transformez ensuite les points non couverts en liste de dette technique priorisée :

| Priorité | Ce qu'il faut y mettre | Que faire |
|---|---|---|
| Must have avant la production | version prise en charge, accès non limité à une personne, audit et logs du control plane, NetworkPolicy default-deny, secrets hors des manifestes, restore testé, PDB ne bloquant pas la mise à niveau | les couvrir avant d'activer le trafic de production : le premier incident ou la première compromission coûte plus cher qu'un retard de lancement |
| Important dans les premières semaines | right-sizing des requests, mix spot, retention des logs, alertes, plan de mises à niveau, VPC endpoints | les formaliser immédiatement après le lancement en tâches avec responsables et échéances |
| Nice to have | tracing des microservices, allocation détaillée des coûts, GitOps mature pour un parc de clusters | les mettre en place de manière itérative en production, sans bloquer le lancement |

La liste de dette technique se formule en tâches explicites, avec un responsable et une échéance. La formulation
« plus tard, un jour » signifie que le point n'est pas couvert et qu'il se trouvera au même endroit au prochain passage.

Que faire ensuite du résultat :

- Attribuez l'ownership des domaines : le réseau, la sécurité et les coûts ont chacun un responsable qui veille
à ce que ses points soient couverts et ne se dégradent pas.
- Parcourez la fiche avant chaque mise en production : un nouveau cluster ou un nouveau service majeur ne part
pas au combat tant que la priorité « must have » n'est pas couverte entièrement et explicitement.
- Associez le résultat aux game days et aux mises à niveau : la vérification du DR-restore et du plan de mise à niveau
revient dans la fiche comme point confirmé ou échoué, et non comme promesse.
- Comparez avec le passage précédent : ce qui importe n'est pas la somme des points, mais les points qui ont été
couverts, ceux qui sont redevenus non couverts et la raison.

## Limites de ce questionnaire

- Il ne remplace pas une revue d'architecture : les axes de préparation sont visibles, mais pas les décisions de conception.
- Il évalue l'existence d'une pratique, pas sa qualité : un audit activé et un audit utile donnent le même point ;
la différence n'apparaît que lors de l'analyse d'un incident.
- Il ne couvre pas la partie applicative : le code des services et les schémas de données restent hors de la fiche.
- Le score n'est pas comparable entre des clusters aux objectifs différents : certains points ne sont pas nécessaires
pour un cluster hors production, et un score faible dans ce cas ne signifie rien de mauvais.
