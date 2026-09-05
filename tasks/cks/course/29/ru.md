<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Глава 29. Поведенческий анализ во время выполнения: Falco

> **Что дальше.** Image scan, подписи и admission policy уменьшают вероятность доставки
> небезопасного workload, но не доказывают, что уже запущенный процесс ведёт себя нормально.
> В этой главе переходим к **runtime detection**: Falco наблюдает системные события ноды и
> сообщает о поведении, похожем на shell в контейнере, чтение чувствительного файла,
> запуск package manager или попытку повысить привилегии. Это начало домена **Monitoring,
> Logging & Runtime Security (20%)** CKS. В главах 30-32 разовьём сигнал до расследования,
> иммутабельности и Kubernetes audit logs.

> **Что нужно знать из CKA.** Контейнеры, namespaces, процессы и container runtime разобраны
> в [главе 00-4 CKA](../../../cka/course/00-4-containers/ru.md). Базовые логи,
> `kubectl logs`, Events и наблюдаемость - в [главе 28 CKA](../../../cka/course/28/ru.md).
> Здесь их не повторяем: используем для security-сигнала и его проверки.

## 29.1. Зачем нужен runtime-детектор

Защита до запуска отвечает на вопрос «можно ли создать этот Pod?». Runtime detection
отвечает на другой вопрос: «что реально сделал процесс после запуска?». Это важно, когда
атакующий эксплуатирует CVE, получает `exec` в контейнер, злоупотребляет легитимным образом
или использует команду, которой нет в manifest.

```mermaid
flowchart LR
    build["image scan и подпись\nдо запуска"] --> admit["admission policy\nразрешить или отклонить Pod"]
    admit --> runtime["контейнер выполняется\nна ноде"]
    runtime --> events["syscalls / eBPF события\nпроцесс, файл, сеть"]
    events --> falco["Falco rule engine"]
    falco --> alert["alert, log, webhook\nи расследование"]
    style build fill:#326ce5,color:#fff
    style admit fill:#673ab7,color:#fff
    style runtime fill:#f4b400,color:#000
    style events fill:#db4437,color:#fff
    style falco fill:#0f9d58,color:#fff
    style alert fill:#326ce5,color:#fff
```

Falco сопоставляет поток событий с правилами. Правило не доказывает компрометацию: shell в
контейнере может быть обычной отладкой, а чтение `/etc/shadow` - ожидаемым действием у
специального агента. Поэтому полезный alert содержит контекст: время, имя правила,
приоритет, процесс, команду, контейнер, Pod, namespace и ноду. Дальше инженер сопоставляет
сигнал с deployment, пользователем, audit logs и задачей workload.

| Контроль | Когда работает | На какой вопрос отвечает | Чего не заменяет |
|---|---|---|---|
| image scan / SBOM | до и после build | известна ли уязвимая component/version | наблюдение за действиями процесса |
| admission policy | при создании объекта | соответствует ли Pod policy | контроль уже работающего процесса |
| Falco | во время выполнения | произошло ли подозрительное системное действие | remediation, изоляцию и расследование |
| Kubernetes audit | при обращении к API | кто вызвал API и что запросил | syscall-контекст процесса на ноде |

Falco особенно полезен для следующих сигналов:

- shell или package manager внутри application container;
- доступ к чувствительным путям, устройствам и socket (`/etc/shadow`, `/dev/mem`,
  `/var/run/docker.sock`); путь `/etc/shadow` обычно относится к файловой системе
  контейнера и означает файл ноды только при явном монтировании host filesystem;
- запуск процесса с неожиданной командой, capability или namespace;
- попытки записать в системный путь, загрузить kernel module или изменить сеть;
- подозрительные сетевые соединения, если соответствующий event source и правило включены.

Не делайте из Falco блокирующий барьер без проектирования реакции. Типичное безопасное
действие по alert - сохранить контекст, ограничить доступ, снять workload с трафика или
масштабировать подтверждённо скомпрометированный Deployment до нуля. Автоматически удалять
любой Pod по одному общему правилу рискованно: ложное срабатывание может стать outage.

