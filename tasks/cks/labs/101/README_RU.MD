# Lab 101 — NetworkPolicy: default-deny, изоляция и EC2 IMDS

## Описание

`NetworkPolicy` работает как allow-list: после default-deny необходимые потоки возвращаются только явными правилами. Принудительное применение правил обеспечивает Calico. Worker этой лабораторной работы — EC2 instance, управляемый Terraform; его Instance Metadata Service (IMDS) доступен по `http://169.254.169.254/`. Terraform явно включает HTTP endpoint, оставляет IMDSv1 GET допустимым для безопасного probe и устанавливает response hop limit `2`, чтобы до default-deny обычный Pod мог подтвердить сетевую достижимость IMDS.

Проверка обращается только к корню IMDS и сохраняет лишь HTTP-код и exit code `curl`: она не запрашивает и не печатает metadata или credentials. Любой HTTP-ответ (`1xx`–`5xx`, включая ожидаемый от конфигурации IMDS `401`) — evidence достижимости сети, но не доказательство доступа к credentials.

## Развёртывание

На управляющей машине запустите окружение:

```bash
TASK=101 make run_cks_task
```

Работайте на worker. Перед началом удалите namespaces от предыдущей попытки, включая независимый control namespace: это исключает старые policy и probe из доказательства.

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

Самостоятельно проверяйте каждый этап на своих ресурсах; `check_result` запускайте после выполнения заданий, а эталонное решение открывайте только после собственной попытки или при затруднении.

## Цель

Настроить минимальный ingress/egress allow-list, закрепить image digest, доказать семантику AND selector и точный `ipBlock.except` для IMDS, а затем сравнить обычный Pod с `hostNetwork`, не предполагая заранее универсальный результат.

## Инфраструктура

| Компонент | Назначение |
|---|---|
| `cks-101` | namespace приложения и ваших `NetworkPolicy` |
| `cks-101-legacy` | namespace сценария legacy-клиента |
| `imds-control` | независимый namespace без policy для baseline и повторного control probe |
| worker EC2 | Terraform-managed EC2 instance с IMDS `http://169.254.169.254/` |
| CNI | Calico |

## Задания

---
| **1** | **Приложение** |
| :---: | :--- |
| Что делаем | Namespace `cks-101`; Deployments `frontend` и `backend` с `replicas: 1`, без `hostNetwork`, одинаковым `viktoruj/ping_pong@sha256:<64hex>`; Service `backend` TCP/8080. |
| Критерии приёмки | Обе replicas Ready, image references одинаковы, Service имеет endpoint. |
| Проверка | ``kubectl -n cks-101 get deploy,svc,endpoints``<br/>**Ожидаем:** Одна ready replica каждого Deployment и TCP/8080 endpoint. |

---
| **2** | **Baseline, default-deny и повторный probe** |
| :---: | :--- |
| Что делаем | В чистом `imds-control` без policy выполните baseline curl к `http://169.254.169.254/`; до policy также измерьте frontend → backend и frontend → IMDS в `cks-101`. Создайте NetworkPolicy `default-deny` без allow-rules, подтвердите в `cks-101` `HTTPCODE:000` и curl `7`/`28`, затем повторите IMDS curl в `imds-control`. |
| Критерии приёмки | Оба control результата имеют `CURL_EXIT:0` + HTTP `1xx`–`5xx`; probe в `cks-101` после default-deny имеет `HTTPCODE:000` и curl `7`/`28`. HTTP-ответ — достижимость, а не deny. |
| Проверка | ``kubectl -n cks-101 get networkpolicy default-deny -o yaml``<br/>**Ожидаем:** Пустой selector, Ingress/Egress, нет allow-rules. |

---
| **3** | **Точный поток приложения** |
| :---: | :--- |
| Что делаем | Создайте frontend egress и backend ingress TCP/8080; проверьте frontend allow и foreign deny с временным source egress. |
| Критерии приёмки | Разрешён только frontend → backend:8080; foreign blocked. |
| Проверка | ``kubectl -n cks-101 get networkpolicy -o yaml``<br/>**Ожидаем:** Нет widening allow policy. |

---
| **4** | **DNS** |
| :---: | :--- |
| Что делаем | Создайте frontend DNS egress только к kube-system/kube-dns, exact UDP/53 и TCP/53; выполните nslookup. |
| Критерии приёмки | DNS allow-set ровно UDP/53+TCP/53, без endPort/extra port. |
| Проверка | ``kubectl -n cks-101 get networkpolicy allow-frontend-dns -o yaml``<br/>**Ожидаем:** DNS probe успешен, ports exact. |

---
| **5** | **IMDS evidence** |
| :---: | :--- |
| Что делаем | После сохранённого baseline повторите `http://169.254.169.254/` из frontend и независимого `imds-control`; сохраните artifact с target, `imds_cidr=169.254.169.254/32`, отдельными numeric `baseline_`, `control_` и `deny_` значениями `CURL_EXIT`/`HTTPCODE`, `level=network`. |
| Критерии приёмки | Baseline и control подтверждают HTTP-достижимость; frontend после policy имеет HTTP `000` плюс curl `7`/`28`. |
| Проверка | ``cat /var/work/tests/artifacts/5/metadata.output``<br/>**Ожидаем:** Один target, точный IMDS `/32`, отдельные baseline/control/deny transport evidence. |

---
| **6** | **Legacy AND и IMDS except** |
| :---: | :--- |
| Что делаем | Создайте legacy namespace/client, AND backend ingress и `allow-legacy-egress` с literal `169.254.169.254/32` в `except`; проверьте IMDS deny, actual legacy backend allow и wrong peers deny. |
| Критерии приёмки | IMDS denied, actual legacy backend allowed, wrong label/namespace denied. |
| Проверка | ``kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml``<br/>**Ожидаем:** `0.0.0.0/0` с literal `169.254.169.254/32` в единственном `except` и один AND peer. |

---
| **7** | **Наблюдение hostNetwork** |
| :---: | :--- |
| Что делаем | Создайте hostnetwork-probe и сохраните IMDS probe/artifacts comparison с task 5. |
| Критерии приёмки | Evidence numeric, comparison consistent, environment-specific. |
| Проверка | ``cat /var/work/tests/artifacts/7/comparison.txt``<br/>**Ожидаем:** Task5/task7 values match artifacts; no fixed outcome. |

## Проверка

```bash
check_result
```

Checker создаёт и удаляет собственные `imds-control` namespace и probes: до и после deny в `cks-101` он подтверждает, что реальный IMDS отвечает из независимого namespace без policy. Он не доверяет control-ресурсам от предыдущей попытки и не заменяет самостоятельные baseline/runtime-проверки. Дополнительные policy, расширяющие разрешённые потоки, приводят к ошибке.

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=101 make delete_cks_task
```
