<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Глава 03. Linux-механизмы безопасности под капотом

> **Проблема.** Контейнер не является виртуальной машиной: workload делит ядро с нодой,
> и выполнение кода внутри Pod становится опаснее при `privileged`, host namespaces,
> лишних capabilities или доступных mount. Понимание Linux-границ нужно, чтобы несколько
> механизмов изоляции дополняли друг друга и ограничивали последствия container escape,
> а не создавали ложное ожидание одной абсолютной защиты.

> **Что дальше.** В главе 02 мы разложили поверхность атаки Kubernetes по слоям. Теперь рассмотрим механизмы Linux, которыми container runtime изолирует процесс пода: namespaces, cgroups, capabilities и фильтрацию syscalls. Это фундамент CKS, но не отдельный экзаменационный домен: он объясняет, почему ограничения из System Hardening (10%) и Minimize Microservice Vulnerabilities (20%) работают и где у них границы.

> **Что нужно из CKA.** Базовое устройство контейнеров, namespaces, cgroups и runtime разобрано в CKA: [контейнеры](../../../cka/course/00-4-containers/ru.md), [Linux](../../../cka/course/00-5-linux/ru.md) и [network namespaces](../../../cka/course/00-7-netns/ru.md). Здесь не повторяем создание контейнера и базовые команды CKA, а рассматриваем security-свойства, проверку изоляции и пути её обхода.

> 🧠 Изоляция контейнера — сочетание независимых Linux-границ, а не одна «магическая» настройка.

## 03.1. Изоляция контейнера - это набор границ, а не виртуальная машина

Обычный OCI workload под runc/containerd - Linux-процесс на общем ядре ноды. Его изоляция складывается из нескольких независимых механизмов. Это не абсолютная формула для sandbox runtimes: Kata добавляет VM boundary, а gVisor заметно меняет взаимодействие процесса с ядром. Если атакующий получил выполнение кода в контейнере, он сначала ограничен этими границами. Ошибка в одной границе не должна автоматически отменять остальные: это и есть defense in depth.

```mermaid
flowchart TB
    app["Процесс приложения<br/>в контейнере"]

    subgraph isolation["Границы изоляции"]
        direction TB
        boundaries["Независимые<br/>механизмы<br/>работают вместе<br/>не по порядку"]
        ns["namespaces<br/>процессы · сеть<br/>mount · hostname"]
        cg["cgroups<br/>CPU · память · PID<br/>и другие ресурсы"]
        caps["capabilities<br/>точечные<br/>привилегии<br/>вместо root"]
        mac["AppArmor / SELinux<br/>обязательный<br/>контроль доступа"]
        sc["seccomp<br/>допустимый набор<br/>syscalls"]
        boundaries ~~~ ns
        ns ~~~ cg
        cg ~~~ caps
        caps ~~~ mac
        mac ~~~ sc
    end

    kernel["Общее ядро<br/>Linux ноды"]
    app --> boundaries
    sc --> kernel

    style app fill:#326ce5,color:#fff
    style boundaries fill:#e8eaed,color:#202124
    style ns fill:#0f9d58,color:#fff
    style cg fill:#0f9d58,color:#fff
    style caps fill:#0f9d58,color:#fff
    style mac fill:#673ab7,color:#fff
    style sc fill:#673ab7,color:#fff
    style kernel fill:#db4437,color:#fff
```

Общее ядро - принципиальная граница контейнерной модели. Уязвимость ядра или container runtime может превратить выполнение кода в контейнере в container escape. Поэтому нельзя считать контейнер полноценной security boundary для недоверенной нагрузки: для неё применяют несколько слоёв hardening и при необходимости sandboxed runtime из главы 22.

Типичный путь атаки выглядит так:

```mermaid
flowchart TB
    exploit["Уязвимость<br/>приложения<br/>или вредоносный<br/>образ"] --> shell["Shell в контейнере"]
    shell --> probe["Разведка<br/>uid · capabilities<br/>mounts · сеть"]
    probe --> weak["Слабая конфигурация<br/>privileged<br/>hostPath<br/>опасная capability<br/>уязвимость runtime"]
    weak --> escape["Выход из изоляции<br/>захват ноды"]
    style exploit fill:#db4437,color:#fff
    style shell fill:#f4b400,color:#000
    style probe fill:#326ce5,color:#fff
    style weak fill:#db4437,color:#fff
    style escape fill:#c0392b,color:#fff
```

Задача инженера - убрать ненужные привилегии, ограничить последствия DoS и сделать попытку escape наблюдаемой или невозможной. Поле `securityContext` является интерфейсом Kubernetes к части этих механизмов, но его базовый синтаксис уже есть в [главе CKA о SecurityContext](../../../cka/course/20/ru.md).

> 🧠 Namespace меняет видимость ресурса, но не удаляет его с ноды и не отменяет явно выданный доступ.

## 03.2. Linux namespaces: что контейнер видит, а чего не видит

Namespace даёт процессу отдельное представление о ресурсе ядра. Процесс не исчезает с ноды, но через API ядра видит только объекты своего namespace. Kubernetes и runtime создают необходимые namespaces при старте sandbox пода.

**Короткое напоминание о запуске обычного Pod.** Пользователь или controller отправляет его спецификацию в API server, scheduler выбирает ноду, а kubelet на этой ноде передаёт Pod container runtime. Runtime создаёт pod sandbox (в том числе нужные namespaces), затем запускает в нём контейнеры Pod. Полный путь создания Pod, роль pause-контейнера и sandbox разобраны в [главе 4 CKA](../../../cka/course/04/ru.md).

