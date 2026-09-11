# Лаба 112 - Runtime: Falco, audit-логи и неизменяемый root filesystem

## Цель

В этой CKS-лабе вы настроите контроль runtime-событий на ноде и audit-логирование API
control plane, а затем сделаете workload неизменяемым в рантайме. Работа идёт на одном
узле: `control-plane` одновременно является workload-нодой, поэтому Falco видит события
из тестовых Pod, а kube-apiserver находится в static Pod manifest.

## Проверьте себя перед стартом

<details>
<summary>1. Почему audit log Kubernetes не может служить заменой Falco для runtime-обнаружения?</summary>

Audit log записывает REQUEST-уровневые события к API server (кто, что и когда запросил через `kubectl`/API) - это evidence на уровне control plane. Falco же наблюдает СИСТЕМНЫЕ ВЫЗОВЫ (syscalls) внутри работающих контейнеров на ноде - например, открытие shell, spawn процесса, запись в файл. Действие типа `docker exec`/`crictl exec` или прямой запуск через `ctr` на ноде НЕ проходит через Kubernetes API вообще и не попадёт в audit log, но будет видно Falco как syscall-событие.
</details>

<details>
<summary>2. В чём разница между `RequestResponse` и `Metadata` уровнями audit-политики, и почему для Secret нужен именно `Metadata`?</summary>

`RequestResponse` записывает полное тело запроса И ответа, включая содержимое ресурса. `Metadata` записывает только метаданные о запросе (кто, когда, какой ресурс, какой verb) БЕЗ тела. Для `secrets` это критично: `RequestResponse` записал бы значение самого секрета (base64-encoded, но всё равно чувствительные данные) в audit log в виде читаемого файла на диске - это создаёт новую поверхность утечки. `Metadata` даёт forensic-след ("кто читал этот Secret и когда") без копирования самого секрета в лог.
</details>

<details>
<summary>3. Почему `readOnlyRootFilesystem: true` не эквивалентен полной защите от компрометации контейнера в рантайме?</summary>

`readOnlyRootFilesystem` блокирует запись в корневую файловую систему контейнера, что мешает злоумышленнику модифицировать бинарники приложения или установить persistence на диск контейнера. Но это НЕ мешает: (а) writable volumes/emptyDir, которые Pod сам явно монтирует (например `/tmp`), (б) выполнению действий в памяти процесса (RCE без записи на диск), (в) сетевым атакам изнутри контейнера, (г) чтению уже смонтированных Secret/ConfigMap. Иммутабельность rootfs - один слой защиты, не полная изоляция.
</details>

## Связь с курсом

- [Глава 29. Поведенческий анализ во время выполнения: Falco](../../course/29/ru.md)
- [Глава 30. Обнаружение угроз и расследование фаз атаки](../../course/30/ru.md)
- [Глава 31. Иммутабельность контейнеров в runtime](../../course/31/ru.md)
- [Глава 32. Audit-логи Kubernetes](../../course/32/ru.md)
- [Глава 26. Реестры, подпись и валидация артефактов](../../course/26/ru.md) - задание 9 связывает admission-контроль registry allowlist с runtime-обнаружением обхода (не signature verification - её проверяет лаба 111).

## Инфраструктура

| Компонент | Назначение |
|---|---|
| `k8s-1` | одноузловой Kubernetes `1.36.0`, containerd и Calico; имя ноды `control-plane` |
| `worker` | рабочая машина с `kubectl`, `check_result` и SSH-доступом `ssh control-plane` |
| `runtime-112` | подготовленный namespace; в нём уже есть Secret `audit-secret` |

Bootstrap намеренно **не** устанавливает Falco и **не** включает audit backend. Он только
готовит каталог `/etc/kubernetes/audit`, каталог логов
`/var/log/kubernetes/audit` и Secret для контролируемого API-запроса. Не меняйте CNI,
версию кластера, Secret или Kubernetes-манифесты вне задания 4.

## Развёртывание

```bash
TASK=112 make run_cks_task
```

На рабочей машине:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## Задания

