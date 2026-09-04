<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Глава 22. Container Runtime Sandbox: gVisor, Kata Containers и RuntimeClass

> **Что дальше.** `securityContext`, Pod Security Admission и admission-policy уменьшают
> привилегии процесса и не пускают опасный YAML, но обычный контейнер всё ещё использует
> ядро ноды. Для недоверенной или особо ценной multi-tenant нагрузки нужна более сильная
> граница исполнения: sandboxed runtime. В этой главе выбираем gVisor (`runsc`) или Kata
> Containers, подключаем их к containerd через `RuntimeClass` и доказываем, что Pod запущен
> именно в sandbox, а не обычным OCI runtime.

> **Что нужно знать из CKA.** Pod, `nodeSelector`, taints/tolerations и диагностика
> планирования разобраны в [главе 16 CKA](../../../cka/course/16/ru.md),
> `securityContext` и least privilege - в [главе 20 CKA](../../../cka/course/20/ru.md),
> а CRI, kubelet и containerd - в [главе 40 CKA](../../../cka/course/40/ru.md). Здесь
> используем эти механизмы для изоляции недоверенного workload, а не повторяем их основы.

## 22.1. Почему обычного контейнера недостаточно для multi-tenancy

Container изолирует PID, mount, network и другие namespaces, а cgroups ограничивают
ресурсы. Но процесс контейнера обычно системно вызывает **то же ядро Linux**, что и
процессы ноды и соседних Pod. Уязвимость ядра, container runtime или неверно выданная
capability может превратить выполнение кода в container escape.

В single-tenant кластере с проверенными образами это может быть приемлемым риском. В
multi-tenancy доверие другое: одна команда, customer workload, CI-job или supplied plugin
не должны получать столь же близкий путь к ядру, как системные компоненты платформы.
`privileged`, host namespaces, `hostPath`, Docker/containerd socket и широкие RBAC-права
при этом остаются опасными **даже в sandbox**.

```mermaid
flowchart LR
    tenantA["tenant A\nобычный Pod"] --> kubelet["kubelet + containerd"]
    tenantB["tenant B\nнедоверенный Pod"] --> kubelet
    kubelet --> runc["runc\nпроцесс близко к ядру ноды"]
    kubelet --> sandbox["gVisor или Kata\nдополнительная граница"]
    runc --> kernel["ядро ноды"]
    sandbox --> kernel
    kernel --> host["нода и другие Pod"]
    style tenantA fill:#326ce5,color:#fff
    style tenantB fill:#db4437,color:#fff
    style runc fill:#f4b400,color:#000
    style sandbox fill:#673ab7,color:#fff
    style kernel fill:#0f9d58,color:#fff
    style host fill:#9e9e9e,color:#fff
```

Sandbox добавляет слой между workload и хостом. Это defence in depth, а не разрешение
ослабить остальные controls:

| Контроль | За что отвечает | Sandbox его не заменяет |
|---|---|---|
| RBAC и ServiceAccount | кто может создать или изменить объект | sandbox не ограничивает API-доступ identity |
| PSA / Kyverno / Gatekeeper | какие поля Pod разрешены | sandbox не должен принимать `privileged` Pod |
| `securityContext` | UID, capabilities, seccomp, filesystem процесса | безопасный runtime не отменяет least privilege |
| NetworkPolicy | с кем workload может общаться | runtime не задаёт сетевой allow-list |
| gVisor / Kata | граница между workload и ядром/хостом | runtime не сканирует образ и не проверяет подпись |

Выбор runtime - свойство класса workload, а не пользователя. Platform team создаёт
RuntimeClass, выделяет совместимые nodes, задаёт admission-policy и наблюдает за ними.
Разработчик указывает разрешённый `runtimeClassName`; ему не нужен доступ к containerd или
SSH на worker node.

## 22.2. Два подхода: gVisor и Kata Containers

**gVisor** запускает контейнер через `runsc`. Его userspace kernel (`Sentry`) перехватывает
большую часть системных вызовов и реализует их в userspace, снижая прямую поверхность атаки
ядра host. В зависимости от платформы gVisor использует platform `systrap` или `ptrace`.
Это обычно легче виртуальной машины, но не полностью отдельное guest kernel.