| Namespace | Изолирует | Что обычно видит процесс контейнера | Security-следствие |
|---|---|---|---|
| `PID` | дерево процессов и PID | свой PID 1 и процессы контейнера или пода | не может штатно инспектировать процессы хоста |
| `NET` | интерфейсы, маршруты, порты, firewall namespace | `eth0`, свой IP и таблицу маршрутов пода | сеть пода не равна сети ноды |
| `MNT` | mount points и файловую иерархию | rootfs образа и объявленные volumes | host filesystem не должен быть доступен без mount |
| `UTS` | hostname и domain name | hostname пода | не раскрывает hostname ноды |
| `IPC` | shared memory, semaphores, message queues | IPC-объекты sandbox пода | не читает IPC других подов или ноды |
| `USER` | UID/GID mapping и capabilities | UID, отображённый в user namespace | UID 0 внутри можно отобразить в непривилегированный UID хоста |

Граница не абсолютна. Например, несколько контейнеров одного пода обычно разделяют `NET` namespace и могут общаться через `localhost`. Поля `hostNetwork`, `hostPID` и `hostIPC` отключают соответствующую границу. Их следует запрещать обычным workload через Pod Security Admission или policy engine.

> 🔬 UID/GID mapping, idmapped mounts и требования к версии kernel/runtime для `hostUsers: false`.

### User namespaces: отдельное отображение UID/GID

User namespace не включается автоматически. В Kubernetes это opt-in: `spec.hostUsers: false` запрашивает user namespace для Pod; в v1.36 функция стала Stable/GA.

**Проблема.** Без user namespace UID 0 внутри обычного контейнера - это тот же числовой UID 0, что и root на ноде. Namespaces скрывают часть ресурсов хоста, но сами по себе не меняют это отображение идентичности. Если процесс получает доступ за ожидаемую границу контейнера, host воспринимает его как root - последствия ошибки в приложении, конфигурации или изоляции становятся существенно тяжелее.

**Защитный эффект.** При поддержке со стороны kubelet, container runtime и ноды UID 0 внутри контейнера отображается в непривилегированный UID на хосте. Приложение по-прежнему может считать себя root **внутри** Pod, но для ядра и файлов хоста это уже не host root. Так user namespace снижает blast radius компрометации и добавляет ещё одну границу между процессом контейнера и нодой.

**Подводные камни.**

- Это не замена least privilege, capabilities, seccomp и MAC: user namespace не исправляет уязвимость ядра и не делает безопасными `privileged`, `hostPath` или host namespaces.
- Совместимость ноды, runtime, volumes и workload обязательна; ниже есть короткий чек-лист, что именно проверить до rollout.
- Pod Security Standards для Pod с user namespaces ослабляют проверки `runAsNonRoot` и `runAsUser`, потому что root внутри такого Pod не равен привилегированному пользователю хоста. Это не отменяет внутренних правил приложения: если оно не должно работать от root, требуйте `runAsNonRoot` и здесь.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-web
  namespace: demo
spec:
  hostUsers: false
  containers:
  - name: web
    image: nginx:1.30.4
```

Перед включением user namespaces проверьте совместимость в трёх местах:

1. **Нода.** Нужен Linux **6.3+**: начиная с него tmpfs поддерживает idmapped mounts. Filesystem должен поддерживать idmapped mounts для `/var/lib/kubelet/pods` и используемых volumes. Выполните на **каждой** ноде, куда может попасть Pod:

   ```bash
   uname -r
   sudo findmnt -T /var/lib/kubelet/pods \
     -o TARGET,SOURCE,FSTYPE,OPTIONS
   ```

   Первая команда должна показать ядро 6.3 или новее; вторая - filesystem, который надо сверить с поддержкой idmapped mounts для образа ноды. Эти команды выявляют неподходящую ноду, но не заменяют canary-запуск Pod с `hostUsers: false`.

2. **Runtime.** Минимальные ориентиры документации: runc >= 1.2, crun >= 1.9 (рекомендуется >= 1.13), containerd >= 2.0 или CRI-O >= 1.25. На целевой ноде посмотрите версию CRI runtime и OCI runtime:

   ```bash
   sudo crictl version
   sudo runc --version 2>/dev/null || sudo crun --version
   ```

   В выводе `crictl version` нужны `runtimeName` и `runtimeVersion`; вторую команду сопоставьте с runtime, который фактически использует нода. Не делайте вывод о версии runc только по версии `kubectl` или API Kubernetes.

3. **Workload и storage.** User namespaces меняют отображение UID/GID. Чтобы файловый volume сохранял корректные владельца и права внутри Pod, kubelet должен подключить его как idmapped mount. У `volumeDevices`/raw block volumes нет filesystem для такого отображения, а Linux NFS client не поддерживает нужные idmapped mounts. Если workload использует один из этих типов, kubelet не сможет подготовить volume для Pod с `hostUsers: false`, и Pod не стартует.

   **Обычный EBS PVC не запрещён.** Если EBS CSI driver предоставляет PVC как filesystem (типичный случай: `volumeMode: Filesystem`, том подключён через `volumeMounts`), такой Pod может работать с user namespaces при поддержке idmapped mounts у filesystem ноды. Например, ext4 и XFS поддерживаются на Linux 6.3+. Но тот же EBS PVC с `volumeMode: Block`, переданный контейнеру через `volumeDevices`, - raw block volume и поэтому несовместим. Поэтому проверяйте storage **до** rollout: это показывает, нужно ли отказаться от user namespaces для workload или сначала сменить способ подключения storage. Для уже созданного test-Pod или аналогичного workload в staging сначала проверьте raw block devices:

   ```bash
   NS=demo
   POD=userns-web

   kubectl get pod -n "$NS" "$POD" -o json | jq -r '
     (
       .spec.containers[]?,
       .spec.initContainers[]?,
       .spec.ephemeralContainers[]?
     ) as $container
     | $container.volumeDevices[]?
     | "container=\($container.name) raw-block-volume=\(.name)"
   '
   ```

   Пустой вывод означает, что `volumeDevices` не используются. Затем проверьте прямые NFS volumes и PV, подключённые через PVC:

   ```bash
   kubectl get pod -n "$NS" "$POD" -o json | jq -r '
     .spec.volumes[]? | select(.nfs)
     | "direct NFS volume: \(.name)"
   '

   for pvc in $(kubectl get pod -n "$NS" "$POD" \
     -o jsonpath='{range .spec.volumes[?(@.persistentVolumeClaim)]}{.persistentVolumeClaim.claimName}{"\n"}{end}'); do
     pv=$(kubectl get pvc -n "$NS" "$pvc" \
       -o jsonpath='{.spec.volumeName}')
     kubectl get pv "$pv" -o json | jq -r '
       if .spec.nfs then "NFS PV: \(.metadata.name)"
       elif .spec.csi then "CSI driver: \(.spec.csi.driver)"
       else "PV without direct NFS: \(.metadata.name)"
       end
     '
   done
   ```

   Любой вывод о raw block или NFS означает, что этот workload не готов к user namespaces. Для CSI volume строка `CSI driver` сама по себе не означает совместимость: её надо подтвердить документацией и тестом конкретного CSI-драйвера.

Есть и жёсткие ограничения API: при `hostUsers: false` нельзя указать `hostNetwork: true`, `hostIPC: true` или `hostPID: true`. Это не настройка hardening, которую можно проигнорировать: Kubernetes отклонит такой Pod.

На ноде namespaces можно посмотреть утилитой `lsns`. Это диагностическая команда для администратора ноды, а не команда, которую надо давать приложению:

```bash
sudo lsns \
  -t pid \
  -t net \
  -t mnt \
  -t uts \
  -t ipc \
  -t user
