Русский · [English](architecture.md) · [Español](architecture_ES.md) · [Français](architecture_FR.md) · [Deutsch](architecture_DE.md) · [ქართული](architecture_GE.md) · [繁體中文](architecture_TW.md) · [日本語](architecture_JP.md) · [На главную](../README_RU.MD)

<a id="architecture"></a>

# Как устроен проект

Практические окружения описаны как код. Makefile выбирает сценарий, Terragrunt организует работу Terraform-модулей, а Terraform создаёт необходимые ресурсы AWS и выводит данные для подключения.

В сценариях с самостоятельно управляемым Kubernetes кластеры устанавливаются через **kubeadm**. В лабораторных **Amazon EKS** используется управляемый Kubernetes в AWS. В зависимости от сценария платформа создаёт VPC, подсети, security groups, EC2-инстансы (в том числе Spot), S3 и другие необходимые ресурсы.

<details>
<summary>Структура репозитория</summary>

| Путь | Назначение |
|---|---|
| [Makefile](../Makefile) | Команды запуска, удаления, просмотра окружений и проверки проекта |
| [tasks](../tasks) | Курсы, задания, лабораторные работы и пробные экзамены |
| [tasks/cka](../tasks/cka) | Совместный курс CKA + CKAD, [лабораторные](../tasks/cka/labs) и [пробные экзамены CKA](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [Пробные экзамены CKAD](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | Курс CKS, [лабораторные](../tasks/cks/labs) и [пробные экзамены](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Курс и лабораторные Amazon EKS |
| [tasks/ica](../tasks/ica) | Курс, лабораторные и пробные экзамены Istio / ICA |
| [tasks/kcsa](../tasks/kcsa) | Курс, вопросы и пробные экзамены KCSA |
| [tasks/kcna](../tasks/kcna) | [Мок-экзамены KCNA](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | Практические пробные экзамены LFCS |
| [tasks/hr](../tasks/hr) | HR-сценарии |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [Мок-экзамены AWS Certified AI Practitioner](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | Описания инфраструктуры |
| [terraform/environments](../terraform/environments) | Конфигурация Terragrunt и локальные каталоги окружений |
| [terraform/modules](../terraform/modules) | Переиспользуемые Terraform-модули |
| [docs](../docs) | Каталог лабораторных, инструкции и дополнительные материалы |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | История изменений проекта |

</details>

<details>
<summary>Kubernetes, runtime, ОС и CNI</summary>

Для собственных сценариев можно использовать модуль [k8s_self_managment](../terraform/modules/k8s_self_managment). Он описывает самостоятельно управляемый Kubernetes-кластер; версия Kubernetes, runtime, ОС, AMI и сеть задаются конфигурацией конкретного сценария.

В проекте используются или использовались следующие варианты:

| Компонент | Варианты |
|---|---|
| Kubernetes | Исторические сценарии с версиями 1.21-1.34; версии новых работ смотрите в их `env.hcl` и описании курса |
| Container runtime | `containerd`, `containerd_gvizor`; в старых сценариях также `docker` и `cri-o` |
| ОС узлов самостоятельно управляемых кластеров | Ubuntu 20.04 LTS и 22.04 LTS в зависимости от сценария |
| CNI | Calico и Cilium в зависимости от сценария |

В прежнем описании платформы указывались сочетания Docker с Kubernetes 1.21-1.23, CRI-O с 1.21-1.29, containerd и `containerd_gvizor` с 1.21-1.33, а также исходные значения Kubernetes 1.33 для CKA/CKS и Ubuntu 22.04 для CKS. Это сведения о старых конфигурациях, а не матрица совместимости новых лабораторных. Актуальные параметры выбирайте по исходникам нужной работы; [история релизов Kubernetes](https://kubernetes.io/releases/) доступна на сайте проекта.

</details>
