# Lab 120 — Дриллы: сервисы и сеть

## Описание

Тренажёр скорости по домену Services & Networking. Короткие независимые задания на
создание Service'ов (ClusterIP, NodePort, headless), Ingress и NetworkPolicy, плюс блок
на JSONPath.

Задания оформлены в экзаменационном стиле с автоматической проверкой командой
`check_result`. Цель дрилла — не разбор теории, а скорость и мышечная память: «набить
руку» и уложиться в темп экзамена. Файлы-ответы для JSONPath-заданий сохраняются в
`/home/ubuntu/answers/`.

## Цель

Закрепить материал глав курса:

- [Глава 7. Services: ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/ru.md) — типы Service'ов, publish через `expose`, Endpoints
- [Глава 31. Service изнутри, DNS и CoreDNS](../../course/31/ru.md) — headless-Service (`clusterIP: None`), DNS-имена
- [Глава 32. Ingress и Ingress-контроллеры](../../course/32/ru.md) — маршрутизация по хосту и пути на backend-Service
- [Глава 34. NetworkPolicy](../../course/34/ru.md) — default-deny, podSelector, policyTypes

## Что мы делаем и зачем

| Блок | Задачи | Навык |
|------|--------|-------|
| **Service'ы** | Deployment `web`, ClusterIP, NodePort, headless | быстро публиковать нагрузку разными типами Service (главы 7, 31) |
| **Маршрутизация и изоляция** | Ingress `web-ing`, NetworkPolicy `deny-all` | правила Ingress по хосту и default-deny трафика (главы 32, 34) |
| **JSONPath** | nodePort Service `web-np` → в файл | извлечение данных через `-o jsonpath` под таймером (глава 47) |

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt и состоит из:

| Компонент  | Описание                                                             |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` с публичными подсетями                            |
| `ssh-keys` | SSH-ключи для доступа к нодам                                        |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, одноузловой |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                          |

Инстансы: `t3.medium` (master) Ubuntu `22.04`. Кластер одноузловой — master
«разтейнчен» (снят taint `control-plane`), поэтому поды планируются прямо на него.

## Развёртывание

```bash
TASK=120 make run_cka_task
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
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте namespace (пространство имён) `net`, затем в нём Deployment `web` с образом `viktoruj/ping_pong:latest` и 2 репликами (`kubectl create ns net`, `kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`). |
| Критерии приёмки    | - Deployment `web` (ns `net`): 2 готовые реплики. |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Опубликуйте Deployment `web` как Service (сервис) типа ClusterIP с именем `web-svc` на порту 80 (`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`). |
| Критерии приёмки    | - Service `web-svc` (ns `net`): Endpoints не пусты. |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте Service `web-np` типа NodePort для `web` с фиксированным `nodePort: 30080` (`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`). |
| Критерии приёмки    | - Service `web-np`: type `NodePort`, `nodePort` 30080. |
---
|        **4**        | **Headless-Service**                                        |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте headless-Service `web-h` с `clusterIP: None` для Pod'ов `web` (селектор `app=web`). Headless-Service раздаёт DNS-записи прямо на Pod'ы, минуя виртуальный IP. |
| Критерии приёмки    | - Service `web-h`: `clusterIP` = `None`. |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте Ingress `web-ing` в namespace `net`: хост `web.local`, путь `/` направляет на backend-Service `web-svc` порт 80 (`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`). |
| Критерии приёмки    | - Правило хоста `web.local` → backend Service `web-svc`, порт 80. |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Создайте NetworkPolicy `deny-all` в namespace `net` с пустым `podSelector: {}` (применяется ко всем Pod'ам) и `policyTypes: [Ingress]` — политика запрещает весь входящий трафик. |
| Критерии приёмки    | - NetworkPolicy `deny-all`: `policyTypes` содержит `Ingress`, `podSelector` пустой. |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Извлеките `nodePort` Service `web-np` через `-o jsonpath` и сохраните в `/home/ubuntu/answers/nodeport.txt` (путь `{.spec.ports[0].nodePort}`). |
| Критерии приёмки    | - Значение в `nodeport.txt` совпадает с `.spec.ports[0].nodePort` Service `web-np`. |
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

Домен Services & Networking (20% CKA / 20% CKAD) — базовые повторы Service'ов, Ingress,
NetworkPolicy.

## Удаление кластера и ресурсов

```bash
TASK=120 make delete_cka_task
```