Перед containment полезно мысленно оценить blast radius: может ли ServiceAccount
скомпрометированного Pod читать Secrets, создавать workload или достигать других
namespace. Это можно и стоит быстро проверить `kubectl auth can-i` от имени
ServiceAccount `falco-shell` как дополнительный шаг; он не обязателен, не влияет на
критерии приёмки и не тестируется.

---
| **1** | **Установить и запустить Falco на workload-ноде** |
| :---: | :--- |
| Что делаем | На `control-plane` установите пакет Falco из официального репозитория Falco и запустите сервис. Используйте modern eBPF engine; не устанавливайте kernel module вручную. Включите сервис через systemd. |
| Критерии приёмки | `falco --version` выполняется; `systemctl is-active falco` возвращает `active`; конфигурация содержит `engine.kind: modern_ebpf`. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

Modern eBPF engine настраивается через `engine.kind: modern_ebpf` в `/etc/falco/falco.yaml` (не через отдельный kernel module driver, который нужен для legacy engine) - если после установки Falco не запускается или падает при старте, проверьте `journalctl -u falco` на ошибки загрузки eBPF program, что может указывать на несовместимое ядро.
</details>

---
| **2** | **Зафиксировать стандартное событие shell в контейнере** |
| :---: | :--- |
| Что делаем | Создайте в `runtime-112` Pod `falco-shell` из `busybox:1.36`, оставьте его Running (`sleep 3600`) и включите `stdin: true`, `tty: true`. Откройте в нём интерактивный `/bin/sh`, дождитесь правила Falco **Terminal shell in container** и сохраните подходящую строку из journal Falco в `/var/work/tests/artifacts/2/falco-shell.log` на рабочей машине. |
| Критерии приёмки | Pod `falco-shell` Running; артефакт не пуст и содержит `Terminal shell in container`. Событие должно быть получено Falco, а не записано вручную. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Просто создать Pod с `stdin: true, tty: true` недостаточно - нужно РЕАЛЬНО открыть интерактивную сессию (`kubectl exec -it falco-shell -- /bin/sh`), чтобы Falco зафиксировал именно spawn shell-процесса внутри контейнера. Ищите событие через `journalctl -u falco --no-pager | grep "Terminal shell"` на `control-plane` (через SSH с worker), а не пытайтесь писать строку в файл руками - тест ожидает реальный timestamp/формат из journal.
</details>

---
| **3** | **Добавить и вызвать custom Falco rule** |
| :---: | :--- |
| Что делаем | На `control-plane` добавьте в `/etc/falco/falco_rules.local.yaml` правило с именем `CKS112 Custom Shell Marker`. Оно должно ловить spawned process в контейнере, у которого `proc.cmdline` содержит `CKS112_CUSTOM_EVENT`, и выводить точную фразу `CKS112 custom shell marker` вместе с `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name` и `command=%proc.cmdline`. Перезапустите Falco. Из `falco-shell` вызовите контролируемый процесс с marker, найдите срабатывание и сохраните его в `/var/work/tests/artifacts/3/falco-custom.log`. |
| Критерии приёмки | Локальный rules-файл существует, содержит имя правила, условие marker и идентификаторы расследования; сервис Falco активен; настоящий journal-артефакт содержит marker, container ID и PID. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Custom rule в `falco_rules.local.yaml` требует `condition`, использующий `spawned_process` (или `evt.type=execve`) вместе с `proc.cmdline contains "CKS112_CUSTOM_EVENT"` - без базового условия по типу события правило может не сработать вообще или сработать на неверные события. После правки файла обязательно `systemctl restart falco` - Falco не перечитывает rules-файлы на лету автоматически.
</details>

