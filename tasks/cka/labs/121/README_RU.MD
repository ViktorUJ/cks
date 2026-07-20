# Lab 121 — Дриллы: RBAC

## Описание

Тренажёр скорости по RBAC: короткие независимые задания на ServiceAccount, Role/
RoleBinding, ClusterRole/ClusterRoleBinding и проверку эффективных прав через
`kubectl auth can-i`. Неймспейс `rbac` создан заранее.

## Цель

Закрепить главы курса:

- [Глава 21. ServiceAccount; аутентификация, авторизация, admission](../../course/21/ru.md)
- [Глава 38. RBAC: Role, ClusterRole и binding'и](../../course/38/ru.md)

## Инфраструктура

| Компонент  | Описание                                                             |
|------------|----------------------------------------------------------------------|
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico, metrics-server, single-node; неймспейс `rbac` создан |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                          |

## Развёртывание

```bash
TASK=121 make run_cka_task
```

## Задания

---
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создать ServiceAccount `app-sa` в неймспейсе `rbac` |
| Критерии приёмки    | - SA `app-sa` существует в `rbac` |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Role `pod-reader` в `rbac`: `get,list,watch` для `pods` |
| Критерии приёмки    | - Role `pod-reader` даёт get/list/watch на pods |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | RoleBinding `read-pods`: `pod-reader` → `app-sa` |
| Критерии приёмки    | - `read-pods` ссылается на `pod-reader` и субъект `app-sa` |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | ClusterRole `cr-viewer`: `get,list` для `nodes` |
| Критерии приёмки    | - `cr-viewer` даёт get/list на nodes |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | ClusterRoleBinding `crb-viewer`: `cr-viewer` → `app-sa` (ns `rbac`) |
| Критерии приёмки    | - `crb-viewer` ссылается на `cr-viewer` и субъект `rbac/app-sa` |
---
|        **6**        | **Проверка прав (auth can-i)**                              |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Убедиться в корректности прав `app-sa` |
| Критерии приёмки    | - `get pods` в `rbac` = yes<br>- `get nodes` = yes<br>- `delete pods` в `rbac` = no |
---

## Проверка результата

```bash
check_result
```

## Решение

[worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Покрытие мок-экзаменов

Домен Cluster Architecture (RBAC) для CKA и Application Security для CKAD — повторы
Role/ClusterRole и связок с ServiceAccount.

## Удаление

```bash
TASK=121 make delete_cka_task
```
