# Лаба 104 — Укрепление доступа к Kubernetes API: RBAC, ServiceAccount и anonymous-auth

## Цель

В этой CKS-лабе вы ограничите доступ к Kubernetes API по принципу наименьших
привилегий. Практика охватывает минимальный namespaced RBAC, современные
короткоживущие токены ServiceAccount, Pod без API-токена, удаление устаревших
избыточных разрешений и отключение анонимного доступа к API server.

Работайте только с объектами, указанными в заданиях. Namespace `security-104` и
намеренно опасная связка `legacy-operator-admin` уже подготовлены стартовым скриптом.
Это учебная конфигурация, а не пример для production.

## Threat model

Предположим, что атакующий уже выполняет код в Pod и пытается использовать identity workload либо отсутствие authentication для движения к Kubernetes API. В таком случае важен не только начальный доступ, но и blast radius после compromise.

Задание 1 закрывает излишний RBAC scope, задание 2 — долгоживущий token, а задание 3 — ненужный API-доступ из Pod. Это уменьшает возможности использовать identity workload после compromise.

Задание 4 устраняет wildcard cluster-wide права, а задание 5 — anonymous access. Каждый из этих путей по отдельности может расширить blast radius до Kubernetes API.

ATT&CK T1528 (Steal Application Access Token) и T1613 дают контекст этому сценарию: задания не моделируют отдельную атаку, а ограничивают последствия уже скомпрометированного workload.

## Инфраструктура

Окружение разворачивается через Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями |
| `ssh-keys` | ключи для доступа к нодам |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd и **Calico** |
| `worker` | рабочая машина с настроенным `kubectl` и `check_result` |

Control-plane разрешает запуск обычных Pod, поэтому отдельный worker-узел не нужен.
Для задания 5 потребуется SSH-доступ к control-plane: именно там расположен манифест
static Pod API server.

## Развёртывание

```bash
TASK=104 make run_cks_task
```

Подключитесь по SSH к рабочей машине. Контекст `cluster1-admin@cluster1` уже настроен.

```bash
time_left
check_result
```

## Задания

---
| **1** | **Минимальный RBAC для чтения Pod** |
| :---: | :--- |
| Что делаем | В namespace `security-104` создайте ServiceAccount `auditor`, Role `pod-observer` и RoleBinding `auditor-pod-observer`. Role должна разрешать **только** `get`, `list`, `watch` ресурса `pods` core API. Свяжите её только с ServiceAccount `auditor`. |
| Критерии приёмки | Role содержит ровно одно правило для `pods` с глаголами `get`, `list`, `watch`; RoleBinding ссылается на эту Role и ServiceAccount `auditor`; от имени `auditor` нельзя удалять `secrets`. |

---
| **2** | **Короткоживущий projected ServiceAccount token** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `api-client` и Pod `token-client` в `security-104`. Не используйте legacy Secret-токен. Отключите обычное автомонтирование токена, а нужный токен смонтируйте через projected volume в `/var/run/secrets/tokens/api-token` с `path: api-token` и `expirationSeconds: 3600` (или меньше). **Не задавайте `audience`**, чтобы kubelet запросил identifier API server по умолчанию. Если приложению необходима отдельная audience, сначала сверьте её с `--api-audiences` (либо default из `--service-account-issuer`) на API server и только затем задавайте явно. |
| Критерии приёмки | Pod использует `api-client`, имеет `automountServiceAccountToken: false`, а projected `serviceAccountToken` без жёстко заданной audience, с указанными path и временем жизни не более часа присутствует в спецификации. TokenReview, выполненный от admin-контекста для смонтированного токена, возвращает `authenticated: true` и имя `system:serviceaccount:security-104:api-client`; отдельная RBAC-проверка подтверждает, что этот ServiceAccount не может удалять `secrets`. |

---
| **3** | **Pod без токена Kubernetes API** |
| :---: | :--- |
| Что делаем | Создайте ServiceAccount `no-token-sa` с `automountServiceAccountToken: false` и Pod `no-token` в `security-104` с этим ServiceAccount. На самом Pod также явно установите `automountServiceAccountToken: false`. Используйте любой безопасный долгоживущий образ, например `busybox:1.36` с `sleep 3600`. |
| Критерии приёмки | У ServiceAccount и Pod отключено автомонтирование; Pod использует `no-token-sa`; в его спецификации нет автоматически добавленного тома токена ServiceAccount. |

---
| **4** | **Удалить избыточные cluster-wide права** |
| :---: | :--- |
| Что делаем | В кластере намеренно оставлены ClusterRole `legacy-operator-admin` с wildcard-правами и ClusterRoleBinding с тем же именем для ServiceAccount `legacy-operator` из `security-104`. Удалите **оба** объекта. Не заменяйте wildcard-доступ на другой широкий ClusterRole. |
| Критерии приёмки | `legacy-operator-admin` не существует ни как ClusterRole, ни как ClusterRoleBinding; ServiceAccount `legacy-operator` больше не может читать `secrets` в `security-104`. |

---
| **5** | **Отключить anonymous access к API server** |
| :---: | :--- |
| Что делаем | На control-plane отредактируйте `/etc/kubernetes/manifests/kube-apiserver.yaml`: аргумент API server должен быть `--anonymous-auth=false`. Kubelet перезапустит static Pod автоматически. Дождитесь готовности API server и убедитесь, что запрос `curl -k https://<api-server>/version` без сертификата и bearer token получает `401`. |
| Критерии приёмки | Команда static Pod API server содержит `--anonymous-auth=false`; неаутентифицированный запрос к `/version` возвращает HTTP `401`. |

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и пять независимых заданий. После изменения API server последний
тест может кратко ждать перезапуска static Pod.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=104 make delete_cks_task
```