---
| **4** | **Включить audit-логирование: RequestResponse для ConfigMap, Metadata для Secret** |
| :---: | :--- |
| Что делаем | На `control-plane` создайте `/etc/kubernetes/audit/policy.yaml`. Policy должна: записывать `RequestResponse` **только в namespace `runtime-112`** для core resource `configmaps` (контролируемый forensic-пример на нечувствительном ресурсе); для core resource `secrets` использовать только `Metadata`, **чтобы тело Secret не попадало в журнал**; реально снижать шум явными `None` rules для high-volume/low-risk traffic и `omitStages: [RequestReceived]`; завершаться безопасным catch-all `Metadata` как *fallback logging*, а не как шумоподавлением. В static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` добавьте `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log`, ротацию (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`) и необходимые hostPath volume/volumeMount для policy-каталога и каталога логов. Дождитесь восстановления API. Создайте ConfigMap `audit-config` в `runtime-112`, прочитайте его (`kubectl get configmap audit-config -n runtime-112 -o json`) и сохраните RequestResponse event в `/var/work/tests/artifacts/4/configmap-request-response.json`. Затем прочитайте `kubectl get secret audit-secret -n runtime-112 -o json` и сохраните его Metadata event в `/var/work/tests/artifacts/4/secret-metadata.json`. |
| Критерии приёмки | kube-apiserver healthy; static manifest содержит оба audit-флага и монтирования; policy задаёт `RequestResponse` для `configmaps` и `Metadata` для `secrets`; в `/var/work/tests/artifacts/4/configmap-request-response.json` — RequestResponse event для ConfigMap; в `/var/work/tests/artifacts/4/secret-metadata.json` — событие Secret уровня `Metadata` **без полей `requestObject`/`responseObject`** (тело Secret не залогировано). |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Порядок правил в audit policy имеет значение: Kubernetes применяет ПЕРВОЕ подходящее правило сверху вниз, поэтому специфичное правило для `configmaps`/`secrets` в `runtime-112` должно идти РАНЬШЕ общего catch-all `Metadata` в конце файла - если catch-all стоит первым, он "перехватит" все запросы раньше специфичных правил. После редактирования static manifest kubelet сам подхватит изменения (не нужен `kubectl apply`/restart) - но подождите, пока `kubectl get --raw=/readyz` снова вернёт успех, прежде чем продолжать.
</details>

---
| **5** | **Сделать Pod с root filesystem только для чтения** |
| :---: | :--- |
| Что делаем | Создайте в `runtime-112` Pod `immutable-app`: контейнер `app`, образ `busybox:1.36`, `sleep 3600`. На контейнере включите `securityContext.readOnlyRootFilesystem: true`; создайте `emptyDir` `writable-tmp` и смонтируйте его в `/tmp` без `readOnly: true`. Не используйте `hostPath`. Докажите, что `touch /cks-112-write-denied` неуспешен, а `touch /tmp/allowed` успешен; сохраните результат отказа в `/var/work/tests/artifacts/5/rootfs-write-denied.log`. |
| Критерии приёмки | Pod Running; root filesystem read-only; `/tmp` - writable `emptyDir`; в Pod нет `hostPath`; запись в rootfs блокируется, в `/tmp` разрешена; артефакт не пуст. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Сохраняйте именно ВЫВОД ОШИБКИ команды `touch /cks-112-write-denied` (`Read-only file system` в stderr), а не просто факт, что команда завершилась с ненулевым кодом - тест проверяет содержимое лога. Не путайте `emptyDir` (эфемерный, живёт с Pod) с `hostPath` (персистентный на ноде, запрещён в этом задании) - оба технически "решают" задачу writable-директории, но только первый разрешён здесь.
</details>

