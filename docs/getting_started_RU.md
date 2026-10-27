Русский · [English](getting_started.md) · [Español](getting_started_ES.md) · [Français](getting_started_FR.md) · [Deutsch](getting_started_DE.md) · [ქართული](getting_started_GE.md) · [繁體中文](getting_started_TW.md) · [日本語](getting_started_JP.md) · [На главную](../README_RU.MD)

<a id="quick-start"></a>

# Быстрый старт

Для чтения курсов достаточно открыть материалы в репозитории. Для запуска практических окружений понадобятся AWS и инструменты платформы. Создаваемые облачные ресурсы оплачиваются в вашем AWS-аккаунте; после работы удаляйте окружение по инструкции сценария.

## 1. Подготовьте инструменты

Можно использовать готовый Docker-образ с зависимостями:

```bash
sudo docker run -it viktoruj/runner
```

[Инструкция по запуску через Docker](run_from_docker_RU.MD) · [Видеоинструкция](https://youtu.be/Xh6sWzafBmw)

[![Запуск платформы через Docker](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "Запуск платформы через Docker")

<details>
<summary>Требования при локальной установке</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- [Профиль AWS](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) или другой настроенный способ аутентификации.
- [IAM-пользователь](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html) с [ключом доступа](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) либо [IAM-роль](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) с правами на создание и удаление ресурсов сценария. В исходной конфигурации предполагаются широкие права на VPC, EC2, IAM и EKS; подробнее о [политиках доступа AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).

Это исходные минимальные версии из документации платформы. Дополнительные требования к инструментам и провайдерам смотрите в выбранном сценарии и его Terraform-конфигурации.

</details>

## 2. Получите репозиторий и настройте AWS

Следующие команды выполняйте в Docker-контейнере либо на машине с установленными инструментами:

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

Настройте доступ к AWS. В [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl) укажите своё значение `backend_bucket`; при необходимости измените `region` и `backend_region`. Проверьте регион и параметры выбранного сценария в его `env.hcl`. Подробный порядок настройки приведён в [инструкции](run_from_docker_RU.MD).

## 3. Выберите и запустите работу

Пример для первой комплексной лабораторной CKA + CKAD:

```bash
TASK=101 make run_cka_task
```

Откройте [описание лабораторной 101](../tasks/cka/labs/101/README_RU.MD), подключитесь к окружению по данным из вывода Terraform и выполните задания.

## 4. Удалите окружение

После выполнения работы следуйте разделу удаления в её описании, затем выполните:

```bash
TASK=101 make delete_cka_task
```

Для другой работы подставьте её номер и команду соответствующего направления из [справочника команд](commands_RU.md).