**Kata Containers** запускает Pod sandbox в lightweight VM: отдельное guest kernel и
hypervisor boundary. Container внутри VM видит guest kernel, а не kernel ноды. Граница
сильнее и семантика Linux ближе к обычной VM, однако выше startup latency, расход памяти и
операционная сложность; нужна поддержка virtualization на node и в облаке.

| Свойство | Обычный `runc` | gVisor / `runsc` | Kata Containers |
|---|---|---|---|
| Ядро, видимое workload | host kernel | userspace kernel gVisor поверх host kernel | отдельное guest kernel VM |
| Граница изоляции | namespaces/cgroups | syscall interception + sandbox | VM/hypervisor + guest kernel |
| Плотность и старт | базовый ориентир | обычно ближе к контейнеру | обычно дороже по памяти и старту |
| Совместимость syscall/kernel features | максимальная | возможны неподдерживаемые syscalls/features | обычно ближе к VM, но зависит от runtime |
| Типичный выбор | trusted platform workload | untrusted web/CI/multi-tenant code | сильная изоляция, регуляторный или особо рискованный workload |

Не оценивайте runtime только по таблице. Протестируйте реальные образы: eBPF, FUSE, low-level
network tools, nested containers, device plugins, huge pages, GPU и host mounts могут быть
несовместимы либо потребовать отдельного дизайна. Нельзя silently fallback с sandbox на
`runc`: тогда заявленная граница исчезнет именно в момент, когда нужна.

## 22.3. Как Kubernetes выбирает runtime: `RuntimeClass` и handler

`RuntimeClass` - cluster-scoped API Kubernetes. Он связывает понятное workload имя с
**handler** из конфигурации CRI на ноде. Важно различать эти строки:

- `metadata.name: gvisor` - имя, которое указывает разработчик в `spec.runtimeClassName`;
- `handler: runsc` - точное имя runtime в CRI configuration containerd;
- `runtime_type: io.containerd.runsc.v1` - implementation runtime в конфигурации
  containerd; это не имя RuntimeClass.

API server не проверяет наличие handler на каждой ноде. Ошибка проявится, когда kubelet
попытается создать Pod. Поэтому handler, бинарники, shim и совместимые nodes готовят до
создания workload.

```mermaid
flowchart LR
    pod["Pod\nruntimeClassName: gvisor"] --> api["kube-apiserver\nRuntimeClass gvisor"]
    api --> rc["handler: runsc\nscheduling constraints"]
    rc --> scheduler["scheduler\nвыбирает sandbox node"]
    scheduler --> kubelet["kubelet на node"]
    kubelet --> cri["containerd CRI\nruntime handler runsc"]
    cri --> shim["containerd-shim-runsc-v1"]
    shim --> sentry["runsc / gVisor Sentry"]
    style pod fill:#326ce5,color:#fff
    style rc fill:#673ab7,color:#fff
    style scheduler fill:#f4b400,color:#000
    style cri fill:#0f9d58,color:#fff
    style sentry fill:#db4437,color:#fff
```

Минимальный RuntimeClass для уже установленного `runsc`:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
kubectl get runtimeclass
kubectl get runtimeclass gvisor -o yaml
```

`RuntimeClass` не является Namespace и не выдаёт право использовать runtime. Ограничьте
создание и изменение RuntimeClass только platform administrators. Если не каждый namespace
должен запускать изолированный или дорогой runtime, ограничьте `runtimeClassName` через
admission-policy и назначайте его платформенным шаблоном.

## 22.4. Scheduling в RuntimeClass: `nodeSelector`, taints и tolerations

Не ставьте gVisor или Kata на все nodes «на всякий случай». Отделите sandbox pool: в нём
есть нужные binary/shim, проверенная конфигурация, capacity и observability. Обычные
workloads не должны случайно занять этот pool, а sandbox workload не должен попасть на node
без нужного handler.

RuntimeClass может содержать `scheduling`. Kubernetes добавляет его `nodeSelector` и
`tolerations` к Pod, который ссылается на этот class. Selector RuntimeClass и selector Pod
объединяются: конфликтующие значения делают Pod unschedulable. Tolerations добавляются, но
не заменяют taint - node остаётся закрытой для Pod без toleration.

```bash
# Выполняет platform administrator только на подготовленном worker.
kubectl label node worker-sandbox sandbox.runtime/gvisor=true
kubectl taint node worker-sandbox sandbox.runtime/gvisor=true:NoSchedule
```

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
```