---
| **6** | **Минимальная цепочка containment от alert до изоляции** |
| :---: | :--- |
| Что делаем | После включения audit backend запустите в `falco-shell` контролируемый долгоживущий процесс с аргументом `CKS112_CUSTOM_EVENT`. **Начните расследование с нового Falco alert**, а не с Pod manifest. Из alert извлеките short container ID и host PID. На `control-plane` через `crictl ps/inspect/inspectp` сопоставьте container → Pod sandbox → namespace/Pod; через Kubernetes API определите ноду. Сохраните `crictl inspect` и `inspectp`. Пока процесс жив, сохраните `/proc/<PID>/status`, `cmdline`, `cgroup` и дерево PID/PPID/user. В audit log найдите `pods/exec` event для `runtime-112/falco-shell` и сохраните его без request/response body. Классифицируйте фазу как `Execution`, технику как `Container Administration Command`, составьте `evidence-summary.txt`. Затем примените default-deny ingress+egress `NetworkPolicy` `incident-quarantine`, удалите скомпрометированный Pod и сохраните отрицательную проверку: повторный `kubectl exec` не проходит. Это минимальная containment-цепочка: credential revocation/rotation и полное remediation требуют отдельного incident-response процесса. |
| Критерии приёмки | В `/var/work/tests/artifacts/6/` есть настоящий Falco alert, CRI inspect/inspectp, три `/proc`-артефакта, process lineage, Metadata audit event для `pods/exec`, итоговая сводка и результат containment; Pod `falco-shell` отсутствует; `incident-quarantine` выбирает все Pod и закрывает ingress+egress; повторный exec имеет non-zero exit code. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Строгий порядок действий важен для достоверности расследования: начинайте с Falco alert (это то, что реально запустило бы incident response), а НЕ с уже известного Pod name - иначе вы просто подтверждаете то, что уже знаете, а не проводите реальную correlation. Собирайте `/proc/<PID>/*` артефакты, пока процесс ЖИВ - как только вы удалите Pod (последний шаг), `/proc` для этого PID исчезнет навсегда, поэтому порядок "сначала evidence, потом containment" необратим при перепутывании.
</details>

---
| **7** | **Override upstream Falco macro, добавить Pod/namespace evidence в output, JSON в файл** |
| :---: | :--- |
| Что делаем | Стандартное правило Falco **Terminal shell in container** сработало бы и на легитимный CI/CD-инструмент, который штатно открывает shell в контейнере (например, `kubectl debug` или sidecar с обслуживающим скриптом). Вместо редактирования самого правила override upstream-макрос, специально предназначенный именно для этого правила: в `/etc/falco/falco_rules.local.yaml` переопределите `user_expected_terminal_shell_in_container_conditions` (по умолчанию `(never_true)` в самом правиле **Terminal shell in container** - не путать с `user_shell_container_exclusions`, который относится к отдельному правилу **Run shell untrusted**/"Shell spawned by untrusted binary"), чтобы он допускал конкретный Pod `ci-runner` в namespace `runtime-112`. Используйте `k8s.pod.name` и `k8s.ns.name`, а не `container.name`: `container.name` - это имя **контейнера** (в этом задании `app`), а не Pod, и совпадение по имени контейнера почти всегда даст неверный или слишком широкий allowlist. Стандартный output правила **Terminal shell in container** не содержит `k8s.pod.name`/`k8s.ns.name` (проверьте upstream `falco_rules.yaml` сами - там их нет); без этого поля correlation конкретного alert с конкретным Pod невозможна надёжно. Через тот же `override` механизм добавьте (`output: append`) к правилу `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` в конец output. Создайте в `runtime-112` Pod `ci-runner` из `busybox:1.36` с интерактивным `sh` (`stdin: true`, `tty: true`) и подтвердите, что для него **не** формируется alert `Terminal shell in container`, тогда как для `falco-shell` (без исключения) alert продолжает срабатывать. Отдельно в `/etc/falco/falco.yaml` включите `json_output: true` и `file_output.enabled: true` с `file_output.filename: /var/log/falco/events.log`; перезапустите Falco. Подтвердите через структурированный JSON (`jq .output_fields`), а не текстовый `grep`, что записанный alert для `falco-shell` содержит `k8s.pod.name == "falco-shell"` и `k8s.ns.name == "runtime-112"`. |
| Критерии приёмки | `falco_rules.local.yaml` содержит `macro: user_expected_terminal_shell_in_container_conditions` с условием, ссылающимся на `k8s.pod.name = "ci-runner"` и `k8s.ns.name = "runtime-112"` (не `never_true`, не `container.name`), и отдельный `override: output: append`, добавляющий `%k8s.ns.name`/`%k8s.pod.name` к правилу `Terminal shell in container`; shell в `ci-runner` не создаёт alert за время наблюдения, а shell в `falco-shell` создаёт; `falco.yaml` содержит `json_output: true` и `file_output: {enabled: true, filename: /var/log/falco/events.log}`; `/var/log/falco/events.log` содержит валидную JSON-строку с `rule == "Terminal shell in container"` и `output_fields["k8s.pod.name"] == "falco-shell"`, `output_fields["k8s.ns.name"] == "runtime-112"`. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

