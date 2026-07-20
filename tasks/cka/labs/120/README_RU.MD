# Lab 120 — Дриллы: сервисы и сеть

## Описание

Тренажёр скорости по домену Services & Networking. Короткие независимые задания на
создание сервисов (ClusterIP, NodePort, headless), Ingress и NetworkPolicy, плюс
JSONPath. Цель — «набить руку» и уложиться в темп экзамена.

Файлы-ответы для JSONPath сохраняются в `/home/ubuntu/answers/`.

## Цель

Закрепить главы курса:

- [Глава 7. Services: ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/ru.md)
- [Глава 31. Service изнутри, DNS и CoreDNS](../../course/31/ru.md)
- [Глава 32. Ingress и Ingress-контроллеры](../../course/32/ru.md)
- [Глава 34. NetworkPolicy](../../course/34/ru.md)

## Инфраструктура

| Компонент  | Описание                                                             |
|------------|----------------------------------------------------------------------|
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), Calico, metrics-server, single-node   |
| `worker`   | Рабочая машина с `kubectl` и `check_result`                          |

## Развёртывание

```bash
TASK=120 make run_cka_task
```

## Задания

---
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Неймспейс `net` + deployment `web` (`nginx`, 2 реплики) |
| Критерии приёмки    | - `web`: 2 готовые реплики |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Сервис `web-svc` (ClusterIP) для `web` на порту 80 |
| Критерии приёмки    | - `web-svc`: Endpoints не пусты |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Сервис `web-np` типа NodePort с `nodePort: 30080` |
| Критерии приёмки    | - `web-np`: type NodePort, nodePort 30080 |
---
|        **4**        | **Headless-сервис**                                         |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Сервис `web-h` с `clusterIP: None` для `web` |
| Критерии приёмки    | - `web-h`: clusterIP = None |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Ingress `web-ing`: хост `web.local`, путь `/` → `web-svc:80` |
| Критерии приёмки    | - Правило `web.local` → backend `web-svc` порт 80 |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | NetworkPolicy `deny-all` в `net`: пустой podSelector, policyTypes Ingress |
| Критерии приёмки    | - `deny-all`: policyTypes содержит Ingress, podSelector пустой |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Сохранить nodePort сервиса `web-np` в `/home/ubuntu/answers/nodeport.txt` |
| Критерии приёмки    | - Значение совпадает с `.spec.ports[0].nodePort` |
---

## Проверка результата

```bash
check_result
```

## Решение

[worker/files/solutions/1.MD](worker/files/solutions/1.MD)

## Покрытие мок-экзаменов

Домен Services & Networking (20% CKA / 20% CKAD) — базовые повторы сервисов, Ingress,
NetworkPolicy.

## Удаление

```bash
TASK=120 make delete_cka_task
```
