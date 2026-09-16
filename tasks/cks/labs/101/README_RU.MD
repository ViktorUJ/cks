# Lab 101 - NetworkPolicy: default-deny, изоляция и EC2 IMDS

## Описание

`NetworkPolicy` работает как allow-list: после default-deny необходимые потоки возвращаются только явными правилами. Принудительное применение правил обеспечивает Calico. Worker этой лабораторной работы - EC2 instance, управляемый Terraform; его Instance Metadata Service (IMDS) доступен по `http://169.254.169.254/`. Terraform явно включает HTTP endpoint, оставляет IMDSv1 GET допустимым для безопасного probe и устанавливает response hop limit `2`, чтобы до default-deny обычный Pod мог подтвердить сетевую достижимость IMDS.

Лабораторная работа проверяет только сетевую достижимость IMDS endpoint без чтения metadata или credentials. Любой фактически полученный HTTP status `1xx–5xx` означает, что TCP/HTTP путь до IMDS существует. `HTTPCODE:000` вместе с transport error/timeout означает отсутствие HTTP-ответа. Конкретный HTTP status зависит от EC2 metadata options: если token usage `required`, GET без валидного IMDSv2 token получает `401`; если IMDSv1 разрешён, tokenless GET считается IMDSv1-запросом и может получить обычный HTTP response.

## Развёртывание

На управляющей машине запустите окружение:

```bash
TASK=101 make run_cks_task
```

После успешного развёртывания Terraform выведет SSH-команду для подключения к worker. Она будет в формате:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Например:

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

Для подключения используйте только адрес из команды:

```bash
ssh ubuntu@<IP>
```

Когда SSH запросит пароль, введите значение, показанное Terraform после `password=`.

**Для runtime-проверок** используйте временный диагностический Pod с теми же labels, что у проверяемой identity. Для HTTP-проверок нужен образ с curl (`curlimages/curl:8.11.1`); для DNS - образ с nslookup (`busybox`). После проверки удаляйте временные Pod'ы и временные policy.

Работайте на worker. Перед началом убедитесь, что namespaces чистые (на всякий случай):

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
| Что делаем | Namespace `cks-101`; Deployments `frontend` и `backend` с `replicas: 1`, без `hostNetwork`, одинаковым `viktoruj/ping_pong@sha256:<64hex>`; Service `backend` TCP/8080.<br/><br/>**Как получить актуальный digest:**<br/>1. Временно запустите Pod из образа `viktoruj/ping_pong:latest`;<br/>2. Дождитесь pull и Ready;<br/>3. Выполните ``kubectl get pod <pod_name> -o jsonpath='{.status.containerStatuses[0].imageID}'`` и извлеките `sha256:<64hex>`;<br/>4. Удалите временный Pod;<br/>5. Используйте полученный digest для обоих Deployment (`viktoruj/ping_pong@sha256:<64hex>`). |
| Критерии приёмки | Обе replicas Ready, image references одинаковы, Service имеет endpoint. |
| Проверка | Выполните ``kubectl -n cks-101 get deploy,svc,endpoints`` и убедитесь, что:<br/>• Обе deployment ready (1/1 ready)<br/>• Service backend имеет endpoint с IP-адресом<br/><br/>Для проверки одинакового образа с digest выполните:<br/>``kubectl -n cks-101 get pods -l 'app in (frontend,backend)' -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}'``<br/>Убедитесь, что оба Pod используют одинаковый образ вида `viktoruj/ping_pong@sha256:<64hex>`. |

