[Русский](commands_RU.md) · English · [Español](commands_ES.md) · [Français](commands_FR.md) · [Deutsch](commands_DE.md) · [ქართული](commands_GE.md) · [繁體中文](commands_TW.md) · [日本語](commands_JP.md) · [Home](../README.MD)

<a id="commands"></a>

# Command reference

Run all commands from the repository root. `TASK` is the selected lab or mock exam number. Use the same `TASK`, `USER_ID`, and `ENV_ID` when launching, viewing Terraform outputs, and deleting an environment.

Commands ending in `_clean` clear the local directory of the corresponding environment before performing the operation. They do not replace deleting cloud resources with `delete_*`.

<details>
<summary>CKA + CKAD: labs and CKA mock exams</summary>

Composite labs for the joint CKA + CKAD course use the `cka_task` commands.

| Command | Action |
|---|---|
| `TASK=101 make run_cka_task` | Create [lab CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | Delete the lab environment |
| `TASK=101 make run_cka_task_clean` | Launch the lab after clearing the local environment directory |
| `TASK=101 make output_cka_task` | Show Terraform outputs |
| `TASK=01 make run_cka_mock` | Create [mock exam CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | Delete the mock exam environment |
| `TASK=01 make run_cka_mock_clean` | Launch the exam after clearing the local environment directory |
| `TASK=01 make output_cka_mock` | Show Terraform outputs |

</details>

<details>
<summary>CKAD: mock exams</summary>

| Command | Action |
|---|---|
| `TASK=01 make run_ckad_mock` | Create [mock exam CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | Delete the mock exam environment |
| `TASK=01 make run_ckad_mock_clean` | Launch the exam after clearing the local environment directory |
| `TASK=01 make output_ckad_mock` | Show Terraform outputs |

</details>

<details>
<summary>CKS: labs and mock exams</summary>

| Command | Action |
|---|---|
| `TASK=101 make run_cks_task` | Create [lab CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | Delete the lab environment |
| `TASK=101 make run_cks_task_clean` | Launch the lab after clearing the local environment directory |
| `TASK=101 make output_cks_task` | Show Terraform outputs |
| `TASK=01 make run_cks_mock` | Create [mock exam CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | Delete the mock exam environment |
| `TASK=01 make run_cks_mock_clean` | Launch the exam after clearing the local environment directory |
| `TASK=01 make output_cks_mock` | Show Terraform outputs |

</details>

<details>
<summary>Istio / ICA: labs and mock exams</summary>

| Command | Action |
|---|---|
| `TASK=01 make run_ica_task` | Create [lab ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | Delete the lab environment |
| `TASK=01 make run_ica_task_clean` | Launch the lab after clearing the local environment directory |
| `TASK=01 make output_ica_task` | Show Terraform outputs |
| `TASK=01 make run_ica_mock` | Create [mock exam ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | Delete the mock exam environment |
| `TASK=01 make run_ica_mock_clean` | Launch the exam after clearing the local environment directory |
| `TASK=01 make output_ica_mock` | Show Terraform outputs |

</details>

<details>
<summary>Amazon EKS: labs</summary>

| Command | Action |
|---|---|
| `TASK=101 make run_eks_task` | Create [lab EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | Delete the lab environment |
| `TASK=101 make run_eks_task_clean` | Launch the lab after clearing the local environment directory |
| `TASK=101 make output_eks_task` | Show Terraform outputs |

Before deleting an EKS environment, perform the preliminary cleanup described in the lab. Some resources are created by Kubernetes controllers or manually and must be deleted before running Terraform destroy.

</details>

<details>
<summary>LFCS: mock exams</summary>

| Command | Action |
|---|---|
| `TASK=01 make run_lfcs_mock` | Create [mock exam LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | Delete the mock exam environment |
| `TASK=01 make run_lfcs_mock_clean` | Launch the exam after clearing the local environment directory |
| `TASK=01 make delete_lfcs_mock_clean` | Delete the exam after clearing the local environment directory |
| `TASK=01 make output_lfcs_mock` | Show Terraform outputs |

</details>

<details>
<summary>HR: practical scenarios</summary>

| Command | Action |
|---|---|
| `TASK=01 make run_hr_mock` | Create [HR scenario 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | Delete the scenario environment |
| `TASK=01 make run_hr_mock_clean` | Launch the scenario after clearing the local environment directory |
| `TASK=01 make output_hr_mock` | Show Terraform outputs |

</details>

<details>
<summary>KCNA, KCSA, and AWS Certified AI Practitioner: test materials</summary>

Open the appropriate section and follow its instructions:

- [KCNA: mock exam 01](../tasks/kcna/mock/01/README.MD).
- [KCSA: course, questions, and mock exams](../tasks/kcsa/README.md).
- [AWS Certified AI Practitioner: mock exam 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>Development and checks</summary>

`make lint` - run the configured project checks through pre-commit.

</details>
