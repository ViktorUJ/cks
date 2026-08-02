[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# CKA + CKAD : manuel pratique d'auto-formation à Kubernetes

Cours pratique commun pour préparer en même temps deux certifications de la CNCF
et de la Linux Foundation :

- **CKA** (Certified Kubernetes Administrator) - administration du cluster :
  installation, maintenance, réseau, stockage, sécurité, troubleshooting.
- **CKAD** (Certified Kubernetes Application Developer) - développement et
  exécution d'applications dans Kubernetes : charges de travail, configuration,
  observabilité, services.

Les examens se recoupent fortement (charges de travail, services, configuration,
stockage, observabilité), les étudier ensemble est donc plus efficace que séparément.
Le noyau commun est parcouru une seule fois, et les spécificités de chaque examen
sont placées dans des parties distinctes. Le cours est lié aux TP dans `tasks/cka/labs`.

> **Version de Kubernetes.** Le cours cible la version actuelle des examens -
> Kubernetes `v1.35` (programmes CKA et CKAD 2025-2026). Les deux examens sont
> pratiques, dans un cluster réel depuis la ligne de commande : CKA - 2 heures,
> CKAD - 2 heures, score de réussite 66%.

## Comment le cours est organisé

Chaque sujet est un dossier numéroté. À l'intérieur se trouvent les fichiers
localisés. La langue principale est le russe (`ru.md`) ; à partir de lui sont faites
les traductions : anglais (`README.md`), espagnol (`es.md`), français (`fr.md`),
allemand (`de.md`) et géorgien (`ge.md`). Le sélecteur est en première ligne.

Chaque chapitre indique à quel examen il se rapporte :

- 🟦 **CKA** - uniquement pour l'administrateur
- 🟩 **CKAD** - uniquement pour le développeur
- 🟪 **CKA + CKAD** - sujet commun aux deux examens

À la fin du cours, il y a deux guides distincts qui rassemblent les chapitres et
les TP pour un examen précis :

- [Programme et TP pour CKA](CKA_FR.md)
- [Programme et TP pour CKAD](CKAD_FR.md)

Tous les termes du cours sont rassemblés dans un référentiel unique :

- [Glossaire du cours](GLOSSARY_FR.md) - tous les termes par chapitre avec liens

## Programmes officiels des examens

CKA (domaines et poids) :

| Domaine | Poids |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (domaines et poids) :

| Domaine | Poids |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## Sommaire

### Partie 0. Fondations pour les débutants (facultative) 🟪 CKA + CKAD

Partie préparatoire pour ceux qui arrivent sans base solide en réseaux, DNS, TLS,
conteneurs, Linux et YAML. Si vous maîtrisez ces sujets avec assurance - vous
pouvez passer directement à la Partie 1. Cette partie n'a pas de TP dédiés : c'est
la fondation sur laquelle s'appuient les autres chapitres (les compétences des
0.5-0.7 s'appliquent directement dans les TP sur les nœuds et le réseau).

- 0.1. [Les réseaux depuis zéro : IP, ports, CIDR et NAT](00-1-net/fr.md)
- 0.2. [Le DNS depuis zéro : comment les noms se transforment en adresses](00-2-dns/fr.md)
- 0.3. [TLS et certificats depuis zéro : HTTPS, clés et autorités de certification](00-3-tls/fr.md)
- 0.4. [Conteneurs et Docker depuis zéro : images, couches, registres et runtime](00-4-containers/fr.md)
- 0.5. [Linux et les outils du nœud depuis zéro : SSH, sudo, systemd, logs, fichiers](00-5-linux/fr.md)
- 0.6. [YAML depuis zéro : indentation, listes, dictionnaires et manifestes](00-6-yaml/fr.md)
- 0.7. [Le réseau Linux sous le capot : network namespaces, veth et routage](00-7-netns/fr.md)
- 0.8. [vim en 15 minutes : survivre et le régler pour YAML](00-8-vim/fr.md)

### Partie 1. Les bases de Kubernetes 🟪 CKA + CKAD

1. [Introduction : Kubernetes, les examens CKA et CKAD, la structure du cours](01/fr.md)
2. [Architecture de Kubernetes : control plane et nœuds worker](02/fr.md)
3. [Travailler avec kubectl : approches impérative et déclarative](03/fr.md)
4. [Les pods : cycle de vie, création et configuration](04/fr.md)
5. [ReplicaSet et Deployment](05/fr.md)
6. [Namespaces, labels, selectors et annotations](06/fr.md)
7. [Services : ClusterIP, NodePort, LoadBalancer, Endpoints](07/fr.md)

### Partie 2. Charges de travail et planification 🟪 CKA + CKAD

8. [Deployment : rolling update et rollback](08/fr.md)
9. [Stratégies de déploiement : blue/green et canary](09/fr.md) 🟩 CKAD
10. [Jobs et CronJobs](10/fr.md)
11. [DaemonSet et StatefulSet](11/fr.md)
12. [Planification des Pods : nodeName, nodeSelector, affinity](12/fr.md)
13. [Taints et tolerations](13/fr.md)
14. [Ressources : requests, limits, LimitRange, ResourceQuota](14/fr.md)
15. [Static Pods, PriorityClass, planificateurs multiples](15/fr.md)
16. [Autoscaling des charges de travail : HPA](16/fr.md)

### Partie 3. Configuration et sécurité des applications 🟪 CKA + CKAD

17. [Commandes, arguments et variables d'environnement](17/fr.md)
18. [ConfigMap](18/fr.md)
19. [Secret](19/fr.md)
20. [SecurityContext et capabilities](20/fr.md)
21. [ServiceAccount ; authentification, autorisation, admission](21/fr.md)

### Partie 4. Conception et build des applications 🟩 CKAD

22. [Pods multi-conteneurs : sidecar, adapter, ambassador, init](22/fr.md)
23. [Images de conteneurs : build, Dockerfile, optimisation](23/fr.md)
24. [Volumes pour les applications : emptyDir et volumes éphémères](24/fr.md)

### Partie 5. Stockage des données 🟪 CKA + CKAD

25. [Volumes, PersistentVolume et PersistentVolumeClaim](25/fr.md)
26. [StorageClass, provisionnement dynamique, stockage dans un StatefulSet](26/fr.md)

### Partie 6. Observabilité et maintenance 🟪 CKA + CKAD

27. [Vérifications d'état : liveness, readiness, startup probes](27/fr.md)
28. [Logging et monitoring : logs, metrics-server, kubectl top](28/fr.md)
29. [Débogage des applications et dépréciation des API](29/fr.md)

### Partie 7. Services et réseau 🟪 CKA + CKAD

30. [Le modèle réseau de Kubernetes, le réseau des pods et le CNI](30/fr.md)
31. [Le Service de l'intérieur, le DNS et CoreDNS](31/fr.md)
32. [Ingress et contrôleurs Ingress](32/fr.md)
33. [Gateway API](33/fr.md)
34. [NetworkPolicy](34/fr.md)

### Partie 8. Architecture du cluster, installation et configuration 🟦 CKA

35. [Installation d'un cluster avec kubeadm](35/fr.md)
- 35A. [Haute disponibilité (HA) : plusieurs nœuds control plane, topologies etcd et répartiteur de charge](35-2-ha/fr.md) 🟦 CKA
- 35B. [Conception et dimensionnement du cluster : infrastructure, topologie, IaC](35-3-design/fr.md) 🟦 CKA
36. [Mise à jour du cluster (lifecycle)](36/fr.md)
37. [Sauvegarde et restauration d'etcd](37/fr.md)
38. [RBAC : Role, ClusterRole et bindings](38/fr.md)
39. [Certificats TLS, kubeconfig et l'API CSR](39/fr.md)
40. [Interfaces d'extension : CNI, CSI, CRI](40/fr.md)
41. [CRD et opérateurs](41/fr.md)
42. [Helm](42/fr.md)
43. [Kustomize](43/fr.md)

### Partie 9. Troubleshooting 🟦 CKA

44. [Déboguer les pannes d'applications](44/fr.md)
45. [Déboguer le control plane et les nœuds worker](45/fr.md)
46. [Déboguer les services et le réseau](46/fr.md)

### Partie 10. Préparation aux examens

47. [L'examen CKAD : format, gestion du temps, JSONPath et productivité kubectl](47/fr.md) 🟩 CKAD
48. [L'examen CKA : format, gestion du temps et stratégie](48/fr.md) 🟦 CKA

## Pratique

- 🧪 [Travaux pratiques](../labs) - 25 TP dans le style de l'examen avec vérification automatique `check_result`
- 🧪 [Examens blancs CKA](../mock) - examens blancs CKA chronométrés (multicluster, SSH, poids des tâches)
- 🧪 [Examens blancs CKAD](../../ckad/mock) - examens blancs CKAD chronométrés

## Quoi lire ensuite

Ce cours est centré sur la préparation aux examens : chaque chapitre est rattaché à un domaine
du CKA ou du CKAD. La philosophie architecturale, l'histoire du projet et un panorama de
l'écosystème (service mesh, GitOps, observabilité) n'y sont volontairement pas inclus : ce sont
des sujets à part, qui ne sont pas demandés à l'examen. Si vous voulez aller plus large et
plus profond :

- **Kubernetes: Up and Running** (Burns, Beda, Hightower, O'Reilly) - pourquoi Kubernetes est
  apparu, l'évolution depuis Borg, les patterns architecturaux des applications.
- **The Kubernetes Book** (Nigel Poulton) - introduction panoramique axée sur la compréhension
  de la plateforme dans son ensemble ; mise à jour chaque année.
- [Documentation officielle de Kubernetes](https://kubernetes.io/docs/) - la source primaire,
  son usage est autorisé pendant l'examen lui-même.
- [CNCF Landscape](https://landscape.cncf.io/) - carte de l'écosystème cloud native.