sudo crictl ps
CONTAINER_ID="${CONTAINER_ID:?set target container id from crictl ps}"
sudo crictl inspect "$CONTAINER_ID" | jq '.info.pid'
PID=$(sudo crictl inspect "$CONTAINER_ID" | jq -r '.info.pid')
sudo lsns -p "$PID"
```

Для проверки, что контейнер находится не в host PID namespace, достаточно сравнить inode namespace у процесса контейнера и PID 1 ноды:

```bash
sudo readlink /proc/1/ns/pid
sudo readlink /proc/"$PID"/ns/pid
# Значения должны различаться для обычного пода.
```

Внутри пода полезна безопасная первичная диагностика:

```bash
kubectl exec -n demo deploy/web -- sh -c '
  echo "hostname: $(hostname)"
  echo "pid namespace: $(readlink /proc/1/ns/pid)"
  echo "network namespace: $(readlink /proc/1/ns/net)"
  ps -ef
  ip route
'
```

Не путайте PID 1 контейнера с PID 1 хоста. PID namespace скрывает процессы, но не отменяет доступ, который вы явно выдали: `hostPath` с `/proc`, `privileged: true` или `hostPID: true` меняют модель угроз. Для диагностики таких полей используйте:

```bash
kubectl get pod -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" hostPID="}{.spec.hostPID}{" hostNetwork="}{.spec.hostNetwork}{" hostIPC="}{.spec.hostIPC}{"\n"}{end}'
```

> 🧠 Namespace ограничивает видимость, cgroup — потребление; `limits` создают ресурсную границу, а `requests` помогают планированию.

## 03.3. cgroups: ресурсные пределы как защита от DoS

Если namespace отвечает на вопрос «что процесс видит», cgroup отвечает на вопрос «сколько ресурса он может потребить». Container runtime помещает процессы контейнера в cgroup и kubelet применяет limits и requests из спецификации Pod.

Без memory limit процесс может занять память ноды и вызвать memory pressure, eviction других подов или kernel OOM. Без PID limit fork bomb может исчерпать таблицу PID. CPU request участвует в scheduling и распределении CPU, а CPU limit задаёт жёсткий ceiling через throttling; слишком низкий CPU limit способен ухудшить latency даже при свободном CPU. Поэтому memory/PID limits дают более прямую границу для DoS, а CPU limit подбирают осознанно по профилю нагрузки. Это доступность кластера, а значит security-сценарий, а не только вопрос производительности.

```mermaid
flowchart TB
    attack["DoS в контейнере<br/>память без конца<br/>или fork bomb"]
    limit["cgroup<br/>контейнера<br/>memory · CPU<br/>PID limits"]
    result["Предел сработал<br/>OOM · throttling<br/>отказ создания PID"]

    attack --> limit --> result

    style attack fill:#db4437,color:#fff
    style limit fill:#326ce5,color:#fff
    style result fill:#0f9d58,color:#fff
```

Минимальный пример лимитов для процесса, который способен обслуживать небольшой HTTP-трафик:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bounded-web
  namespace: demo
spec:
  containers:
  - name: web
    image: nginx:1.30.4
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
```

> 🔬 `spec.resources` на уровне Pod — beta-возможность Kubernetes v1.34 для общего resource budget контейнеров.

### Pod-Level Resources: общая граница Pod