Под с `runtimeClassName: gvisor` получает оба scheduling constraints автоматически:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: untrusted-web
  namespace: tenant-a
spec:
  runtimeClassName: gvisor
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.30.4-alpine-slim
    ports:
    - containerPort: 8080
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

Не копируйте `nodeSelector` и toleration в каждый Deployment, если они уже в RuntimeClass:
это создаёт два источника истины. Явные pod-level constraints допустимы только когда они
сужают выбор, например по architecture или zone. Сначала проверьте итоговый Pod и Event:

```bash
kubectl -n tenant-a apply -f untrusted-web.yaml
kubectl -n tenant-a get pod untrusted-web -o wide
kubectl -n tenant-a get pod untrusted-web -o jsonpath='{.spec.runtimeClassName}{"\n"}'
kubectl -n tenant-a get pod untrusted-web -o jsonpath='{.spec.nodeSelector}{"\n"}'
kubectl -n tenant-a describe pod untrusted-web
```

### Kata RuntimeClass

Kata class устроен так же, но handler обязан совпадать с containerd. Не называйте class
`kata`, если handler на node называется `kata-qemu`, иначе конфигурация станет неясной.
Один из понятных вариантов - одинаковое короткое имя:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
scheduling:
  nodeSelector:
    sandbox.runtime/kata: "true"
  tolerations:
  - key: sandbox.runtime/kata
    operator: Equal
    value: "true"
    effect: NoSchedule
```

Для Kata pool предварительно проверьте, что hardware virtualization доступна и разрешена
гипервизору. Простая метка node не создаёт эту возможность.

## 22.5. Установка gVisor и подключение `runsc` к containerd

Ниже - runbook для выделенной Linux node с containerd. Версии `runsc`, shim, Kubernetes и
containerd должны быть заранее протестированы и зафиксированы в Git/IaC. Не подменяйте
production runtime командой `latest` в середине incident.

### 1. Установить `runsc` и shim

У gVisor binary и containerd shim должны соответствовать одной проверенной версии и
архитектуре node. Получите release из доверенного внутреннего repository или официального
pinned release, проверьте checksum/signature и установите с root-only правами. Команды ниже
показывают форму установки; `<VERSION>` и `<ARCH>` заменяются утверждёнными значениями.

```bash
VERSION=<approved-gvisor-version>
ARCH=$(uname -m)
BASE_URL="https://storage.googleapis.com/gvisor/releases/release/${VERSION}/${ARCH}"

curl -fsSLO "${BASE_URL}/runsc"
curl -fsSLO "${BASE_URL}/runsc.sha512"
sha512sum -c runsc.sha512
sudo install -o root -g root -m 0755 runsc /usr/local/bin/runsc

curl -fsSLO "${BASE_URL}/containerd-shim-runsc-v1"
curl -fsSLO "${BASE_URL}/containerd-shim-runsc-v1.sha512"
sha512sum -c containerd-shim-runsc-v1.sha512
sudo install -o root -g root -m 0755 containerd-shim-runsc-v1 \
  /usr/local/bin/containerd-shim-runsc-v1

runsc --version
command -v containerd-shim-runsc-v1
```

Для package-managed installation используйте пакет из одобренного repository вместо
смешивания package и вручную скачанного shim. В любом варианте путь к shim должен быть в
`PATH` systemd service containerd; проверьте `systemctl show containerd -p Environment` и
unit/drop-in. Не устанавливайте runtime только на control-plane, если Pod планируется на
workers.

### 2. Добавить runtime handler containerd

Сначала сохраните рабочую конфигурацию и посмотрите используемую версию containerd. Путь
плагина в config и допустимые options могут различаться между версиями и дистрибутивами;
проверяйте документацию **вашей** версии и не заменяйте целиком vendor-managed `config.toml`.

```bash
sudo cp -a /etc/containerd/config.toml \
  "/etc/containerd/config.toml.before-runsc.$(date +%F-%H%M%S)"
