[Русский](architecture_RU.md) · [English](architecture.md) · [Español](architecture_ES.md) · Français · [Deutsch](architecture_DE.md) · [ქართული](architecture_GE.md) · [繁體中文](architecture_TW.md) · [日本語](architecture_JP.md) · [Accueil](../README_FR.MD)

<a id="architecture"></a>

# Architecture de la plateforme

Les environnements pratiques sont définis comme du code. Le Makefile choisit le scénario, Terragrunt coordonne les modules Terraform, et Terraform crée les ressources AWS nécessaires et affiche les informations de connexion.

Les scénarios Kubernetes autogérés installent les clusters avec **kubeadm**. Les travaux pratiques **Amazon EKS** utilisent Kubernetes géré sur AWS. Selon le scénario, la plateforme crée VPC, sous-réseaux, groupes de sécurité, instances EC2 (y compris Spot), S3 et d'autres ressources nécessaires.

<details>
<summary>Structure du dépôt</summary>

| Chemin | Rôle |
|---|---|
| [Makefile](../Makefile) | Commandes de lancement, de suppression et de consultation des environnements, et de vérification du projet |
| [tasks](../tasks) | Cours, tâches, travaux pratiques et examens blancs |
| [tasks/cka](../tasks/cka) | Cours commun CKA + CKAD, [travaux pratiques](../tasks/cka/labs) et [examens blancs CKA](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [Examens blancs CKAD](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | Cours CKS, [travaux pratiques](../tasks/cks/labs) et [examens blancs](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Cours et travaux pratiques Amazon EKS |
| [tasks/ica](../tasks/ica) | Cours, travaux pratiques et examens blancs Istio / ICA |
| [tasks/kcsa](../tasks/kcsa) | Cours, questions et examens blancs KCSA |
| [tasks/kcna](../tasks/kcna) | [Examens blancs KCNA](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | Examens blancs pratiques LFCS |
| [tasks/hr](../tasks/hr) | Scénarios HR |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [Examens blancs AWS Certified AI Practitioner](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | Définitions de l'infrastructure |
| [terraform/environments](../terraform/environments) | Configuration Terragrunt et répertoires locaux des environnements |
| [terraform/modules](../terraform/modules) | Modules Terraform réutilisables |
| [docs](../docs) | Catalogue des travaux pratiques, instructions et ressources complémentaires |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | Historique des modifications du projet |

</details>

<details>
<summary>Kubernetes, runtimes, système et CNI</summary>

Vous pouvez utiliser le module [k8s_self_managment](../terraform/modules/k8s_self_managment) pour vos scénarios. Il définit un cluster Kubernetes autogéré ; la version, le runtime, le système, l'AMI et le réseau sont définis par chaque scénario.

Le projet utilise ou a utilisé les options suivantes :

| Composant | Options |
|---|---|
| Kubernetes | Scénarios historiques en versions 1.21-1.34 ; consultez `env.hcl` et le cours pour les exercices récents |
| Container runtime | `containerd`, `containerd_gvizor` ; les anciens scénarios utilisent aussi `docker` et `cri-o` |
| Système des nœuds des clusters autogérés | Ubuntu 20.04 LTS et 22.04 LTS selon le scénario |
| CNI | Calico ou Cilium selon le scénario |

L'ancienne description indiquait Docker avec Kubernetes 1.21-1.23, CRI-O avec 1.21-1.29, containerd et `containerd_gvizor` avec 1.21-1.33, ainsi que Kubernetes 1.33 par défaut pour CKA/CKS et Ubuntu 22.04 pour CKS. Ces données concernent d'anciennes configurations et ne constituent pas une matrice de compatibilité pour les nouveaux travaux pratiques. Choisissez les paramètres actuels dans les sources de l'exercice ; l'[historique des versions Kubernetes](https://kubernetes.io/releases/) est disponible sur le site du projet.

</details>
