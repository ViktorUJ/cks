# Lab 121 — Дриллы: RBAC

## Описание

Тренажёр скорости по RBAC: короткие независимые задания на ServiceAccount, Role/
RoleBinding, ClusterRole/ClusterRoleBinding и проверку эффективных прав через
`kubectl auth can-i`. Namespace `rbac` создан заранее.

Задания оформлены в экзаменационном стиле с автоматической проверкой командой
`check_result`. Цель дрилла — не разбор теории, а скорость и мышечная память: «набить
руку» на императивном создании RBAC-объектов и уложиться в темп экзамена.

## Цель

Закрепить материал глав курса:

- [Глава 21. ServiceAccount; аутентификация, авторизация, admission](../../course/21/ru.md) — ServiceAccount, цепочка authn/authz/admission
- [Глава 38. RBAC: Role, ClusterRole и binding'и](../../course/38/ru.md) — Role/ClusterRole, RoleBinding/ClusterRoleBinding, проверка прав `auth can-i`

## Что мы делаем и зачем

| Блок | Задачи | Навык |
|------|--------|-------|
| **Namespaced RBAC** | ServiceAccount `app-sa`, Role `pod-reader`, RoleBinding `read-pods` | права в пределах namespace через Role + binding (глава 38) |
| **Cluster-wide RBAC** | ClusterRole `cr-viewer`, ClusterRoleBinding `crb-viewer` | доступ к кластерным ресурсам (nodes) через ClusterRole (глава 38) |
| **Проверка прав** | `kubectl auth can-i` для `app-sa` | быстрая валидация эффективных прав ServiceAccount (глава 21) |

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt и состоит из:

| Компонент  | Описание                                                                        |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` с публичными подсетями                                       |
| `ssh-keys` | SSH-ключи для доступа к нодам                                                    |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, одноузловой; namespace `rbac` создан заранее |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                                     |

Инстансы: `t3.medium` (master) Ubuntu `22.04`. Кластер одноузловой — master
«разтейнчен» (снят taint `control-plane`), поэтому поды планируются прямо на него.

## Развёртывание

```bash
TASK=121 make run_cka_task
```

После создания подключитесь к рабочей машине (worker) по SSH и выполняйте задания
оттуда. `kubectl` уже настроен на контекст `cluster1-admin@cluster1`.

Полезные команды на рабочей машине:

```bash
time_left       # сколько осталось времени
check_result    # проверить решение
```

## Задания

---
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте ServiceAccount `app-sa` в namespace `rbac` (`kubectl -n rbac create serviceaccount app-sa`). |
| Критерии приёмки    | - ServiceAccount `app-sa` существует в namespace `rbac`. |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте Role `pod-reader` в namespace `rbac` с правами `get,list,watch` на ресурс `pods` (`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`). |
| Критерии приёмки    | - Role `pod-reader` даёт `get`/`list`/`watch` на `pods`. |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте RoleBinding `read-pods` в namespace `rbac`, связав Role `pod-reader` с субъектом ServiceAccount `app-sa` (`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`). |
| Критерии приёмки    | - RoleBinding `read-pods` ссылается на Role `pod-reader` и субъект `app-sa`. |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте ClusterRole `cr-viewer` с правами `get,list` на кластерный ресурс `nodes` (`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`). |
| Критерии приёмки    | - ClusterRole `cr-viewer` даёт `get`/`list` на `nodes`. |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте ClusterRoleBinding `crb-viewer`, связав ClusterRole `cr-viewer` с субъектом ServiceAccount `app-sa` из namespace `rbac` (`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`). |
| Критерии приёмки    | - ClusterRoleBinding `crb-viewer` ссылается на ClusterRole `cr-viewer` и субъект `rbac/app-sa`. |
---
|        **6**        | **Проверка прав (auth can-i)**                              |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Проверьте эффективные права `app-sa` через `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa`: `get pods` в `rbac`, `get nodes` и `delete pods` в `rbac`. Убедитесь, что связки выданы корректно. |
| Критерии приёмки    | - `get pods` в namespace `rbac` = `yes`;<br/>- `get nodes` = `yes`;<br/>- `delete pods` в namespace `rbac` = `no`. |
---

## Проверка результата

На рабочей машине запустите автоматическую проверку:

```bash
check_result
```

Скрипт прогонит тесты и покажет, сколько заданий выполнено.

## Решение

Эталонное решение: [worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Покрытие мок-экзаменов

Домен Cluster Architecture (RBAC) для CKA и Application Security для CKAD — повторы
Role/ClusterRole и связок с ServiceAccount.

## Удаление кластера и ресурсов

```bash
TASK=121 make delete_cka_task
```