containerd --version
sudo grep -n -A12 -B2 'runtimes' /etc/containerd/config.toml
```

Для containerd CRI plugin с runtime v1 configuration добавьте handler `runsc` рядом с
остальными `[...runtimes.<name>]`:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
```

Не меняйте `default_runtime_name` на `runsc`: системные DaemonSet, CNI, CSI и отлаженные
обычные workload могут требовать `runc`. RuntimeClass должен выбирать sandbox явно.

Проверьте TOML и перезапускайте daemon только по процедуре change management: рестарт
containerd может затронуть создание новых контейнеров и работу ноды. На production node
сначала cordon/drain с учётом DaemonSet и PDB, затем примените проверенную конфигурацию.

```bash
sudo systemctl restart containerd
sudo systemctl is-active --quiet containerd && echo 'containerd: active'
sudo journalctl -u containerd -b --no-pager | tail -n 80
sudo crictl info | jq '.config.containerd.runtimes.runsc'
```

`crictl info` должен показать `runsc` с `runtimeType` `io.containerd.runsc.v1`. Если
handler не появился или service не active, остановитесь: RuntimeClass пока не создавайте и
не переносите workload на эту node.

## 22.6. Установка Kata Containers и containerd handler

Kata требует не только `containerd-shim-kata-v2`, но и выбранный hypervisor, kernel/rootfs
и совместимую host virtualization. Предпочтителен vendor-supported package или проверенный
Kata release, развёрнутый конфигурационным management на отдельном pool. Не копируйте
бинарник с laptop на production worker.

После установки проверьте именно runtime и virtualization, а не только наличие пакета:

```bash
command -v containerd-shim-kata-v2
kata-runtime --version
sudo kata-runtime check
ls -l /dev/kvm
```

`kata-runtime check` и `/dev/kvm` - примеры для распространённой QEMU/KVM конфигурации;
точная команда и hypervisor зависят от выбранного Kata runtime. Отсутствующий `/dev/kvm`,
запрещённая nested virtualization или несовместимый instance type означают, что node нельзя
маркировать как `sandbox.runtime/kata=true`.

Контейнеру нужен отдельный CRI handler. Для распространённого Kata v2 shim:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  runtime_type = "io.containerd.kata.v2"
```

После change/restart containerd проверьте handler так же, как для gVisor:

```bash
sudo systemctl restart containerd
sudo systemctl is-active --quiet containerd && echo 'containerd: active'
sudo crictl info | jq '.config.containerd.runtimes.kata'
```

На некоторых дистрибутивах package создаёт handler с другим именем, например
`kata-qemu`. В этом случае RuntimeClass должен использовать **фактическое** имя handler, а
не пример из статьи. Сверьте `crictl info`, config.toml и `RuntimeClass.spec.handler` до
rollout.

## 22.7. Rollout: от одного Pod к namespace policy

Sandbox может изменить timing, filesystem semantics, network behavior и потребление
ресурсов. Безопасный rollout начинается с отдельного test namespace и одного
representative workload.

1. **Проверить node.** Binary, shim, containerd handler, label и taint должны быть на
   каждой node целевого pool.
2. **Создать RuntimeClass.** Handler и scheduling должны отражать уже работающую node
   configuration.
3. **Запустить positive test.** Непривилегированный Pod c `runtimeClassName` должен стать
   `Running` на sandbox node.
4. **Проверить negative test.** Pod с конфликтующим selector или node без handler не должен
   quietly перейти на обычный runtime; ожидается `Pending` или явный create error.
5. **Проверить приложение.** Readiness, egress, DNS, volumes, latency, shutdown и метрики
   должны соответствовать SLO.
6. **Расширять scope.** Deployment/Job переводят канареечно; admission policy запрещает
   небезопасные сочетания и использование class вне разрешённых namespaces.

Deployment обычно меняют только так:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-worker
  namespace: tenant-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: report-worker
  template:
    metadata:
      labels:
        app: report-worker
    spec:
      runtimeClassName: gvisor
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: worker
        image: registry.example.com/report-worker@sha256:<digest>
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

Не добавляйте `hostNetwork`, `hostPID`, `hostIPC`, `privileged`, hostPath или device mounts,
чтобы «починить» несовместимость sandbox. Это либо ломает модель угроз, либо сигнализирует,
что workload должен быть переработан или запущен в отдельном доверенном pool с явно
документированным исключением.

### Runtime overhead

`RuntimeClass.overhead` сообщает scheduler дополнительный CPU/memory, потребляемый runtime
per Pod. Значения берут из benchmark конкретной версии, node type и workload, а не из
случайного интернет-примера. Без overhead scheduler может переплотнить sandbox node;
с завышенным значением теряется capacity.

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
overhead:
  podFixed:
    memory: "<measured-memory-overhead>"
    cpu: "<measured-cpu-overhead>"
scheduling:
  nodeSelector:
    sandbox.runtime/kata: "true"
```

