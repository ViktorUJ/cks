[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Лаба 103 - CIS/kube-bench, Secure Ingress TLS и проверка бинарников

## Описание

В этой лабораторной работе вы настраиваете одноузловой Kubernetes-кластер как инженер
по безопасности: фиксируете исходную картину CIS Benchmark, исправляете небезопасные
параметры kubelet и kube-apiserver, публикуете Ingress только по TLS, ограничиваете TLS
control plane и подтверждаете целостность установленных Kubernetes-бинарников.

Это не повторение базовой настройки Kubernetes из CKA. Здесь важны места применения
настроек: `KubeletConfiguration`, static Pod manifests control plane, TLS-параметры etcd
и проверяемые артефакты работы. Работайте с узлом control plane через SSH-имя
`control-plane`, подготовленное на worker.

## Цель

Закрепить материал глав курса:

- [Глава 07. CIS Benchmark и kube-bench](../../course/07/ru.md)
- [Глава 08. Secure Ingress с TLS](../../course/08/ru.md)
- [Глава 09. Небезопасные аргументы компонентов и проверка бинарников](../../course/09/ru.md)

## Проверьте себя перед стартом

<details>
<summary>1. Почему запуск kube-bench профилем `cis-1.12` на Kubernetes 1.36 нельзя называть authoritative CIS compliance?</summary>

Пиннутая в этой лабе версия `kube-bench 0.16.0` не содержит профиля для 1.36 вообще - её встроенный version mapping доходит только до `"1.34": "cis-1.12"` (самый новый доступный профиль). Явно указывая `--benchmark cis-1.12` на кластере 1.36, мы принудительно используем ближайший существующий профиль как approximation: часть проверок может быть неактуальна для более новой версии, а новые security-relevant параметры именно для 1.36 этот профиль ещё не покрывает. Это ценный практический сигнал, но не formal compliance statement для версии 1.36.
</details>

<details>
<summary>2. Почему `--tls-cipher-suites` на kube-apiserver не настраивает шифры именно для TLS 1.3?</summary>

В Go (на котором написан kube-apiserver) флаг `--tls-cipher-suites` управляет только cipher suites для TLS версий ≤ 1.2. Для TLS 1.3 Go сам выбирает набор шифров из fixed, hardcoded списка - конфигурировать их через этот флаг нельзя. Поэтому реальную защиту здесь даёт `--tls-min-version=VersionTLS13` (запрещает более старые протоколы целиком), а `--tls-cipher-suites` актуален там, где TLS 1.2 всё ещё допускается (например, etcd в этой лабе).
</details>

<details>
<summary>3. Почему нельзя использовать хеш, вычисленный из самого проверяемого файла, как эталон для SHA-256 verification?</summary>

Если вычислить SHA-256 файла и сравнить с самим собой, проверка всегда пройдёт - даже если файл был подменён на что-то вредоносное. Эталонная checksum должна быть получена из независимого, доверенного источника - официальной страницы релиза Kubernetes, а не из локального файла, который вы проверяете.
</details>

## Что мы создаём и зачем

| Объект или артефакт | Что это | Зачем в этой лабе |
|---|---|---|
| Отчёт `kube-bench` | снимок CIS-проверок control-plane | фиксирует исходные рекомендации и служит основанием для hardening |
| Kubelet configuration | настройки kubelet на ноде | отключает read-only endpoint и anonymous access |
| Static Pod manifest apiserver | декларация kube-apiserver | отключает profiling и задаёт строгий TLS |
| TLS Secret и Ingress | TLS termination для приложения | Ingress завершает TLS для HTTPS на `secure.cks.local`, а ingress-nginx перенаправляет обычные HTTP-запросы на HTTPS через `ssl-redirect` |
| Static Pod manifest etcd | декларация локального etcd | ограничивает допустимые TLS cipher suites |
| SHA-256 артефакт | результат сверки `kubelet` и `kubectl` | подтверждает целостность бинарников относительно хешей релиза |

```mermaid
flowchart TB
    W["worker"] -->|"SSH"| CP["control-plane"]
    W -->|"kubectl"| API["kube-apiserver"]
    CP --> K["kubelet config<br/>readOnlyPort=0<br/>anonymous=false"]
    CP --> A["static Pod kube-apiserver<br/>profiling=false<br/>TLS 1.3"]
    CP --> E["static Pod etcd<br/>cipher suites"]
    API --> I["Ingress + TLS Secret"]
    W --> R["artifacts<br/>kube-bench / TLS / SHA-256"]
    style W fill:#326ce5,color:#fff
    style CP fill:#db4437,color:#fff
    style API fill:#673ab7,color:#fff
    style I fill:#0f9d58,color:#fff
    style R fill:#f4b400,color:#000
```

## Инфраструктура

Окружение разворачивается в AWS (`eu-central-1`) через Terragrunt.

| Компонент | Описание |
|---|---|
| `vpc` | VPC `10.103.0.0/16` с публичными подсетями |
| `ssh-keys` | SSH-ключи для доступа к нодам |
| `k8s-1` | Одноузловой Kubernetes `1.36.0` (kubeadm), containerd и Calico |
| `worker` | Рабочая машина с `kubectl`, `kube-bench`, SSH-доступом и `check_result` |

> **Версия и экзамен.** На 2026-09-06 официальный CKS exam исходит из Kubernetes `v1.35`. Эта лаба использует `1.36.0`, поэтому всё, что относится к этой версии, является forward-looking учебным сценарием, а не заявлением о текущей экзаменационной версии.

Control-plane разтаинчен, поэтому при необходимости на нём можно запустить учебный Pod.
Для заданий 2, 3 и 5 static Pods автоматически пересоздаются kubelet после сохранения
изменённого манифеста или конфигурации. Не удаляйте control-plane Pods вручную.

## Развёртывание

```bash
TASK=103 make run_cks_task
```

Подключитесь к worker по SSH. Контекст уже настроен:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Адрес control-plane можно получить и проверить так:

```bash
kubectl get nodes -o wide
ssh control-plane sudo hostname
```

## Задания

---

| **1** | **Отчёт CIS Benchmark** |
| :---: | :--- |
| Что делаем | На узле `control-plane` прогоните `kube-bench` для Kubernetes `1.36.0`. Сохраните полный evidence в `/var/work/tests/artifacts/1/kube-bench.txt`: `kubernetes_version`, `kube_bench_version`, выбранный `benchmark`, `mapping_status`, затем сам отчёт. Установленный на worker `kube-bench` можно скопировать на узел; проверяться должен именно узел. Встроенный в пиннутый `kube-bench 0.16.0` version mapping заканчивается записью `"1.34": "cis-1.12"` - более новых профилей (включая какой-либо профиль под 1.35/1.36) в этой версии нет вовсе. Поэтому запускайте `--benchmark cis-1.12` явно и помечайте результат на `1.36` как `forced-approximate`, а не authoritative compliance. **Запускайте полный набор targets для `cis-1.12`:** `--targets master,node,controlplane,etcd,policies` - это карта targets, которую kube-bench сопоставляет профилю `cis-1.12`; пропуск любого из них даёт неполный отчёт. |
| Критерии приёмки | - evidence содержит все четыре version/mapping поля;<br/>- `mapping_status=forced-approximate` явно объясняет отсутствие официального покрытия `1.36`;<br/>- в отчёте есть результаты всех разделов `master`, `node`, `controlplane`, `etcd`, `policies` (не только произвольная строка `[PASS]`/`[WARN]`/`[FAIL]`);<br/>- текст не выдаёт результат за authoritative CIS compliance для Kubernetes `1.36`. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Проверка ожидает четыре конкретных строки-маркера в начале файла: `kubernetes_version=v1.36.x`, `kube_bench_version=v0.16.0`, `benchmark=cis-1.12`, `mapping_status=forced-approximate` - это не декоративный текст, а формат, который тест ищет буквально. Запускайте `kube-bench` на самом control-plane node, а не удалённо с worker - у kube-bench нет режима "проверить чужую ноду по SSH". Не забудьте `--targets master,node,controlplane,etcd,policies` - без явного указания targets секции `etcd` и `policies` могут быть пропущены. Также добавляйте `--config-dir /opt/kube-bench/cfg` явно: у бинарника `--config-dir` по умолчанию указывает на `/etc/kube-bench/cfg` (а не на текущую директорию), которого здесь не существует, из-за чего без явного флага `kube-bench` завершается ошибкой `config file is missing 'target_mapping' section`.
</details>

---

| **2** | **Hardening kubelet: read-only port и anonymous auth** |
| :---: | :--- |
| Что делаем | На control-plane исправьте kubelet configuration: установите `readOnlyPort: 0` и `authentication.anonymous.enabled: false` в `/var/lib/kubelet/config.yaml`. Перезапустите kubelet и дождитесь готовности ноды. Не подменяйте проверку текстовым артефактом: настройки должны быть применены на ноде. |
| Критерии приёмки | - в действующей kubelet configuration есть `readOnlyPort: 0`;<br/>- anonymous authentication kubelet отключён;<br/>- нода `Ready` после перезапуска. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

`authentication.anonymous.enabled: false` находится ВЛОЖЕННО, под ключом `authentication.anonymous`, а не как отдельное top-level поле `anonymous: false` - проверьте отступы YAML внимательно. После правки config.yaml нужно перезапустить сам сервис kubelet (`systemctl restart kubelet`), редактирование файла само по себе не применяет изменения к работающему процессу.
</details>

---

| **3** | **Hardening kube-apiserver: отключить profiling** |
| :---: | :--- |
| Что делаем | В static Pod manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` добавьте `--profiling=false`. Дождитесь пересоздания kube-apiserver и убедитесь, что API готов. |
| Критерии приёмки | - в manifest kube-apiserver есть `--profiling=false`;<br/>- `kubectl get --raw='/readyz'` возвращает успешный результат;<br/>- static Pod kube-apiserver запущен. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Не редактируйте Pod через `kubectl edit` - это static Pod, kubelet управляет им напрямую из файла манифеста на диске и перезапишет любое изменение через API обратно. Добавьте флаг прямо в YAML-файл на ноде и подождите: kubelet заметит изменение файла не мгновенно.
</details>

---

| **4** | **Secure Ingress с TLS** |
| :---: | :--- |
| Что делаем | Создайте namespace `cks-103` и TLS-Secret `secure-ingress-tls` типа `kubernetes.io/tls` для хоста `secure.cks.local` (сертификат должен содержать `secure.cks.local` именно в Subject Alternative Name, не только в CN). Создайте Deployment `secure-app` (`viktoruj/ping_pong:alpine`, задайте `SERVER_NAME=secure-app` и `SRV_PORT=80` через `kubectl set env`), Service `secure-app` и Ingress `secure-ingress` с `ingressClassName: nginx`, TLS-секцией для этого хоста и ссылкой на Secret. Включите аннотацию `nginx.ingress.kubernetes.io/ssl-redirect: "true"`. Controller `ingress-nginx` в этой лабе уже установлен и Ready как lab-owned fixture (см. [главу 08](../../course/08/ru.md) про его retirement) - убедитесь, что он реально обрабатывает ваш Ingress: HTTPS-запрос через controller должен получить ответ `200` с телом, содержащим `Server Name: secure-app` (маркер именно этого backend), а HTTP-запрос - redirect (`Location`) на HTTPS-host `https://secure.cks.local` (ingress-nginx не всегда сохраняет путь в `Location`, проверяется именно host). Для проверки сертификата допустим самоподписанный сертификат. |
| Критерии приёмки | - Secret `secure-ingress-tls` в `cks-103` имеет тип `kubernetes.io/tls` и поля `tls.crt`, `tls.key`; соответствие пары проверяется по public key (алгоритм-независимо, без привязки к RSA/modulus);<br/>- сертификат содержит `secure.cks.local` в SAN;<br/>- Ingress `secure-ingress` содержит `ingressClassName: nginx`, аннотацию `ssl-redirect: "true"`, `spec.tls` с хостом `secure.cks.local` и ссылкой на `secure-ingress-tls`, backend `secure-app:80`;<br/>- Service `secure-app` имеет реальный endpoint;<br/>- controller `ingress-nginx` Ready;<br/>- HTTPS-запрос через controller действительно возвращает `200` с телом, содержащим `Server Name: secure-app` (не просто любой `2xx`/`3xx`, который может вернуть сам controller без доступа к backend);<br/>- HTTP-запрос через controller получает redirect с заголовком `Location`, указывающим на HTTPS-host `https://secure.cks.local` (не любой `3xx`; путь после хоста необязателен). |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Создавайте TLS Secret через `kubectl create secret tls secure-ingress-tls --cert=... --key=...` - это автоматически задаёт правильный `type: kubernetes.io/tls` и корректно кодирует данные в base64. Если создать Secret вручную с типом `Opaque` и ключами `tls.crt`/`tls.key`, тест на `type` не пройдёт, даже если данные технически валидны. Не забудьте `-addext 'subjectAltName=DNS:secure.cks.local'` при генерации сертификата openssl - современные клиенты и Ingress controller проверяют именно SAN, а не только CN.

Проверка пары certificate/private key делается по public key, а не по RSA-specific modulus - это работает одинаково для RSA и EC/ECDSA ключей:

```bash
cert_pub=$(kubectl -n cks-103 get secret secure-ingress-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | awk '{print $1}')
key_pub=$(kubectl -n cks-103 get secret secure-ingress-tls -o jsonpath='{.data.tls\.key}' \
  | base64 -d | openssl pkey -pubout -outform DER | sha256sum | awk '{print $1}')
[[ -n "$cert_pub" && "$cert_pub" == "$key_pub" ]]
```

Для end-to-end проверки не используйте Pod IP из `Endpoints` controller-а - он не гарантированно маршрутизируется с отдельной worker VM. Используйте ClusterIP Service `ingress-nginx-controller` и выполняйте запрос **с control-plane node**, где cluster Service networking доступен:

```bash
CONTROLLER_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
ssh control-plane "curl -sS -k --max-time 5 --resolve secure.cks.local:443:${CONTROLLER_IP} https://secure.cks.local/"
```
</details>

---

| **5** | **TLS hardening control plane** |
| :---: | :--- |
| Что делаем | В `/etc/kubernetes/manifests/kube-apiserver.yaml` задайте `--tls-min-version=VersionTLS13` и `--tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`. В `/etc/kubernetes/manifests/etcd.yaml` задайте `--cipher-suites` с тем же набором. После пересоздания компонентов подтвердите, что согласуется `TLSv1.3` (`openssl s_client -tls1_3`) и что `TLSv1.2` отклоняется (`openssl s_client -tls1_2` завершается ошибкой handshake), и сохраните вывод в `/var/work/tests/artifacts/5/tls13.txt`. Важно понимать семантику: в Go флаг `--tls-cipher-suites` действует только для TLS ≤ 1.2, а при `--tls-min-version=VersionTLS13` конкретные TLS 1.3 cipher suites этим флагом не настраиваются (Go выбирает их сам). Поэтому для kube-apiserver фактическую защиту здесь даёт именно min-version 1.3; cipher-suites значимы там, где допускается TLS 1.2 (например, для etcd). |
| Критерии приёмки | - оба требуемых TLS-флага есть в manifest kube-apiserver;<br/>- cipher suites есть в manifest etcd;<br/>- kube-apiserver и etcd здоровы;<br/>- артефакт TLS содержит подтверждение `TLSv1.3` и зафиксированный отказ TLS 1.2 (non-zero exit/handshake failure). |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Флаг на etcd называется `--cipher-suites` (без `tls-` в начале) - это ДРУГОЕ имя флага по сравнению с `--tls-cipher-suites` на kube-apiserver. Перепутать имена флагов - частая ошибка. Проверьте себя двумя отдельными командами `openssl s_client -connect <host>:6443 -tls1_3` (должен успешно соединиться) и `-tls1_2` (должен завершиться ошибкой handshake) - обе на порт kube-apiserver, а не etcd.
</details>

---

| **6** | **Проверка целостности kubelet и kubectl** |
| :---: | :--- |
| Что делаем | Сверьте SHA-256 установленных `kubelet` на control-plane и `kubectl` на worker с опубликованными checksum Kubernetes `v1.36.0`. Сохраните команды и итог `sha256sum -c` в `/var/work/tests/artifacts/6/binaries.sha256.txt`. Не используйте хеши, вычисленные из проверяемого файла, как эталон. |
| Критерии приёмки | - артефакт существует;<br/>- в нём есть отдельные успешные результаты для `kubelet` и `kubectl` (`OK`);<br/>- эталонные суммы получены из официального release `v1.36.0`. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Скачайте официальный файл `kubelet.sha256`/`kubectl.sha256` с `https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/` (или соответствующей платформы) и используйте `sha256sum -c` с этим файлом против реального установленного бинарника - именно вывод этой команды (`kubelet: OK`, `kubectl: OK`) и нужен в артефакте, а не просто сам хеш.
</details>

---

| **7** | **Remediation cycle: от конкретного kube-bench FAIL до PASS** |
| :---: | :--- |
| Что делаем | Отчёт задания 1 - снимок текущего состояния; здесь нужно связать один конкретный проваленный тест с его исправлением. На control-plane запустите `kube-bench` именно с `--check 1.1.1` (права static Pod manifest kube-apiserver; лабораторная инфраструктура намеренно выставляет mode `0644`, `cis-1.12` требует `600` или строже) и сохраните вывод **до** исправления в `/var/work/tests/artifacts/7/before.txt` - он должен содержать `[FAIL]` для этого теста. Исправьте право доступа файла `/etc/kubernetes/manifests/kube-apiserver.yaml` (`chmod 600`), затем повторно запустите тот же `--check 1.1.1` и сохраните вывод в `/var/work/tests/artifacts/7/after.txt` - он должен содержать `[PASS]` без единого `[FAIL]` для этого check. |
| Критерии приёмки | `before.txt` содержит строку `[FAIL]` для check `1.1.1`; фактические права файла на ноде после исправления - ровно `600`; `after.txt` содержит `[PASS]` для check `1.1.1` и не содержит `[FAIL]` для него; kube-apiserver остаётся здоров после изменения (fs-only правка, компонент не пересоздаётся). |

<details>
<summary>💡 Подсказка к заданию 7</summary>

Это задание про порядок действий, а не только про итоговое состояние: сначала зафиксируйте `[FAIL]` (before.txt), только потом делайте `chmod 600`, потом снова прогоните проверку (after.txt). Если сделать `chmod` до сохранения before.txt, вы не получите нужный `[FAIL]` в первом артефакте. Изменение прав файла - это fs-only операция, kubelet не пересоздаёт static Pod из-за смены прав самого файла манифеста (в отличие от изменения его содержимого).
</details>

---

| **8** | **Remediation cycle: kube-controller-manager, тот же приём для другого компонента** |
| :---: | :--- |
| Что делаем | То же самое, что в задании 7, но для `kube-controller-manager` и другого check ID: `--check 1.1.3` (права static Pod manifest kube-controller-manager; лабораторная инфраструктура намеренно выставляет mode `0644`). Сохраните вывод **до** исправления в `/var/work/tests/artifacts/8/before.txt` (должен содержать `[FAIL]` для `1.1.3`), исправьте `chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml`, затем сохраните повторный запуск в `/var/work/tests/artifacts/8/after.txt` (должен содержать `[PASS]` без `[FAIL]` для `1.1.3`). |
| Критерии приёмки | `before.txt` содержит строку `[FAIL]` для check `1.1.3`; права файла после исправления - ровно `600`; `after.txt` содержит `[PASS]` для `1.1.3` и не содержит для него `[FAIL]`; `kube-controller-manager` остаётся `Running` (fs-only правка, компонент не пересоздаётся). |

<details>
<summary>💡 Подсказка к заданию 8</summary>

Тот же порядок действий, что и в задании 7: сначала `before.txt` с `[FAIL]`, потом `chmod`, потом `after.txt` с `[PASS]`. Не переносите старые CIS check ID "по памяти" - `1.1.3` в пиннутой версии `kube-bench 0.16.0`/профиле `cis-1.12` - это именно kube-controller-manager pod specification file permissions, проверьте это через `--check 1.1.3` перед тем, как исправлять.
</details>

---

| **9** | **Отключить profiling на оставшихся control-plane компонентах** |
| :---: | :--- |
| Что делаем | Задание 3 уже отключило profiling на kube-apiserver. По умолчанию kubeadm не добавляет `--profiling=false` в манифесты `kube-controller-manager` и `kube-scheduler` вообще - оба компонента до сих пор обслуживают pprof HTTP endpoints с профилированием процесса. Добавьте `--profiling=false` в `command` static Pod manifests `/etc/kubernetes/manifests/kube-controller-manager.yaml` и `/etc/kubernetes/manifests/kube-scheduler.yaml`. Дождитесь пересоздания обоих static Pods и убедитесь, что оба остаются `Running`. |
| Критерии приёмки | - реально запущенный Pod `kube-controller-manager` содержит `--profiling=false` в своём `command` (проверяется через API, а не текстом файла на диске);<br/>- то же самое для `kube-scheduler`;<br/>- оба Pod в фазе `Running` после пересоздания. |

<details>
<summary>💡 Подсказка к заданию 9</summary>

Тот же приём, что и в задании 3, только для двух других static Pod manifests. Не редактируйте Pod через `kubectl edit` - kubelet перезапишет любое такое изменение из файла на диске. Добавьте флаг прямо в YAML на ноде и подождите пересоздания - оно происходит не мгновенно. Не путайте это задание с `protectKernelDefaults` (это отдельный kubelet-параметр, уже закрыт в лабе 105 заданием 8) - здесь речь именно про HTTP profiling endpoint control-plane компонентов.
</details>

---

## Проверка результата

На worker запустите:

```bash
check_result
```

Проверка содержит Init и девять независимых заданий. Системные задания проверяются по
состоянию узла control plane через SSH и по артефактам, а не только по объектам API.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление кластера и ресурсов

```bash
TASK=103 make delete_cks_task
```