Два разных override-механизма легко перепутать: `macro` override меняет УСЛОВИЕ срабатывания правила (кого исключить), а `output` override с `append` меняет только ФОРМАТ вывода (что печатать) - для этого задания нужны ОБА, отдельными блоками `- macro: ...` и `- rule: ... / override: / output: append`. Проверьте буквально написание `user_expected_terminal_shell_in_container_conditions` - Falco имеет несколько похожих по названию макросов для разных правил (упомянутый в задании `user_shell_container_exclusions` относится к ДРУГОМУ правилу), использование неверного макроса не даст ошибки загрузки, но allowlist просто не будет работать.
</details>

---
| **8** | **Audit webhook backend вместо/вместе с локальным файлом** |
| :---: | :--- |
| Что делаем | Разверните в `runtime-112` минимальный HTTP-приёмник `audit-receiver` (Deployment + Service на порту `8080`, любой образ, который пишет тело каждого запроса в лог контейнера, например `mendhak/http-https-echo` или эквивалент), который будет получать audit-события. На `control-plane` создайте `/etc/kubernetes/audit/webhook-config.yaml` в формате kubeconfig с `server: http://<ClusterIP приёмника>:8080/audit` (для лабы допустим HTTP; в production webhook требует HTTPS и client certificate - см. главу 32). В static manifest `kube-apiserver.yaml` добавьте `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` и `--audit-webhook-batch-max-wait=1s` (уменьшенная задержка batch для наблюдаемости в лабе), сохранив уже настроенный `--audit-policy-file` и `--audit-log-path` из задания 4 - webhook дополняет, а не заменяет local file backend. После восстановления API выполните любой аудируемый запрос (например, `kubectl get configmap audit-config -n runtime-112`) и подтвердите в логах `audit-receiver`, что событие было доставлено. |
| Критерии приёмки | `audit-receiver` Running с Service; `webhook-config.yaml` - валидный kubeconfig с `server` на этот Service; static manifest kube-apiserver содержит `--audit-webhook-config-file` и `--audit-webhook-batch-max-wait`, а также сохранённые флаги file backend из задания 4; kube-apiserver healthy после изменения; логи `audit-receiver` содержат хотя бы одно JSON audit event тела запроса с полем `objectRef`. |

<details>
<summary>💡 Подсказка к заданию 8</summary>

`webhook-config.yaml` - это ФОРМАТ KUBECONFIG (с `clusters`/`users`/`contexts`), а не произвольный YAML с полем `server` - если структура файла не соответствует kubeconfig schema, kube-apiserver не сможет его распарсить и не запустится вовсе. Не забудьте, что webhook ДОПОЛНЯЕТ file backend, а не заменяет - если вы удалите флаги `--audit-policy-file`/`--audit-log-path` из задания 4, тесты задания 4 перестанут проходить.
</details>

