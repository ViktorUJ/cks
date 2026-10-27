[Русский](getting_started_RU.md) · [English](getting_started.md) · [Español](getting_started_ES.md) · Français · [Deutsch](getting_started_DE.md) · [ქართული](getting_started_GE.md) · [繁體中文](getting_started_TW.md) · [日本語](getting_started_JP.md) · [Accueil](../README_FR.MD)

<a id="quick-start"></a>

# Premiers pas et prérequis

Vous pouvez lire les cours directement dans le dépôt. Les environnements pratiques nécessitent AWS et les outils de la plateforme. Les ressources sont facturées à votre compte AWS ; supprimez les environnements après la session selon les instructions du scénario.

## 1. Préparer les outils

Vous pouvez utiliser l'image Docker préparée avec les dépendances :

```bash
sudo docker run -it viktoruj/runner
```

[Instructions de lancement avec Docker](run_from_docker_FR.MD) · [Instructions vidéo](https://youtu.be/Xh6sWzafBmw)

[![Lancer la plateforme avec Docker](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "Lancer la plateforme avec Docker")

<details>
<summary>Prérequis pour une installation locale</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- Un [profil AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) ou une autre méthode d'authentification configurée.
- Un [utilisateur IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) avec une [clé d'accès](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html), ou un [rôle IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html), autorisé à créer et supprimer les ressources du scénario. La configuration d'origine suppose des permissions étendues sur VPC, EC2, IAM et EKS ; consultez les [politiques d'accès AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).

Il s'agit des versions minimales d'origine indiquées dans la documentation. Consultez le scénario et sa configuration Terraform pour les exigences supplémentaires concernant les outils et les fournisseurs.

</details>

## 2. Récupérer le dépôt et configurer AWS

Exécutez les commandes suivantes dans le conteneur Docker ou sur une machine équipée des outils :

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

Configurez l'accès à AWS. Définissez votre propre `backend_bucket` dans [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl) ; modifiez `region` et `backend_region` si nécessaire. Vérifiez la région et les paramètres dans le fichier `env.hcl` du scénario. Le [guide Docker](run_from_docker_FR.MD) détaille la configuration.

## 3. Choisir et lancer un exercice

Exemple du premier travail pratique composite CKA + CKAD :

```bash
TASK=101 make run_cka_task
```

Ouvrez le [travail pratique 101](../tasks/cka/labs/101/README_FR.MD), connectez-vous à l'aide des informations de Terraform et réalisez les tâches.

## 4. Supprimer l'environnement

Après l'exercice, suivez ses instructions de suppression, puis exécutez :

```bash
TASK=101 make delete_cka_task
```

Pour un autre exercice, remplacez le numéro et utilisez la commande du domaine correspondant dans la [référence des commandes](commands_FR.md).