Изменение overhead влияет на новые Pod и admission/scheduling, поэтому его проверяют в
staging вместе с resource requests/limits и autoscaler behavior.

## 22.8. Проверка: sandbox действительно работает, а не просто указан в YAML

Одной проверки `spec.runtimeClassName` недостаточно: поле показывает intent, а не
успешность запуска нужным runtime. Соберите доказательства на трёх уровнях: Kubernetes,
CRI/containerd и внутри workload. Для диагностики временно сохраняйте node name, runtime
handler, Pod UID и время; это связывает API object с node logs.

```bash
NS=tenant-a
POD=untrusted-web

# 1. Intent и placement Kubernetes.
kubectl -n "$NS" get pod "$POD" -o wide
kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.runtimeClassName}{" node="}{.spec.nodeName}{" phase="}{.status.phase}{"\n"}'
kubectl -n "$NS" describe pod "$POD"

# 2. На выбранной node: CRI runtime и ошибки create sandbox.
sudo crictl pods --name "$POD"
sudo crictl ps -a --name "$POD"
sudo crictl info | jq '.config.containerd.runtimes.runsc'
sudo journalctl -u containerd --since '15 minutes ago' --no-pager | \
  grep -Ei 'runsc|gvisor|kata|sandbox|error'
```

Параметры `crictl` и формат вывода зависят от release. Если CRI не показывает handler
напрямую, используйте идентификатор sandbox/container из `crictl inspectp` и сопоставьте
его с log containerd/shim. Не делайте вывод только по имени Pod: доказательство - создание
sandbox обработчиком `runsc` или `kata` без fallback.

### Наблюдение изнутри Pod и на host

В обычном контейнере `uname -a` обычно показывает kernel ноды. В gVisor syscall results
виртуализируются: `uname`, `/proc` и другие данные могут показывать gVisor-specific или
ограниченную картину. В Kata процесс увидит guest kernel, отдельный от host. Эти признаки
полезны, но их нельзя считать единственным security proof: output может меняться между
версиями и не обязан раскрывать implementation.

```bash
# Внутри sandbox Pod: диагностический отпечаток workload view.
kubectl -n "$NS" exec "$POD" -- sh -c '
  echo "=== uname ==="; uname -a
  echo "=== pid 1 cgroup ==="; cat /proc/1/cgroup
  echo "=== mounts ==="; mount | head -n 20
  echo "=== dmesg (if permitted) ==="; dmesg 2>&1 | head -n 40 || true
'

# На host: host kernel остаётся kernel ноды, а не guest/Sentry view Pod.
uname -a
sudo journalctl -u containerd --since '15 minutes ago' --no-pager | tail -n 120
```

Для учебного gVisor scenario `dmesg` внутри успешно стартовавшего Pod может содержать
признак запуска gVisor, например `Starting gVisor`. Сохраните требуемый артефакт ровно в
формате лабораторной работы; не экстраполируйте одну такую строку на production proof.
В production надёжнее сочетание RuntimeClass, placement, CRI handler/shim logs и
application smoke test.

| Наблюдение | Что доказывает | Чего не доказывает |
|---|---|---|
| `runtimeClassName: gvisor` в Pod | намерение выбрать class | что handler существует на node |
| Pod `Running` на sandbox node | scheduler и kubelet приняли Pod | сам по себе не показывает implementation runtime |
| `crictl info` содержит `runsc`/`kata` | node configured для handler | что конкретный Pod не был создан иначе |
| containerd/shim log с Pod UID/container ID | конкретный sandbox создан нужным handler | что приложение функционально |
| `uname`/`dmesg` внутри | workload view отличается от host; полезный сигнал | полную корректность isolation boundary |
| `uname` и logs на host | host-side context и runtime activity | содержимое guest/userspace kernel Pod |

