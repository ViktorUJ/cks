[← Оглавление курса](README_RU.md) · [Глоссарий](GLOSSARY_RU.md) · [Шпаргалка](CHEATSHEET_RU.md)

# Справочник ошибок и дебага CKS

Формат «Симптом → Причина → Быстрое решение» для самых частых причин `[FAIL]` в лабах
`101-113`. Все записи основаны на реальных `HINT:`-строках, которые `check_result` уже
выводит в `tests.bats` каждой лабы - этот файл группирует их по симптому, а не по лабе, чтобы
искать по тому, что вы видите на экране, а не по номеру задания.

> Каждая запись содержит ссылку на лабу/задание - там `check_result` даст точный HINT для
> вашей текущей ситуации. Этот файл - быстрый вход в диагностику, а не замена вывода теста.

## Как искать

`Ctrl+F` по ключевому слову ошибки (`Read-only`, `401`, `CrashLoopBackOff`, `not Running`,
имени флага) или откройте раздел по теме ниже.

- [YAML/kubectl и admission](#yaml-kubectl-и-admission)
- [RBAC и ServiceAccount](#rbac-и-serviceaccount)
- [NetworkPolicy и Cilium](#networkpolicy-и-cilium)
- [Secrets и шифрование](#secrets-и-шифрование)
- [AppArmor / seccomp / gVisor](#apparmor--seccomp--gvisor)
- [Read-only filesystem и Pod Security](#read-only-filesystem-и-pod-security)
- [Control plane, static Pod, TLS](#control-plane-static-pod-tls)
- [System hardening ноды](#system-hardening-ноды)
- [Falco и runtime-обнаружение](#falco-и-runtime-обнаружение)
- [Audit log](#audit-log)
- [Supply chain: Trivy/SBOM/Cosign/Kyverno](#supply-chain-trivysbomcosignkyverno)
- [gVisor / Cilium WireGuard / Istio](#gvisor--cilium-wireguard--istio)

---

## YAML/kubectl и admission

**[Симптом] `ValidatingAdmissionPolicy`/`ValidatingPolicy` не блокирует то, что должна**
├── Причина 1: CEL-выражение проверяет не то поле, либо логика инвертирована.
│   └── Решение: проверьте выражение отдельно на конкретном тестовом объекте; убедитесь, что проверяется именно `object.spec.automountServiceAccountToken`/`image().repository()` и т.п., а не похожее поле. *(лаба 107, задание 6; лаба 112, задание 9)*
├── Причина 2: `matchResources`/`matchConstraints` не ограничены нужным namespace - policy либо не срабатывает вовсе, либо слишком широкая.
│   └── Решение: добавьте `namespaceSelector`/`matchConditions` с точным именем namespace. *(лаба 107, задание 6)*
└── Причина 3: сравнение использует `startsWith`/prefix вместо exact `==`/`!=` - пропускает похожие имена (`busybox-evil` при allowlist `busybox`).
    └── Решение: используйте точное сравнение везде, где admission и runtime-контроль (Falco) должны быть эквивалентны. *(лаба 112, задание 9)*

**[Симптом] Полностью корректный Pod внезапно отклонён admission с сообщением про `PodSecurity`**
├── Причина: отклоняет PSA (namespace label `enforce`), а не ваша собственная `ValidatingAdmissionPolicy`/Kyverno policy.
│   └── Решение: убедитесь, что тестовый Pod полностью совместим с PSA `restricted`, прежде чем проверять именно вашу policy - иначе тест не может изолировать её собственное поведение. *(лаба 107, задание 6)*

**[Симптом] Мутация Kyverno `MutatingPolicy` не применяется к Pod**
├── Причина: в policy не задан `mutations`, либо `applyConfiguration`/patch не устанавливает точный ключ/значение.
│   └── Решение: проверьте dry-run admission response - в нём должен появиться label/поле с точным именем и значением из задания. *(лаба 108, задание 5)*

---

## RBAC и ServiceAccount

**[Симптом] ServiceAccount имеет больше прав, чем должен (например, может удалять Secret)**
├── Причина 1: осталась лишняя `ClusterRoleBinding`/`RoleBinding`, не названная в задании явно.
│   └── Решение: проверьте ВСЕ binding на этот ServiceAccount, не только тот, что упомянут в задании - `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>`. *(лаба 104, задания 1, 4)*
└── Причина 2: удалён binding, но ServiceAccount всё ещё числится subject в ДРУГОЙ, не упомянутой в задании привязке.
    └── Решение: если binding реально удалён, текущие права уже отозваны немедленно - сам по себе оставшийся ClusterRole без привязки никому ничего не выдаёт. Если доступ всё же сохраняется, ищите ВТОРУЮ привязку на этот ServiceAccount. Отдельно (не как причину сохранения доступа) удаляйте и опасный wildcard ClusterRole - это не отзывает текущий доступ, но убирает reusable-шаблон, готовый к будущей случайной/злонамеренной новой привязке. *(лаба 104, задание 4)*

**[Симптом] `automountServiceAccountToken: false` не действует - токен всё равно смонтирован**
├── Причина: поле выставлено только на Pod ИЛИ только на ServiceAccount, но не на обоих (для defence-in-depth задания).
│   └── Решение: если задание требует именно оба уровня - выставьте `automountServiceAccountToken: false` и на ServiceAccount, и на Pod явно. *(лаба 104, задание 3)*

**[Симптом] `TokenReview` не аутентифицирует projected token, либо аутентифицирует не тот ServiceAccount**
├── Причина 1: у `serviceAccountToken` volume source задан `audience`, который API server не принимает.
│   └── Решение: убрать поле `audience`, если задание не требует его явно. *(лаба 104, задание 2)*
└── Причина 2: токен ещё не смонтирован/устарел - Pod не успел получить свежий volume.
    └── Решение: подождите готовности Pod, проверьте `mountPath`/`readOnly` точно как в задании. *(лаба 104, задание 2)*

**[Симптом] Неаутентифицированный `curl` к `/version` не возвращает `401` после добавления `--anonymous-auth=false`**
├── Причина 1: static Pod ещё не перезапустился с новым манифестом - изменение файла на диске не применяется мгновенно.
│   └── Решение: подождите, пока kubelet заметит изменение файла и пересоздаст static Pod - редактирование самого `Pod`-объекта через API не поможет, kubelet пересоздаст его из манифеста на диске. Пока перезапуск не завершился, ожидайте временную недоступность API (connection refused/timeout), а не `401` - `401` появится только ПОСЛЕ того, как флаг реально заработает. *(лаба 104, задание 5)*
└── Причина 2: проверяли аутентифицированным `kubectl` вместо чистого неаутентифицированного запроса.
    └── Решение: `--anonymous-auth=false` влияет только на запросы БЕЗ credential (`curl` без сертификата/токена). Обычный `kubectl` с валидным kubeconfig не должен получать `401` из-за этого флага - если это происходит, проблема в другом (протухший токен/сертификат, а не anonymous-auth), проверяйте это отдельно. *(лаба 104, задание 5)*

---

## NetworkPolicy и Cilium

**[Симптом] NetworkPolicy пропускает трафик, который должна блокировать (или наоборот)**
├── Причина 1: `namespaceSelector` и `podSelector` в РАЗНЫХ элементах списка `from` - это OR, а не AND.
│   └── Решение: чтобы получить AND, оба selector должны быть в ОДНОМ элементе `from`. *(лаба 101, задание 6 - классическая "AND-trap")*
├── Причина 2: `podSelector: {}` (пустой) перепутан с конкретным `matchLabels` - default-deny должен выбирать ВСЕ Pod.
│   └── Решение: для default-deny both ingress/egress используйте `podSelector: {}` с пустыми массивами `ingress`/`egress`. *(лаба 101, задание 2)*
└── Причина 3: широкий `ipBlock: 0.0.0.0/0` без `except` для чувствительного CIDR (например, node metadata `169.254.169.254/32`).
    └── Решение: явно добавьте `except` внутри `ipBlock`, а не отдельное правило-исключение. *(лаба 101, задание 6)*

**[Симптом] DNS не резолвится после включения default-deny egress**
├── Причина: default-deny блокирует и DNS-трафик к `kube-dns`, если нет явного allow-правила.
│   └── Решение: добавьте egress-правило с `namespaceSelector` на `kube-system` и портом 53 (TCP/UDP). *(лаба 101, задание 4)*

**[Симптом] `hostNetwork: true` Pod ведёт себя не так, как ожидалось при NetworkPolicy**
├── Причина: NetworkPolicy - CNI-уровень; поведение с `hostNetwork` зависит от конкретного CNI (implementation-defined для Calico).
│   └── Решение: это ожидаемое наблюдение, а не баг - задание именно про то, что hostNetwork может обходить некоторые CNI-политики. *(лаба 101, задание 7)*

**[Симптом] CiliumNetworkPolicy L7-правило (`http.method`/`path`) не работает, либо L7-запрос падает вместо ожидаемого 403**
├── Причина: L7-политика Cilium строже L3/L4 - несовпадение по `method`/`path` даёт HTTP 403, а не connection failure, если L3/L4 уже разрешён.
│   └── Решение: проверьте, что `toPorts.rules.http` содержит точный `method`/`path`; ожидайте именно HTTP 403 у неразрешённого метода, а не таймаут. *(лаба 102, задание 3)*

**[Симптом] `toFQDNs` правило Cilium не резолвит домен / разрешает больше, чем нужно**
├── Причина 1: нет companion egress-правила, разрешающего DNS к `kube-dns` (`toPorts.rules.dns matchPattern: "*"`) - Cilium должен видеть DNS-ответ, чтобы динамически резолвить FQDN policy.
│   └── Решение: добавьте отдельное egress-правило на DNS в дополнение к `toFQDNs`. *(лаба 102, задание 4)*
└── Причина 2: `toPorts` не ограничен нужным портом (например, 443) - разрешает весь трафик к FQDN, а не только HTTPS.
    └── Решение: ограничьте `toPorts` конкретным портом/протоколом внутри того же правила `toFQDNs`. *(лаба 102, задание 4)*

---

## Secrets и шифрование

**[Симптом] `defaultMode` для Secret volume задаёт не те права**
├── Причина: `defaultMode` в YAML парсится как DECIMAL, если не начинается с `0`. `defaultMode: 400` - это decimal 400, а НЕ octal 0400/256.
│   └── Решение: используйте `defaultMode: 0400` (с ведущим нулём) или числовое значение `256` напрямую. *(лаба 104, задание 6 - см. также [CHEATSHEET](CHEATSHEET_RU.md#2-cluster-hardening))*

**[Симптом] Секрет всё ещё доступен через `env`/`envFrom`, хотя задание требует только volume mount**
├── Причина: `envFrom.secretRef`/`env[].valueFrom.secretKeyRef` не были удалены при переходе на volume.
│   └── Решение: полностью убрать ссылки на Secret через env - секрет должен быть доступен ТОЛЬКО через volume mount. *(лаба 104, задание 6)*

**[Симптом] `EncryptionConfiguration` не шифрует новые Secret / не может прочитать старые**
├── Причина 1: порядок `providers` неверный - первый provider используется для НОВОЙ записи, остальные только для чтения существующих.
│   └── Решение: поставьте нужный provider (`aescbc`) первым, `identity: {}` - последним, чтобы читать уже существующие plaintext-записи до re-encryption. *(лаба 109, задание 2)*
└── Причина 2: файл конфигурации не имеет прав `600` - секретный материал ключа доступен лишним пользователям.
    └── Решение: `chmod 600` на `encryption-config.yaml`. *(лаба 109, задание 2)*

**[Симптом] "До"-evidence о plaintext Secret в etcd не засчитывается**
├── Причина: evidence снято ПОСЛЕ создания `EncryptionConfiguration`, когда Secret уже зашифрован.
│   └── Решение: снимайте "before"-evidence ДО применения шифрования - позже эта же проверка невозможна. *(лаба 109, задание 1)*

---

## AppArmor / seccomp / gVisor

**[Симптом] AppArmor-профиль "загружен", но не блокирует ожидаемое действие**
├── Причина 1: профиль присутствует как файл, но не загружен в ядро через `apparmor_parser -r`.
│   └── Решение: наличие файла недостаточно - профиль должен быть реально загружен (`apparmor_parser -r -v`) и виден в `aa-status` как `(enforce)`. *(лаба 106, задание 1)*
└── Причина 2: имя профиля в Pod spec не совпадает точно (с учётом регистра) с именем в `/etc/apparmor.d/`.
    └── Решение: сверьте `securityContext.appArmorProfile.localhostProfile` с реальным именем профиля на ноде. *(лаба 106, задание 2)*

**[Симптом] Pod с кастомным AppArmor/seccomp профилем не запускается (`CreateContainerError`)**
├── Причина: профиль назначен, но реально не загружен на ту ноду, куда Pod запланирован.
│   └── Решение: используйте `nodeSelector`, гарантирующий размещение именно на ноде с загруженным профилем - профили AppArmor/seccomp node-local. *(лаба 106, задания 2, 4)*

**[Симптом] `unshare` (или другой syscall) не блокируется кастомным seccomp-профилем**
├── Причина: JSON-профиль имеет неверный синтаксис, либо не был реально загружен/применён после правки.
│   └── Решение: перепроверьте структуру `defaultAction`/`syscalls[].names`/`action`; после правки Pod должен быть пересоздан, чтобы применить `seccompProfile`. *(лаба 106, задания 4-5)*

**[Симптом] `localhostProfile` для seccomp не находится**
├── Причина: путь указан как абсолютный, а должен быть относителен к kubelet seccomp root (`/var/lib/kubelet/seccomp/`).
│   └── Решение: указывайте путь относительно seccomp root, не полный путь на диске. *(лаба 106, задание 4)*

**[Симптом] gVisor Pod не показывает отличий от обычного runc (`dmesg`/`uname -r` совпадают)**
├── Причина: `runtimeClassName: gvisor` не применился - Pod по факту работает через runc.
│   └── Решение: проверьте RuntimeClass существует, handler `runsc`, и Pod действительно был пересоздан с `runtimeClassName`. *(лаба 110, задание 2)*

**[Симптом] containerd не запускается / RuntimeClass gVisor не работает после правки `config.toml`**
├── Причина: синтаксическая ошибка TOML, либо секция `runtimes.runsc` не содержит точный `runtime_type = "io.containerd.runsc.v1"`.
│   └── Решение: проверьте TOML синтаксис построчно; секция должна называться `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]`. *(лаба 110, задание 1)*

---

## Read-only filesystem и Pod Security

**[Симптом] `Pod` падает с ошибкой `Read-only file system`**
├── Причина: включён `readOnlyRootFilesystem: true`, но приложению нужна запись в путь (`/tmp`, `/var/run`, кэш и т.п.), для которого нет writable volume.
│   └── Решение: добавьте `emptyDir` volume и смонтируйте именно в тот путь, куда приложение пишет - НЕ используйте `hostPath` (это утечка данных на ноду). *(лаба 107, задание 5; лаба 112, задание 5)*

**[Симптом] Запись в `/tmp` внутри Pod с `readOnlyRootFilesystem: true` не проходит, хотя должна**
├── Причина: `mountPath` смонтированного `emptyDir` не совпадает точно с ожидаемым путём (опечатка).
│   └── Решение: сверьте `volumeMounts[].mountPath` буква в букву с путём, куда реально пишет приложение. *(лаба 107, задание 5; лаба 112, задание 5)*

**[Симптом] nginx (или другое приложение) падает в `CrashLoopBackOff` после включения `readOnlyRootFilesystem`**
├── Причина: приложению нужно НЕСКОЛЬКО writable путей одновременно (`/tmp`, `/var/run`, `/var/cache/nginx`, `/etc/nginx/conf.d`), а не один.
│   └── Решение: добавьте writable `emptyDir` для каждого пути, куда приложение пишет; для генерации конфига перед стартом используйте init container. *(лаба 111, задание 4)*

---

## Control plane, static Pod, TLS

**[Симптом] Правка `/etc/kubernetes/manifests/kube-apiserver.yaml` (или другого static Pod) не применяется**
├── Причина: kubelet не успел заметить изменение файла на диске.
│   └── Решение: подождите (обычно секунды-десятки секунд); НЕ редактируйте Pod-объект через `kubectl edit` - kubelet пересоздаст его из файла на диске в любом случае. *(лабы 103, 104, 112)*

**[Симптом] kube-apiserver/etcd не запускается после добавления TLS-флагов**
├── Причина: неверный `--tls-cipher-suites`/`--cipher-suites` (опечатка в названии cipher suite) или несовместимый `--tls-min-version`.
│   └── Решение: сверьте cipher suite строки байт-в-байт с эталоном; слишком строгий список может сломать внутреннюю коммуникацию компонентов. *(лаба 103, задание 5)*

**[Симптом] Ingress с TLS не работает / сертификат не применяется**
├── Причина: Secret создан как `Opaque` вместо `kubernetes.io/tls`, либо отсутствует `tls.crt`/`tls.key`.
│   └── Решение: используйте `kubectl create secret tls` (тип `kubernetes.io/tls` автоматически) вместо генерации Opaque Secret вручную. *(лаба 103, задание 4)*

---

## System hardening ноды

**[Симптом] `sshd`-конфигурация `PermitRootLogin no` не действует**
├── Причина: проверяли ТЕКСТ конфиг-файла, а не ЭФФЕКТИВНОЕ значение - более позднее правило, `Include` или `Match`-блок может переопределить более раннюю строку.
│   └── Решение: используйте `sshd -T` для проверки эффективного значения, а не `grep` по файлу. *(лаба 105, задание 5)*

**[Симптом] `sctp` (или другой kernel-модуль) продолжает загружаться после `blacklist`**
├── Причина: обычный `blacklist sctp` только останавливает авто-загрузку через alias-резолюцию; прямой `modprobe sctp` всё равно может сработать.
│   └── Решение: добавьте override `install sctp /bin/true` в дополнение к `blacklist`; для уже загруженного модуля выполните `modprobe -r sctp`. *(лаба 105, задание 7)*

**[Симптом] kubelet не запускается после изменения `/var/lib/kubelet/config.yaml`**
├── Причина 1: включён `protectKernelDefaults: true`, но параметры ядра не соответствуют ожидаемым - kubelet СОЗНАТЕЛЬНО откажется стартовать при несовпадении.
│   └── Решение: выставьте нужные sysctl (`kernel.unprivileged_bpf_disabled=1`, `vm.overcommit_memory=1`) через `/etc/sysctl.d/` и `sysctl --system`, а не разовым `sysctl -w` (не переживёт перезагрузку). *(лаба 105, задание 8)*
└── Причина 2: синтаксическая ошибка в YAML (неверные отступы).
    └── Решение: `journalctl -u kubelet -n 50 | grep -i "parse"` для точной строки ошибки.

**[Симптом] UFW блокирует SSH/kubectl доступ после включения**
├── Причина: `ufw --force enable` выполнен ДО добавления allow-правил для собственного IP.
│   └── Решение: всегда добавляйте allow-правило для SSH (порт 22) и API server (6443) с вашего IP ПЕРЕД включением default-deny firewall - иначе рискуете потерять доступ. *(лаба 105, задание 3)*

---

## Falco и runtime-обнаружение

**[Симптом] Falco custom rule не срабатывает на ожидаемый marker/команду**
├── Причина 1: rule не была загружена - Falco не перечитывает `falco_rules.local.yaml` на лету.
│   └── Решение: `systemctl restart falco` после каждой правки правил. *(лаба 112, задания 3, 7)*
└── Причина 2: `condition` не хватает базового `spawned_process`/`container` перед специфичным условием по `proc.cmdline`.
    └── Решение: убедитесь, что условие начинается с `spawned_process and container and ...`. *(лаба 112, задание 3)*

**[Симптом] Falco allowlist на `container.image.repository` пропускает то, что не должна (prefix-trap)**
├── Причина: условие использует `startswith`/prefix-сравнение вместо точного `==`/`!=` - имя вроде `library/busybox-evil` "начинается" с разрешённой строки `library/busybox`.
│   └── Решение: используйте exact `!=`/`==`, синхронизировав семантику с admission policy (Kyverno). *(лаба 112, задание 9 - см. также [CHEATSHEET](CHEATSHEET_RU.md#6-monitoring-logging--runtime-security))*

**[Симптом] Override макроса Falco не исключает ожидаемый Pod из правила**
├── Причина: перепутан макрос - `user_expected_terminal_shell_in_container_conditions` (для правила **Terminal shell in container**) и `user_shell_container_exclusions` (для другого правила **Run shell untrusted**) похожи по названию, но относятся к разным правилам.
│   └── Решение: сверьте, к какому именно правилу привязан макрос, прежде чем override. *(лаба 112, задание 7)*

**[Симптом] Записанный JSON alert Falco не содержит `k8s.pod.name`/`k8s.ns.name`**
├── Причина: стандартный output правила **Terminal shell in container** не включает эти поля по умолчанию.
│   └── Решение: добавьте `override: output: append` с `%k8s.ns.name`/`%k8s.pod.name` отдельно от override условия макроса. *(лаба 112, задание 7)*

**[Симптом] Correlation Falco alert → Pod/namespace через `crictl` не срабатывает**
├── Причина: используется устаревший/несуществующий Pod - `/proc/<PID>` для завершённого процесса исчезает навсегда.
│   └── Решение: начинайте расследование с НОВОГО alert, извлекайте `container_id`/`host_pid` из него, собирайте `/proc`-evidence, ПОКА процесс жив - не смешивайте evidence из разных запусков. *(лаба 112, задание 6)*

---

## Audit log

**[Симптом] Правило audit policy для конкретного namespace/ресурса не применяется, срабатывает "неправильное" правило**
├── Причина: API server применяет ПЕРВОЕ подходящее правило сверху вниз; catch-all в начале файла "перехватывает" события раньше специфичных правил.
│   └── Решение: располагайте специфичные правила (namespace/resource-scoped) РАНЬШЕ общего catch-all в конце файла. *(лаба 112, задание 4 - см. [CHEATSHEET](CHEATSHEET_RU.md#6-monitoring-logging--runtime-security))*

**[Симптом] Secret audit event содержит тело секрета (`requestObject`/`responseObject`)**
├── Причина: уровень для `secrets` установлен как `RequestResponse` вместо `Metadata`.
│   └── Решение: используйте `level: Metadata` для `secrets` - это даёт forensic след без копирования содержимого секрета в лог. *(лаба 112, задание 4)*

**[Симптом] kube-apiserver не восстанавливается после добавления `--audit-policy-file`/`--audit-webhook-*`**
├── Причина: hostPath volume/volumeMount для каталога policy или логов не добавлен в static manifest, либо webhook config - не валидный kubeconfig.
│   └── Решение: проверьте `volumeMounts` для `/etc/kubernetes/audit` и `/var/log/kubernetes/audit`; webhook config должен иметь структуру kubeconfig (`clusters`/`users`/`contexts`), а не произвольный YAML. *(лаба 112, задания 4, 8)*

---

## Supply chain: Trivy/SBOM/Cosign/Kyverno

**[Симптом] `trivy image --list-all-pkgs` evidence не засчитывается**
├── Причина: список пакетов вписан вручную "по памяти" вместо сохранения реального вывода команды.
│   └── Решение: сохраняйте команду И её вывод в файл через `tee`/redirect - тест ищет буквальную строку команды как доказательство. *(лаба 111, задание 5)*

**[Симптом] `bom generate`/`syft` SBOM не проходит проверку формата**
├── Причина: спутаны SPDX (`bom`, ключ `spdxVersion`) и CycloneDX (`syft -o cyclonedx-json`, ключ `bomFormat`) форматы/инструменты.
│   └── Решение: `bom` - нативно SPDX; `syft` - для CycloneDX; не смешивайте команды и ожидаемые ключи JSON. *(лаба 111, задания 6-7)*

**[Симптом] `trivy sbom` возвращает ошибку или сканирует не то**
├── Причина: путь к SBOM-файлу передан в `trivy image` вместо `trivy sbom` - разные субкоманды с разным вводом.
│   └── Решение: `trivy sbom <файл>` принимает SBOM как вход; `trivy image <ref>` - image reference. *(лаба 111, задание 8)*

**[Симптом] `cosign verify` для предполагаемо НЕподписанного (negative-control) образа неожиданно УСПЕШЕН**
├── Причина: "unsigned" rebuild дал ТОТ ЖЕ digest, что и уже подписанный artifact (например, reproducible/cached build без реальных изменений содержимого) - раз digest совпадает, это криптографически тот же artifact, и его подпись (сделанная для оригинального digest) валидна и для этой ссылки, поэтому `cosign verify` проходит, а не падает.
│   └── Решение: перед негативным контролем явно сравните `$SIGNED_DIGEST`/`$UNSIGNED_DIGEST` и убедитесь, что они РАЗНЫЕ; если совпали - внесите контролируемое отличие в сборку (например `--build-arg` с уникальным значением), чтобы гарантировать другой digest, иначе negative-control образ окажется тем же подписанным artifact под другим тегом. *(лаба 111, задание 9c)*

**[Симптом] Новый Pod после создания Kyverno policy "допущен", но это не доказывает, что policy сработала**
├── Причина: тестировали через `kubectl apply` уже существующего Deployment - если template не изменился, новый Pod не создаётся, и `Running` - это старый Pod, созданный ДО policy.
│   └── Решение: создайте буквально НОВЫЙ объект (`kubectl run` с новым именем) ПОСЛЕ policy и сравните `creationTimestamp` Pod и policy - Pod должен быть позже. *(лаба 111, задание 9b)*

**[Симптом] Kyverno admission denial evidence не засчитывается как "signature-specific"**
├── Причина: денайл произошёл по несвязанной причине (например, `manifest unknown` - образ просто не существует/не pullable), а не из-за отсутствия подписи.
│   └── Решение: сначала докажите, что образ СУЩЕСТВУЕТ и pullable, затем - что подписи НЕТ, и только потом пытайтесь создать Pod. *(лаба 111, задание 9c)*

---

## gVisor / Cilium WireGuard / Istio

**[Симптом] `cilium-dbg encrypt status` не показывает WireGuard**
├── Причина: шифрование включено через недокументированный/эфемерный CLI-путь (`cilium encrypt enable`) вместо source-of-truth (Helm values или ConfigMap key) - может не переживать restart агента.
│   └── Решение: используйте `encryption.enabled=true`/`encryption.type=wireguard` через Helm или `enable-wireguard: true` в ConfigMap, затем `rollout restart` агентов. *(лаба 110, задание 4)*

**[Симптом] tcpdump-захват межнодового трафика показывает plaintext marker, хотя WireGuard включён**
├── Причина: захват сделан НЕ на физическом интерфейсе ноды (например, внутри Pod veth), где трафик ещё не зашифрован WireGuard-туннелем.
│   └── Решение: захватывайте на реальном физическом NIC ноды, не на loopback/veth внутри Pod. *(лаба 110, задание 5)*

**[Симптом] Istio `PeerAuthentication STRICT` не блокирует plaintext-клиента**
├── Причина: тестовый "внешний" клиент случайно получил Istio sidecar (namespace injection применилась не туда, куда думали).
│   └── Решение: убедитесь, что plaintext-клиент НЕ имеет `istio-proxy` sidecar - именно его отсутствие доказывает эффект STRICT mTLS. Не подменяйте negative control клиентом с sidecar. *(лаба 110, задание 6)*

---

[← Оглавление курса](README_RU.md) · [Глоссарий](GLOSSARY_RU.md) · [Шпаргалка](CHEATSHEET_RU.md)