## 29.2. Как Falco получает события: ядро, driver и eBPF

Процесс контейнера всё равно использует kernel ноды: делает `execve`, `openat`, `connect`,
`unlink` и другие syscalls. Container namespaces ограничивают видимость и доступ процесса,
но не создают отдельное ядро. Falco получает события на ноде, обогащает их метаданными
container runtime и Kubernetes и проверяет против rules.

```mermaid
flowchart TB
    app["процесс в контейнере\nsh / curl / приложение"] --> syscall["syscall: execve, openat, connect"]
    syscall --> kernel["ядро Linux ноды"]
    kernel --> driver["Falco driver\nkmod или modern eBPF"]
    driver --> userspace["Falco userspace\nfields + rule engine"]
    runtime["containerd / CRI\nPod и container metadata"] --> userspace
    userspace --> output["stdout, syslog, journal,\nHTTP(S) или Falcosidekick"]
    style app fill:#f4b400,color:#000
    style syscall fill:#db4437,color:#fff
    style kernel fill:#326ce5,color:#fff
    style driver fill:#673ab7,color:#fff
    style userspace fill:#0f9d58,color:#fff
    style runtime fill:#326ce5,color:#fff
    style output fill:#0f9d58,color:#fff
```

В Falco 0.44 legacy eBPF probe удалён. Для syscall event source выбирают один из
поддерживаемых driver: `kmod` или `modern_ebpf`.

| Способ | Как работает | Плюсы | Ограничения и проверка |
|---|---|---|---|
| `kmod` | модуль Falco загружается в ядро и передаёт события userspace | привычный путь для поддерживаемого kernel | нужны совместимость kernel/header и право загрузить модуль; после обновления ядра driver может перестать собираться |
| `modern_ebpf` | современный eBPF driver Falco использует CO-RE и не собирает отдельный kernel module | не требует kernel headers и сборки модуля; удобен на immutable/minimal host | требуются поддерживаемый kernel и BPF-возможности; часть окружений запрещает BPF или требует privileged agent |

Не выбирайте backend только по названию: сверяйте поддерживаемую версию Falco, kernel ноды,
политику хоста и фактический startup log. Строки о `Kernel module` или `modern eBPF` в
startup log - доказательство выбранного пути, а не достаточно только параметра Helm.

Для обогащения CRI metadata Falco нужен фактический socket runtime ноды. Современные
обычные пути: containerd - `/run/containerd/containerd.sock`, CRI-O - `/run/crio/crio.sock`;
`/var/run` на Linux часто является ссылкой на `/run`, но путь и доступ надо подтвердить на
каждой ноде. Не монтируйте socket по памяти: найдите его и сопоставьте с runtime.

```bash
sudo find /run /var/run -type s \( -name containerd.sock -o -name crio.sock \) -print 2>/dev/null
kubectl get nodes -o wide
```

Агент наблюдения имеет повышенные права, поскольку читает системные события и часто
использует host namespaces, `/proc`, runtime socket или eBPF. Это обоснованное исключение
для security-agent, но его надо ограничивать: доверять официальному образу и chart,
фиксировать версию, давать права только Falco namespace, обновлять agent и не использовать
его ServiceAccount для обычных workload.

## 29.3. Установка: пакет на ноде или DaemonSet

Выбор зависит от модели эксплуатации. Для экзамена или одной ноды пакетную установку
проще диагностировать через доступный service manager и его журнал; `systemctl` и
`journalctl` применимы только на systemd-системах. Для Kubernetes-кластера обычно выбирают
DaemonSet: один Falco Pod размещается на каждой ноде и получает доступ к событиям именно
этой ноды.

### Установка пакетом на ноде