**Pod-Level Resources** находятся в Beta с Kubernetes v1.34 и включены по умолчанию. Через `spec.resources` можно задать общий `requests` и `limits` Pod для CPU, memory и hugepages: это aggregate budget всего Pod, а не замена явных ресурсов контейнера. Aggregate Pod limit — реальная общая граница для контейнеров Pod; container-level limits остаются отдельными пределами каждого контейнера.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-budget-web
  namespace: demo
spec:
  resources:
    requests:
      cpu: "500m"
      memory: 128Mi
    limits:
      cpu: "1"
      memory: 256Mi
  containers:
  - name: app
    image: nginx:1.30.4
```

Сохраните пример как `pod-budget-web.yaml` и проверьте именно общий budget в `spec.resources`:

```bash
kubectl apply -f pod-budget-web.yaml
kubectl wait -n demo --for=condition=Ready pod/pod-budget-web --timeout=120s
kubectl get pod -n demo pod-budget-web \
  -o jsonpath='{.spec.resources}{"\n"}'
kubectl describe pod -n demo pod-budget-web
```

На cgroup v2 лимиты видны через файлы `memory.max`, `cpu.max` и `pids.max`; расположение cgroup конкретного процесса показывает `/proc/<pid>/cgroup`:

```bash
sudo cat /proc/"$PID"/cgroup
CGROUP=$(awk -F: '$1 == "0" {print $3}' /proc/"$PID"/cgroup)
sudo cat "/sys/fs/cgroup${CGROUP}/memory.max"
sudo cat "/sys/fs/cgroup${CGROUP}/cpu.max"
sudo cat "/sys/fs/cgroup${CGROUP}/pids.max"
```

На старой ноде с cgroup v1 контроллеры расположены в отдельных mount points, поэтому не копируйте путь из cgroup v2 без проверки. Сначала определите режим:

```bash
stat -fc %T /sys/fs/cgroup
# cgroup2fs означает cgroup v2.
```

Запомните эти границы по отдельности:

- **Внутри workload: `requests` и `limits`.** `requests` влияют на scheduler и QoS, но сами по себе не останавливают прожорливый процесс. Жёсткую границу задают `limits`: для CPU это ceiling через возможный throttling, поэтому CPU limit не выбирают произвольно низким.
- **На уровне namespace: `ResourceQuota` и `LimitRange`.** Ресурсы одного Pod не защищают namespace от суммарного потребления. `ResourceQuota` ограничивает его общий бюджет, а `LimitRange` задаёт defaults и допустимые границы для каждого workload. Вместе они не позволяют одной команде вытеснить остальных неполным манифестом.
- **PID: limit задаёт администратор ноды.** В YAML обычного Pod нельзя указать «этому workload разрешено N процессов». Вместо этого администратор задаёт kubelet параметр `podPidsLimit` - максимальное число PID **для одного Pod** на этой ноде. Kubelet применяет его через PID cgroup. Поэтому проверка состоит из двух шагов: сначала найдите `podPidsLimit` в конфигурации kubelet, затем у уже запущенного Pod проверьте `pids.max` в его cgroup.
- **При memory pressure: OOM в cgroup.** Ядро может завершить процесс контейнера в области соответствующей cgroup. Если завершается основной процесс, kubelet перезапускает контейнер в соответствии с `restartPolicy`.
- **Проверяйте безопасно.** Не доказывайте работу memory limit намеренным OOM на production-ноде.

> 🎯 Уберите `privileged`, host namespaces, избыточные capabilities и `allowPrivilegeEscalation: true`; задайте `capabilities.drop: [ALL]`, `RuntimeDefault` и нужный MAC-профиль.

## 03.4. Linux capabilities: root надо дробить

UID 0 не является единственным признаком привилегий. Ядро Linux делит часть полномочий root на capabilities. У процесса есть несколько наборов capabilities, включая permitted, effective, inheritable, bounding и ambient. Проверка только `id` не доказывает, что процесс безопасен.

Некоторые capabilities особенно опасны для обычного приложения:

| Capability | Риск | Нормальная причина выдачи |
|---|---|---|
| `CAP_SYS_ADMIN` | широкий набор административных операций, mount и namespace-операции; частый компонент escape-цепочек | почти никогда не нужен бизнес-приложению |
| `CAP_SYS_MODULE` | загрузка и выгрузка kernel modules | системный компонент ноды, не pod приложения |
| `CAP_SYS_PTRACE` | трассировка и чтение памяти совместимых процессов | узкий диагностический инструмент |
| `CAP_NET_ADMIN` | изменение интерфейсов, маршрутов и firewall | CNI и сетевой агент |
| `CAP_DAC_OVERRIDE` | обход файловых DAC-проверок | не выдавать workload без явной причины |
| `CAP_SETUID` / `CAP_SETGID` | смена UID/GID | специальный bootstrap, не steady state приложения |
| `CAP_BPF` / `CAP_PERFMON` | работа с BPF и performance-механизмами ядра | наблюдаемость на ноде с отдельной моделью доверия |

Посмотрите capabilities файла и процесса на ноде:

```bash
sudo getcap -r /usr/local/bin 2>/dev/null
sudo capsh --print
sudo getpcaps "$PID"
```

`getcap` показывает file capabilities, которые executable получает при запуске. `getpcaps "$PID"` показывает capabilities указанного процесса; `capsh --print` без аргумента показывает состояние текущей shell, а не ранее найденного container PID. Команды требуют права на ноде для чужого процесса; это ожидаемо и само является защитой.

Перед добавлением `NET_BIND_SERVICE` проверьте значение `net.ipv4.ip_unprivileged_port_start` в network namespace целевого Pod. Если порог равен `0`, непривилегированный процесс уже может слушать низкий порт, и capability не нужна:

```bash
kubectl exec -n demo <pod> -- cat /proc/sys/net/ipv4/ip_unprivileged_port_start
```

Для обычного непривилегированного контейнера `allowPrivilegeEscalation: false` устанавливает для процесса Linux `no_new_privs`: дочерний процесс после `exec` не должен получить новые привилегии через setuid/setgid-биты или file capabilities.

Есть важное исключение Kubernetes: `allowPrivilegeEscalation` фактически всегда `true`, если контейнер запущен с `privileged: true` или имеет `CAP_SYS_ADMIN`. Поэтому сначала уберите `privileged` и чрезмерные capabilities; `allowPrivilegeEscalation: false` - дополнительная граница, а не способ обезопасить такой контейнер.

При `allowPrivilegeEscalation: true` (значение по умолчанию) Kubernetes не ставит `no_new_privs`. Само `true` не выдаёт capability и не делает контейнер privileged, но оставляет путь к повышению привилегий: скомпрометированный непривилегированный процесс может выполнить setuid/setgid-программу или файл с capabilities из образа и получить предложенный этим файлом UID/GID или capability. Так RCE от имени пользователя приложения может превратиться в root или процесс с дополнительными capabilities **внутри контейнера**, расширяя последствия атаки и возможные escape-цепочки. Если приложению не нужен такой exec, безопаснее установить `false`.

Это важная, но не единственная граница; она не заменяет drop capabilities, seccomp и MAC. В Kubernetes безопасная отправная точка - удалить всё и добавить одну capability только при документированной необходимости. Только если настройка sysctl и требования приложения это подтверждают, legacy-приложению для TCP 80 может потребоваться `NET_BIND_SERVICE`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capability-example
  namespace: demo
spec:
  containers:
  - name: web
    image: nginx:1.30.4
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

Проверка проявленной конфигурации и состояния процесса:

```bash
kubectl apply -f capability-example.yaml
kubectl get pod -n demo capability-example \
  -o jsonpath='{.spec.containers[0].securityContext.capabilities}{"\n"}'
