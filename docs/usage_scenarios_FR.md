[Русский](usage_scenarios_RU.md) · [English](usage_scenarios.md) · [Español](usage_scenarios_ES.md) · Français · [Deutsch](usage_scenarios_DE.md) · [ქართული](usage_scenarios_GE.md) · [繁體中文](usage_scenarios_TW.md) · [日本語](usage_scenarios_JP.md) · [Accueil](../README_FR.MD)

<a id="usage"></a>

# Scénarios d'utilisation et vidéos

<details>
<summary>Travaux pratiques CKA + CKAD et CKS : du lancement à la validation</summary>

1. Choisissez un exercice dans le [catalogue](labs.MD) et lisez sa description : `tasks/cka/labs/<number>/README_FR.MD` ou `tasks/cks/labs/<number>/README_FR.MD` pour les exercices traduits.
2. Vérifiez `env.hcl` : région, types d'instances et paramètres. Si vous définissez `ami_id` manuellement, l'image doit correspondre à la région et à l'architecture ; pour une sélection automatique, suivez les paramètres du scénario.
3. Créez l'environnement : `TASK=101 make run_cka_task` ou `TASK=101 make run_cks_task`.
4. Trouvez la commande SSH dans la sortie Terraform. Les exercices composites commencent généralement sur la machine `worker`, certains scénarios sur un nœud du plan de contrôle. Utilisez `worker_pc_ip`, `master_external_ip` ou la commande fournie par votre scénario.
5. Connectez-vous avec l'utilisateur `ubuntu`. Avec une clé, utilisez `ssh ubuntu@<IP> -i <key_path>` ; si l'environnement affiche un mot de passe, utilisez `ssh ubuntu@<IP>` puis saisissez-le à l'invite.
6. Si nécessaire, vérifiez la fin de l'initialisation sur la machine concernée : `tail -f /var/log/cloud-init-output.log`.
7. Réalisez les tâches. Pour les exercices composites, lancez `check_result` sur la machine de travail et suivez la méthode décrite.
8. Étudiez la solution de référence. Pour l'exercice 101 : [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_FR.MD) et [CKS](../tasks/cks/labs/101/worker/files/solutions/1_FR.MD). Ailleurs, l'emplacement peut varier ; utilisez le lien du catalogue ou de la description.
9. Effectuez le nettoyage préalable indiqué, puis supprimez l'environnement : `TASK=101 make delete_cka_task` ou `TASK=101 make delete_cks_task`.

Pour relancer après nettoyage du répertoire local, utilisez `run_cka_task_clean` ou `run_cks_task_clean`. Les ressources cloud doivent être supprimées avec `delete_*`.

</details>

<details>
<summary>Examens blancs pratiques CKA, CKAD, CKS, ICA et HR</summary>

Procédure générale :

1. Choisissez le numéro de l'examen et ouvrez son README dans `tasks/<track>/mock/<number>/`.
2. Au besoin, modifiez les paramètres prévus dans `env.hcl` : système (`ubuntu_version`), mode d'achat EC2 (`spot` ou `ondemand`) et types d'instances.
3. Lancez avec `TASK=<number> make run_<track>_mock`. Utilisez `run_<track>_mock_clean` pour un lancement après nettoyage local.
4. Trouvez `worker_pc_ip` ou la commande SSH dans la sortie Terraform, puis connectez-vous à la machine de travail comme `ubuntu` avec la clé ou le mot de passe de l'environnement.
5. Ouvrez les tâches et travaillez depuis cette machine. Utilisez `ssh <node_name>` pour accéder à un nœud selon la description de l'examen.
6. Consultez le temps restant avec `time_left` et le résultat avec `check_result` si ces commandes sont prévues.
7. Après la tentative, consultez les solutions et les tests ci-dessous.
8. Supprimez l'environnement avec `TASK=<number> make delete_<track>_mock`.

| Domaine | Tâches de l'examen 01 | Solutions | Vérifications automatiques |
|---|---|---|---|
| CKA | [Description](../tasks/cka/mock/01) | [Solutions](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [Description](../tasks/ckad/mock/01) | [Solutions](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [Description](../tasks/cks/mock/01) | [Solutions](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [Description](../tasks/ica/mock/01) | [Solutions](../tasks/ica/mock/01/worker/files/solutions) | [Répertoire des tests](../tasks/ica/mock/01/worker/files/tests) |
| HR | [Description](../tasks/hr/mock/01) | [Solutions](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

Instructions vidéo et explications :

- CKA: [lancement de l'examen blanc](https://www.youtube.com/watch?v=P-YYX4CTWIg), [solutions de l'examen 01](https://youtu.be/IZsqAPpbBxM).
- CKS: [lancement de l'examen blanc](https://youtu.be/_GbsBOMaJ9Q), [explication des solutions](https://youtu.be/I8CPwcGbrG8).
- CKAD: [lancement de l'examen blanc](https://youtu.be/7X4Y9QhbTsk), [explication des solutions](https://youtu.be/yQK7Ca8d-yw).
- HR: [vidéo du scénario](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS : réaliser un travail pratique</summary>

1. Choisissez un numéro dans le [catalogue EKS](labs.MD#eks-labs) et lisez la description.
2. Vérifiez `env.hcl`, puis lancez `TASK=101 make run_eks_task` avec le numéro choisi.
3. Trouvez `worker_pc_ip` ou la commande SSH dans la sortie Terraform. Connectez-vous comme `ubuntu` avec la clé ou le mot de passe indiqué.
4. Réalisez les tâches et vérifiez le résultat. Les exercices composites fournissent `check_result`.
5. Consultez la solution liée dans la description ou le catalogue, par exemple la [solution de l'exercice 101](../tasks/eks/labs/101/worker/files/solutions/1_FR.MD).
6. Effectuez le nettoyage préalable de la section de suppression, puis lancez `TASK=101 make delete_eks_task` avec le bon numéro.

</details>

Autres scénarios : [Travaux pratiques Istio / ICA](../tasks/ica/README_FR.MD), [Examen blanc LFCS n° 01](../tasks/lfcs/mock/01), [Ressources d'évaluation KCSA](../tasks/kcsa/README_FR.md), [Examen blanc KCNA n° 01](../tasks/kcna/mock/01/README.MD), [Examen blanc AWS Certified AI Practitioner n° 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
