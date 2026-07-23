# Lab 114 — Troubleshooting: чиним сломанные ресурсы

## Описание

Практическая работа по домену Troubleshooting (30% CKA). В кластере заранее развёрнуты
**сломанные** объекты — ваша задача найти и устранить причины, применяя систематический
маршрут отладки: `get` → `describe` (Events) → `logs` → починка. Задания имитируют
типовые инциденты: ImagePullBackOff, пустые Endpoints из-за неверного селектора и
CreateContainerConfigError из-за отсутствующего ConfigMap.

Все задания оформлены в экзаменационном стиле (как реальные вопросы CKA/CKAD) с
автоматической проверкой командой `check_result`.

## Цель

Закрепить материал глав курса:

- [Глава 44. Отладка сбоев приложений](../../course/44/ru.md) — маршрут `get` → `describe` → `logs`, разбор статусов Pods
- [Глава 45. Отладка control plane и worker-нод](../../course/45/ru.md) — диагностика узлов и системных компонентов
- [Глава 46. Отладка сервисов и сети](../../course/46/ru.md) — связка Service ↔ Endpoints ↔ метки

## Что мы чиним и зачем

В этой лабе мы чиним три независимых инцидента: неисправный образ, разорванную связку
Service и подов, и недостающую конфигурацию. Каждая поломка отрабатывает свой участок
маршрута отладки:

| Поломка | Симптом | Причина | Чему учит |
|---------|---------|---------|-----------|
| **ReplicaSet `rs-app2223`** (namespace `rsapp`) | ImagePullBackOff | неверный тег образа | разбор проблем образа и пересоздание Pods RS (глава 44) |
| **Service `svc-broken`** (namespace `tsvc`) | пустые Endpoints | selector не совпал с label Pods | связка Service ↔ Endpoints ↔ метки (глава 46) |
| **Deployment `capp`** (namespace `cfgapp`) | CreateContainerConfigError | нет нужного ConfigMap | зависимости конфигурации (глава 44) |

Итоговая картина того, что будет развёрнуто:

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints пусты"] -->|"fix selector"| b2["Endpoints есть"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt и состоит из:

| Компонент  | Описание                                                             |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` с публичными подсетями                            |
| `ssh-keys` | SSH-ключи для доступа к нодам                                        |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, одноузловой; при старте разворачивает сломанные объекты |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                          |

Инстансы: `t3.medium` (master) Ubuntu `22.04`. Кластер одноузловой — master
«разтейнчен» (снят taint `control-plane`), поэтому поды планируются прямо на него.

## Развёртывание

```bash
TASK=114 make run_cka_task
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
|        **1**        | **Починить ReplicaSet**                                     |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | В namespace `rsapp` Pods ReplicaSet `rs-app2223` висят в `ImagePullBackOff`. Пройдите маршрут: `kubectl get po -n rsapp` (видим статус), `kubectl describe po -n rsapp <pod>` (в Events — образ `viktoruj/ping_pong:doesnotexist123` не тянется). Исправьте образ в шаблоне RS на рабочий (`viktoruj/ping_pong:latest`) через `kubectl edit rs rs-app2223 -n rsapp`. RS не пересоздаёт Pods при смене шаблона — удалите старые Pods (`kubectl delete po -n rsapp -l <label>`), чтобы RS поднял новые. Добейтесь `2` готовых реплик. |
| Критерии приёмки    | - ReplicaSet `rs-app2223` (namespace `rsapp`): `2` Ready реплики. |
---
|        **2**        | **Починить Service (пустые Endpoints)**                     |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Service `svc-broken` в namespace `tsvc` не отдаёт трафик — у него пустые Endpoints. Диагностика: `kubectl get endpoints svc-broken -n tsvc` (пусто), `kubectl describe svc svc-broken -n tsvc` (selector, например `app=WRONG`), `kubectl get pods -n tsvc --show-labels` (у Pods метка `app=web`). Приведите selector Service к реальным label Pods (`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`) и убедитесь, что Endpoints заполнились. |
| Критерии приёмки    | - Service `svc-broken` (namespace `tsvc`): Endpoints не пусты (≥ 1 адрес). |
---
|        **3**        | **Починить Deployment (нет ConfigMap)**                     |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Deployment `capp` в namespace `cfgapp` падает в `CreateContainerConfigError`. Маршрут: `kubectl get po -n cfgapp` (видим статус), `kubectl describe po -n cfgapp <pod>` (в Events — не найден ConfigMap `missing-config`). Создайте недостающий ConfigMap (`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`) и дождитесь, пока деплой станет готовым (`kubectl rollout status deploy capp -n cfgapp`). |
| Критерии приёмки    | - Deployment `capp` (namespace `cfgapp`): ≥ 1 Ready реплика. |
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

Лаба закрывает задания моков по troubleshooting: CKAD mock 01 (№4 — fix ReplicaSet);
общий навык troubleshooting из CKA mock 01/02 (разбор статусов, Endpoints,
конфигурации) и CKAD mock 02 (№7/№8 — fix ingress/netpol).

## Удаление кластера и ресурсов

```bash
TASK=114 make delete_cka_task
```