kubectl exec -n demo capability-example -- sh -c 'grep Cap /proc/1/status'
```

Значения `CapEff` в `/proc/1/status` закодированы шестнадцатеричной маской. Для человекочитаемого разбора используйте `capsh --decode=<значение>` на ноде или в диагностическом образе, которому это средство доверенно установлено:

```bash
capsh --decode=0000000000000400
# Пример: 0x400 соответствует cap_net_bind_service.
```

`privileged: true` не является заменой настройки capabilities. Такой контейнер получает все Linux capabilities, а обычное confinement seccomp, AppArmor и SELinux для него снимается или игнорируется. Для CKS это красный флаг: сначала удалите `privileged`, затем оцените необходимость каждой capability отдельно.

## 03.5. Syscalls и seccomp: сокращаем доступный API ядра

Любое действие пользовательского процесса в итоге приходит в ядро через syscall: открыть файл, создать сокет, выделить память, сменить namespace. Даже если приложению не нужна опасная операция, уязвимый процесс может попытаться вызвать соответствующий syscall. seccomp позволяет ядру разрешить, запретить, логировать или завершить процесс по правилу syscall.

```mermaid
flowchart TB
    process["Процесс контейнера"] --> syscall["syscall<br/>openat · clone<br/>mount · …"]
    syscall --> filter["seccomp profile"]
    filter -->|"allow"| kernel["Ядро выполняет<br/>syscall"]
    filter -->|"errno или kill"| blocked["Операция<br/>заблокирована"]
    filter -->|"log"| audit["Событие для<br/>расследования"]
    style process fill:#326ce5,color:#fff
    style filter fill:#673ab7,color:#fff
    style kernel fill:#0f9d58,color:#fff
    style blocked fill:#db4437,color:#fff
    style audit fill:#f4b400,color:#000
```

seccomp не определяет, кто может читать Kubernetes API, и не исправляет небезопасный образ. Это последний фильтр между скомпрометированным процессом и API ядра. Он особенно полезен вместе с `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false` и MAC-профилем.

Если `seccompProfile` не задан, Pod может остаться `Unconfined`. Исключение - нода, где в kubelet включён `seccompDefault: true`: там отсутствующий профиль получает `RuntimeDefault`. Не считайте это универсальным свойством кластера - проверьте конфигурацию ноды и явным образом задавайте профиль для workload.

Для большинства workload начните с runtime-профиля вместо `Unconfined`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: demo
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.30.4
```

Проверьте именно спецификацию Pod, а не предположение о дефолте runtime:

```bash
kubectl apply -f runtime-default.yaml
kubectl get pod -n demo runtime-default \
  -o jsonpath='{.spec.securityContext.seccompProfile.type}{"\n"}'
kubectl describe pod -n demo runtime-default
```

Кастомный профиль применяют, когда есть измеренный и воспроизводимый набор syscalls. Он хранится на каждой ноде, где может стартовать Pod, в каталоге kubelet `seccomp` profiles. Неправильный путь или отсутствие профиля на выбранной ноде приведут к отказу старта Pod. Полный формат профиля, audit-режим и применение `Localhost` разобраны в главе 17; не создавайте deny-list вслепую, иначе обновление приложения сломается в production.

Для диагностики syscall-поведения на изолированной test-ноде используют `strace`:

```bash
sudo strace -f -p "$PID" -e trace=%file,%network
# Не запускайте длительный strace на высоконагруженном production-процессе.
```

## 03.6. MAC: AppArmor и SELinux дополняют DAC

