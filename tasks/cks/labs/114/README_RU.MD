[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts, client certificates и API exposure

## Описание

Kubeconfig, который выдаётся студенту, содержит несколько context: рабочий `cluster1-admin@cluster1`
и два заведомо нерабочих (`staging-admin@staging`, `legacy-admin@legacy`), указывающих на несуществующие
API server. `current-context` сразу после логина выставлен на нерабочий `staging-admin@staging` - это
намеренно воспроизводит реальную ситуацию на экзамене, когда кандидату выдают kubeconfig с несколькими
context и нужно самостоятельно понять, какой из них рабочий.

Отдельно в том же kubeconfig есть пользователь `cluster9-admin` с полноценным, реально сгенерированным
самоподписанным client certificate (`client-certificate-data`/`client-key-data`). Этот сертификат не даёт
никаких прав в кластере (apiserver не доверяет его CA) - задание учит читать и разбирать
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

Научиться безопасно работать с kubeconfig, содержащим несколько context, извлекать и проверять
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
|       Что делаем       | • Выполните `kubectl config get-contexts`, определите текущий (нерабочий) `current-context`.<br/>• Найдите реально рабочий context и переключитесь на него: `kubectl config use-context <name>`. |
| Критерии приёмки | • `current-context` == `cluster1-admin@cluster1`.<br/>• Из этого context реально проходит запрос к API server (не просто существует в файле). |
|        Проверка        | `kubectl config current-context`, затем `kubectl get nodes` - должен вернуть реальный список узлов, а не connection error. |

---

|           **2**           | **Client certificate extraction**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Что делаем       | • Извлеките `client-certificate-data` пользователя `cluster9-admin` из kubeconfig, декодируйте base64 и разберите сертификат через `openssl x509`.<br/>• Сохраните результат в `/var/work/tests/artifacts/task2-cert.txt` в формате `KEY=VALUE`, по одному значению на строку: `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| Критерии приёмки | • Все пять значений в артефакте совпадают с тем, что извлекается из исходного bootstrap-сертификата `cluster9-admin`.<br/>• Checker сверяет исходный fingerprint, неизменность сертификата в kubeconfig и все пять полей. |
|        Проверка        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` выводит `sha256 Fingerprint=AA:BB:...` - в артефакт запишите hex без двоеточий (регистр не важен). |

---

|           **3**           | **Baseline: NodePort exposure**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Что делаем       | • Создайте namespace `cks-114`.<br/>• Создайте Deployment `backend` (например `viktoruj/ping_pong:alpine` с `SRV_PORT=80`, label `app=backend`).<br/>• Создайте Service `kubernetes-public` типа `NodePort` на порту 80, с явным `nodePort: 30114`.<br/>• **Не трогайте** `default/kubernetes` Service. |
| Критерии приёмки | • Backend реально достижим и с worker (снаружи кластера) по `<node-internal-ip>:30114`, и внутри кластера по `kubernetes-public.cks-114.svc.cluster.local`.<br/>• `default/kubernetes` остаётся `ClusterIP`.<br/>• Задание 4 потом превращает этот же Service в `ClusterIP`, поэтому к концу лабы NodePort-состояние уже не наблюдается: историческая фаза NodePort подтверждается двумя HTTP 200 пробами (с worker и по DNS из Pod), проверкой backend/EndpointSlice и монитором, сохраняющим UID Service и Deployment.<br/>• Сначала выполните задание 3 полностью и дождитесь файла `/var/lib/cks-lab114-checker/nodeport-phase-seen`, который создаёт монитор после обеих успешных live-проб; только потом выполняйте задание 4. Файл является подтверждением исторической фазы для того же Service/Deployment. |
|        Проверка        | С worker (снаружи кластера): `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>Изнутри кластера (временный Pod с curl): `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. IP узла: `kubectl get nodes -o wide`. |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Что делаем       | • Измените `kubernetes-public` на тип `ClusterIP`.<br/>• Помните: API server не допускает явно заданный `nodePort` при типе `ClusterIP` - надёжнее убрать поле явно (`kubectl edit svc kubernetes-public` и удалите строку `nodePort`, либо JSON patch с `op: remove` для `/spec/ports/0/nodePort`). |
| Критерии приёмки | • Внешний путь `<node-internal-ip>:30114` теперь заблокирован транспортно (connection refused/timeout).<br/>• Внутрикластерный путь по-прежнему работает.<br/>• Backend Pod остаётся Ready. |
|        Проверка        | С worker: `curl -m5 http://<node-internal-ip>:30114/` -> ошибка соединения (не HTTP-код).<br/>Изнутри кластера: `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 как и раньше.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, ни у одного порта нет `nodePort`. |

## Проверка

```bash
check_result
```

Checker проверяет `current-context` и живой запрос к API через него, независимо извлекает и разбирает
сертификат `cluster9-admin`, проверяет его относительно исходного bootstrap fingerprint и сравнивает с вашим артефактом, а также выполняет внутрикластерную HTTP 200 пробу по Service DNS, проверяет Deployment, EndpointSlice и неизменность `default/kubernetes`. Историческую NodePort-фазу подтверждает root-owned монитор с двумя live-пробами до переключения Service; в состоянии ClusterIP checker проверяет live DNS и транспортный отказ NodePort.

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=114 make delete_cks_task
```
