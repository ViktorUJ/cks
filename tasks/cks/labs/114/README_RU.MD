# Lab 114 - Kubeconfig contexts, client certificates и API exposure

## Описание

Kubeconfig, который выдаётся студенту, содержит несколько contexts: рабочий `cluster1-admin@cluster1`
и два заведомо нерабочих (`staging-admin@staging`, `legacy-admin@legacy`), указывающих на несуществующие
API server. `current-context` сразу после логина выставлен на нерабочий `staging-admin@staging` - это
намеренно воспроизводит реальную ситуацию на экзамене, когда кандидату выдают kubeconfig с несколькими
context и нужно самостоятельно понять, какой из них рабочий.

Отдельно в том же kubeconfig есть пользователь `cluster9-admin` с полноценным, реально сгенерированным
самоподписанным client certificate (`client-certificate-data`/`client-key-data`). Этот сертификат не даёт
никаких прав в кластере (его CA никому не доверяет apiserver) - задание учит читать и разбирать
client certificate из kubeconfig, а не аутентифицироваться им.

Также лаба закрывает классический сценарий уменьшения площади атаки Service: сначала вы сознательно
создаёте `NodePort` Service (внешне достижимый на IP control-plane узла), затем сокращаете его до
`ClusterIP`, доказывая эффект вживую в обе стороны.

## Развёртывание

На управляющей машине запустите окружение:

```bash
TASK=114 make run_cks_task
```

После успешного развёртывания Terraform выведет SSH-команду для подключения к worker:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Подключайтесь только по адресу из вывода Terraform:

```bash
ssh ubuntu@<IP>
```

Работайте на worker. Самостоятельно проверяйте каждый этап; `check_result` запускайте после выполнения
заданий, эталонное решение открывайте только после собственной попытки или при затруднении.

## Цель

Научиться безопасно работать с kubeconfig, содержащим несколько контекстов, извлекать и проверять
client certificate без его использования для аутентификации, и осознанно управлять exposure Service
через переключение `NodePort` -> `ClusterIP`.

## Инфраструктура

| Компонент | Назначение |
| --- | --- |
| kubeconfig (`~/.kube/config`) | 4 context: 1 рабочий (`cluster1-admin@cluster1`), 2 decoy (`staging-admin@staging`, `legacy-admin@legacy`), 1 с реальным client certificate (`cluster9-admin@cluster1`) |
| `cks-114` | namespace вашего backend приложения и Service |
| control-plane EC2 | одноузловой kubeadm-кластер, CNI Calico |

## Задания

---

|           **1**           | **Kubeconfig context inventory**                                                                                                                                                                       |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | Выполните `kubectl config get-contexts`, определите текущий (нерабочий) `current-context`, найдите реально рабочий context и переключитесь на него `kubectl config use-context <name>`. |
| Критерии приёмки | `current-context` == `cluster1-admin@cluster1`; из этого context реально проходит запрос к API server (не просто существует в файле). |
|        Проверка        | `kubectl config current-context`, затем `kubectl get nodes` - должен вернуть реальный список узлов, а не connection error. |

---

|           **2**           | **Client certificate extraction**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Что делаем       | Извлеките `client-certificate-data` пользователя `cluster9-admin` из kubeconfig, декодируйте base64 и разберите сертификат через `openssl x509`. Сохраните результат в `/var/work/tests/artifacts/task2-cert.txt` в формате `KEY=VALUE`, по одному значению на строку: `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| Критерии приёмки | Все пять значений в артефакте совпадают с тем, что реально извлекается из текущего kubeconfig (checker извлекает сертификат независимо и сравнивает). |
|        Проверка        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` выводит `sha256 Fingerprint=AA:BB:...` - в артефакт запишите hex без двоеточий (регистр не важен). |

---

|           **3**           | **Baseline: NodePort exposure**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | Создайте namespace `cks-114`, Deployment `backend` (например `viktoruj/ping_pong:alpine` с `SRV_PORT=80`, label `app=backend`), и Service `kubernetes-public` типа `NodePort` на порту 80, с явным `nodePort: 30114`. **Не трогайте** `default/kubernetes` Service. |
| Критерии приёмки | Backend реально достижим и с самого узла по `<node-internal-ip>:30114`, и внутри кластера по `kubernetes-public.cks-114.svc.cluster.local`. `default/kubernetes` остаётся `ClusterIP`. |
|        Проверка        | С worker (снаружи кластера): `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>Изнутри кластера (временный Pod с curl): `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. IP узла: `kubectl get nodes -o wide`. |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Что делаем       | Измените `kubernetes-public` на тип `ClusterIP`. Помните: API server не позволит оставить `nodePort` при типе `ClusterIP` - поле нужно явно убрать (`kubectl edit svc kubernetes-public` и удалите строку `nodePort`, либо `kubectl patch` с `$patch: replace` на массиве `ports`). |
| Критерии приёмки | Внешний путь `<node-internal-ip>:30114` теперь заблокирован транспортно (connection refused/timeout); внутрикластерный путь по-прежнему работает; backend Pod остаётся Ready. |
|        Проверка        | С worker: `curl -m5 http://<node-internal-ip>:30114/` -> ошибка соединения (не HTTP-код).<br/>Изнутри кластера: `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 как и раньше.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, ни у одного порта нет `nodePort`. |

## Проверка

```bash
check_result
```

Checker проверяет `current-context` и живой запрос к API через него, независимо извлекает и разбирает
сертификат `cluster9-admin` и сравнивает с вашим артефактом, а также сам выполняет внешний и
внутрикластерный probe к `kubernetes-public` до и после смены типа Service.

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=114 make delete_cks_task
```
