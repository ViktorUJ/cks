[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Laboratoire : Principes fondamentaux de Karpenter

## Description

Ce laboratoire vous présentera **Karpenter**, un outil de mise à l’échelle automatique des nœuds dans un cluster Amazon EKS. Karpenter crée et supprime dynamiquement des instances EC2 en fonction des besoins de vos applications, afin d’optimiser les coûts et les performances.

**Ce que vous apprendrez :**
- Comment configurer un NodePool et une EC2NodeClass de base
- Comment Karpenter met automatiquement les nœuds à l’échelle lorsque la charge évolue
- Comment gérer les ressources à l’aide de limites
- Comment fonctionnent la consolidation et l’optimisation de la taille des nœuds
- Comment mettre à jour les nœuds lorsque la configuration change (drift)
- Comment utiliser plusieurs NodePool pour différents types de charge

## Sommaire
- [Préparation de l’environnement](#préparation-de-lenvironnement)
  - [Lancement du laboratoire](#lancement-du-laboratoire)
  - [Ressources créées](#ressources-créées)
  - [Prérequis](#prérequis)
- [Configuration de base du NodePool](#configuration-de-base-du-nodepool)
  - [Vérification du fonctionnement de Karpenter](#vérification-du-fonctionnement-de-karpenter)
  - [Création d’une application de test](#création-dune-application-de-test)
  - [Création du NodePool et de l’EC2NodeClass](#création-du-nodepool-et-de-lec2nodeclass)
  - [Vérification de la création automatique des nœuds](#vérification-de-la-création-automatique-des-nœuds)
- [Mise à l’échelle des applications](#mise-à-léchelle-des-applications)
  - [Mise à l’échelle horizontale](#mise-à-léchelle-horizontale)
  - [Ajout automatique de nœuds](#ajout-automatique-de-nœuds)
- [Limitation des ressources](#limitation-des-ressources)
  - [Configuration des limites CPU](#configuration-des-limites-cpu)
  - [Diagnostic des problèmes de limites](#diagnostic-des-problèmes-de-limites)
- [Gestion du cycle de vie des nœuds (Disruption)](#gestion-du-cycle-de-vie-des-nœuds-disruption)
- [Optimisation de la taille des nœuds (RightSizing)](#optimisation-de-la-taille-des-nœuds-rightsizing)
  - [Sélection automatique de la taille optimale](#sélection-automatique-de-la-taille-optimale)
  - [Remplacement des nœuds lorsque les exigences changent](#remplacement-des-nœuds-lorsque-les-exigences-changent)
- [Mise à jour de la configuration des nœuds (Drift)](#mise-à-jour-de-la-configuration-des-nœuds-drift)
  - [Mise à jour des images AMI](#mise-à-jour-des-images-ami)
  - [Migration automatique vers de nouvelles versions](#migration-automatique-vers-de-nouvelles-versions)
- [Utilisation de plusieurs NodePool](#utilisation-de-plusieurs-nodepool)
  - [Isolation de la charge avec Taints et Tolerations](#isolation-de-la-charge-avec-taints-et-tolerations)
  - [Nœuds spécialisés pour les Job](#nœuds-spécialisés-pour-les-job)
- [Nettoyage des ressources](#nettoyage-des-ressources)

## Préparation de l’environnement

### Lancement du laboratoire
[exécution via docker ](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)
Pour lancer le laboratoire, exécutez la commande suivante :

```bash
TASK=02 make run_eks_task
```

**Ce qui se passe lors de l’exécution de la commande :**
- Terraform/Terragrunt déploiera automatiquement toute l’infrastructure nécessaire dans AWS
- Le processus prendra environ 15 à 20 minutes
- Vous verrez dans la sortie de la commande des informations importantes (connexion SSH, noms des ressources)

### Ressources créées

Lors de l’exécution de la commande, l’infrastructure AWS suivante sera déployée :

#### Infrastructure réseau (VPC)
- **VPC** avec le bloc CIDR `10.10.0.0/16` dans la région `eu-central-1`
- **Sous-réseaux publics** (pour les ressources ayant accès à Internet) :
  - `eks-AZ-1` (10.10.1.0/24) dans la zone de disponibilité `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) dans la zone de disponibilité `eu-central-1b`
- **Sous-réseaux privés** (pour les ressources internes) :
  - `private-subnet-1` (10.10.15.0/24) pour les nœuds EKS dans `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) pour les nœuds EKS dans `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) pour RDS dans `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) pour RDS dans `eu-central-1b`
- **NAT Gateway** pour le trafic Internet sortant depuis les sous-réseaux privés

#### Cluster EKS
- **EKS Control Plane** version `1.34` (plan de contrôle Kubernetes)
- **Fargate profile** pour les pods système (kube-system, karpenter)
- **Karpenter** version `1.8.1` (contrôleur d’auto-scaling)
- **EKS Add-ons** : coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Configuration de Karpenter
- Contrôleur Karpenter avec des ressources dédiées :
  - CPU : 0.4 cœur (requests et limits)
  - Memory : 0.5Gi (requests et limits)
- Découverte automatique des sous-réseaux avec les tags `karpenter.sh/discovery`

#### Composants supplémentaires
- **Security Groups** avec les règles de sécurité correspondantes
- **Rôles et politiques IAM** pour Karpenter et EKS
- **OIDC provider** pour l’intégration avec les services AWS

#### Fichier de configuration principal

Tous les paramètres de l’infrastructure sont définis dans le fichier `tasks/eks/labs/02/env.hcl`. Pour modifier la configuration, modifiez les paramètres appropriés dans ce fichier.

### Prérequis

Assurez-vous d’avoir configuré :
- **AWS CLI** avec les autorisations d’accès appropriées
- Des limites de nombre de nœuds augmentées dans la région `eu-central-1` (si nécessaire)

## Configuration de base du NodePool

### Vérification du fonctionnement de Karpenter

**Étape 1 : Connexion au nœud de travail**

Recherchez dans la sortie de la commande la ligne de connexion SSH et connectez-vous au nœud de travail :

```bash
# Exemple de sortie :
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # Utilisez votre adresse IP et votre mot de passe
```

**Étape 2 : Vérification de l’état du contrôleur Karpenter**

Assurez-vous que le contrôleur Karpenter est démarré et opérationnel :

```bash
kubectl get po -n karpenter
```

**Résultat attendu :**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**Étape 3 : Vérification des NodePool et EC2NodeClass existants**

Vérifiez qu’aucun NodePool n’a encore été créé :

```bash
kubectl get nodepools
```

**Résultat :**
```
No resources found
```

Vérifiez l’EC2NodeClass :

```bash
kubectl get ec2nodeclasses
```

**Résultat :**
```
No resources found
```

**Ce que cela signifie :** NodePool et EC2NodeClass sont les principales ressources de Karpenter. NodePool définit les nœuds à créer, tandis qu’EC2NodeClass définit la manière de les configurer (AMI, sous-réseaux, security groups, etc.).

### Création d’une application de test

Déployons une simple application de test :

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Résultat :**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**Étape 4 : Vérification de l’état des pods**

Vérifiez l’état des pods créés :

```bash
kubectl get po -n team-19
```

**Résultat :**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**Remarque :** Le pod est à l’état `Pending` (en attente). C’est normal à cette étape.

**Étape 5 : Diagnostic du problème**

Affichons les informations détaillées du pod :

```bash
kubectl describe po -n team-19
```

**Partie importante de la sortie :**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**Explication du problème :**
- Le pod ne peut être planifié sur aucun nœud
- Les 3 nœuds existants sont des nœuds Fargate pour les pods système (kube-system, karpenter)
- Le Fargate profile est configuré uniquement pour certains namespaces, et `team-19` n’en fait pas partie
- Nous devons créer un NodePool pour que Karpenter puisse créer des nœuds EC2 adaptés

### Création du NodePool et de l’EC2NodeClass

**Étape 6 : Création du NodePool**

Le NodePool définit les paramètres des nœuds que Karpenter créera :

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # Étiquette permettant d’identifier les nœuds
    spec:
      requirements:
        # Architectures de processeur prises en charge
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # Système d’exploitation
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # Type d’instances : spot (moins cher) ou on-demand (plus stable)
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # Catégories d’instances (t - burstable, m - usage général, r - optimisé pour la mémoire)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # Génération des instances (supérieure à 2 = plus récente)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # Tailles des instances
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # Référence à l’EC2NodeClass avec les paramètres AWS
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # Durée de vie du nœud (30 jours)
      expireAfter: 720h # 30 * 24h = 720h
  # Limites de ressources pour l’ensemble du NodePool
  limits:
    cpu: 4  # Maximum de 4 CPU pour tous les nœuds de ce pool
  # Paramètres de consolidation (optimisation)
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # Supprimer les nœuds vides ou sous-utilisés
    consolidateAfter: 30s  # 30 secondes après que le nœud est devenu vide
EoF

kubectl apply -f default-nodepool.yaml
```

**Étape 7 : Obtention des paramètres depuis la sortie Terraform**

Recherchez les valeurs suivantes dans la sortie de la commande `make run_eks_task` :

```bash
# Exemple de sortie :
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Étape 8 : Création de l’EC2NodeClass**

L’EC2NodeClass définit les paramètres AWS spécifiques aux nœuds :

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # Rôle IAM pour les nœuds (remplacez-le par le vôtre depuis la sortie Terraform)
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # Sélection de l’image AMI
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023, dernière version
  # Sélection des sous-réseaux par tags
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Remplacez par le nom de votre cluster
  # Sélection des security groups par tags
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Remplacez par le nom de votre cluster
  # Tags pour les instances EC2 créées
  tags:
      Name: "eks2-viktor-01-default"  # Remplacez par le nom de votre cluster
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # Remplacez par le nom de votre cluster
  # Configuration des disques
  blockDeviceMappings:
    - deviceName: /dev/xvda    # Disque racine
      ebs:
        volumeType: gp3        # Type de disque (gp3 - moderne, performant)
        volumeSize: 25Gi       # Taille du disque
        iops: 3000             # IOPS pour gp3
        throughput: 125        # Débit MiB/s
        encrypted: true        # Chiffrement du disque
        deleteOnTermination: true  # Supprimer le disque lors de la suppression de l’instance
EoF

kubectl create -f default-nodeclass.yaml
```

### Vérification de la création automatique des nœuds

**Étape 9 : Vérification de l’état des ressources**

Vérifiez que l’EC2NodeClass est créée et prête :

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Résultat attendu :**
```
NAME      READY   AGE
default   True    2m17s
```

Vérifiez le NodePool :

```bash
kubectl get nodepools.karpenter.sh
```

**Résultat attendu :**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**Si l’état n’est pas READY :**

Diagnostiquez l’EC2NodeClass :

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**Exemple de sortie réussie :**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

Vérifiez le NodePool :

```bash
kubectl describe nodepools.karpenter.sh default
```

**En cas d’erreurs, vérifiez les journaux du contrôleur :**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Exemple de journaux réussis :**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**Étape 10 : Vérification du NodeClaim**

Un NodeClaim est une demande de création de nœud. Karpenter crée un NodeClaim, qui devient ensuite une instance EC2 réelle :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**Ce que nous voyons :**
- Un NodeClaim nommé `default-c549s` a été créé
- Une instance de type `t3a.small` (2 vCPU, 2GB RAM) a été choisie
- Une instance spot est utilisée (moins chère)
- Le nœud se trouve dans la zone `eu-central-1a`

**Étape 11 : Vérification du pod de l’application**

Le pod devrait maintenant démarrer correctement :

```bash
kubectl get po -n team-19
```

**Résultat :**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**L’état est passé à `Running` !**

**Étape 12 : Vérification des nœuds du cluster**

Affichons tous les nœuds du cluster :

```bash
kubectl get no
```

**Résultat :**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**Remarque :**
- Les 3 premiers nœuds sont des nœuds Fargate (pour les pods système)
- Le dernier nœud est une instance EC2 créée par Karpenter

### Vérification de la suppression automatique des nœuds

**Étape 13 : Suppression de l’application**

Supprimons notre application :

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Résultat :**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**Étape 14 : Vérification de la suppression des pods**

```bash
kubectl get po -n team-19
```

**Résultat :**
```
No resources found in team-19 namespace.
```

**Étape 15 : Attente de la suppression du NodeClaim**

Patientez environ 30 secondes (la valeur de `consolidateAfter` dans le NodePool), puis vérifiez :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
No resources found
```

**Karpenter a supprimé automatiquement le NodeClaim, car le nœud est devenu vide !**

**Étape 16 : Vérification des nœuds**

```bash
kubectl get no
```

**Résultat :**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**Le nœud EC2 a été supprimé ! Il ne reste que les nœuds Fargate.**

**Conclusion :** Karpenter gère automatiquement le cycle de vie des nœuds : il les crée lorsque cela est nécessaire et les supprime lorsqu’ils ne sont plus requis, optimisant ainsi les coûts.

## Mise à l’échelle des applications

Dans cette section, nous verrons comment Karpenter ajoute automatiquement des nœuds lorsque la charge augmente.

### Mise à l’échelle horizontale

**Étape 1 : Déploiement de l’application de test**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Étape 2 : Vérification des ressources créées**

Vérifiez le NodeClaim :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

Vérifiez les nœuds :

```bash
kubectl get no
```

**Résultat :**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

Vérifiez les pods :

```bash
kubectl get po -n team-19
```

**Résultat :**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### Ajout automatique de nœuds

**Étape 3 : Mise à l’échelle à 6 répliques**

Augmentons le nombre de répliques de l’application :

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**Résultat :**
```
deployment.apps/team19 scaled
```

**Étape 4 : Vérification de l’état des pods**

```bash
kubectl get po -n team-19
```

**Résultat :**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**Les 6 pods sont tous démarrés avec succès !**

**Étape 5 : Vérification du NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Remarque :** Karpenter a ajouté automatiquement un second nœud (`default-gm8sj`), car un seul nœud ne suffisait pas à héberger les 6 pods.

**Étape 6 : Mise à l’échelle à 16 répliques**

Augmentons encore davantage la charge :

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**Étape 7 : Vérification de l’état des pods**

```bash
kubectl get po -n team-19
```

**Résultat :**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**Problème :** Certains pods sont à l’état `Pending`. Pourquoi ? Passons à la section suivante pour le comprendre.

## Limitation des ressources

Dans cette section, nous déterminerons pourquoi certains pods sont restés à l’état `Pending` et apprendrons à gérer les limites de ressources dans NodePool.

### Configuration des limites CPU

**Étape 1 : Vérification des limites actuelles du NodePool**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**Résultat :**
```json
{
  "cpu": 4
}
```

**Ce que cela signifie :** Une limite de 4 CPU est définie dans le NodePool. Cela signifie que le nombre cumulé de CPU de tous les nœuds de ce pool ne peut pas dépasser 4 cœurs.

**Étape 2 : Vérification des NodeClaim existants**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Analyse :**
- Nous avons 2 nœuds de type `t4g.small`
- Chaque `t4g.small` possède 2 vCPU
- Total : 2 nœuds × 2 vCPU = 4 vCPU
- **Nous avons atteint la limite !** Karpenter ne peut pas créer d’autres nœuds.

### Diagnostic des problèmes de limites

**Étape 3 : Vérification des journaux de Karpenter**

Voyons ce qu’indiquent les journaux du contrôleur :

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**Résultat :**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**Message clé :** `"all available instance types exceed limits for nodepool"`

Cela confirme que Karpenter ne peut pas créer de nouveaux nœuds en raison de la limite CPU.

**Étape 4 : Augmentation de la limite CPU**

Augmentons la limite CPU à 6 cœurs :

```bash
kubectl edit nodepools.karpenter.sh default
```

Trouvez la section `limits` et modifiez la valeur :

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # Remplacez par 6
```

Enregistrez les modifications (`:wq` dans vim ou Ctrl+O, Enter, Ctrl+X dans nano).

**Étape 5 : Vérification de la création d’un nouveau nœud**

Attendez quelques secondes, puis vérifiez le NodeClaim :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**Excellent !** Karpenter a créé le troisième nœud (`default-gpgn9`).

**Étape 6 : Vérification des pods de l’application**

```bash
kubectl get po -n team-19
```

**Résultat :**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**Les 16 pods sont maintenant tous à l’état `Running` !**

### Vérification de la consolidation automatique

**Étape 7 : Réduction du nombre de répliques**

Réduisons le nombre de répliques à 3 :

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**Étape 8 : Surveillance des journaux de Karpenter**

Suivez les journaux en temps réel :

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Vous verrez des messages de consolidation :**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**Ce qui se passe :**
- Karpenter a détecté un nœud sous-utilisé (`underutilized`)
- Il a décidé de supprimer le nœud (`decision: delete`)
- Il marque d’abord le nœud avec le taint `karpenter.sh/disrupted:NoSchedule`
- Il déplace les pods vers d’autres nœuds
- Il supprime le nœud

**Étape 9 : Vérification des nœuds restants**

Attendez environ une minute, puis vérifiez :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**Il ne reste qu’un seul nœud !** Karpenter a supprimé les nœuds superflus, optimisant les coûts.

### Informations supplémentaires sur les limites

Les limites peuvent être définies sur différents types de ressources :
- **cpu** — nombre de cœurs de processeur
- **memory** — quantité de mémoire vive
- **gpu** — nombre de GPU (pour les charges ML/AI)
- **nodes** — nombre maximal de nœuds

**Exemple de configuration avec plusieurs limites :**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

Pour en savoir plus sur les limites, consultez la [documentation officielle de Karpenter](https://karpenter.sh/docs/concepts/nodepools/#speclimits).

## Gestion du cycle de vie des nœuds (Disruption)

Karpenter prend en charge la gestion automatique du cycle de vie des nœuds avec le paramètre `consolidateAfter` dans la spécification NodePool.

**Concepts clés :**

- **consolidateAfter** — délai d’attente avant la suppression d’un nœud lorsqu’il est devenu vide ou sous-utilisé
- **consolidationPolicy** — politique de consolidation :
  - `WhenEmpty` — supprimer uniquement les nœuds entièrement vides
  - `WhenEmptyOrUnderutilized` — supprimer les nœuds vides et sous-utilisés (recommandé)

**Exemple de configuration :**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # Supprimer 30 secondes après la libération
```

**Fonctionnement :**

1. Karpenter surveille constamment l’utilisation des ressources sur les nœuds
2. Lorsqu’un nœud devient vide ou sous-utilisé, Karpenter démarre un minuteur
3. Si, au terme du délai indiqué (`consolidateAfter`), le nœud n’est toujours pas nécessaire, Karpenter :
   - Marque le nœud avec le taint `karpenter.sh/disrupted:NoSchedule`
   - Déplace les pods vers d’autres nœuds de façon contrôlée
   - Supprime le nœud

**Paramètres supplémentaires :**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # Ne pas supprimer plus de 10 % des nœuds simultanément
```

Pour en savoir plus sur disruption, consultez la [documentation officielle](https://karpenter.sh/docs/concepts/disruption/).

---

## Optimisation de la taille des nœuds (RightSizing)

Karpenter sélectionne automatiquement la taille de nœud optimale selon les exigences des pods. Cette fonction est appelée « right-sizing » : le choix du type d’instance le plus adapté et économique.

### Sélection automatique de la taille optimale

**Étape 1 : Définition de la limite CPU**

Augmentons la limite du NodePool à 10 cœurs :

```bash
kubectl edit nodepools.karpenter.sh default
```

Modifiez :

```yaml
spec:
  limits:
    cpu: 6     # Remplacez par 10
```

**Étape 2 : Déploiement d’une application avec des exigences élevées**

Déployons une application qui demande 3 CPU :

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Étape 3 : Vérification du NodeClaim créé**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**Remarque :** Karpenter a choisi une instance `t3.xlarge` avec 4 vCPU, car le pod demande 3 CPU.

**Étape 4 : Vérification des détails du nœud**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**Étiquettes importantes :**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### Remplacement des nœuds lorsque les exigences changent

**Étape 5 : Réduction des exigences du pod**

Modifions les exigences CPU dans le deployment :

```bash
kubectl edit deployments.apps -n team-19 team19
```

Trouvez la section `resources` et modifiez :

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # Remplacez par "50m" (50 millicœurs)
        memory: 500Mi
```

Enregistrez les modifications.

**Étape 6 : Surveillance des journaux de Karpenter**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Vous verrez :**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**Ce qui se passe :**
- Karpenter a détecté que le nœud est sous-utilisé (`underutilized`)
- Il a décidé de remplacer le nœud (`decision: replace`)
- Il crée un nouveau nœud moins coûteux

**Création d’un nouveau NodeClaim :**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**Lancement de la nouvelle instance :**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**Étape 7 : Vérification du nouveau NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**Excellent !** Karpenter a remplacé `t3.xlarge` (4 vCPU) par `t4g.small` (2 vCPU), qui est nettement moins coûteux.

**Étape 8 : Nettoyage**

Supprimez le deployment :

```bash
kubectl delete deployments.apps -n team-19 team19
```

Attendez la suppression du NodeClaim :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
No resources found
```

**Conclusion :** Karpenter optimise automatiquement la taille des nœuds en sélectionnant les options les plus économiques qui répondent aux exigences des applications.

## Mise à jour de la configuration des nœuds (Drift)

Drift est un mécanisme de mise à jour automatique des nœuds lorsque la configuration de l’EC2NodeClass change. Lorsque vous modifiez l’AMI, les security groups, les user data ou d’autres paramètres, Karpenter remplace automatiquement les nœuds existants par de nouveaux nœuds avec la configuration mise à jour.

### Mise à jour des images AMI

**Étape 1 : Obtention de l’AMI de la version EKS précédente**

Obtenons l’ID AMI pour EKS version 1.33 :

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**Résultat :**
```
ami-0fc1cdef3ebc3a8fe
```

**Étape 2 : Configuration de l’ancien AMI dans l’EC2NodeClass**

Modifiez l’EC2NodeClass :

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Trouvez la section `amiSelectorTerms` et modifiez :

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Avant
```

Par :

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # ID AMI spécifique de la version 1.33
```

**Étape 3 : Déploiement de l’application**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Étape 4 : Vérification de la version du nœud**

```bash
kubectl get no
```

**Résultat :**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- Version 1.33 !
```

**Remarque :** Le nœud utilise Kubernetes version 1.33.5 (depuis l’ancien AMI).

### Migration automatique vers de nouvelles versions

**Étape 5 : Retour à la sélection automatique de l’AMI**

Modifiez de nouveau l’EC2NodeClass :

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Modifiez comme suit :

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Sélection automatique de la dernière version
```

**Ce qui se passe :**
- Karpenter détecte la modification de l’EC2NodeClass
- Il détermine que le nœud existant utilise une configuration obsolète (drift)
- Il crée automatiquement un nouveau nœud avec l’AMI mise à jour
- Il déplace les pods vers le nouveau nœud de façon contrôlée
- Il supprime l’ancien nœud

**Étape 6 : Vérification de la mise à jour du nœud**

Attendez environ une minute, puis vérifiez les nœuds :

```bash
kubectl get no
```

**Résultat (après ~30 secondes) :**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- Nouvelle version !
```

**Résultat (après ~4 minutes) :**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**Excellent !** Karpenter a remplacé automatiquement le nœud par un nouveau avec une version AMI mise à jour (1.34.2).

**Étape 7 : Nettoyage**

```bash
kubectl delete deployments.apps -n team-19 team19
```

Attendez la suppression du NodeClaim :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
No resources found
```

**Conclusion :** Drift permet de mettre automatiquement à jour les nœuds lors de modifications de configuration, sans intervention manuelle. C’est particulièrement utile pour :
- Mettre à jour les AMI (correctifs de sécurité, nouvelles versions de Kubernetes)
- Modifier les security groups
- Mettre à jour les scripts user data
- Modifier les rôles IAM

---

## Utilisation de plusieurs NodePool

Dans un environnement de production, il est souvent nécessaire de répartir la charge entre différents groupes de nœuds. Par exemple :
- Contrôleurs Ingress sur des nœuds dédiés
- Nœuds puissants pour les tâches périodiques (jobs)
- Nœuds avec GPU pour les charges ML/AI
- Nœuds à grande capacité mémoire pour les bases de données

### Isolation de la charge avec Taints et Tolerations

**Scénario :** Nous devons exécuter des job périodiques ayant des exigences de ressources élevées (CPU, mémoire, GPU).

**Exigences :**
1. Les pods ordinaires ne doivent pas être planifiés sur ces nœuds (uniquement les job)
2. Tant qu’un job s’exécute sur le nœud, aucune consolidation ne doit avoir lieu
3. Dès que le job est terminé, le nœud doit être supprimé

### Nœuds spécialisés pour les Job

**Étape 1 : Création d’un NodePool spécialisé**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # Étiquette pour l’identification
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 jours
      # IMPORTANT : Le taint empêche les pods ordinaires de s’exécuter sur ces nœuds
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # Les pods sans toleration correspondante ne pourront pas démarrer
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # Supprimer UNIQUEMENT les nœuds vides (pas pendant l’exécution d’un job)
    consolidateAfter: 10s           # Suppression rapide après la fin du job
EoF

kubectl apply -f job-nodepool.yaml
```

**Différences essentielles avec le NodePool default :**

1. **Taints** — empêchent les pods ordinaires de s’exécuter :
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — le nœud est supprimé seulement lorsqu’il est entièrement vide (n’interrompt pas les job en cours)

3. **consolidateAfter: 10s** — suppression rapide après la fin du job

**Étape 2 : Obtention des paramètres depuis la sortie Terraform**

Recherchez dans la sortie :

```bash
# Exemple :
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Étape 3 : Création d’une EC2NodeClass pour les job**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # Remplacez par le vôtre
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Remplacez par le nom de votre cluster
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Remplacez par le nom de votre cluster
  tags:
      Name: "eks2-viktor-01-job"  # Remplacez par le nom de votre cluster
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**Étape 4 : Vérification de l’état des ressources**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Résultat :**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**Résultat :**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**Si l’état n’est pas READY**, effectuez le diagnostic :

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Étape 5 : Exécution d’un Job avec Toleration**

Créez un job qui peut s’exécuter sur les nœuds avec le taint `workType=job` :

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # La toleration permet au pod de s’exécuter sur les nœuds avec le taint correspondant
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # L’affinity garantit que le pod s’exécutera précisément sur les nœuds du NodePool job
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**Étape 6 : Vérification de la création du NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat :**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**Vérification du pod :**

```bash
kubectl get po
```

**Résultat (pendant l’exécution) :**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**Résultat (après la fin) :**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**Vérification des nœuds :**

```bash
kubectl get no
```

**Résultat :**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**Étape 7 : Vérification de la suppression automatique du nœud**

Attendez environ 10 à 15 secondes après la fin du job, puis vérifiez les nœuds :

```bash
kubectl get no
```

**Résultat :**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Le nœud a été supprimé avec succès !** Karpenter a supprimé automatiquement le nœud 10 secondes après la fin du job.

**Conclusion :** L’utilisation de plusieurs NodePool avec des taints et tolerations permet de :
- Isoler différents types de charge
- Optimiser les coûts (suppression rapide des nœuds après la fin des job)
- Empêcher les pods ordinaires de s’exécuter sur des nœuds spécialisés
- Gérer avec souplesse les politiques de consolidation pour différents types de charge

## Nettoyage des ressources

Après avoir terminé le laboratoire, vous devez supprimer toutes les ressources créées afin d’éviter des dépenses inutiles.

**Étape 1 : Vérification de l’absence de NodeClaim actifs**

Assurez-vous qu’il n’existe aucun NodeClaim actif :

```bash
kubectl get nodeclaims.karpenter.sh
```

**Résultat attendu :**
```
No resources found
```

**S’il existe des NodeClaim actifs :**

1. Vérifiez qu’aucun pod ne s’exécute sur les nœuds :

```bash
kubectl get pods --all-namespaces -o wide
```

2. Supprimez le deployment, les pods ou les jobs :

```bash
# Exemple de suppression d’un deployment
kubectl delete deployment -n team-19 team19

# Exemple de suppression d’un job
kubectl delete job testjob
```

3. Après avoir supprimé les pods, supprimez manuellement le NodeClaim (si nécessaire) :

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**Étape 2 : Vérification des nœuds du cluster**

Assurez-vous qu’il ne reste que des nœuds Fargate :

```bash
kubectl get no
```

**Résultat attendu :**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Tous les nœuds doivent commencer par `fargate-`.**

**Étape 3 : Suppression de l’infrastructure**

Supprimez toutes les ressources créées pour le laboratoire :

```bash
TASK=02 make delete_eks_task
```

**Sortie de la commande :**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**Saisissez `y` pour confirmer la suppression.**

**Ce qui sera supprimé :**
- Nœud de travail (worker)
- Contrôleur Karpenter et ressources associées
- Clés SSH
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC et infrastructure réseau

**Le processus de suppression prendra environ 10 à 15 minutes.**

---

## Conclusion

Félicitations ! Vous avez terminé avec succès le laboratoire sur les principes fondamentaux de Karpenter.

**Ce que vous avez appris :**

1. **Configuration de base** — création d’un NodePool et d’une EC2NodeClass pour la gestion automatique des nœuds
2. **Mise à l’échelle automatique** — Karpenter ajoute dynamiquement des nœuds lorsque la charge augmente
3. **Gestion des limites** — contrôle de la quantité maximale de ressources avec limits
4. **Consolidation** — suppression automatique des nœuds vides et sous-utilisés afin d’optimiser les coûts
5. **Right-sizing** — sélection automatique de la taille de nœud optimale selon les exigences des pods
6. **Drift** — mise à jour automatique des nœuds lorsque la configuration change (AMI, security groups, etc.)
7. **NodePool multiples** — isolation de différents types de charge avec taints, tolerations et affinity

**Principaux avantages de Karpenter :**

- **Mise à l’échelle rapide** — les nœuds sont créés en quelques secondes, et non en quelques minutes
- **Optimisation des coûts** — sélection automatique des types d’instances les plus économiques
- **Flexibilité** — prise en charge des instances spot et on-demand, ainsi que de diverses architectures (amd64, arm64)
- **Simplicité** — configuration déclarative avec des ressources Kubernetes
- **Automatisation** — intervention manuelle minimale dans la gestion des nœuds

**Ressources supplémentaires :**

- [Documentation officielle de Karpenter](https://karpenter.sh/docs/)
- [Bonnes pratiques pour Karpenter](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Guide de dépannage](https://karpenter.sh/docs/troubleshooting/)
- [Bonnes pratiques AWS EKS](https://aws.github.io/aws-eks-best-practices/)

**Étapes suivantes :**

- Découvrez les fonctionnalités avancées de Karpenter (weighted NodePools, custom AMI, GPU support)
- Intégrez Karpenter à vos applications de production
- Configurez la surveillance et les alertes pour Karpenter
- Optimisez les coûts en analysant l’utilisation des instances spot vs on-demand