## 22.9. Типовые отказы и безопасная диагностика

| Симптом | Вероятная причина | Проверка и действие |
|---|---|---|
| Pod `Pending`, `didn't match Pod's node affinity/selector` | нет node с label из RuntimeClass либо конфликт selector Pod | `kubectl describe pod`; сравните `spec.nodeSelector` и labels nodes |
| Pod `Pending`, taint не tolerated | Pod не получил или не совпадает toleration RuntimeClass | проверьте `kubectl get runtimeclass -o yaml`, `kubectl describe node` |
| `FailedCreatePodSandBox`, unknown runtime handler | нет блока handler, ошибочное имя или containerd не перечитан | сверить `RuntimeClass.handler`, config.toml, `crictl info`; исправить и restart по runbook |
| `executable file not found` для shim | shim не установлен или вне PATH service containerd | проверить `command -v`, permissions и systemd Environment |
| gVisor Pod стартует, приложение ломается | syscall, mount или network feature не поддержаны/иначе реализованы | минимальный reproducer, runtime docs, исправить app либо выбрать иной approved runtime |
| Kata не стартует | отсутствует KVM/nested virtualization, hypervisor/kernel config или capacity | `kata-runtime check`, `/dev/kvm`, cloud instance capabilities, logs shim |
| Pod оказался на обычной node | RuntimeClass без `scheduling`, pool не tainted или указан другой class | проверить class, node name, labels/taints; не считать это sandbox rollout |

Не «лечите» `FailedCreatePodSandBox` удалением `runtimeClassName`: это превращает
security failure в незаметный downgrade. Оставьте workload остановленным, пока platform
team не подтвердит другой допустимый RuntimeClass или отдельный risk acceptance.

## 22.10. Как это применяют в продакшене

- **Выделяйте pool по доверию.** gVisor/Kata nodes получают только sandbox workload через
  RuntimeClass scheduling, label и `NoSchedule` taint; системные agents и trusted workloads
  живут отдельно.
- **Сохраняйте default `runc`.** Перевод всей платформы на новый runtime без compatibility
  matrix повышает blast radius. Sandbox включают по class и канареечно.
- **Держите handler как контракт.** Version binaries, shim, containerd config и
  RuntimeClass меняются одной reviewed change. Случайная разница имён `runsc`, `kata` и
  `kata-qemu` - источник outages.
- **Запрещайте dangerous combinations.** PSA/admission-policy не должны допускать
  `privileged`, host namespaces, hostPath/socket mounts и broad exemptions в tenant
  namespace независимо от RuntimeClass.
- **Считайте capacity.** Измеряйте runtime overhead, startup latency, density, node
  pressure и cold-start. Kata pool часто требует отдельного autoscaling profile.
- **Мониторьте границу.** Alert на `FailedCreatePodSandBox`, containerd/shim errors,
  sandbox node NotReady, рост startup latency и неожиданное размещение outside pool.
- **Планируйте обновления.** Обновление host kernel, containerd, gVisor/Kata и Kubernetes
  тестируют как одну compatibility matrix. Перед drain проверьте PDB и выведите node из
  scheduling, а не обновляйте runtime под активными tenant Pod вслепую.

## 22.11. Как это пригодится: на экзамене и в реальной работе

- **На экзамене.** Нужно уметь отличить `RuntimeClass`, CRI handler и `runtime_type`,
  направить Pod на подготовленный sandbox pool через `scheduling`, labels, taints и
  tolerations, а также диагностировать `FailedCreatePodSandBox` без небезопасного fallback
  на `runc`.
- **В реальной работе.** Эти навыки позволяют изолировать недоверенные tenant-, CI- и
  plugin-workload, безопасно раскатывать gVisor или Kata по канарейке, учитывать overhead и
  подтверждать runtime по данным Kubernetes, CRI/containerd и application smoke test.

## 22.12. Мини-глоссарий

