[Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Глоссарий курса CKS

[← Оглавление курса](README_RU.md) · [Путеводитель CKS](CKS_RU.md)

Единый алфавитный справочник терминов CKS. Термин приведён на английском, описание — на русском, а в колонке «Главы» даны ссылки на места, где он разобран.

| Термин | Описание | Главы |
|--------|----------|-------|
| **4C** | Модель слоёв Cloud, Cluster, Container и Code для оценки защиты Kubernetes. | [02](02/ru.md) |
| **Admission control** | Этап обработки запроса API server после authentication и authorization, до записи объекта в etcd. | [01](01/ru.md), [20](20/ru.md) |
| **Admission policy** | Правило, которое разрешает, изменяет или отклоняет запрос к Kubernetes API. | [01](01/ru.md), [20](20/ru.md) |
| **Admission scan** | Контроль при создании workload, использующий результаты сканирования или связанные attestations. | [28](28/ru.md) |
| **Admission verification** | Обязательная проверка происхождения или подписи образа до сохранения Pod API server. | [26](26/ru.md) |
| **aescbc** | Локальный provider шифрования AES-CBC с HMAC; ключ хранится в защищённой конфигурации. | [21](21/ru.md) |
| **aesgcm** | AEAD-provider AES-GCM для шифрования API-данных; ключи требуют плановой ротации. | [21](21/ru.md) |
| **allow-list / allowlist** | Явный список разрешённых действий, источников или назначений; всё не перечисленное запрещено. | [12](12/ru.md), [15](15/ru.md), [17](17/ru.md) |
| **anonymous authentication** | Сопоставление запроса без credential с `system:anonymous`; для API и kubelet обычно отключается. | [12](12/ru.md) |
| **AppArmor** | Path-based Linux MAC, ограничивающий разрешённые profile операции процесса. | [03](03/ru.md), [16](16/ru.md) |
| **apparmor_parser** | Утилита проверки, загрузки, замены и выгрузки AppArmor profile. | [16](16/ru.md) |
| **Artifact** | Результат build: например OCI image, SBOM, chart или provenance. | [25](25/ru.md) |
| **Artifact repository** | Контролируемое хранилище артефактов: registry, package- или chart-repository. | [25](25/ru.md) |
| **attack surface** | Все интерфейсы, компоненты и точки входа, через которые возможны атака или ошибка конфигурации. | [02](02/ru.md), [14](14/ru.md), [24](24/ru.md) |
| **Attribution** | Привязка события к процессу, container, Pod, identity, node и времени. | [30](30/ru.md) |
| **audience** | Получатель ServiceAccount token; сервис должен принимать token только со своей audience. | [11](11/ru.md) |
| **audit / enforce / warn** | Независимые PSA-режимы: записать нарушение, отклонить Pod или вернуть предупреждение. | [19](19/ru.md), [31](31/ru.md) |
| **audit backend** | Локальный file backend или webhook backend, получающий выбранные audit policy события. | [32](32/ru.md) |
| **audit event** | Запись API server об одном запросе к Kubernetes API. | [32](32/ru.md) |
| **audit policy** | Упорядоченные правила, задающие audit level и исключаемые стадии событий. | [32](32/ru.md) |
| **auditID** | Идентификатор, связывающий все audit-стадии одного API-запроса. | [32](32/ru.md) |
| **Base image** | Образ в инструкции `FROM`, задающий исходную файловую систему build stage. | [24](24/ru.md) |
| **Bound ServiceAccount token** | Краткоживущий token TokenRequest API, привязанный к ServiceAccount и Pod. | [11](11/ru.md) |
| **BPF filter** | Программа фильтра, выполняемая kernel для системного вызова в seccomp filter mode. | [17](17/ru.md) |
| **break-glass access** | Контролируемый временный привилегированный доступ для аварии или инцидента. | [10](10/ru.md), [15](15/ru.md) |
| **Build context** | Набор файлов, передаваемых builder; его сокращает `.dockerignore`. | [24](24/ru.md) |
| **CAP_SYS_ADMIN** | Чрезмерно широкая Linux capability, опасная для обычной нагрузки. | [03](03/ru.md) |
| **capability** | Отдельная Linux-привилегия из полномочий root; безопасный baseline убирает `ALL` и возвращает только необходимое. | [03](03/ru.md), [18](18/ru.md) |
| **CEL** | Common Expression Language — язык выражений встроенной ValidatingAdmissionPolicy. | [20](20/ru.md) |
| **cgroup** | Группа процессов с ограничениями и учётом CPU, memory, PID и других ресурсов. | [03](03/ru.md) |
| **CI gate** | Обязательная проверка, блокирующая следующий этап pipeline при non-zero exit code. | [27](27/ru.md), [28](28/ru.md) |
| **Cilium** | CNI и security-платформа Kubernetes на eBPF. | [06](06/ru.md), [23](23/ru.md) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | Кластерная политика Cilium; широкое действие требует особенно осторожного rollout. | [06](06/ru.md) |
| **CiliumNetworkPolicy (CNP)** | Namespaced ресурс политики Cilium с правилами L3/L4/L7. | [06](06/ru.md) |
| **cipher suite** | Набор криптографических алгоритмов TLS, совместимый с certificate и клиентами. | [09](09/ru.md) |
| **CIS Kubernetes Benchmark** | Рекомендации CIS по безопасной конфигурации Kubernetes-компонентов и нод. | [01](01/ru.md), [07](07/ru.md) |
| **CKS** | Certified Kubernetes Security Specialist — практическая сертификация по безопасности Kubernetes. | [01](01/ru.md), [33](33/ru.md) |
| **Clair** | Сервисный scanner и indexer уязвимостей container images. | [28](28/ru.md) |
| **complain** | Режим AppArmor, в котором нарушения policy журналируются, но не блокируются. | [16](16/ru.md) |
| **condition** | Булево выражение Falco по полям события, определяющее срабатывание rule. | [29](29/ru.md) |
| **Constraint** | Экземпляр Gatekeeper template с параметрами, match scope и реакцией. | [20](20/ru.md) |
| **ConstraintTemplate** | Rego template и schema параметров для нового типа Gatekeeper constraint. | [20](20/ru.md) |
| **container escape** | Выход из ожидаемой изоляции container к ресурсам node или другого tenant. | [03](03/ru.md) |
| **Container runtime sandbox** | Runtime, добавляющий границу изоляции между workload и host kernel. | [22](22/ru.md) |
| **context** | Именованная комбинация cluster, user и namespace в kubeconfig. | [33](33/ru.md) |
| **Correlation** | Связывание событий разных источников в единую хронологию инцидента. | [30](30/ru.md) |
| **Cosign** | Инструмент Sigstore для подписи и проверки OCI-artifacts. | [26](26/ru.md) |
| **CRI** | Container Runtime Interface; `crictl` обращается к runtime через CRI socket. | [14](14/ru.md), [30](30/ru.md) |
| **CRI socket** | Endpoint связи kubelet и runtime, например `/run/containerd/containerd.sock`. | [14](14/ru.md) |
| **CVE** | Идентификатор публично известной уязвимости. | [13](13/ru.md), [28](28/ru.md) |
| **CycloneDX** | Формат OWASP для inventory компонентов и security analysis в SBOM. | [25](25/ru.md), [28](28/ru.md) |
| **daemon.json** | Конфигурационный файл Docker daemon, обычно `/etc/docker/daemon.json`. | [14](14/ru.md) |
| **DaemonSet** | Kubernetes workload, поддерживающий Pod агента на каждой выбранной node. | [29](29/ru.md) |
| **defense in depth** | Независимые защитные слои, уменьшающие последствия отказа одного control. | [01](01/ru.md), [02](02/ru.md) |
| **deny-list** | Policy, где default action разрешает syscalls, а отдельные syscalls запрещены. | [17](17/ru.md) |
| **Digest** | Неизменяемый SHA-256 identifier конкретного image manifest или artifact, в отличие от mutable tag. | [09](09/ru.md), [24](24/ru.md), [25](25/ru.md), [26](26/ru.md) |
| **distroless** | Минимальный runtime image без package manager и обычно без shell. | [24](24/ru.md), [31](31/ru.md) |
| **docker group** | Группа с доступом к Docker socket, которую следует считать root-equivalent. | [14](14/ru.md) |
| **Docker socket** | `/var/run/docker.sock`, локальный API Docker daemon; доступ к нему почти равен root на host. | [14](14/ru.md) |
| **drop-in** | Отдельный конфигурационный файл, дополняющий базовую конфигурацию, например systemd или SSH. | [15](15/ru.md) |
| **eBPF** | Механизм ядра Linux для ограниченных программ; Cilium применяет его для datapath, Falco — для событий. | [06](06/ru.md), [29](29/ru.md) |
| **egress policy** | NetworkPolicy, задающая допустимые исходящие соединения Pod. | [04](04/ru.md), [05](05/ru.md) |
| **encryption at rest** | Шифрование данных, сохранённых в etcd, на диске, в snapshot и backup. | [21](21/ru.md) |
| **EncryptionConfiguration** | Конфигурация providers шифрования, читаемая kube-apiserver. | [21](21/ru.md) |
| **enforce** | Режим AppArmor или PSA, в котором нарушение policy реально блокируется. | [16](16/ru.md), [19](19/ru.md) |
| **Entity** | Предопределённая группа адресов Cilium, например `world`, `cluster` или `host`. | [06](06/ru.md) |
| **envelope encryption** | Шифрование объекта DEK, который в свою очередь защищён внешним KEK. | [21](21/ru.md) |
| **evidence** | Проверяемый артефакт: API object, log, profile, scanner report или сетевой тест, подтверждающий результат. | [33](33/ru.md) |
| **exemption** | Узкий bypass PSA для доверенной namespace, username или RuntimeClass; он не выдаёт RBAC-права. | [19](19/ru.md) |
| **Exfiltration** | Несанкционированный вывод данных за пределы доверенной границы. | [02](02/ru.md), [30](30/ru.md) |
| **failurePolicy** | Действие API server при недоступности или ошибке webhook/policy: обычно `Fail` либо `Ignore`. | [20](20/ru.md) |
| **Falco** | Rule engine для security-событий runtime, использующий kernel events и container/Kubernetes metadata. | [29](29/ru.md), [30](30/ru.md) |
| **Falco rule override** | Локальное изменение condition или исключений Falco rule без правки vendor ruleset. | [29](29/ru.md), [30](30/ru.md) |
| **falco_rules.local.yaml** | Предпочтительный файл для локальных override и custom Falco rules. | [29](29/ru.md), [30](30/ru.md) |
| **False positive** | Finding, неприменимый к конкретному resource; требует узкого документированного exception. | [27](27/ru.md) |
| **fixed version** | Версия компонента, в которой поставщик исправил CVE. | [13](13/ru.md), [28](28/ru.md) |
| **footprint** | Набор пакетов, процессов, портов, socket и конфигурации, увеличивающий поверхность атаки node. | [14](14/ru.md) |
| **Gatekeeper** | Kubernetes policy engine на OPA с моделью `ConstraintTemplate` и `Constraint`. | [20](20/ru.md), [26](26/ru.md) |
| **Grype** | Scanner container images и SBOM из ecosystem Anchore. | [28](28/ru.md) |
| **gVisor** | Sandbox runtime с userspace kernel; его OCI runtime и CRI handler часто называется `runsc`. | [03](03/ru.md), [22](22/ru.md) |
| **handler** | Имя runtime в CRI configuration; должно совпадать с `RuntimeClass.spec.handler`. | [22](22/ru.md) |
| **host endpoint** | Сетевой endpoint node, а не обычного Pod в CNI dataplane. | [05](05/ru.md) |
| **host firewall** | Фильтрация трафика на самой node, например `ufw`, `iptables` или `nftables`. | [15](15/ru.md) |
| **host namespace** | Namespace node, разделяемый Pod через `hostPID`, `hostNetwork` или `hostIPC`. | [18](18/ru.md) |
| **Host PID** | PID container-процесса в PID namespace node; нужен для `/proc` и `strace`. | [30](30/ru.md) |
| **Hubble** | Наблюдаемость сетевых flows Cilium. | [06](06/ru.md) |
| **identity** | Идентификатор endpoint Cilium, построенный из labels; не следует путать с provider `identity`. | [06](06/ru.md), [21](21/ru.md) |
| **ImagePolicyWebhook** | Admission plugin, делегирующий решение об image внешнему backend через `ImageReview`. | [26](26/ru.md) |
| **IMDS** | Instance Metadata Service — endpoint metadata экземпляра cloud provider. | [05](05/ru.md) |
| **IMDSv2** | Вариант AWS IMDS с обязательным временным token для metadata-запросов. | [05](05/ru.md) |
| **Immutable infrastructure** | Подход, при котором production artifact не меняют в runtime, а заменяют новой проверенной версией. | [02](02/ru.md), [31](31/ru.md) |
| **include** | Директива подключения внешнего файла: `Include` в SSH, `#include` в AppArmor или `include:` в конфигурации проверок. | [15](15/ru.md), [16](16/ru.md), [27](27/ru.md) |
| **Ingress** | Трафик, входящий в Pod, либо Kubernetes API-объект маршрутизации внешнего HTTP/HTTPS к Service — значение определяется контекстом. | [04](04/ru.md), [08](08/ru.md) |
| **IngressClass** | Выбор реализации Ingress, например NGINX Ingress Controller. | [08](08/ru.md) |
| **Inner packet** | Исходный Pod-to-Pod flow, видимый до encryption или после decryption. | [23](23/ru.md) |
| **ipBlock** | Правило ingress/egress для CIDR или отдельного IP; `except` исключает адреса и подсети. | [04](04/ru.md), [05](05/ru.md) |
| **IPsec ESP** | IP-level protected payload с конфиденциальностью и integrity между Security Associations. | [23](23/ru.md) |
| **Kata Containers** | Runtime, запускающий Pod sandbox в lightweight VM с guest kernel. | [03](03/ru.md), [22](22/ru.md) |
| **KEK/DEK** | Key Encryption Key и Data Encryption Key в схеме envelope encryption. | [21](21/ru.md) |
| **kernel module** | Загружаемый модуль kernel; один из способов захвата событий Falco. | [29](29/ru.md) |
| **Keyless signing** | Подпись с short-lived certificate после OIDC-аутентификации вместо постоянного локального signing key. | [26](26/ru.md) |
| **Kill chain** | Последовательность фаз атаки от initial access до достижения цели, например exfiltration. | [02](02/ru.md), [30](30/ru.md) |
| **kube-bench** | Инструмент проверки конфигурации по профилям CIS Kubernetes Benchmark. | [07](07/ru.md), [33](33/ru.md) |
| **kube-linter** | Линтер Kubernetes YAML и Helm charts с набором best-practice checks. | [27](27/ru.md) |
| **kubelet** | Агент Kubernetes на node; его защищённый endpoint обычно слушает порт `10250`. | [05](05/ru.md), [07](07/ru.md) |
| **kubesec** | Scanner Kubernetes manifests, выводящий security score и controls. | [27](27/ru.md) |
| **Kyverno** | Kubernetes-native policy engine с YAML rules `validate`, `mutate`, `generate` и `verifyImages`. | [20](20/ru.md), [26](26/ru.md), [31](31/ru.md) |
| **L3/L4** | Сетевой уровень и транспортный протокол/порт в политике Cilium. | [06](06/ru.md) |
| **L7** | Протокольный уровень, например HTTP method/path, Kafka или DNS. | [06](06/ru.md) |
| **lateral movement** | Перемещение атакующего от скомпрометированной нагрузки к другим системам, данным или identity. | [02](02/ru.md), [04](04/ru.md) |
| **least privilege** | Выдача identity только минимально необходимых прав, области действия и срока. | [02](02/ru.md), [10](10/ru.md), [15](15/ru.md) |
| **legacy annotation** | Устаревшая beta-аннотация AppArmor; её читают для миграции, но не используют для новых Pod. | [16](16/ru.md) |
| **level** | Объём данных audit event: `None`, `Metadata`, `Request` или `RequestResponse`. | [32](32/ru.md) |
| **Linkerd identity** | mTLS identity Linkerd, обычно построенная от ServiceAccount. | [23](23/ru.md) |
| **live-restore** | Режим Docker, сохраняющий работающие containers при рестарте daemon. | [14](14/ru.md) |
| **Localhost** | Kubernetes type для AppArmor/seccomp profile, заранее загруженного на node. | [16](16/ru.md), [17](17/ru.md) |
| **localhostProfile** | Относительный к kubelet seccomp root путь JSON-profile. | [17](17/ru.md) |
| **MAC** | Mandatory Access Control — обязательная policy доступа поверх UID/GID и mode bits. | [03](03/ru.md), [16](16/ru.md) |
| **macro** | Переиспользуемый именованный фрагмент Falco condition. | [29](29/ru.md) |
| **mTLS** | TLS, в котором certificate предъявляют и client, и server. | [23](23/ru.md) |
| **Multi-stage build** | Dockerfile с отдельными stage сборки и runtime, соединёнными `COPY --from=`. | [24](24/ru.md) |
| **Mutating admission webhook** | Webhook, который добавляет или изменяет объект до validation. | [20](20/ru.md) |
| **namespace** | Изолированное представление ресурса kernel для группы процессов; не то же самое, что Kubernetes namespace. | [03](03/ru.md) |
| **namespaceSelector** | Выбор Kubernetes namespace по labels для межnamespace NetworkPolicy-правила. | [04](04/ru.md) |
| **network namespace** | Изоляция интерфейсов, маршрутов и сетевого стека процесса. | [03](03/ru.md) |
| **no_new_privs** | Флаг kernel, запрещающий получить дополнительные права через `exec`; его включает `allowPrivilegeEscalation: false`. | [18](18/ru.md) |
| **Node authorizer** | Authorizer действий kubelet-identity над необходимыми ей Node и Pod объектами. | [12](12/ru.md) |
| **Node encryption** | Защита трафика между nodes; не тождественна identity конкретного workload. | [23](23/ru.md) |
| **NodeRestriction** | Admission plugin, дополнительно ограничивающий kubelet его node и назначенными ей Pod. | [12](12/ru.md) |
| **Notary Project / Notation** | OCI signing ecosystem с X.509 trust policy; для Kubernetes enforcement ему нужна admission integration. | [26](26/ru.md) |
| **OCI** | Открытый стандарт формата container image и artifact, используемый registry и signing-инструментами. | [25](25/ru.md), [26](26/ru.md) |
| **OPA** | Open Policy Agent — policy engine, исполняющий декларативные правила Rego. | [20](20/ru.md), [27](27/ru.md) |
| **Outer packet** | Зашифрованный packet между node IP в физической сети. | [23](23/ru.md) |
| **partial credit** | Частичный зачёт независимых корректно выполненных частей задачи. | [33](33/ru.md) |
| **PeerAuthentication** | Istio policy inbound mTLS; режим `STRICT` отклоняет plaintext. | [23](23/ru.md) |
| **Performance-based** | Формат экзамена, в котором результат достигается в рабочей среде, а не выбирается в тесте. | [01](01/ru.md), [33](33/ru.md) |
| **PID namespace** | Изоляция списка процессов и их PID. | [03](03/ru.md) |
| **Pod UID** | Неизменяемый UID конкретного экземпляра Pod, надёжнее имени при корреляции. | [30](30/ru.md) |
| **podSelector** | Выбор Pod по labels в namespace NetworkPolicy. | [04](04/ru.md) |
| **PolicyReport** | Report об outcome policy checks, если этот API установлен policy engine. | [31](31/ru.md) |
| **private key** | Секретная часть TLS-identity; требует ограниченных прав доступа, обычно `0600`. | [07](07/ru.md), [08](08/ru.md) |
| **profiling** | Endpoints диагностики производительности процесса; без необходимости выключаются флагом `--profiling=false`. | [07](07/ru.md), [12](12/ru.md) |
| **projected volume** | Volume, собирающий token, ConfigMap, downward API и другие источники в файлы Pod. | [11](11/ru.md) |
| **provenance** | Metadata о source, inputs, builder и процессе создания artifact; доказуемое происхождение. | [09](09/ru.md), [25](25/ru.md), [26](26/ru.md) |
| **provider** | Механизм шифрования и дешифрования определённых API-resources. | [21](21/ru.md) |
| **PSA** | Pod Security Admission — встроенный validating admission controller для PSS. | [19](19/ru.md), [31](31/ru.md) |
| **PSP** | PodSecurityPolicy — удалённый в Kubernetes 1.25 предшественник PSA. | [19](19/ru.md) |
| **PSS** | Pod Security Standards: готовые профили `privileged`, `baseline` и `restricted`. | [19](19/ru.md) |
| **purl** | Package URL — идентификатор package с ecosystem и version. | [25](25/ru.md) |
| **re-encryption** | Переписывание старых API-объектов через новый provider или ключ. | [21](21/ru.md) |
| **read-only kubelet port** | Legacy неаутентифицированный port kubelet, который должен быть отключён значением `0`. | [07](07/ru.md), [09](09/ru.md), [12](12/ru.md) |
| **read-only root filesystem** | Режим, в котором image layer нельзя изменять; допустимые записи выносят в volumes. | [18](18/ru.md), [31](31/ru.md), [33](33/ru.md) |
| **Registry allowlist** | Policy, разрешающая image только из определённых registry/repository prefixes. | [26](26/ru.md) |
| **release cadence** | Регулярность выхода minor- и patch-релизов. | [13](13/ru.md) |
| **remediation** | Устранение риска обновлением artifact, dependency или base image с подтверждением результата. | [28](28/ru.md) |
| **Rendered manifest** | Окончательный YAML после `helm template` или `kustomize build`, который должен анализироваться перед deploy. | [27](27/ru.md) |
| **RoleBinding** | Namespaced привязка Role или ClusterRole к субъекту, например ServiceAccount. | [10](10/ru.md), [11](11/ru.md) |
| **Rootless Podman** | Режим Podman, в котором build/run выполняет обычный пользователь, а не root daemon. | [24](24/ru.md) |
| **rotation** | Переименование и удаление старых log files по размеру, количеству или возрасту. | [21](21/ru.md), [32](32/ru.md) |
| **rule** | Именованный детектор Falco с condition, output и priority. | [29](29/ru.md) |
| **runtime detection** | Обнаружение подозрительного поведения уже работающего процесса по syscall/eBPF и runtime metadata. | [01](01/ru.md), [29](29/ru.md), [30](30/ru.md) |
| **Runtime mutation** | Изменение filesystem или configuration работающего container. | [31](31/ru.md) |
| **runtime overhead** | Фиксированные дополнительные CPU/memory, учитываемые scheduler для Pod выбранного RuntimeClass. | [22](22/ru.md) |
| **RuntimeClass** | Cluster-scoped Kubernetes resource, выбирающий CRI handler и необязательные overhead/scheduling constraints. | [19](19/ru.md), [22](22/ru.md) |
| **RuntimeDefault** | Profile, поставляемый выбранным container runtime, для AppArmor или seccomp. | [16](16/ru.md), [17](17/ru.md), [18](18/ru.md) |
| **sandbox pool** | Выделенные nodes с подготовленным runtime, label, taint и capacity. | [22](22/ru.md) |
| **sandboxed runtime** | Runtime с усиленной границей изоляции, например gVisor или Kata Containers. | [03](03/ru.md), [22](22/ru.md) |
| **SCMP_ACT_ERRNO** | Seccomp action, возвращающий syscall ошибку без его выполнения. | [17](17/ru.md) |
| **SCMP_ACT_LOG** | Seccomp action, разрешающий syscall и запрашивающий его журналирование kernel. | [17](17/ru.md) |
| **seccomp** | Linux-механизм фильтрации системных вызовов процесса. | [03](03/ru.md), [17](17/ru.md), [18](18/ru.md) |
| **SECCOMP audit record** | Kernel/audit запись о событии, связанном с seccomp. | [17](17/ru.md) |
| **Secret mount** | Временное подключение credential к одной build-команде без записи в final layer. | [24](24/ru.md) |
| **security advisory** | Первичное уведомление производителя о затронутых версиях, условиях эксплуатации, mitigation и fixed version. | [13](13/ru.md) |
| **SecurityContext** | Kubernetes-поля, задающие identity и ограничения процесса или Pod. | [18](18/ru.md), [33](33/ru.md) |
| **self-signed certificate** | Certificate, подписанный собственным ключом, а не доверенным CA; подходит для теста, но не доверен по умолчанию. | [08](08/ru.md) |
| **SELinux** | Label-based MAC с type enforcement, дополняющий обычные права доступа. | [03](03/ru.md) |
| **ServiceAccount (SA)** | Namespaced identity для Pod и процессов в Kubernetes API. | [11](11/ru.md), [23](23/ru.md) |
| **severity** | Классификация серьёзности finding: `LOW`, `MEDIUM`, `HIGH` или `CRITICAL`. | [28](28/ru.md) |
| **SHA-256 checksum** | 256-битный digest файла для проверки точного совпадения байтов с опубликованным artifact. | [09](09/ru.md) |
| **shim** | Процесс или binary containerd, связывающий containerd с конкретным runtime. | [22](22/ru.md) |
| **Sidecar** | Proxy или иной вспомогательный container рядом с приложением, перехватывающий или обслуживающий трафик. | [23](23/ru.md) |
| **SLSA** | Модель зрелости практик защиты software supply chain. | [25](25/ru.md) |
| **Software supply chain** | Путь source, dependencies, build systems и artifacts до running workload. | [25](25/ru.md) |
| **SPDX** | Открытый стандарт описания packages, licenses и их отношений в SBOM. | [25](25/ru.md), [28](28/ru.md) |
| **SSRF** | Server-Side Request Forgery — уязвимость, заставляющая сервер запрашивать выбранный атакующим адрес. | [05](05/ru.md) |
| **stage** | Момент создания audit event: `RequestReceived`, `ResponseStarted`, `ResponseComplete` или `Panic`. | [32](32/ru.md) |
| **static analysis** | Проверка Dockerfile, manifests и policy без запуска workload. | [27](27/ru.md) |
| **static Pod** | Pod из локального манифеста node, которым kubelet управляет без scheduler через Kubernetes API. | [07](07/ru.md), [09](09/ru.md), [12](12/ru.md), [32](32/ru.md), [33](33/ru.md) |
| **sudoers** | Политика команд, которые пользователь может выполнить от имени другого пользователя; редактируется через `visudo`. | [15](15/ru.md) |
| **SUID/SGID** | Специальные биты файла, запускающие программу с effective UID владельца или GID группы. | [15](15/ru.md) |
| **support window** | Диапазон поддерживаемых веток версии, для которых выпускаются security patches. | [13](13/ru.md) |
| **Syft** | Инструмент генерации SBOM из image, filesystem или archive. | [25](25/ru.md) |
| **syscall** | Системный вызов, через который процесс запрашивает операцию у kernel. | [03](03/ru.md), [17](17/ru.md), [29](29/ru.md) |
| **system:unauthenticated** | Группа анонимного субъекта; binding на неё требует того же ревью, что и на `system:anonymous`. | [12](12/ru.md) |
| **systemd unit** | Описание service, socket, timer или иной сущности, которой управляет systemd. | [14](14/ru.md) |
| **TLS minimum version** | Минимальная TLS-версия, которую server согласует с client. | [09](09/ru.md) |
| **TLS Secret** | Secret типа `kubernetes.io/tls` с ключами `tls.crt` и `tls.key`. | [08](08/ru.md) |
| **TLS termination** | Завершение TLS handshake и расшифровка трафика на ingress controller. | [08](08/ru.md) |
| **toFQDNs** | Cilium egress-правило по DNS-именам и наблюдаемым DNS-ответам. | [06](06/ru.md) |
| **TokenRequest API** | API выпуска short-lived ServiceAccount token. | [11](11/ru.md) |
| **Transparent encryption** | Шифрование datapath без изменения приложения, Service или URL; Cilium применяет его на nodes. | [23](23/ru.md) |
| **triage** | Быстрая классификация finding или события по источнику, риску, scope и следующему действию. | [33](33/ru.md) |
| **Trivy** | Scanner images, SBOM, filesystem, secrets и configuration/IaC. | [28](28/ru.md), [33](33/ru.md) |
| **Unconfined** | Отсутствие seccomp-фильтра для container; временное исключение, а не baseline. | [17](17/ru.md) |
| **Unix socket** | Локальная файловая точка IPC; её права определяют, кто обращается к API daemon. | [14](14/ru.md) |
| **userns-remap** | User namespace remapping UID/GID container на host. | [14](14/ru.md) |
| **Validating admission webhook** | Webhook, который разрешает либо отклоняет объект. | [20](20/ru.md) |
| **ValidatingAdmissionPolicy** | Встроенная API server validation на CEL без внешнего webhook; применяется binding-ом. | [20](20/ru.md) |
| **version skew** | Допустимая разница версий Kubernetes-компонентов; kubelet не должен быть новее API server. | [13](13/ru.md) |
| **webhook collector** | HTTPS endpoint, принимающий audit events для централизованного хранения и анализа. | [32](32/ru.md) |
| **WireGuard** | VPN-протокол с key pair peers; public key определяет разрешённого peer. | [23](23/ru.md) |
| **Workload identity** | Криптографически проверяемая identity workload, обычно связанная с ServiceAccount/namespace в mesh. | [23](23/ru.md) |
| **Writable layer** | Изменяемый слой, добавляемый runtime поверх read-only image layers. | [31](31/ru.md) |
| **Zero trust** | Отказ от неявного доверия на основании сети, namespace или расположения. | [02](02/ru.md) |