Обычный Linux DAC проверяет UID, GID и mode bits файла. В модели DAC (Discretionary Access Control, дискреционный контроль доступа) владелец объекта может менять mode bits, например через `chmod`, и тем самым выдавать или отзывать доступ в пределах DAC-модели. Смена UID-владельца файла в Linux требует `CAP_CHOWN`; непривилегированный владелец может изменить группу файла только на группу, членом которой он является. Процесс с достаточными UID/GID или capabilities может пройти либо обойти часть обычных DAC-проверок.

**Mandatory Access Control (MAC, обязательный контроль доступа)** добавляет вторую, обязательную для ядра проверку. Администратор загружает policy, а ядро сопоставляет процесс с его profile/label и проверяет, разрешено ли ему конкретное действие над файлом, сокетом или другим объектом. Даже если DAC уже разрешил доступ, MAC может его запретить; сам процесс не может снять или ослабить policy. Цель - локализовать скомпрометированный процесс: например, веб-сервер не должен читать SSH-ключи или менять системные файлы только потому, что получил дополнительный UID, capability либо доступ к файлу. Поэтому MAC дополняет DAC, capabilities и seccomp, а не заменяет их.

| Механизм | Основная модель | Где чаще встречается | Что проверять |
|---|---|---|---|
| AppArmor | profile-based, пути файлов и операции | Ubuntu, Debian и часть managed-нод | `aa-status`, загруженный profile, `DENIED` в audit log |
| SELinux | labels и type enforcement | RHEL, Fedora, OpenShift и совместимые ОС | `getenforce`, labels, AVC denial в audit log |

Оба механизма решают одну задачу, но профили и эксплуатация не взаимозаменяемы. Нельзя скопировать AppArmor profile в SELinux-ноде и ожидать его применения. Перед проектированием policy определите, что реально включено на образе ноды:

```bash
sudo aa-status || true
getenforce 2>/dev/null || true
sudo journalctl -k --since '10 minutes ago' | grep -Ei 'apparmor|avc|denied' || true
```

В Kubernetes актуальный интерфейс AppArmor - `securityContext.appArmorProfile`. Пример с runtime profile:

```yaml
securityContext:
  appArmorProfile:
    type: RuntimeDefault
```

`RuntimeDefault` требует, чтобы container runtime на ноде предоставлял совместимый default profile; проверяйте это на фактическом node pool, а не только в YAML. Для `Localhost` профиль должен быть заранее загружен на целевую ноду и указан через `localhostProfile`. Это node-local dependency: scheduler не переносит профиль между нодами. Поэтому в production профиль доставляют конфигурационным управлением, проверяют на каждом node pool и ограничивают размещение Pod. Реализацию профиля и разбор `DENIED` изучим в главе 16.

Для SELinux параметры метки задают через `securityContext.seLinuxOptions` только в соответствии с policy образа ноды. При отказе сначала изучайте AVC denial, а не отключайте SELinux. Volumes и файлы на filesystem должны иметь подходящие SELinux labels; особенно внимательно проверяйте hostPath, persistent volumes и общие writable volumes.

> 🧠 Контейнеры разделяют ядро с нодой; sandboxed runtime добавляет изоляцию для недоверенной или высокорисковой нагрузки.

## 03.7. Границы изоляции, sandboxed runtime и диагностика escape-рисков

namespaces, cgroups, capabilities, seccomp и MAC работают в одном ядре. Если риск-профиль требует сильной границы между tenant-ами, используйте sandboxed runtime. gVisor перехватывает значительную часть syscalls в user space, а Kata Containers запускает workload в лёгкой VM. Это снижает вероятность прямого использования ядра ноды ценой совместимости, latency и операционной сложности.

```mermaid
flowchart TB
    normal["Обычный runtime<br/>процесс<br/>→ host kernel"]
    gvisor["gVisor<br/>процесс → Sentry<br/>→ host kernel"]
    kata["Kata Containers<br/>процесс<br/>→ guest kernel<br/>→ VM boundary<br/>→ host kernel"]
    risk["Недоверенный tenant<br/>или высокорисковая<br/>нагрузка"] --> gvisor
    risk --> kata
    style normal fill:#f4b400,color:#000
    style gvisor fill:#326ce5,color:#fff
    style kata fill:#673ab7,color:#fff
    style risk fill:#db4437,color:#fff
```

Sandbox не отменяет остальные меры. Даже в gVisor или Kata workload не должен получать `privileged`, host namespaces, Docker socket или широкие RBAC-права. Сначала примените least privilege, затем выберите RuntimeClass по модели угроз. Установка `runsc`, `RuntimeClass` и планирование на совместимые nodes разобраны в главе 22.

> 🔬 Forensic-style сопоставление декларативного Pod с PID, namespaces и cgroup на ноде.

Практический чеклист расследования подозрительного Pod:

```bash
NAMESPACE="${NAMESPACE:?set target namespace}"
POD="${POD:?set target pod name}"

# 1. Найти явные обходы namespaces и privileged-режим.
kubectl get pod -n "$NAMESPACE" "$POD" -o yaml | \
  grep -E 'privileged:|hostPID:|hostIPC:|hostNetwork:|hostPath:|allowPrivilegeEscalation:'

# 2. Посмотреть объявленные Pod-level и container-level securityContext,
#    а также volumes. Это декларативная конфигурация, не доказательство
#    фактически применённых runtime/kernel settings.
kubectl get pod -n "$NAMESPACE" "$POD" -o json | jq '
{
  podSecurityContext: .spec.securityContext,
  containers: [
    (
      .spec.containers[]?,
      .spec.initContainers[]?,
      .spec.ephemeralContainers[]?
    )
    | {
        name: .name,
        securityContext: .securityContext
      }
  ],
  volumes: .spec.volumes
}
'

# 3. На ноде найти Pod sandbox, затем container и его namespace/cgroup.
#    В `crictl ps --name` фильтруется имя контейнера, не имя Pod.
sudo crictl pods \
  --name "^${POD}$" \
  --namespace "^${NAMESPACE}$"
POD_ID="${POD_ID:?set target pod sandbox id from crictl pods}"
sudo crictl ps --pod "$POD_ID"
CONTAINER_ID="${CONTAINER_ID:?set target container id from crictl ps}"
sudo crictl inspect "$CONTAINER_ID" | jq '.info.pid'
PID="$(sudo crictl inspect "$CONTAINER_ID" | jq -r '.info.pid')"
PID="${PID:?failed to get pid from crictl inspect}"
sudo lsns -p "$PID"
sudo cat "/proc/$PID/cgroup"
```

Типичные ошибки:

- Считать UID 0 внутри контейнера автоматическим root на ноде. User mapping и другие границы могут его ограничить, но это всё равно плохая отправная точка для application workload.
- Считать namespace достаточной защитой. `hostPath`, host namespaces, `privileged` и kernel CVE меняют результат.
- Добавлять `CAP_SYS_ADMIN` для исправления симптома. Сначала выясните требуемую операцию и используйте более узкий capability или другой дизайн.
- Оставлять Pod без `limits`, потому что приложение «обычно» мало потребляет. Одного дефекта или злонамеренного запроса достаточно для DoS.
- Включать custom seccomp profile без тестов приложения и без доставки профиля на все целевые nodes.
- Применять AppArmor profile, не убедившись, что профиль загружен на ноде, где scheduler запустил Pod.

> 🏭 Шаблоны workload, admission policy, разделение node pool и наблюдение за отказами закрепляют безопасный baseline и исключения.

## 03.8. Как это применяют в продакшене

