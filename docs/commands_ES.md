[Русский](commands_RU.md) · [English](commands.md) · Español · [Français](commands_FR.md) · [Deutsch](commands_DE.md) · [ქართული](commands_GE.md) · [繁體中文](commands_TW.md) · [日本語](commands_JP.md) · [Página principal](../README_ES.MD)

<a id="commands"></a>

# Referencia de comandos

Ejecuta todos los comandos desde la raíz del repositorio. `TASK` es el número del laboratorio o simulacro elegido. Utiliza los mismos `TASK`, `USER_ID` y `ENV_ID` al iniciar el entorno, consultar las salidas de Terraform y eliminarlo.

Los comandos terminados en `_clean` vacían el directorio local del entorno correspondiente antes de realizar la operación. No sustituyen la eliminación de recursos en la nube mediante `delete_*`.

<details>
<summary>CKA + CKAD: laboratorios y simulacros CKA</summary>

Los laboratorios compuestos del curso conjunto CKA + CKAD utilizan los comandos `cka_task`.

| Comando | Acción |
|---|---|
| `TASK=101 make run_cka_task` | Crear [laboratorio CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | Eliminar el entorno del laboratorio |
| `TASK=101 make run_cka_task_clean` | Iniciar el laboratorio tras vaciar el directorio local del entorno |
| `TASK=101 make output_cka_task` | Mostrar las salidas de Terraform |
| `TASK=01 make run_cka_mock` | Crear [simulacro de examen CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | Eliminar el entorno del simulacro |
| `TASK=01 make run_cka_mock_clean` | Iniciar el simulacro tras vaciar el directorio local del entorno |
| `TASK=01 make output_cka_mock` | Mostrar las salidas de Terraform |

</details>

<details>
<summary>CKAD: simulacros de examen</summary>

| Comando | Acción |
|---|---|
| `TASK=01 make run_ckad_mock` | Crear [simulacro de examen CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | Eliminar el entorno del simulacro |
| `TASK=01 make run_ckad_mock_clean` | Iniciar el simulacro tras vaciar el directorio local del entorno |
| `TASK=01 make output_ckad_mock` | Mostrar las salidas de Terraform |

</details>

<details>
<summary>CKS: laboratorios y simulacros</summary>

| Comando | Acción |
|---|---|
| `TASK=101 make run_cks_task` | Crear [laboratorio CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | Eliminar el entorno del laboratorio |
| `TASK=101 make run_cks_task_clean` | Iniciar el laboratorio tras vaciar el directorio local del entorno |
| `TASK=101 make output_cks_task` | Mostrar las salidas de Terraform |
| `TASK=01 make run_cks_mock` | Crear [simulacro de examen CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | Eliminar el entorno del simulacro |
| `TASK=01 make run_cks_mock_clean` | Iniciar el simulacro tras vaciar el directorio local del entorno |
| `TASK=01 make output_cks_mock` | Mostrar las salidas de Terraform |

</details>

<details>
<summary>Istio / ICA: laboratorios y simulacros</summary>

| Comando | Acción |
|---|---|
| `TASK=01 make run_ica_task` | Crear [laboratorio ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | Eliminar el entorno del laboratorio |
| `TASK=01 make run_ica_task_clean` | Iniciar el laboratorio tras vaciar el directorio local del entorno |
| `TASK=01 make output_ica_task` | Mostrar las salidas de Terraform |
| `TASK=01 make run_ica_mock` | Crear [simulacro de examen ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | Eliminar el entorno del simulacro |
| `TASK=01 make run_ica_mock_clean` | Iniciar el simulacro tras vaciar el directorio local del entorno |
| `TASK=01 make output_ica_mock` | Mostrar las salidas de Terraform |

</details>

<details>
<summary>Amazon EKS: laboratorios</summary>

| Comando | Acción |
|---|---|
| `TASK=101 make run_eks_task` | Crear [laboratorio EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | Eliminar el entorno del laboratorio |
| `TASK=101 make run_eks_task_clean` | Iniciar el laboratorio tras vaciar el directorio local del entorno |
| `TASK=101 make output_eks_task` | Mostrar las salidas de Terraform |

Antes de eliminar un entorno EKS, realiza la limpieza previa indicada en el laboratorio. Algunos recursos se crean mediante controladores de Kubernetes o manualmente y deben eliminarse antes de ejecutar Terraform destroy.

</details>

<details>
<summary>LFCS: simulacros de examen</summary>

| Comando | Acción |
|---|---|
| `TASK=01 make run_lfcs_mock` | Crear [simulacro de examen LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | Eliminar el entorno del simulacro |
| `TASK=01 make run_lfcs_mock_clean` | Iniciar el simulacro tras vaciar el directorio local del entorno |
| `TASK=01 make delete_lfcs_mock_clean` | Eliminar el simulacro tras vaciar el directorio local del entorno |
| `TASK=01 make output_lfcs_mock` | Mostrar las salidas de Terraform |

</details>

<details>
<summary>HR: escenarios prácticos</summary>

| Comando | Acción |
|---|---|
| `TASK=01 make run_hr_mock` | Crear [escenario HR 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | Eliminar el entorno del escenario |
| `TASK=01 make run_hr_mock_clean` | Iniciar el escenario tras vaciar el directorio local del entorno |
| `TASK=01 make output_hr_mock` | Mostrar las salidas de Terraform |

</details>

<details>
<summary>KCNA, KCSA y AWS Certified AI Practitioner: materiales de evaluación</summary>

Abre la sección correspondiente y sigue sus instrucciones:

- [KCNA: simulacro n.º 01](../tasks/kcna/mock/01/README.MD).
- [KCSA: curso, preguntas y simulacros](../tasks/kcsa/README_ES.md).
- [AWS Certified AI Practitioner: simulacro n.º 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>Desarrollo y comprobaciones</summary>

`make lint` - ejecutar las comprobaciones configuradas del proyecto mediante pre-commit.

</details>
