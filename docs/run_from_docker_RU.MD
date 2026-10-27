Русский · [English](run_from_docker.MD) · [Español](run_from_docker_ES.MD) · [Français](run_from_docker_FR.MD) · [Deutsch](run_from_docker_DE.MD) · [ქართული](run_from_docker_GE.MD) · [繁體中文](run_from_docker_TW.MD) · [日本語](run_from_docker_JP.MD) · [На главную](../README_RU.MD)

# Быстрый старт через Docker

Готовый Docker-образ содержит зависимости и утилиты для запуска лабораторных и практических мок-экзаменов. Ниже приведён пример запуска пробного экзамена CKA № 01.

[Видеоинструкция](https://youtu.be/Xh6sWzafBmw)

## 1. Запустите контейнер

На машине с установленным Docker выполните:

```bash
sudo docker run -it viktoruj/runner
```

Все следующие команды выполняйте внутри контейнера.

## 2. Склонируйте репозиторий

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. Настройте хранение состояния Terraform

Откройте [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl). Замените `backend_bucket` на собственное имя S3-бакета для состояния Terraform. При необходимости измените регион инфраструктуры `region` и регион хранения состояния `backend_region`:

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

Также проверьте регион и параметры выбранного сценария в его `env.hcl`.

## 4. Настройте доступ к AWS

Укажите свои ключи доступа вместо значений-заполнителей:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

При использовании временных учётных данных также задайте `AWS_SESSION_TOKEN`.

## 5. Проверьте квоты AWS

Окружению может потребоваться несколько EC2-инстансов. В консоли AWS откройте **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** и проверьте квоты для используемого региона и семейства инстансов:

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** для On-Demand.
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** для Spot.

Эти квоты учитывают vCPU, а не число инстансов. Если доступной квоты недостаточно для выбранного сценария, запросите увеличение. Для других семейств инстансов проверьте соответствующие квоты.

## 6. Запустите сценарий

Для одного окружения:

```bash
TASK=01 make run_cka_mock
```

Для отдельного пользователя или нескольких независимых окружений:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Подключитесь к рабочей машине по данным из вывода Terraform и следуйте [описанию экзамена](../tasks/cka/mock/01/README.MD).

Для другой работы выберите направление и номер в [каталоге лабораторных](labs.MD) или на [главной странице](../README_RU.MD). Команды запуска приведены в [справочнике](commands_RU.md).

## 7. Удалите окружение после работы

Созданные ресурсы оплачиваются в вашем AWS-аккаунте. Выполните предварительную очистку, если она указана в описании сценария, затем удалите окружение.

Для одного окружения:

```bash
TASK=01 make delete_cka_mock
```

Для окружения конкретного пользователя:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

Используйте те же `TASK`, `USER_ID` и `ENV_ID`, с которыми запускали сценарий.

[Подробнее о независимых окружениях и CMDB](environments_RU.md) · [Сценарии использования](usage_scenarios_RU.md)