- **Закладывают ограничения в шаблон workload.** Базовый Helm chart или platform template задаёт `resources.limits`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault` и non-root запуск. Команда отклоняется от шаблона только с обоснованием.
- **Запрещают опасные обходы policy.** Pod Security Admission уровня `restricted` или Kyverno/Gatekeeper не допускают `privileged`, host namespaces, небезопасные capabilities и отсутствующий seccomp. Детали policy будут в главах 19 и 20.
- **Разделяют node pools по доверию.** CNI, CSI и node agents, которым действительно нужны `NET_ADMIN` или host mounts, работают отдельно от бизнес-нагрузки. Для multi-tenancy выбирают gVisor или Kata через `RuntimeClass`.
- **Наблюдают за отказами, а не отключают защиту.** AppArmor/SELinux denial, seccomp error, OOMKilled и PID exhaustion поступают в логи и метрики. Причину устраняют изменением приложения, writable volume или узкой policy, а не возвратом `privileged: true`.
- **Проверяют фактическое состояние ноды.** Kubernetes manifest описывает желаемое состояние, но profile AppArmor, режим SELinux, cgroup mode и runtime config находятся на node. Их проверяют в image pipeline и в периодическом hardening-аудите.

## 03.9. Мини-глоссарий

- **namespace** - изолированное представление ресурса ядра для группы процессов.
- **PID namespace** - изоляция списка процессов и PID.
- **network namespace** - изоляция интерфейсов, маршрутов и сетевого стека.
- **cgroup** - группа процессов с ограничениями и учётом ресурсов.
- **capability** - отдельная Linux-привилегия, выделенная из полномочий root.
- **CAP_SYS_ADMIN** - чрезмерно широкая capability, опасная для обычной нагрузки.
- **syscall** - системный вызов, через который процесс обращается к ядру.
- **seccomp** - фильтр syscalls, применяемый ядром к процессу.
- **MAC** - Mandatory Access Control, обязательная policy доступа поверх UID/GID и mode bits.
- **AppArmor** - profile-based MAC для Linux.
- **SELinux** - label-based MAC с type enforcement.
- **container escape** - выход из ожидаемой изоляции контейнера к ресурсам ноды или другого tenant-а.
- **sandboxed runtime** - runtime с усиленной границей изоляции, например gVisor или Kata Containers.

## 03.10. Итоги главы

- Контейнер использует общее ядро ноды; его защита складывается из нескольких Linux-механизмов, а не из одной «песочницы».
- `PID`, `NET`, `MNT`, `UTS`, `IPC` и `USER` namespaces ограничивают видимость ресурсов, но host namespaces, `hostPath` и `privileged` могут эту границу обойти. User namespace включается отдельно через `spec.hostUsers: false` и требует поддержки ноды и runtime.
- cgroups ограничивают CPU, memory и PID, защищая ноду и соседние workload от DoS; PID limit задаёт kubelet через `podPidsLimit`, а cgroup OOM может завершить процесс и привести к restart контейнера.
- Capabilities дробят полномочия root. Безопасный baseline - удалить `ALL` и вернуть только документированную минимальную capability после проверки sysctl и реальной потребности.
- seccomp с `RuntimeDefault` уменьшает доступный процессу API ядра; без явно заданного профиля возможен `Unconfined`, если на ноде не включён `seccompDefault`.
- AppArmor и SELinux дополняют обычные права файлов обязательной policy; для них важны runtime/node profile, AVC и labels volumes. Для сильно недоверенной нагрузки дополнительно рассматривают gVisor или Kata.

## 03.11. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Эта глава даёт модель для задач CKS, где нужно объяснить или исправить `capabilities`, seccomp, AppArmor, `privileged`, host namespaces и отсутствие limits. Проверяйте не только YAML: используйте `kubectl get ... -o jsonpath`, `kubectl exec`, а при доступе по SSH - `crictl`, `lsns`, `aa-status` и `/proc/<pid>/cgroup`. Практическое продолжение - лаба 106 и главы 16-17.

**В реальной работе.** Понимание нижнего уровня помогает отличить безопасное исключение от опасного обхода. Если приложение просит `privileged` или `CAP_SYS_ADMIN`, это повод разобрать его вызовы, mounts и архитектуру. Если Pod падает с OOMKilled или profile denial, это наблюдаемый сигнал для точечной правки, а не причина отключать весь hardening.

## 03.12. Вопросы для самопроверки

<details>
<summary>1. Почему контейнер не равен виртуальной машине и какая роль у общего kernel ноды?</summary>

Обычный OCI workload под runc/containerd — это Linux-процесс с общим ядром ноды, а не отдельная VM. Namespaces, cgroups, capabilities, MAC и seccomp создают несколько границ, но уязвимость ядра или runtime может привести от выполнения кода в контейнере к container escape.
</details>

<details>
<summary>2. Какие namespaces разделяют процессы, сеть и mount points, и какие поля Pod могут убрать эти границы?</summary>

`PID` namespace изолирует дерево процессов, `NET` — интерфейсы, маршруты и порты, а `MNT` — mount points и файловую иерархию. Поля `hostPID`, `hostNetwork` и `hostIPC` отключают соответствующие границы; `hostPath` и `privileged: true` также меняют модель доступа к ресурсам ноды.
</details>

<details>
<summary>3. Чем `requests` отличаются от `limits` в сценарии защиты ноды от DoS?</summary>

`requests` влияют на scheduling и QoS, но сами по себе не останавливают прожорливый процесс. Жёсткую границу задают `limits`: memory limit ограничивает последствия memory pressure/OOM, а CPU limit даёт ceiling через throttling; PID limit задаётся kubelet параметром `podPidsLimit`.
</details>

<details>
<summary>4. Почему `CAP_SYS_ADMIN` нельзя выдавать для исправления произвольной ошибки приложения?</summary>

`CAP_SYS_ADMIN` даёт широкий набор административных операций, включая mount и namespace-операции, и часто участвует в escape-цепочках. Вместо исправления симптома нужно определить реально необходимую операцию, удалить `ALL` capabilities и вернуть только одну узкую capability при документированной необходимости.
</details>

<details>
<summary>5. Какие команды помогут сопоставить container с host PID, namespaces и cgroup?</summary>

На ноде используют `sudo crictl ps`, затем `sudo crictl inspect "$CONTAINER_ID" | jq '.info.pid'`, чтобы получить PID контейнера. Для проверки применяют `sudo lsns -p "$PID"` и `sudo cat "/proc/$PID/cgroup"`; inode PID namespace можно сравнить командами `readlink /proc/1/ns/pid` и `readlink /proc/"$PID"/ns/pid`.
</details>

<details>
<summary>6. Чем seccomp дополняет capabilities и почему `RuntimeDefault` лучше, чем `Unconfined` для обычного workload?</summary>

Capabilities ограничивают отдельные привилегии, а seccomp фильтрует доступный процессу API ядра на уровне syscalls. Явный `RuntimeDefault` сокращает этот набор для обычной нагрузки, тогда как при отсутствии профиля Pod может остаться `Unconfined`, если на ноде не включён `seccompDefault`.
</details>

<details>
<summary>7. В чём эксплуатационная разница между AppArmor и SELinux?</summary>

AppArmor использует profile-based policy по путям и операциям и типичен для Ubuntu/Debian, а SELinux применяет labels и type enforcement на RHEL/Fedora/OpenShift. Их профили не взаимозаменяемы: перед настройкой проверяют `aa-status` либо `getenforce` и разбирают AppArmor `DENIED` или SELinux AVC denial, а не отключают MAC.
</details>

<details>
<summary>8. Когда одной контейнерной изоляции недостаточно и зачем нужен sandboxed runtime?</summary>

Для недоверенных tenant-ов или высокорисковой нагрузки общая с нодой kernel boundary может быть недостаточной. gVisor перехватывает значительную часть syscalls в user space, а Kata запускает workload в лёгкой VM, уменьшая риск прямого использования ядра ценой совместимости, latency и операционной сложности.
</details>

## Практика

🧪 [Лаба 106 - AppArmor + seccomp](../../labs/106/README_RU.MD) связывает эти механизмы с работающими профилями на ноде и проверкой блокировки действий в Pod. Перед ней изучите [главу 16](../16/ru.md) об AppArmor и [главу 17](../17/ru.md) о seccomp; для усиленной изоляции продолжите с [главой 22](../22/ru.md) о sandboxed containers.

🌐 Дополнительная интерактивная практика (killer.sh/killercoda, внешний ресурс): [container-namespaces-docker](https://killercoda.com/killer-shell-cks/scenario/container-namespaces-docker) · [container-namespaces-podman](https://killercoda.com/killer-shell-cks/scenario/container-namespaces-podman)

## Справочные материалы

- [Kubernetes: ограничения безопасности ядра Linux](https://kubernetes.io/docs/concepts/security/linux-kernel-security-constraints/)
- [Kubernetes: User Namespaces](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/)

---
[Оглавление](../README_RU.md) · [Глава 02](../02/ru.md) · [Глава 04](../04/ru.md)