---
| **9** | **Интеграционное задание: обойти admission allowlist через containerd напрямую и обнаружить попытку через Falco** |
| :---: | :--- |
| Что делаем | Это задание связывает Supply Chain Security (см. [лабу 111](../111/README_RU.MD) и [главу 26](../../course/26/ru.md)) с Runtime Security этой лабы. **Важное отличие от лабы 111**: там `ImageValidatingPolicy` проверяет **криптографическую подпись** (Cosign). Здесь policy проверяет только **registry/repository allowlist** (permitted registry, без signature/attestor) - более простой, но так же реальный admission control, с тем же принципом: он работает только на API admission path и не видит действия, которые к нему не обращаются. Установите Kyverno (`install-kyverno`, как в лабе 111) и создайте `ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL, `apiVersion: policies.kyverno.io/v1`), которая через `image(c.image).registry()`/`.repository()` (Kyverno CEL Image library) **отклоняет** любой Pod в `runtime-112`, чей image не равен точно `registry: docker.io` и `repository: library/busybox` - не `startsWith`, чтобы не пропустить похожие имена вроде `busybox-evil`. Дайте policy уникальное сообщение денайла, например `CKS112_TRUSTED_REPO_POLICY: only docker.io/library/busybox is allowed`. Подтвердите этот путь: примените Pod `blocked-attempt` с image `alpine:3.20` (не в allowlist) и сохраните вывод admission denial в `9/admission-deny.txt`. Затем на `control-plane` через `sudo ctr -n k8s.io images pull docker.io/library/alpine:3.20` и `sudo ctr -n k8s.io run -d docker.io/library/alpine:3.20 cks112-bypass-1 sh -c 'echo CKS112_CTR_BYPASS; sleep 5'` смоделируйте путь, который не проходит через API server и не виден admission controller (используйте `-d`/detached и уникальный ID, чтобы не столкнуться с предыдущим запуском при повторной проверке; после проверки удалите container/task явным `ctr task kill`/`ctr container rm`). **Перед тем как писать Falco-правило, определите РЕАЛЬНОЕ observed-значение поля `%container.image.repository` для доверенного `docker.io/library/busybox` на вашем containerd/Falco стеке** - это поле формируется по-разному в разных версиях (возможно с hostname registry, возможно без него), поэтому не предполагайте формат заранее: временным правилом с безопасным marker выведите значение в лог и сохраните его как `$TRUSTED_REPO` (сохраните evidence в `9/observed-trusted-repo.txt`). Добавьте в `falco_rules.local.yaml` custom rule `CKS112 Runtime Bypass of Admission`, которая ловит spawned process с `proc.cmdline` содержащим `CKS112_CTR_BYPASS` **и** `container.image.repository`, не входящим в allowlist - используйте **точное** сравнение `container.image.repository != "$TRUSTED_REPO"` с наблюдаемым значением (не `startswith`/prefix-проверку: `not container.image.repository startswith "$TRUSTED_REPO"` пропустил бы, то есть не заметил бы, репозиторий вроде `<observed-value>-evil`, потому что его имя просто начинается с разрешённой подстроки - та же ошибка, которую избегает Kyverno policy выше через `==`, а не `startsWith`), и выводит `container.image.repository` вместе с идентификаторами процесса. Дополнительно проверьте оба контролируемых случая: доверенный `docker.io/library/busybox` НЕ должен вызывать срабатывание правила (только по признаку repository - сам marker `CKS112_CTR_BYPASS` при этом всё равно может быть проверен отдельно), а образ с repository `<observed-value>-evil` ДОЛЖЕН вызывать срабатывание - именно это доказывает, что сравнение точное, а не prefix-based. Сохраните срабатывание в `9/falco-bypass-attempt.log`. |
| Критерии приёмки | Kyverno установлен и Available; `ValidatingPolicy require-trusted-registry-runtime-112` существует с `apiVersion: policies.kyverno.io/v1`, validation action `Deny`, использует `image(...).registry()`/`.repository()` для точного (не `startsWith`) сравнения, и её `message`/`messageExpression` содержит уникальный маркер `CKS112_TRUSTED_REPO_POLICY`; Pod `blocked-attempt` не создан (admission denial), `9/admission-deny.txt` содержит именно этот маркер (не любую generic admission-ошибку); `9/observed-trusted-repo.txt` содержит реально наблюдённое значение `%container.image.repository` для доверенного образа; `falco_rules.local.yaml` содержит правило `CKS112 Runtime Bypass of Admission` с **точным** (не `startswith`/prefix) условием на `container.image.repository`, использующим именно это наблюдённое значение; `9/falco-bypass-attempt.log` содержит непустое срабатывание с `CKS112_CTR_BYPASS` и image repository вне allowlist (суффикс `-evil` к наблюдённому значению) - этот репозиторий специально выбран как prefix-trap: он должен обнаруживаться, несмотря на то что начинается с разрешённой строки. |

<details>
<summary>💡 Подсказка к заданию 9</summary>

Ключевая мысль задания: `ctr` (containerd CLI) обращается НАПРЯМУЮ к containerd, минуя kube-apiserver и, следовательно, минуя ЛЮБОЙ admission controller (в том числе Kyverno) - это демонстрация того, что admission control защищает только путь через Kubernetes API, а не всю ноду. Ваше Falco-правило должно проверять оба условия через `and` в одном `condition` (marker `CKS112_CTR_BYPASS` И repository вне allowlist) - если проверить только marker, правило сработает даже на легитимные тестовые процессы с похожим cmdline.
</details>

---
| **10** | **Обнаружить доступ к `/dev/mem` через отдельный класс Falco-условия и остановить workload** |
| :---: | :--- |
| Что делаем | Задания 3, 7 и 9 использовали условие на `spawned_process`/`proc.cmdline` - обнаружение по запуску процесса. Здесь нужен принципиально другой класс Falco condition: обнаружение по **открытию файла/устройства**. В `runtime-112` уже есть Deployment `mem-scanner` (2 реплики), один из Pod которого периодически открывает `/dev/mem` изнутри контейнера - обычное application workload не имеет причины делать это, и такой доступ является сильным индикатором опасной конфигурации или попытки обхода изоляции контейнера. На `control-plane` добавьте в `/etc/falco/falco_rules.local.yaml` правило `CKS112 Container access to /dev/mem` с условием `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`, priority `CRITICAL`, output должен содержать `container_id=%container.id`, `k8s_pod=%k8s.pod.name` и `k8s_ns=%k8s.ns.name`. Перезапустите Falco. Найдите срабатывание в journal, определите через него **конкретный** Pod (не угадывайте по имени - используйте `k8s_pod` из самого alert), сохраните строку алерта в `/var/work/tests/artifacts/10/falco-devmem.log`, затем выполните `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` и сохраните итоговое состояние (`kubectl get deployment mem-scanner -n runtime-112 -o json`) в `/var/work/tests/artifacts/10/scaled-down.json`. |
| Критерии приёмки | `falco_rules.local.yaml` содержит правило с именем `CKS112 Container access to /dev/mem`, условием на `fd.name = /dev/mem` (не на `proc.cmdline`/spawned_process) и `container.id != host`, priority `CRITICAL`; Falco активен; `10/falco-devmem.log` - настоящая строка из journal с этим правилом и непустым `k8s_pod`; Deployment `mem-scanner` масштабирован до `replicas: 0`; `10/scaled-down.json` подтверждает `spec.replicas == 0`. |

<details>
<summary>💡 Подсказка к заданию 10</summary>

Не путайте это условие с заданиями 3/7/9 - там `spawned_process`/`execve` ловит ЗАПУСК процесса по командной строке, а здесь `open`/`openat`/`openat2` ловит ОТКРЫТИЕ конкретного файла/устройства независимо от того, какой процесс это делает и с какими аргументами командной строки. `container.id != host` отсекает легитимные системные процессы на самой ноде (не в контейнере), которым доступ к `/dev/mem` может быть нужен по другим причинам. Не масштабируйте Deployment до находки alert - сначала обнаружение через Falco, потом containment, иначе вы не докажете, что нашли Pod именно через мониторинг, а не заранее зная, какой из двух реплик виноват.
</details>

## Проверка

```bash
check_result
```

Проверка содержит Init и десять независимых тестов. Она проверяет состояние Falco и
kube-apiserver по SSH, API-объекты, CRI/`/proc` evidence, audit correlation, containment
и фактический отказ записи в rootfs. После
изменения static Pod manifest не перезапускайте kubelet без необходимости: kubelet сам
заметит изменение. Если API временно недоступен, дождитесь `kubectl get --raw=/readyz`.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=112 make delete_cks_task
```
