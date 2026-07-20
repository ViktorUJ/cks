# Lab 116 — kubeadm: поднять кластер с нуля (init + join)

## Описание

Даны **две абсолютно чистые ноды** Ubuntu — без container runtime и без пакетов
Kubernetes. Полный сетап вы делаете **сами, с нуля**: ставите и настраиваете
**containerd**, prerequisites (swap, модули ядра, sysctl), пакеты
`kubeadm`/`kubelet`/`kubectl`, затем `kubeadm init` на control plane, устанавливаете
CNI и присоединяете worker через `kubeadm join`.

Отличие от лабы 111 (там обновляют готовый кластер) — здесь нет ни кластера, ни даже
рантайма: вы собираете всё от голой ОС.

## Цель

Закрепить главы курса:

- [Глава 35. Установка кластера с помощью kubeadm](../../course/35/ru.md)
- [Глава 30. Сетевая модель Kubernetes и CNI](../../course/30/ru.md)

## Инфраструктура

| Компонент | Описание                                                                 |
|-----------|--------------------------------------------------------------------------|
| `node-1`  | Чистая нода `cp` — будущий control plane; здесь запускается `check_result` |
| `node-2`  | Чистая нода `node` — будущий worker                                       |

Обе ноды — голый Ubuntu 22.04: **без container runtime и без пакетов Kubernetes**.
Подключение — по SSH к ноде `cp`; с неё доступна `node` командой `ssh node`.

```mermaid
flowchart LR
    a["2 чистые ноды<br>(голый Ubuntu)"] -->|"containerd + kubeadm/kubelet/kubectl"| b["prerequisites"]
    b -->|"kubeadm init на cp"| c["control plane"]
    c -->|"установить CNI"| d["cp Ready"]
    d -->|"kubeadm join на node"| e["2 ноды Ready"]
    style a fill:#f4b400,color:#000
    style b fill:#e8a838,color:#000
    style c fill:#326ce5,color:#fff
    style d fill:#0f9d58,color:#fff
    style e fill:#673ab7,color:#fff
```

## Развёртывание

```bash
TASK=116 make run_cka_task
```

## Задания

Работа ведётся на ноде `cp` (control plane), worker доступен как `ssh node`.

> **Подготовка (на обеих нодах).** Перед `kubeadm init` установите и настройте всё
> сами: swap off, модули ядра (`overlay`, `br_netfilter`), sysctl, **containerd**
> (с `SystemdCgroup=true`), пакеты `kubeadm`/`kubelet`/`kubectl` v1.35. Без этого
> `kubeadm init`/`join` не пройдут preflight. Точные команды — в решении.

---
|        **1**        | **Инициализировать control plane**                          |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | `kubeadm init` на `cp`, настроить kubeconfig |
| Критерии приёмки    | - `/etc/kubernetes/admin.conf` создан<br>- нода `cp` зарегистрирована |
---
|        **2**        | **Установить CNI**                                          |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Установить сетевой плагин (например, Calico) |
| Критерии приёмки    | - нода `cp` в статусе `Ready` |
---
|        **3**        | **Присоединить worker**                                     |
| :-----------------: | :----------------------------------------------------------- |
| Что делаем          | Выполнить `kubeadm join` на ноде `node` |
| Критерии приёмки    | - В кластере 2 ноды, обе `Ready` |
---

## Проверка результата

На ноде `cp`:

```bash
check_result
```

## Решение

[node-1/files/solutions/1.MD](node-1/files/solutions/1.MD)

## Покрытие мок-экзаменов

Домен Cluster Architecture, Installation & Configuration (CKA) — установка кластера
kubeadm с нуля (init + CNI + join).

## Удаление

```bash
TASK=116 make delete_cka_task
```