Ниже показан типичный поток для Debian/Ubuntu. Перед установкой берите актуальные
инструкции и ключ репозитория из [документации Falco](https://falco.org/docs/), сверяйте
архитектуру и поддерживаемый kernel. В production закрепляйте проверенную версию пакета в
системе управления конфигурацией, а не обновляйте agent непроверенным latest.

Имя unit и даже наличие systemd зависят от дистрибутива и способа установки: не считайте
`falco.service` универсальным. Если пакет зарегистрировал systemd unit, обнаружьте его;
иначе используйте service manager и журналы, поставленные с пакетом.

```bash
# На ноде: добавить официальный Falco repository согласно текущей документации Falco.
sudo apt-get update
sudo apt-get install -y falco

falco_unit="$(systemctl list-unit-files --no-legend 2>/dev/null   | awk '$1 ~ /^falco.*\.service$/ {print $1; exit}')"
test -n "$falco_unit" || { echo 'Falco systemd unit не найден'; exit 1; }
sudo systemctl enable --now "$falco_unit"
sudo systemctl is-active "$falco_unit"
sudo systemctl status "$falco_unit" --no-pager
sudo journalctl -u "$falco_unit" -b --no-pager | tail -n 80
```

Если агент не стартует, сначала смотрят его журнал, kernel и загруженные модули, а не
меняют правила вслепую. Для systemd-варианта:

```bash
uname -r
sudo journalctl -u "$falco_unit" -b --no-pager | grep -Ei 'driver|ebpf|module|error|fail'
lsmod | grep -i falco || true
sudo falco --version
```

На некоторых системах пакет получает правила и configuration files из нескольких каталогов.
Не предполагают конкретный driver по имени пакета: startup log должен показать, что Falco
загрузил, и предупредить об ошибках schema validation или probe.

### Установка DaemonSet через Helm

Официальный chart развёртывает Falco как DaemonSet. Значения chart и driver backend нужно
сверять с версией chart: названия ключей могут меняться. В примере выбран современный
драйвер **modern eBPF** (`modern_ebpf`, CO-RE - не требует kernel headers и сборки модуля)
и namespace `falco`; перед production-install используйте зафиксированную версию chart,
совместимую с вашим Kubernetes и kernel.

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Укажите проверенную версию chart через переменную CHART_VERSION.
CHART_VERSION="${CHART_VERSION:?set chart version}"
helm upgrade --install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --version "$CHART_VERSION" \
  --set driver.kind=modern_ebpf

kubectl -n falco get daemonset,pods -o wide
kubectl -n falco rollout status daemonset/falco --timeout=5m
kubectl -n falco logs daemonset/falco -c falco --tail=80
```

DaemonSet должен иметь Pod на каждой подходящей ноде. Сравните desired/current/ready и
проверьте ноды без Pod: taint, nodeSelector, tolerations, несовместимая архитектура или
ошибка driver часто объясняют неполное покрытие.

```bash
kubectl -n falco get daemonset falco \
  -o custom-columns='NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,CURRENT:.status.currentNumberScheduled,READY:.status.numberReady'
kubectl -n falco get pods -l app.kubernetes.io/name=falco -o wide
kubectl -n falco describe daemonset falco
```

Для package-install custom rule находится на самой ноде. Для DaemonSet правило обычно
передают через values/ConfigMap chart или монтируют как отдельный файл. Не редактируйте
файл внутри живого Falco Pod: изменение исчезнет после restart/rollout и не пройдёт review.
Сохраняйте правило в Git, применяйте декларативно и перезапускайте/rollout restart только
после проверки синтаксиса.

## 29.4. Файлы конфигурации и стандартные правила

На package-install обычные пути Falco:

| Путь | Назначение | Как с ним работать |
|---|---|---|
| `/etc/falco/falco.yaml` | основной configuration: event sources, outputs, порядок rules files | менять осознанно, валидировать и перезапускать service |
| `/etc/falco/falco_rules.yaml` | upstream standard rules, macros и lists | читать и обновлять пакетом; не хранить свои правки здесь |
| `/etc/falco/falco_rules.local.yaml` | локальные override и custom rules | предпочтительное место для своих правил |
| `/etc/falco/rules.d/` | дополнительные rule files в package/container configuration | использовать, только если каталог включён в `rules_files` текущей конфигурации |

Фактический список и порядок загружаемых rules задаёт `rules_files` в применённой конфигурации Falco и подтверждает startup log. Старое имя `rules_file` относится к Falco до 0.38 и сейчас deprecated; в новых конфигурациях и материалах используйте `rules_files`.

```bash
sudo grep -n '^rules_files:' /etc/falco/falco.yaml
sudo falco --support
sudo sed -n '1,120p' /etc/falco/falco_rules.local.yaml

# Проверить main config и весь ruleset, который он реально загружает.
sudo falco -c /etc/falco/falco.yaml --dry-run
```

Сначала ищут готовое стандартное правило и его поля. Это быстрее и безопаснее, чем писать
condition по памяти:

```bash
sudo grep -nE '^- rule:|^- macro:|^- list:' /etc/falco/falco_rules.yaml | head -n 50
sudo falco --list | grep -E '^(proc\.name|proc\.cmdline|fd\.name|container|k8s\.)'
```

Команда `falco --list` и конкретные доступные поля зависят от версии. Для Kubernetes
контекста полезны `k8s.ns.name`, `k8s.pod.name`, `k8s.pod.uid`; для процесса -
`proc.name`, `proc.cmdline`, `proc.exepath`; для файлового события - `fd.name`; для
контейнера - `container.id`, `container.name`, `container.image`. Если поле недоступно,
Falco может напечатать `<NA>`: это не повод подменять расследование догадкой.

## 29.5. Синтаксис Falco: rule, condition, output, priority, macro и list

Falco rules - YAML-документы. `rule` определяет детектор, `condition` - булево выражение
по event fields, `output` - строку alert, а `priority` задаёт серьёзность. `macro` даёт
переиспользуемое имя фрагменту condition; `list` хранит набор значений. Это делает правило
короче, облегчает review и позволяет менять allowlist/denylist без копирования выражений.

```mermaid
flowchart LR
    event["syscall event\nproc, fd, container"] --> condition["condition\nсопоставить поля"]
    macro["macro\nобщая часть условия"] --> condition
    list["list\nнабор имён или путей"] --> condition
    condition --> rule["rule\nсработал или нет"]
    rule --> output["output\nконтекст alert"]
    rule --> priority["priority\nNOTICE/WARNING/CRITICAL"]
    style event fill:#326ce5,color:#fff
    style macro fill:#673ab7,color:#fff
    style list fill:#673ab7,color:#fff
    style condition fill:#f4b400,color:#000
    style rule fill:#0f9d58,color:#fff
    style output fill:#db4437,color:#fff
    style priority fill:#db4437,color:#fff
```

Пример локального файла ниже ловит интерактивный запуск `sh` или `bash` внутри
контейнера: `proc.tty != 0` требует выделенный TTY. Он намеренно пишет Pod/namespace,
image, доступный image digest, host и команду: alert без этих полей мало пригоден для triage.

```yaml
# /etc/falco/falco_rules.local.yaml
- list: interactive_shell_names
  items: [sh, bash]

- list: sensitive_files
  items: [/etc/shadow, /etc/sudoers]

- macro: container_process_exec
  condition: evt.type in (execve, execveat) and container

- rule: Interactive shell in container
  desc: Detect an interactive shell with a TTY started in a container
  condition: >
    container_process_exec and proc.name in (interactive_shell_names) and proc.tty != 0
  output: >
    Interactive shell in container (user=%user.name command=%proc.cmdline process=%proc.name
    container_id=%container.id container_image=%container.image
    container_image_digest=%container.image.digest host=%host.name
    namespace=%k8s.ns.name pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, shell, mitre_execution]

- rule: Sensitive file opened in container
  desc: Detect a container-local sensitive file opened by a container process
  condition: >
    open_read and container and fd.name in (sensitive_files)
  output: >
    Sensitive file opened in container (file=%fd.name user=%user.name
    command=%proc.cmdline container_id=%container.id container_image=%container.image
    container_image_digest=%container.image.digest host=%host.name
    namespace=%k8s.ns.name pod=%k8s.pod.name)
  priority: WARNING
  tags: [container, filesystem, mitre_credential_access]
```

`/etc/shadow` в этом правиле - путь, наблюдаемый в mount namespace контейнера. Он не
доказывает чтение `/etc/shadow` ноды, если в контейнер не смонтирована host filesystem.
`%container.image.digest` зависит от metadata runtime и может быть `<NA>`; `%host.name`
связывает alert с хостом, на котором Falco увидел событие.

`open_read` в примере - macro из standard Falco rules. Поэтому порядок rules files имеет
значение: upstream rules с этим macro должны загрузиться раньше local file. Если ваш
configuration использует другое имя macro или не включает standard rules, либо определите
нужное условие локально, либо исправьте порядок `rules_files` - не обходите ошибку простым
удалением condition.

В современных Falco не используйте `evt.dir`: поле deprecated с 0.42. Для этого detector достаточно ограничить syscall через `evt.type` и container context.

После изменения всегда выполняют проверку до restart. Для package-install:

```bash
sudo falco -c /etc/falco/falco.yaml --dry-run
# Если Falco установлен как systemd unit, используйте ранее обнаруженное имя unit.
sudo systemctl restart "$falco_unit"
sudo journalctl -u "$falco_unit" -n 80 --no-pager
```

Для DaemonSet проверка происходит в Pod startup log. Добавьте file декларативно через
values/ConfigMap, примените изменение и дождитесь rollout:

```bash
kubectl -n falco rollout restart daemonset/falco
kubectl -n falco rollout status daemonset/falco --timeout=5m
kubectl -n falco logs daemonset/falco -c falco --tail=120
```

### Правила, suppression и типичные ошибки

Сначала пишут детектор в audit-режиме и измеряют шум. Если легитимный workload запускает
shell, ограничивайте исключение по конкретному image, namespace, Pod label или command,
а не отключайте глобальное правило. Обоснование исключения, владелец и срок пересмотра
должны быть видны в Git.

| Ошибка | Последствие | Что сделать |
|---|---|---|
| изменить `falco_rules.yaml` | обновление пакета затрёт local change, сложно сравнивать с upstream | хранить override в `falco_rules.local.yaml` или отдельном подключённом файле |
| output без namespace/Pod | alert нельзя быстро связать с workload | добавить `%k8s.ns.name`, `%k8s.pod.name`, container и process fields |
| condition только по `proc.name=sh` | много ложных срабатываний вне контейнеров | добавить `container`, тип события и точный контекст |
| исключить весь namespace навсегда | злоумышленник получает тихую зону | делать минимальное, документированное и временное исключение |
| не валидировать rule | Falco может не запуститься после restart | запускать validation и читать startup log до rollout |

## 29.6. Сгенерировать shell-событие и прочитать alert

Проверка должна доказать всю цепочку: Falco запущен на ноде, custom rule загружен,
действие произошло, alert содержит ожидаемый `output`. Один статус `Running` у Pod или
`active` у service доказывает только запуск агента.

Создадим короткоживущий Pod с известным образом и выполним shell. Работайте в отдельном
namespace и удалите тестовый Pod после проверки.

```bash
kubectl create namespace runtime-demo
kubectl -n runtime-demo run falco-shell \
  --image=busybox:1.36 \
  --restart=Never \
  --command -- sleep 600
kubectl -n runtime-demo wait --for=condition=Ready pod/falco-shell --timeout=90s

# -it выделяет TTY и соответствует условию proc.tty != 0 в правиле.
kubectl -n runtime-demo exec -it falco-shell -- sh -c 'id; echo falco-rule-test'
```

При package-install смотрят журнал, заданный service manager. Для systemd unit это
`journalctl`; на системах с настроенным syslog Falco output также может попасть в
`/var/log/syslog`. Фильтр ищет имя правила из `output`, а не случайное слово из startup log.

```bash
sudo journalctl -u "$falco_unit" --since '5 minutes ago' --no-pager \
  | grep 'Interactive shell in container'

# Проверяйте syslog только если он настроен как output Falco в этой системе.
sudo grep 'Interactive shell in container' /var/log/syslog | tail -n 20
```

При DaemonSet alert будет в stdout конкретного Falco Pod на ноде, где исполнялся
`falco-shell`. Сначала найдите ноду тестового Pod, затем Pod Falco на этой ноде.

```bash
node="$(kubectl -n runtime-demo get pod falco-shell -o jsonpath='{.spec.nodeName}')"
kubectl -n falco get pods -o wide --field-selector spec.nodeName="$node"

falco_pod="$(kubectl -n falco get pods -l app.kubernetes.io/name=falco \
  --field-selector spec.nodeName="$node" \
  -o jsonpath='{.items[0].metadata.name}')"
kubectl -n falco logs "$falco_pod" -c falco --since=5m \
  | grep 'Interactive shell in container'
```

Ожидаемый смысл строки, а не фиксированные значения, такой:

```text
Warning Interactive shell in container (user=root command=sh -c id; echo falco-rule-test process=sh container_id=... container_image=busybox:1.36 container_image_digest=... host=worker-1 namespace=runtime-demo pod=falco-shell)
```

Значения `user`, container ID, имя Pod и timestamp всегда зависят от окружения. Сохраните
результат для расследования или лабораторной проверки, затем сопоставьте его с workload:

```bash
kubectl -n runtime-demo get pod falco-shell -o wide
kubectl -n runtime-demo get pod falco-shell \
  -o jsonpath='{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}'
kubectl delete namespace runtime-demo
```

Если alert не появился, не ослабляйте rule до бессмысленного состояния. Проверьте по
порядку: Falco Pod/service работает на **той же** ноде; local file подключён; validation и
startup log успешны; название поля совместимо с версией; тест действительно выполнил
`execve` в контейнере; output смотрят в правильном journal/Pod. Затем повторите тест с
уникальной строкой в `output`, чтобы не перепутать новый alert со старым.

## 29.7. Проверка готовности Falco

Минимальная operational-проверка после установки или изменения rules:

1. **Покрытие нод.** Для package-install агент и выбранный driver подтверждены на каждой
   ноде. Для DaemonSet число `READY` должно совпасть с `DESIRED`, а список Falco Pod должен
   явно содержать ровно один ready Pod на каждой intended node; отдельно проверяют ноды,
   исключённые selector, taint или toleration.
2. **Backend.** Startup log подтверждает загрузку `kmod` или `modern_ebpf` и event source
   `syscall`; в нём нет driver/schema errors.
3. **Rules.** `falco_rules.local.yaml` валиден, подключён после standard rules, его
   изменения хранятся декларативно.
4. **Событие.** Контролируемое действие - shell в test Pod - создаёт alert с именем rule.
5. **Контекст.** Alert содержит минимум namespace, Pod, container/image, доступный image
   digest, host/node, process/command и время; инженер может найти владельца workload.
6. **Реакция.** Определено, кто получает alert и что происходит дальше: triage, escalation,
   изоляция, evidence preservation и closure.

Пример быстрой проверки package-install:

```bash
sudo systemctl is-active --quiet "$falco_unit" && echo 'Falco systemd unit: active'
sudo falco --validate /etc/falco/falco_rules.local.yaml
sudo journalctl -u "$falco_unit" -b --no-pager | tail -n 100
```

И DaemonSet:

```bash
kubectl -n falco rollout status daemonset/falco --timeout=5m
kubectl -n falco get daemonset falco \
  -o custom-columns='NAME:.metadata.name,DESIRED:.status.desiredNumberScheduled,CURRENT:.status.currentNumberScheduled,READY:.status.numberReady'
kubectl -n falco get pods -l app.kubernetes.io/name=falco \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase,FALCO_READY:.status.containerStatuses[?(@.name=="falco")].ready'
kubectl get nodes -o wide
kubectl -n falco logs daemonset/falco -c falco --tail=100
```

Сопоставьте колонку `NODE` с каждой intended node, а `FALCO_READY` - с `true`. Если node
отсутствует, `READY < DESIRED` или Pod не ready, это непокрытая нода, а не успешная установка.

```bash
# Показать selector и scheduling-причины для отсутствующих нод.
kubectl -n falco describe daemonset falco
```

## 29.8. Как это применяют в продакшене

### Production extension: lifecycle rules и доставка alert

Следующие практики дополняют базовую установку и проверку выше как production extension:
они нужны для управляемого жизненного цикла rules и централизованной доставки, но не
заменяют проверку локального alert на каждой ноде.

- **Управляйте rule artifact через `falcoctl`.** Устанавливайте проверенный artifact с
  точной версией, проверяйте установленный набор и включение его файлов в `rules_files`.
  Не выполняйте массовое обновление artifact без теста совместимости с версией Falco и
  review изменений rules.

  ```bash
  falcoctl artifact install falco-rules:<verified-rules-version>
  falcoctl artifact list
  sudo falco -c /etc/falco/falco.yaml --dry-run
  ```

  Фиксируйте в Git и configuration management версии Falco package/chart, `falcoctl` и
  каждого rules artifact. Обновление сначала проверяют в test-кластере, затем закрепляют
  новую совместимую версию, а не оставляют плавающий `latest`.
- **Доставляйте alert штатным output.** Для прямой интеграции используйте native HTTP(S)
  output Falco; для fan-out в SIEM, chat или incident system используйте Falcosidekick как
  downstream получатель Falco events. Falco plugins - отдельный механизм для event source и
  связанных полей/обработки, а не универсальный output channel. Подключайте plugin только
  по его совместимой документации и проверяйте его отдельно.

- **Проектируйте сигнал вместе с реакцией.** Каждое high-priority rule должно иметь owner,
  канал доставки, runbook и понятный способ отличить expected action от incident. Alert без
  реакции становится шумом.
- **Развёртывайте на всех нужных нодах.** DaemonSet должен учитывать taint, nodeSelector,
  control-plane и отдельные worker pools. Нода без Falco - слепая зона, а не «частично
  установленный агент».
- **Храните local rules как код.** Rule, исключения, severity и output проходят ревью в Git,
  применяются GitOps/Helm и проверяются в тестовой среде. Upstream rules не редактируют.
- **Сохраняйте контекст и evidence.** Отправляйте структурированный alert в централизованную
  logging/SIEM-систему, сохраняйте event time, node, container ID, image digest, Pod,
  namespace, process и rule version.
- **Тюньте без выключения наблюдаемости.** Сначала измеряйте false positives; уточняйте
  condition по image, command или namespace. Временная suppression должна иметь owner и
  срок истечения.
- **Комбинируйте контроли.** Falco обнаруживает действие, но не исправляет CVE и не
  запрещает опасный Pod сам по себе. Его связывают с image scan, admission policy,
  read-only filesystem, audit logs, NetworkPolicy и incident response.

## 29.9. Мини-глоссарий

- **runtime detection** - обнаружение подозрительного поведения уже работающего процесса.
- **Falco** - rule engine для security-событий runtime, использующий kernel events и
  container/Kubernetes metadata.
- **syscall** - системный вызов процесса к ядру, например `execve` или `openat`.
- **kernel module** - загружаемый модуль ядра; один из способов захвата событий Falco.
- **eBPF** - механизм безопасно ограниченных программ в ядре, используемый как backend
  наблюдения за событиями.
- **DaemonSet** - Kubernetes workload, обеспечивающий Pod агента на каждой выбранной ноде.
- **rule** - именованный детектор Falco с condition, output и priority.
- **condition** - булево выражение по полям события, определяющее срабатывание rule.
- **macro** - переиспользуемый именованный фрагмент condition.
- **list** - именованный список значений, используемый в condition.
- **output** - формат alert; должен содержать расследовательский контекст.
- **priority** - серьёзность alert, например `NOTICE`, `WARNING`, `ERROR` или `CRITICAL`.
- **`falco_rules.local.yaml`** - предпочтительный файл для локальных override и custom rules.

## 29.10. Итоги главы

- Falco наблюдает поведение во время выполнения и дополняет, но не заменяет image scan,
  admission policy и Kubernetes audit logs.
- Он получает события syscall через `kmod` или `modern_ebpf`, затем обогащает их
  container/Kubernetes metadata и проверяет rules.
- Для одной ноды подходит пакет с доступным в системе service manager; для кластера
  используют DaemonSet, проверяя coverage каждой intended node и startup log driver.
- Rule состоит из `condition`, `output` и `priority`; `macro` и `list` предотвращают
  копирование логики. Свои правила хранят в `falco_rules.local.yaml`, а не в upstream file.
- Полезный alert несёт rule name, время, process/command, container/image, доступный image
  digest, host/node, namespace и Pod.
- Установка считается проверенной только после контролируемого runtime-события и найденного
  alert с ожидаемым output.

## 29.11. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Нужно быстро определить, где запущен Falco, найти активные rules files,
создать или изменить local rule, проверить синтаксис, сгенерировать указанное действие и
вывести alert с нужными полями в требуемый файл. Не редактируйте upstream rules без причины
и не ограничивайтесь командой запуска: критерий обычно проверяет конкретный event/output.

**В реальной работе.** Falco помогает заметить действия после компрометации, которые не
видны в manifest: shell, доступ к socket, запись в чувствительный путь или неожиданный
процесс. Ценность создаёт не сам агент, а полное покрытие нод, versioned rules, качественный
контекст, управляемый уровень шума и связка alert с incident-response процессом.

## 29.12. Вопросы для самопроверки

1. Почему успешный image scan не заменяет runtime detection?
2. Какие системные данные Falco видит через kernel module/eBPF и зачем ему metadata
   container runtime?
3. Когда выберете package-install, а когда DaemonSet? Как докажете покрытие всех нод?
4. Чем отличаются `rule`, `condition`, `output`, `priority`, `macro` и `list`?
5. Почему custom rule нужно класть в `falco_rules.local.yaml`, а не менять
   `falco_rules.yaml`?
6. Какие поля должны быть в output, чтобы alert можно было связать с Kubernetes workload?
7. Как воспроизводимо проверить правило на shell в контейнере и где читать его alert для
   package-install и DaemonSet?
8. Почему исключение целого namespace из детектора хуже точного временного исключения?

## Практика

Практика runtime-домена объединяет правила Falco, Kubernetes audit logs и иммутабельность
контейнера. В ней нужно запустить или проверить Falco, поймать shell-событие, добавить
custom rule с проверяемым output и сохранить evidence для `check_result`.

🧪 Лаба 112 (Runtime: Falco, audit-логи и иммутабельность): [tasks/cks/labs/112](../../labs/112/README_RU.MD)

Для формата экзаменационных заданий и работы с `check_result` используйте также
[лабораторные материалы CKA](../../../cka/labs/112/README_RU.MD). Содержание CKS-лабы
расширяет этот формат Falco, audit logs и runtime-immutability задачами.

Полезная документация: [Falco documentation](https://falco.org/docs/) ·
[Falco rules](https://falco.org/docs/concepts/rules/) ·
[Falco installation](https://falco.org/docs/setup/)

---
[Оглавление](../README_RU.md) · [Глава 28](../28/ru.md) · [Глава 30](../30/ru.md)