- **Container runtime sandbox** - runtime, добавляющий границу между workload и host kernel.
- **gVisor** - sandbox runtime с userspace kernel; CRI handler часто называется `runsc`.
- **`runsc`** - OCI runtime gVisor и имя handler в данном примере.
- **Kata Containers** - runtime, запускающий Pod sandbox в lightweight VM с guest kernel.
- **RuntimeClass** - cluster-scoped Kubernetes resource, выбирающий CRI handler и опциональные
  overhead/scheduling constraints.
- **handler** - имя runtime в CRI configuration, которое должно совпадать с
  `RuntimeClass.spec.handler`.
- **shim** - процесс/бинарник containerd, связывающий containerd с конкретным runtime.
- **sandbox pool** - выделенные nodes с подготовленным runtime, label, taint и capacity.
- **runtime overhead** - фиксированные дополнительные CPU/memory, которые scheduler учитывает
  для Pod выбранного RuntimeClass.

## 22.13. Итоги главы

- Обычные контейнеры разделяют ядро ноды; для недоверенной multi-tenant нагрузки gVisor или
  Kata добавляют значимую дополнительную границу, но не заменяют RBAC, PSA,
  `securityContext` и NetworkPolicy.
- gVisor (`runsc`) перехватывает системные вызовы через userspace kernel; Kata использует
  lightweight VM и guest kernel. Выбор определяется моделью угроз, compatibility и SLO.
- `RuntimeClass.metadata.name`, `spec.handler` и `containerd runtime_type` - разные уровни
  именования. Handler должен в точности совпасть с CRI configuration каждой target node.
- `RuntimeClass.scheduling` с `nodeSelector` и tolerations вместе с labels/taints ограничивает
  sandbox workload подготовленным node pool.
- Для containerd нужны соответствующие binary и shim, handler в config.toml и controlled
  restart/verification daemon. Default `runc` не меняют без причины.
- Проверка должна связать Pod class и node с handler/shim в CRI/containerd logs, а затем
  подтвердить workload view и application behavior; одного `runtimeClassName` недостаточно.
- Нельзя скрытно удалять `runtimeClassName` после сбоя. Это security downgrade, который
  требует явного решения и компенсирующих controls.

## 22.14. Вопросы для самопроверки

1. Почему namespaces и cgroups не делают обычный контейнер полноценной kernel security
   boundary для недоверенного tenant?
2. В чём ключевая разница между userspace kernel gVisor и guest kernel Kata?
3. Чем отличаются `RuntimeClass.metadata.name`, `handler` и `runtime_type` containerd?
4. Почему API server не может гарантировать, что handler доступен на выбранной node?
5. Как `RuntimeClass.scheduling.nodeSelector` и tolerations взаимодействуют с labels и taints
   sandbox node pool?
6. Почему опасно установить `runsc` default runtime для всего кластера без compatibility
   testing?
7. Какие файлы/binaries должны быть согласованы для gVisor и containerd?
8. Почему `runtimeClassName: gvisor` и `Running` ещё не являются полным доказательством
   sandbox execution?
9. Что означает, если `uname` внутри Kata Pod отличается от `uname` host, и почему этого
   недостаточно как единственного доказательства?
10. Почему удаление `runtimeClassName` ради быстрого восстановления - security downgrade?

## Практика

Отработайте RuntimeClass, `runsc`, scheduling и проверку sandbox в
[лабе 110 - gVisor, Cilium и Istio](../../labs/110/README_RU.MD). Установите `runsc` на
подготовленную node, создайте `RuntimeClass` `gvisor` с handler `runsc`, изолируйте node
label/taint, переведите workload в namespace `team-purple` на этот class и подтвердите
размещение. Для учебного сценария сохраните `dmesg` успешно стартовавшего Pod в требуемый
артефакт и сопоставьте его с данными host/containerd.

Полезные официальные справки: [RuntimeClass](https://kubernetes.io/docs/concepts/containers/runtime-class/),
[RuntimeClass scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling),
[gVisor](https://gvisor.dev/docs/), [gVisor с containerd](https://gvisor.dev/docs/user_guide/containerd/)
и [Kata Containers](https://katacontainers.io/).

---
[Оглавление](../README_RU.md) · [Глава 21](../21/ru.md) · [Глава 23](../23/ru.md)
