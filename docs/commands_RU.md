Русский · [English](commands.md) · [Español](commands_ES.md) · [Français](commands_FR.md) · [Deutsch](commands_DE.md) · [ქართული](commands_GE.md) · [繁體中文](commands_TW.md) · [日本語](commands_JP.md) · [На главную](../README_RU.MD)

<a id="commands"></a>

# Команды платформы

Все команды выполняются из корня репозитория. `TASK` - номер выбранной лабораторной или пробного экзамена. Используйте одинаковые `TASK`, `USER_ID` и `ENV_ID` при запуске, просмотре результатов Terraform и удалении одного окружения.

Команды с суффиксом `_clean` очищают локальный каталог соответствующего окружения перед выполнением операции. Они не заменяют удаление облачных ресурсов командой `delete_*`.

<details>
<summary>CKA + CKAD: лабораторные и пробные экзамены CKA</summary>

Комплексные лабораторные совместного курса CKA + CKAD запускаются командами `cka_task`.

| Команда | Действие |
|---|---|
| `TASK=101 make run_cka_task` | Создать [лабораторную CKA + CKAD](labs.MD#cka-labs) № 101 |
| `TASK=101 make delete_cka_task` | Удалить окружение лабораторной |
| `TASK=101 make run_cka_task_clean` | Запустить лабораторную с очисткой локального каталога окружения |
| `TASK=101 make output_cka_task` | Показать выходные значения Terraform |
| `TASK=01 make run_cka_mock` | Создать [пробный экзамен CKA № 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | Удалить окружение пробного экзамена |
| `TASK=01 make run_cka_mock_clean` | Запустить экзамен с очисткой локального каталога окружения |
| `TASK=01 make output_cka_mock` | Показать выходные значения Terraform |

</details>

<details>
<summary>CKAD: пробные экзамены</summary>

| Команда | Действие |
|---|---|
| `TASK=01 make run_ckad_mock` | Создать [пробный экзамен CKAD № 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | Удалить окружение пробного экзамена |
| `TASK=01 make run_ckad_mock_clean` | Запустить экзамен с очисткой локального каталога окружения |
| `TASK=01 make output_ckad_mock` | Показать выходные значения Terraform |

</details>

<details>
<summary>CKS: лабораторные и пробные экзамены</summary>

| Команда | Действие |
|---|---|
| `TASK=101 make run_cks_task` | Создать [лабораторную CKS](labs.MD#cks-labs) № 101 |
| `TASK=101 make delete_cks_task` | Удалить окружение лабораторной |
| `TASK=101 make run_cks_task_clean` | Запустить лабораторную с очисткой локального каталога окружения |
| `TASK=101 make output_cks_task` | Показать выходные значения Terraform |
| `TASK=01 make run_cks_mock` | Создать [пробный экзамен CKS № 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | Удалить окружение пробного экзамена |
| `TASK=01 make run_cks_mock_clean` | Запустить экзамен с очисткой локального каталога окружения |
| `TASK=01 make output_cks_mock` | Показать выходные значения Terraform |

</details>

<details>
<summary>Istio / ICA: лабораторные и пробные экзамены</summary>

| Команда | Действие |
|---|---|
| `TASK=01 make run_ica_task` | Создать [лабораторную ICA](labs.MD#ica-labs-istio-certified-associate) № 01 |
| `TASK=01 make delete_ica_task` | Удалить окружение лабораторной |
| `TASK=01 make run_ica_task_clean` | Запустить лабораторную с очисткой локального каталога окружения |
| `TASK=01 make output_ica_task` | Показать выходные значения Terraform |
| `TASK=01 make run_ica_mock` | Создать [пробный экзамен ICA № 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | Удалить окружение пробного экзамена |
| `TASK=01 make run_ica_mock_clean` | Запустить экзамен с очисткой локального каталога окружения |
| `TASK=01 make output_ica_mock` | Показать выходные значения Terraform |

</details>

<details>
<summary>Amazon EKS: лабораторные</summary>

| Команда | Действие |
|---|---|
| `TASK=101 make run_eks_task` | Создать [лабораторную EKS](labs.MD#eks-labs) № 101 |
| `TASK=101 make delete_eks_task` | Удалить окружение лабораторной |
| `TASK=101 make run_eks_task_clean` | Запустить лабораторную с очисткой локального каталога окружения |
| `TASK=101 make output_eks_task` | Показать выходные значения Terraform |

Перед удалением EKS-окружения выполните предварительную очистку, указанную в описании лабораторной. Некоторые ресурсы создаются Kubernetes-контроллерами или вручную и требуют удаления до запуска Terraform destroy.

</details>

<details>
<summary>LFCS: пробные экзамены</summary>

| Команда | Действие |
|---|---|
| `TASK=01 make run_lfcs_mock` | Создать [пробный экзамен LFCS № 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | Удалить окружение пробного экзамена |
| `TASK=01 make run_lfcs_mock_clean` | Запустить экзамен с очисткой локального каталога окружения |
| `TASK=01 make delete_lfcs_mock_clean` | Удалить экзамен с предварительной очисткой локального каталога окружения |
| `TASK=01 make output_lfcs_mock` | Показать выходные значения Terraform |

</details>

<details>
<summary>HR: практические сценарии</summary>

| Команда | Действие |
|---|---|
| `TASK=01 make run_hr_mock` | Создать [HR-сценарий № 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | Удалить окружение сценария |
| `TASK=01 make run_hr_mock_clean` | Запустить сценарий с очисткой локального каталога окружения |
| `TASK=01 make output_hr_mock` | Показать выходные значения Terraform |

</details>

<details>
<summary>KCNA, KCSA и AWS Certified AI Practitioner: тестовые материалы</summary>

Откройте соответствующий раздел и следуйте его инструкциям:

- [KCNA: мок-экзамен № 01](../tasks/kcna/mock/01/README.MD).
- [KCSA: курс, вопросы и пробные экзамены](../tasks/kcsa/README_RU.md).
- [AWS Certified AI Practitioner: мок-экзамен № 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>Разработка и проверки</summary>

`make lint` - запустить настроенные проверки проекта через pre-commit.

</details>
