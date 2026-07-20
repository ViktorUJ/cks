# Lab 122 — Дриллы: планирование подов

## Описание

Тренажёр скорости по домену Workloads & Scheduling: короткие независимые задания на
nodeSelector, nodeAffinity, requests/limits, PriorityClass и taints/tolerations.
Кластер одноузловой — метки и тейнты вешаются на единственную ноду.

> **Важно:** задание 6 (taint) выполняйте последним — тейнт `NoSchedule` мешает
> планировать поды без toleration.

## Цель

Закрепить главы курса:

- [Глава 12. Планирование подов: nodeName, nodeSelector, affinity](../../course/12/ru.md)
- [Глава 13. Taints и tolerations](../../course/13/ru.md)
- [Глава 14. Ресурсы: requests, limits, LimitRange, ResourceQuota](../../course/14/ru.md)
- [Глава 15. Static Pods, PriorityClass, несколько планировщиков](../../course/15/ru.md)

## Инфраструктура

| Компонент  | Описание                                                             |
|------------|----------------------------------------------------------------------|
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico, metrics-server, single-node; неймспейс `sched` создан |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                          |

## Развёртывание

```bash
TASK=122 make run_cka_task
```

## Задания

---
|        **1**        | **Метка на ноду**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Повесить на ноду метку `disk=ssd` |
| Критерии приёмки    | - У ноды есть метка `disk=ssd` |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Pod `sel` (ns `sched`) с `nodeSelector: disk=ssd` |
| Критерии приёмки    | - `sel` Running, nodeSelector `disk=ssd` |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Pod `aff` (ns `sched`) с required nodeAffinity `disk in (ssd)` |
| Критерии приёмки    | - `aff` Running, nodeAffinity задан |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Pod `res` (ns `sched`): requests `100m/64Mi`, limits `200m/128Mi` |
| Критерии приёмки    | - `res` Running, limits cpu и memory заданы |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | PriorityClass `high-prio` (value 1000) + Pod `prio` с ним |
| Критерии приёмки    | - `high-prio` value=1000<br>- `prio` Running с `priorityClassName: high-prio` |
---
|        **6**        | **Taint + toleration** (последним)                          |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Тейнт ноды `dedicated=special:NoSchedule` + Pod `tol` с toleration |
| Критерии приёмки    | - Нода имеет тейнт `dedicated=special:NoSchedule`<br>- `tol` Running |
---

## Проверка результата

```bash
check_result
```

## Решение

[worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Покрытие мок-экзаменов

Домен Workloads & Scheduling (15% CKA) — повторы nodeSelector/affinity, ресурсов,
PriorityClass, taints/tolerations.

## Удаление

```bash
TASK=122 make delete_cka_task
```
