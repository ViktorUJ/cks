[Русский](commands_RU.md) · [English](commands.md) · [Español](commands_ES.md) · Français · [Deutsch](commands_DE.md) · [ქართული](commands_GE.md) · [繁體中文](commands_TW.md) · [日本語](commands_JP.md) · [Accueil](../README_FR.MD)

<a id="commands"></a>

# Référence des commandes

Exécutez toutes les commandes à la racine du dépôt. `TASK` est le numéro du travail pratique ou de l'examen blanc choisi. Utilisez les mêmes `TASK`, `USER_ID` et `ENV_ID` pour lancer l'environnement, consulter les sorties Terraform et le supprimer.

Les commandes se terminant par `_clean` vident le répertoire local de l'environnement concerné avant l'opération. Elles ne remplacent pas la suppression des ressources cloud avec `delete_*`.

<details>
<summary>CKA + CKAD : travaux pratiques et examens blancs CKA</summary>

Les travaux pratiques composites du cours commun CKA + CKAD utilisent les commandes `cka_task`.

| Commande | Action |
|---|---|
| `TASK=101 make run_cka_task` | Créer [travail pratique CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | Supprimer l'environnement du travail pratique |
| `TASK=101 make run_cka_task_clean` | Lancer le travail pratique après nettoyage du répertoire local |
| `TASK=101 make output_cka_task` | Afficher les sorties Terraform |
| `TASK=01 make run_cka_mock` | Créer [examen blanc CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | Supprimer l'environnement de l'examen blanc |
| `TASK=01 make run_cka_mock_clean` | Lancer l'examen après nettoyage du répertoire local |
| `TASK=01 make output_cka_mock` | Afficher les sorties Terraform |

</details>

<details>
<summary>CKAD : examens blancs</summary>

| Commande | Action |
|---|---|
| `TASK=01 make run_ckad_mock` | Créer [examen blanc CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | Supprimer l'environnement de l'examen blanc |
| `TASK=01 make run_ckad_mock_clean` | Lancer l'examen après nettoyage du répertoire local |
| `TASK=01 make output_ckad_mock` | Afficher les sorties Terraform |

</details>

<details>
<summary>CKS : travaux pratiques et examens blancs</summary>

| Commande | Action |
|---|---|
| `TASK=101 make run_cks_task` | Créer [travail pratique CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | Supprimer l'environnement du travail pratique |
| `TASK=101 make run_cks_task_clean` | Lancer le travail pratique après nettoyage du répertoire local |
| `TASK=101 make output_cks_task` | Afficher les sorties Terraform |
| `TASK=01 make run_cks_mock` | Créer [examen blanc CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | Supprimer l'environnement de l'examen blanc |
| `TASK=01 make run_cks_mock_clean` | Lancer l'examen après nettoyage du répertoire local |
| `TASK=01 make output_cks_mock` | Afficher les sorties Terraform |

</details>

<details>
<summary>Istio / ICA : travaux pratiques et examens blancs</summary>

| Commande | Action |
|---|---|
| `TASK=01 make run_ica_task` | Créer [travail pratique ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | Supprimer l'environnement du travail pratique |
| `TASK=01 make run_ica_task_clean` | Lancer le travail pratique après nettoyage du répertoire local |
| `TASK=01 make output_ica_task` | Afficher les sorties Terraform |
| `TASK=01 make run_ica_mock` | Créer [examen blanc ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | Supprimer l'environnement de l'examen blanc |
| `TASK=01 make run_ica_mock_clean` | Lancer l'examen après nettoyage du répertoire local |
| `TASK=01 make output_ica_mock` | Afficher les sorties Terraform |

</details>

<details>
<summary>Amazon EKS : travaux pratiques</summary>

| Commande | Action |
|---|---|
| `TASK=101 make run_eks_task` | Créer [travail pratique EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | Supprimer l'environnement du travail pratique |
| `TASK=101 make run_eks_task_clean` | Lancer le travail pratique après nettoyage du répertoire local |
| `TASK=101 make output_eks_task` | Afficher les sorties Terraform |

Avant de supprimer un environnement EKS, effectuez le nettoyage préalable décrit dans le travail pratique. Certaines ressources sont créées par des contrôleurs Kubernetes ou manuellement et doivent être supprimées avant Terraform destroy.

</details>

<details>
<summary>LFCS : examens blancs</summary>

| Commande | Action |
|---|---|
| `TASK=01 make run_lfcs_mock` | Créer [examen blanc LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | Supprimer l'environnement de l'examen blanc |
| `TASK=01 make run_lfcs_mock_clean` | Lancer l'examen après nettoyage du répertoire local |
| `TASK=01 make delete_lfcs_mock_clean` | Supprimer l'examen après nettoyage du répertoire local |
| `TASK=01 make output_lfcs_mock` | Afficher les sorties Terraform |

</details>

<details>
<summary>HR : scénarios pratiques</summary>

| Commande | Action |
|---|---|
| `TASK=01 make run_hr_mock` | Créer [scénario HR 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | Supprimer l'environnement du scénario |
| `TASK=01 make run_hr_mock_clean` | Lancer le scénario après nettoyage du répertoire local |
| `TASK=01 make output_hr_mock` | Afficher les sorties Terraform |

</details>

<details>
<summary>KCNA, KCSA et AWS Certified AI Practitioner : ressources d'évaluation</summary>

Ouvrez la section correspondante et suivez ses instructions :

- [KCNA : examen blanc n° 01](../tasks/kcna/mock/01/README.MD).
- [KCSA : cours, questions et examens blancs](../tasks/kcsa/README_FR.md).
- [AWS Certified AI Practitioner : examen blanc n° 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>Développement et vérifications</summary>

`make lint` - exécuter les vérifications configurées du projet via pre-commit.

</details>
