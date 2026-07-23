# Lab 122 — Дриллы: планирование подов

## Описание

Тренажёр скорости по домену Workloads & Scheduling: короткие независимые задания на
nodeSelector, nodeAffinity, requests/limits, PriorityClass и taints/tolerations.
Кластер одноузловой — labels (метки) и taints вешаются на единственную ноду.

Задания оформлены в экзаменационном стиле с автоматической проверкой командой
`check_result`. Цель дрилла — не разбор теории, а скорость и мышечная память: «набить
руку» на управлении планированием Pod'ов и уложиться в темп экзамена.

> **Важно:** задание 6 (taint) выполняйте последним — taint `NoSchedule` мешает
> планировать Pod'ы без toleration.

## Цель

Закрепить материал глав курса:

- [Глава 12. Планирование подов: nodeName, nodeSelector, affinity](../../course/12/ru.md) — привязка Pod'ов к нодам через nodeSelector и nodeAffinity
- [Глава 13. Taints и tolerations](../../course/13/ru.md) — отталкивание Pod'ов taints и их допуск tolerations
- [Глава 14. Ресурсы: requests, limits, LimitRange, ResourceQuota](../../course/14/ru.md) — запросы и лимиты CPU/памяти на контейнер
- [Глава 15. Static Pods, PriorityClass, несколько планировщиков](../../course/15/ru.md) — приоритет Pod'ов через PriorityClass

## Что мы делаем и зачем

| Блок | Задачи | Навык |
|------|--------|-------|
| **Привязка к ноде** | label `disk=ssd`, Pod `sel` (nodeSelector), Pod `aff` (nodeAffinity) | направлять Pod'ы на нужные ноды (глава 12) |
| **Ресурсы и приоритет** | Pod `res` (requests/limits), PriorityClass `high-prio` + Pod `prio` | requests/limits и приоритет планирования (главы 14, 15) |
| **Taints и tolerations** | taint `dedicated=special:NoSchedule` + Pod `tol` | изоляция ноды taint'ом и допуск через toleration (глава 13) |

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt и состоит из:

| Компонент  | Описание                                                                        |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` с публичными подсетями                                       |
| `ssh-keys` | SSH-ключи для доступа к нодам                                                    |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, одноузловой; namespace `sched` создан заранее |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                                     |

Инстансы: `t3.medium` (master) Ubuntu `22.04`. Кластер одноузловой — master
«разтейнчен» (снят taint `control-plane`), поэтому поды планируются прямо на него.

## Развёртывание

```bash
TASK=122 make run_cka_task
```

После создания подключитесь к рабочей машине (worker) по SSH и выполняйте задания
оттуда. `kubectl` уже настроен на контекст `cluster1-admin@cluster1`.

Полезные команды на рабочей машине:

```bash
time_left       # сколько осталось времени
check_result    # проверить решение
```

## Задания

Имя единственной ноды удобно получить в переменную:
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`.

---
|        **1**        | **Метка на ноду**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Повесьте на ноду label (метку) `disk=ssd` (`kubectl label node $NODE disk=ssd`). |
| Критерии приёмки    | - У ноды есть label `disk=ssd`. |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте Pod `sel` (ns `sched`, образ `viktoruj/ping_pong:latest`) с `nodeSelector: disk=ssd` — Pod планируется только на ноду с этим label. |
| Критерии приёмки    | - Pod `sel` в состоянии `Running`, `nodeSelector` `disk=ssd`. |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте Pod `aff` (ns `sched`, образ `viktoruj/ping_pong:latest`) с required nodeAffinity: ключ `disk`, оператор `In`, значения `[ssd]` (`requiredDuringSchedulingIgnoredDuringExecution`). |
| Критерии приёмки    | - Pod `aff` в состоянии `Running`, nodeAffinity задан. |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте Pod `res` (ns `sched`, образ `viktoruj/ping_pong:latest`) с requests `cpu=100m`, `memory=64Mi` и limits `cpu=200m`, `memory=128Mi` на контейнере. |
| Критерии приёмки    | - Pod `res` в состоянии `Running`, limits `cpu` и `memory` заданы. |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте PriorityClass `high-prio` со значением `value: 1000` (`kubectl create priorityclass high-prio --value=1000`), затем Pod `prio` (ns `sched`, образ `viktoruj/ping_pong:latest`) с `priorityClassName: high-prio`. |
| Критерии приёмки    | - PriorityClass `high-prio` `value=1000`;<br/>- Pod `prio` в состоянии `Running` с `priorityClassName: high-prio`. |
---
|        **6**        | **Taint + toleration** (последним)                          |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Повесьте на ноду taint `dedicated=special:NoSchedule` (`kubectl taint node $NODE dedicated=special:NoSchedule`), затем создайте Pod `tol` (ns `sched`, образ `viktoruj/ping_pong:latest`) с соответствующим toleration (`key=dedicated`, `operator=Equal`, `value=special`, `effect=NoSchedule`). **Делайте это задание последним** — taint помешает планировать остальные Pod'ы. |
| Критерии приёмки    | - Нода имеет taint `dedicated=special:NoSchedule`;<br/>- Pod `tol` в состоянии `Running`. |
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

Домен Workloads & Scheduling (15% CKA) — повторы nodeSelector/affinity, ресурсов,
PriorityClass, taints/tolerations.

## Удаление кластера и ресурсов

```bash
TASK=122 make delete_cka_task
```
