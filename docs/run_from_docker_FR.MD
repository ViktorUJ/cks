[Русский](run_from_docker_RU.MD) · [English](run_from_docker.MD) · [Español](run_from_docker_ES.MD) · Français · [Deutsch](run_from_docker_DE.MD) · [ქართული](run_from_docker_GE.MD) · [繁體中文](run_from_docker_TW.MD) · [日本語](run_from_docker_JP.MD) · [Accueil](../README_FR.MD)

# Démarrage rapide avec Docker

L'image Docker prête à l'emploi contient les dépendances et les utilitaires nécessaires pour lancer les travaux pratiques et les examens blancs pratiques. L'exemple ci-dessous lance l'examen blanc CKA n° 01.

[Instructions vidéo](https://youtu.be/Xh6sWzafBmw)

## 1. Lancer le conteneur

Sur une machine où Docker est installé, exécutez :

```bash
sudo docker run -it viktoruj/runner
```

Exécutez toutes les commandes suivantes à l'intérieur du conteneur.

## 2. Cloner le dépôt

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. Configurer le stockage de l'état Terraform

Ouvrez [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl). Remplacez `backend_bucket` par le nom de votre propre bucket S3 destiné à l'état Terraform. Si nécessaire, modifiez la région de l'infrastructure `region` et celle du stockage de l'état `backend_region` :

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

Vérifiez aussi la région et les paramètres dans le fichier `env.hcl` du scénario choisi.

## 4. Configurer l'accès à AWS

Remplacez les valeurs d'exemple par vos propres clés d'accès :

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

Si vous utilisez des identifiants temporaires, définissez également `AWS_SESSION_TOKEN`.

## 5. Vérifier les quotas AWS

L'environnement peut nécessiter plusieurs instances EC2. Dans la console AWS, ouvrez **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** et vérifiez les quotas de la région et de la famille d'instances utilisées :

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** pour On-Demand.
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** pour Spot.

Ces quotas sont exprimés en vCPU et non en nombre d'instances. Si le quota disponible ne suffit pas au scénario choisi, demandez une augmentation. Pour d'autres familles d'instances, vérifiez les quotas correspondants.

## 6. Lancer le scénario

Pour un seul environnement :

```bash
TASK=01 make run_cka_mock
```

Pour un utilisateur donné ou plusieurs environnements indépendants :

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Connectez-vous à la machine de travail à l'aide des informations affichées par Terraform et suivez les [instructions de l'examen](../tasks/cka/mock/01/README.MD).

Pour un autre exercice, choisissez son domaine et son numéro dans le [catalogue des travaux pratiques](labs.MD) ou sur la [page d'accueil](../README_FR.MD). Les commandes de lancement figurent dans le [guide des commandes](commands_FR.md).

## 7. Supprimer l'environnement après la session

Les ressources sont facturées à votre compte AWS. Effectuez le nettoyage préalable indiqué dans le README du scénario, puis supprimez l'environnement.

Pour un seul environnement :

```bash
TASK=01 make delete_cka_mock
```

Pour l'environnement d'un utilisateur donné :

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

Utilisez les mêmes valeurs de `TASK`, `USER_ID` et `ENV_ID` que lors du lancement du scénario.

[Environnements indépendants et CMDB](environments_FR.md) · [Scénarios d'utilisation](usage_scenarios_FR.md)