---
| **2** | **Baseline, default-deny и повторный probe** |
| :---: | :--- |
| Что делаем | Создайте namespace `imds-control` и запустите в нём временный Pod с curl (`curlimages/curl:8.11.1`) для baseline probe IMDS. Создайте временный Pod с label=app=frontend в namespace cks-101 для измерения baseline frontend → backend и frontend → IMDS. **Сохраните baseline значения** CURL_EXIT и HTTPCODE - они понадобятся для artifact. Затем создайте NetworkPolicy `default-deny` без allow-rules. Подтвердите в `cks-101` `HTTPCODE:000` и curl `7`/`28`, повторите IMDS curl из imds-control. |
| Критерии приёмки | Оба control результата имеют `CURL_EXIT:0` + HTTP `1xx`–`5xx`; probe в `cks-101` после default-deny имеет `HTTPCODE:000` и curl `7`/`28`. HTTP-ответ - достижимость, а не deny. |
| Проверка | 1. Выполните ``kubectl -n cks-101 get networkpolicy default-deny -o yaml`` - убедитесь, что podSelector пустой, policyTypes содержит Ingress и Egress, нет правил в egress и ingress.<br/>2. После default-deny: curl из временного frontend probe к backend должен вернуть `000` и exit code `7` или `28`.<br/>3. После default-deny: curl из imds-control к IMDS должен вернуть HTTP `1xx-5xx` и exit code `0`. |

---
| **3** | **NetworkPolicy для приложения** |
| :---: | :--- |
| Что делаем | Создайте две NetworkPolicy: `allow-frontend-egress-to-backend` (frontend egress к backend:8080 TCP) и `allow-backend-ingress-from-frontend` (backend ingress от frontend). Проверьте: 1) frontend может достичь backend; 2) создайте временный Pod с другим label и временную egress policy к backend - он не должен пройти ingress на backend. |
| Критерии приёмки | Разрешён только frontend → backend:8080; чужая identity заблокирована. |
| Проверка | 1. Выполните ``kubectl -n cks-101 get networkpolicy -o yaml`` - убедитесь, что есть только default-deny и две allow policy (не должно быть дополнительных policy, расширяющих доступ).<br/>2. Выполните curl из frontend probe к backend - должен вернуть HTTP 2xx.<br/>3. Создайте Pod с label=app=foreign, дайте ему временную egress к backend - он будет заблокирован ingress policy backend (нет HTTP ответа), curl вернёт `000` и exit code `7` или `28`. |

---
| **4** | **DNS** |
| :---: | :--- |
| Что делаем | Создайте NetworkPolicy `allow-frontend-dns` с frontend egress только к kube-system/kube-dns, exact UDP/53 и TCP/53 (без endPort). Выполните nslookup из frontend probe для проверки. |
| Критерии приёмки | DNS allow-set ровно UDP/53+TCP/53, без endPort/extra port. |
| Проверка | 1. Выполните ``kubectl -n cks-101 get networkpolicy allow-frontend-dns -o yaml`` - убедитесь, что есть ровно два порта: UDP/53 и TCP/53 (без endPort, без дополнительных портов).<br/>2. Выполните ``kubectl -n cks-101 exec <frontend-pod> -- nslookup kubernetes.default.svc.cluster.local`` - DNS должен разрешить имя. |

---
| **5** | **IMDS evidence** |
| :---: | :--- |
| Что делаем | Выполните IMDS probe из временного frontend Pod (созданного в задании 2) и из Pod в namespace `imds-control`. Используйте сохранённые из задания 2 baseline значения. Сохраните в `/var/work/tests/artifacts/5/metadata.output` данные в точном формате:<br/><br/>```<br/>target=http://169.254.169.254/<br/>imds_cidr=169.254.169.254/32<br/>baseline_CURL_EXIT:<number><br/>baseline_HTTPCODE:<3digits><br/>control_CURL_EXIT:<number><br/>control_HTTPCODE:<3digits><br/>deny_CURL_EXIT:<number><br/>deny_HTTPCODE:<3digits><br/>level=network<br/>``` |
| Критерии приёмки | Baseline и control подтверждают HTTP-достижимость; frontend после policy имеет HTTP `000` плюс curl `7`/`28`. |
| Проверка | 1. Выполните ``cat /var/work/tests/artifacts/5/metadata.output`` и проверьте:<br/>• target = http://169.254.169.254/<br/>• imds_cidr = 169.254.169.254/32<br/>• baseline_CURL_EXIT:0, baseline_HTTPCODE:1xx-5xx (IMDS достижим до default-deny)<br/>• control_CURL_EXIT:0, control_HTTPCODE:1xx-5xx (imds-control всегда достижим)<br/>• deny_CURL_EXIT:7 или 28, deny_HTTPCODE:000 (frontend заблокирован после default-deny)<br/>• level = network |

