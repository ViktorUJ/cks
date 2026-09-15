[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 — NetworkPolicy: default-deny, изоляция и защита metadata

## Описание

`NetworkPolicy` работает как allow-list: после default-deny необходимые потоки нужно вернуть явными правилами. Enforcement выполняет CNI; в этой lab используется Calico. Базовые selectors и NetworkPolicy разобраны в [главе CKA 34](../../../cka/course/34/ru.md).

Лаба изолирует небольшое приложение, оставляет ему только backend и DNS, проверяет защиту metadata и показывает границы переносимости `hostNetwork`.

## Цель

Настроить минимальный ingress/egress allow-list, закрепить образ immutable digest, корректно использовать AND selectors и `ipBlock.except`, а также записать security evidence.

## Что мы создаём и зачем

| Объект | Что это и зачем |
| --- | --- |
| Namespace `cks-101` | Изолированная граница ресурсов и политик lab. |
| Deployments `frontend`, `backend` | Приложения с identity `app=frontend` и `app=backend`. |
| Service `backend` | Стабильный TCP-доступ к backend на `8080`. |
| `default-deny` | Закрывает ingress и egress для всех Pod `cks-101`. |
| Frontend/backend policies | Возвращают только поток frontend → backend:8080. |
| `allow-frontend-dns` | Открывает frontend только DNS к kube-dns/CoreDNS. |
| `cks-101-legacy`, `legacy-client` | Проверяют AND selectors и исключение metadata из broad egress. |
| `hostnetwork-probe` | Фиксирует environment-specific наблюдение для `hostNetwork`. |

## Инфраструктура

| Компонент | Значение |
| --- | --- |
| vpc | `10.101.0.0/16`, две публичные подсети |
| ssh-keys | Доступ к worker по ключу lab-окружения |
| k8s-1 | Kubernetes `v1.36.0`, kubeadm, Calico |
| worker | Настроенные `kubectl` и `check_result` |

## Развёртывание

```bash
TASK=101 make run_cks_task
```

Работайте с worker, где уже настроен `kubectl`.

```bash
time_left
check_result
```

## Задания

| № | Задание |
| :---: | --- |
| **1** | Создайте namespace `cks-101`. Временно запустите resolver Pod из `viktoruj/ping_pong:latest`, дождитесь фактического pull, определите текущий `sha256` digest и удалите resolver. Создайте Deployments `frontend` и `backend` с метками `app=frontend`/`app=backend` и **одним и тем же** `viktoruj/ping_pong@sha256:<64hex>`. Создайте Service `backend`, TCP `8080` → `8080`. **Критерии:** оба Deployment Ready, immutable references совпадают, mutable tag не используется, Service имеет endpoint. |
| **2** | В `cks-101` создайте `NetworkPolicy` `default-deny`: `podSelector: {}`, `policyTypes: [Ingress, Egress]`, без allow-rules. **Критерии:** policy охватывает все Pod и закрывает оба направления. |
| **3** | Создайте `allow-frontend-egress-to-backend` и `allow-backend-ingress-from-frontend`. Первая выбирает `app=frontend` и разрешает только egress к `app=backend`, TCP/8080; вторая выбирает `app=backend` и разрешает только ingress от `app=frontend`, TCP/8080. **Критерии:** frontend identity достигает backend, foreign identity не проходит; selectors и port ограничены указанным потоком. |
| **4** | Создайте `allow-frontend-dns`, выбирающую `app=frontend` и разрешающую только DNS к kube-dns/CoreDNS в `kube-system` по UDP/53 и TCP/53. **Критерии:** DNS lookup из frontend identity успешен, broad egress не добавлен. |
| **5** | Убедитесь, что allow-list не разрешает `169.254.169.254`. Сохраните `/var/work/tests/artifacts/5/metadata.output` с `CURL_EXIT:<n>`, `HTTPCODE:000` и классификацией `level=network`. HTTP `401/403` — HTTP response, а не network deny. **Критерии:** evidence содержит network failure/timeout; дополнительная deny-policy для metadata не нужна. |
| **6** | Создайте `cks-101-legacy` и Deployment `legacy-client` (`curlimages/curl:8.11.1`, `sleep 3600`, `app=legacy-client`) без default-deny namespace. Создайте `allow-backend-ingress-from-legacy` для backend:8080: `namespaceSelector` для `cks-101-legacy` и `podSelector` `app=legacy-client` должны быть в **одном** `from` peer (AND). В legacy namespace создайте `allow-legacy-egress` для `legacy-client`: `0.0.0.0/0` с `except: 169.254.169.254/32`. **Критерии:** target, AND peer, TCP/8080 и except имеют указанную область действия. |
| **7** | Создайте `hostnetwork-probe` в `cks-101` с `hostNetwork: true`, `app=frontend` и образом `curlimages/curl:8.11.1`. Выполните тот же metadata probe, сохраните `/var/work/tests/artifacts/7/hostnetwork-metadata.output` и сравнение с task 5 в `/var/work/tests/artifacts/7/comparison.txt`. **Критерии:** оба фактических результата и явная пометка `environment-specific` записаны; конкретный HTTP outcome не требуется. |

## Проверка результата

```bash
check_result
```

Checker проверит семь заданий.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Покрытие мок-экзаменов

- CKS mock 01 — task 8 `Network policy`;
- CKS mock 02 — task 8 `Network policy`;
- CKS mock 03 — task 8 `Network policy`;
- CKS mock 04 — task 5 `Network policy`.

Lab 101 расширяет базовую mock-тему security-проверками egress, metadata и selector semantics.

## Удаление кластера и ресурсов

```bash
TASK=101 make delete_cks_task
```