---
| **6** | **Legacy AND и IMDS except** |
| :---: | :--- |
| Что делаем | Создайте namespace `cks-101-legacy` с Deployment `legacy-client`: replicas=1, без hostNetwork, образ `curlimages/curl:8.11.1`, команда `sleep 3600`. Создайте NetworkPolicy `allow-backend-ingress-from-legacy` в namespace `cks-101`: выбирает backend, содержит один ingress peer с AND selector (namespaceSelector и podSelector в одном элементе `from`), TCP/8080. Создайте NetworkPolicy `allow-legacy-egress` в namespace `cks-101-legacy`: выбирает app=legacy-client, содержит ipBlock cidr=0.0.0.0/0 с единственным except 169.254.169.254/32, без дополнительных allow-rules. Проверьте: 1) IMDS из legacy-client заблокирован; 2) legacy-client может достичь backend; 3) Pod с другим label в том же namespace не может пройти ingress; 4) Pod с label=legacy-client в namespace cks-101 не может пройти ingress. После проверок удалите временные Pod'ы и временные policy. |
| Критерии приёмки | IMDS заблокирован, фактический legacy backend разрешён, неверная label/namespace заблокирована. |
| Проверка | 1. Выполните ``kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml`` - убедитесь, что ipBlock cidr=0.0.0.0/0 с единственным except 169.254.169.254/32.<br/>2. Выполните ``kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml`` - убедитесь, что есть AND selector (namespaceSelector и podSelector в одном элементе from), TCP/8080.<br/>3. Выполните curl из legacy-client к IMDS - должен вернуть `000` и exit code `7` или `28`.<br/>4. Выполните curl из legacy-client к backend - должен вернуть HTTP 2xx.<br/>5. Создайте Pod с label=app=wrong в cks-101-legacy с временной egress к backend - curl должен вернуть `000` и exit code `7` или `28`.<br/>6. Создайте Pod с label=app=legacy-client в cks-101 с временной egress к backend - curl должен вернуть `000` и exit code `7` или `28`. |

---
| **7** | **Наблюдение hostNetwork** |
| :---: | :--- |
| Что делаем | Создайте Pod с образом `curlimages/curl:8.11.1`, label=app=frontend и spec.hostNetwork=true. Выполните из него IMDS probe и сохраните результаты в `/var/work/tests/artifacts/7/hostnetwork-metadata.output` в формате:<br/><br/>```<br/>CURL_EXIT:<number><br/>HTTPCODE:<3digits><br/>```<br/><br/>Создайте comparison файл `/var/work/tests/artifacts/7/comparison.txt` в формате:<br/><br/>```<br/>task5_result=curl_exit=<number> http_code=<3digits><br/>task7_result=curl_exit=<number> http_code=<3digits><br/>... environment-specific ...<br/>``` |
| Критерии приёмки | Числовые значения evidence, согласующееся сравнение, зависит от окружения. |
| Проверка | 1. Проверьте, что Pod hostnetwork-probe имеет spec.hostNetwork=true: ``kubectl -n cks-101 get pod hostnetwork-probe -o jsonpath='{.spec.hostNetwork}'``.<br/>2. Выполните ``cat /var/work/tests/artifacts/7/hostnetwork-metadata.output`` - должны быть CURL_EXIT и HTTPCODE (с двоеточием).<br/>3. Выполните ``cat /var/work/tests/artifacts/7/comparison.txt`` - должны быть task5_result и task7_result с curl_exit и http_code (через =), а также строка содержащая "environment-specific".<br/>Примечание: результат может отличаться от task 5 - это зависит от CNI и конфигурации узла. |

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
