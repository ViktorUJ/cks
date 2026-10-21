[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 112 - эталонное решение: Falco, audit-логи и иммутабельность

Работаем как на экзамене. Откройте **два терминала** и оставьте оба открытыми до конца лабы:

- **Терминал 1 - control-plane:** `ssh control-plane`, затем `sudo -i` (дальше все команды на узле
  выполняются от root, без `sudo`). Единственный узел control plane также запускает рабочие нагрузки.
- **Терминал 2 - рабочая машина:** здесь `kubectl`, `scp` и проверки.

Артефакты, которые получены на узле, сохраняются в `/tmp/art/<номер задания>/` на control-plane и
копируются на рабочую машину командой `scp` в `/var/work/tests/artifacts/<номер>/`.

## Где взять примеры в документации

| Что нужно | Страница и раздел |
| :--- | :--- |
| Установка Falco из apt (ключ, репозиторий, `apt-get install -y falco`), переменные `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`, `systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| Переопределение правил и макросов Falco (`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy (уровни `None`/`Metadata`/`Request`/`RequestResponse`, `omitStages`, `rules`), флаги `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage/-maxbackup/-maxsize`, монтирование `hostPath`, webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` и `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| Deny-all `NetworkPolicy` | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

Первый запуск на рабочей машине (терминал 2):

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

Первый запуск на узле (терминал 1):

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. Установка Falco с modern eBPF

Устанавливаем Falco из официального APT-репозитория (команды со страницы Install в документации
Falco). Modern eBPF не требует вручную собирать или загружать kernel module.

```bash
# терминал 1 (control-plane, root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**Установку выполняйте отдельной командой:** `apt-get` сбрасывает буфер ввода терминала, поэтому
строки, вставленные сразу за ней, пропадают.

```bash
# терминал 1 (control-plane, root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# терминал 1 (control-plane, root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# Пакет ставит unit falco-modern-bpf.service, а falco.service - лишь alias на него;
# `systemctl enable falco` по alias-у завершается ошибкой, поэтому включаем реальный unit.
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

`sleep 20` нужен, потому что при первом запуске modern eBPF probe открывается с несколькими
повторными попытками (в journal видно несколько строк `Opening 'syscall' source`): пока он не
открыт, Falco не фиксирует события, и shell из задания 2 может остаться незамеченным. Если
алерта нет, повторите `exec` спустя несколько секунд.

Если сервис не запускается, сначала посмотрите `journalctl -u falco-modern-bpf -b --no-pager`.
Не заменяйте engine на kernel module: в этой лабе требуется именно `modern_ebpf`.

## 2. Стандартное правило для shell в контейнере

```bash
# терминал 2 (рабочая машина)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: falco-shell
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/falco-shell --timeout=120s
kubectl exec -it -n "$NS" falco-shell -- /bin/sh
# Внутри shell: exit
```

Сохраните настоящее событие Falco: оно берётся из journal на control-plane. Falco пишет событие с
небольшой задержкой, поэтому подождите пару секунд после выхода из shell. Не создавайте артефакт
вручную:

```bash
# терминал 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# терминал 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. Локальное правило и контролируемый marker

Falco уже загружает `/etc/falco/falco_rules.local.yaml`; добавим правило именно туда.
`spawned_process` сохраняет совместимость с правилами Falco, а `container` не позволяет
матчить тот же marker, запущенный на хосте.

```bash
# терминал 1 (control-plane, root)
cat > /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
EOF
systemctl restart falco && systemctl is-active falco && sleep 10
```

```bash
# терминал 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# терминал 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# терминал 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

После каждого `restart falco` в решении стоит `sleep 10`: Falco загружает правила и метаданные
контейнеров около 5 секунд, и события, произошедшие раньше, он не запишет в journal.

## 4. Audit: RequestResponse для ConfigMap, Metadata для Secret

Создадим policy по правилу главы 32: полный request/response пишем только для
нечувствительного `configmaps` в `runtime-112`; для `secrets` берём `Metadata`, чтобы тело Secret
(токены, пароли) не попало в журнал. `None` и `omitStages` действительно сокращают high-volume
noise; финальный catch-all `Metadata` - fallback logging, а не шумоподавление. Порядок правил важен:
специфичные правила идут до catch-all. Структура файла - из примера в документации (раздел Audit
policy).

```bash
# терминал 1 (control-plane, root)
cat > /etc/kubernetes/audit/policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
# 1. Noise reduction: high-volume events and health probes are not forensic evidence here.
- level: None
  resources:
  - group: ""
    resources: ["events"]
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
# 2. ConfigMap: constrained forensic RequestResponse example.
- level: RequestResponse
  namespaces: ["runtime-112"]
  resources:
  - group: ""
    resources: ["configmaps"]
# 3. Secret matters for investigation, but its body must not be logged.
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 4. Fallback logging for the rest of the API (not noise reduction).
- level: Metadata
EOF
```

Отредактируйте `/etc/kubernetes/manifests/kube-apiserver.yaml` на control-plane (`vim`). В `command`
контейнера `kube-apiserver` добавьте:

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

В `volumeMounts` того же контейнера добавьте:

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

В `spec.volumes` добавьте:

```yaml
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit
    type: Directory
- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit
    type: DirectoryOrCreate
```

```bash
# терминал 1 (control-plane, root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Это static Pod: kubelet автоматически пересоздаст API server (около минуты, до этого
`kubectl` отвечает `connection refused`). Дождитесь его готовности:

```bash
# терминал 2: повторяйте, пока команда не вернёт "ok"
kubectl get --raw=/readyz
```

```bash
# терминал 1: флаги попали в рабочий manifest
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Создайте ConfigMap и сгенерируйте оба запроса, затем сохраните по одному подходящему JSON event
как артефакты:

```bash
# терминал 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# терминал 1 (control-plane, root)
# ConfigMap: полный RequestResponse event (нечувствительные данные).
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret: только Metadata, без тела.
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# терминал 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

Проверьте, что ConfigMap залогирован с телом, а Secret - только на уровне `Metadata` и
**без** `requestObject`/`responseObject`:

```bash
# терминал 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. Неизменяемый root filesystem

`emptyDir` даёт приложению контролируемое место для runtime-файлов; root filesystem
остается read-only. `hostPath` не нужен и не допускается.

```bash
# терминал 2
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir: {}
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/immutable-app --timeout=120s
```

Докажем оба свойства и сохраним сообщение об отказе:

```bash
# терминал 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. Минимальная цепочка containment от alert до изоляции

Audit backend уже работает, поэтому новый `kubectl exec` оставит API evidence. Запускаем
контролируемый долгоживущий процесс: marker остаётся в command line достаточно долго для
проверки `/proc`. В production подозрительный процесс не запускают повторно; здесь это
безопасная planted evidence одноразовой лабы.

```bash
# терминал 1 (control-plane, root): момент начала прогона (время берём с control-plane,
# где потом читаем journal)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# терминал 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

Дальше всё делаем на control-plane, пока процесс жив: берём alert, а из него - container id и
host pid (начинаем с alert, а не угадываем):

```bash
# терминал 1 (control-plane, root)
cd /tmp/art/6
journalctl -u falco-modern-bpf -b --since "$START" --no-pager | grep -F 'CKS112 custom shell marker' | tail -1 > falco-alert.log
cat falco-alert.log

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' falco-alert.log | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' falco-alert.log | tail -1)
echo "SHORT_ID=$SHORT_ID HOST_PID=$HOST_PID"

CONTAINER_ID=$(crictl ps -a -q | grep "^$SHORT_ID" | head -1)
crictl inspect $CONTAINER_ID > cri-container.json
SANDBOX_ID=$(jq -r '.status.sandboxId // .status.sandboxID // .info.sandboxID // empty' cri-container.json)
crictl inspectp $SANDBOX_ID > cri-sandbox.json
printf 'container_init_pid=%s\n' "$(jq -r '.info.pid // empty' cri-container.json)" > cri-mapping.txt

cat /proc/$HOST_PID/status > proc-status.txt
tr '\0' ' ' < /proc/$HOST_PID/cmdline > proc-cmdline.txt; echo >> proc-cmdline.txt
cat /proc/$HOST_PID/cgroup > proc-cgroup.txt
ps -eo pid,ppid,user,lstart,args --forest > process-tree.txt
```

Теперь коррелируем API event. Современный `kubectl exec` работает поверх WebSocket, поэтому в audit он
виден как `get` (при SPDY-fallback - `create`), оба варианта подходят. Для `pods/exec` достаточно
`Metadata`: command из request body может содержать секрет, поэтому `RequestResponse` здесь не нужен.

```bash
# терминал 1 (control-plane, root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# терминал 2: забрать все файлы цепочки и собрать итоговый summary
scp 'control-plane:/tmp/art/6/*' /var/work/tests/artifacts/6/

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' "$DIR/falco-alert.log" | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' "$DIR/falco-alert.log" | tail -1)
CONTAINER_ID=$(jq -r '.status.id' "$DIR/cri-container.json")
POD=$(jq -r '.status.metadata.name' "$DIR/cri-sandbox.json")
NAMESPACE=$(jq -r '.status.metadata.namespace' "$DIR/cri-sandbox.json")
NODE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
CONTAINER_INIT_PID=$(jq -r '.info.pid // empty' "$DIR/cri-container.json")

cat > "$DIR/evidence-summary.txt" <<EOF
alert_rule=CKS112 Custom Shell Marker
namespace=$NAMESPACE
pod=$POD
node=$NODE
runtime=containerd
container_id=$CONTAINER_ID
container_init_pid=$CONTAINER_INIT_PID
host_pid=$HOST_PID
audit_verb=$(jq -r .verb "$DIR/audit-exec.json")
audit_subresource=exec
attack_phase=Execution
technique=Container Administration Command
containment=quarantine-and-delete
EOF
cat "$DIR/evidence-summary.txt"
```

Сначала сохраняем evidence, затем изолируем namespace на сетевом уровне и удаляем
скомпрометированный Pod. Это минимальная containment-цепочка, а не полное расследование:
credential revocation/rotation, поиск других workload и восстановление owner/controller выполняются
отдельным IR-процессом. Последняя команда доказывает отрицательный outcome, а не ищет конкретный
текст ошибки.

```bash
# терминал 2
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: incident-quarantine
  namespace: runtime-112
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: []
  egress: []
EOF

kubectl delete pod falco-shell -n "$NS" --wait=true
wait "$INCIDENT_EXEC_PID" 2>/dev/null
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT' > "$DIR/post-containment-exec.log" 2>&1
printf 'pod=deleted\nnetworkpolicy=incident-quarantine\nexec_exit=%s\n' "$?" > "$DIR/containment.txt"
cat "$DIR/containment.txt"
# exec_exit=1 (не 0)
```

## Задание 7. Override upstream-макроса и вывод в JSON/файл

Стандартное правило **Terminal shell in container** сработает и на легитимный
инструмент. Правильное место для environment-specific исключения - не редактирование
самого правила, а override зарезервированного upstream-макроса именно этого правила:
`user_expected_terminal_shell_in_container_conditions` (по умолчанию `(never_true)`, то
есть исключений нет). Не путайте его с похожим по названию `user_shell_container_exclusions` -
тот относится к отдельному правилу **Run shell untrusted** ("Shell spawned by untrusted
binary") и не влияет на **Terminal shell in container**. Используйте `k8s.pod.name` и
`k8s.ns.name`, а не `container.name`: `container.name` - это имя **контейнера** (здесь
`app`), а не Pod, и совпадение по имени контейнера почти всегда даёт неверный или слишком
широкий allowlist.

```bash
# терминал 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

Создайте Pod с интерактивным shell под именем, которое теперь исключено:

```bash
# терминал 2
kubectl apply -n runtime-112 -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ci-runner
  labels:
    app: ci-runner
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n runtime-112 --for=condition=Ready pod/ci-runner --timeout=60s
kubectl exec -n runtime-112 -it ci-runner -- sh -c 'echo shell-open; sleep 2'
```

Отдельно проверьте, что `immutable-app` из задания 5 (без исключения) продолжает давать alert - override
не должен тихо погасить правило целиком:

```bash
# терминал 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# терминал 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

Стандартный output правила **Terminal shell in container** не содержит `k8s.pod.name`/
`k8s.ns.name` (можно убедиться на control-plane: `grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
покажет `output` без этих полей). Без Pod/namespace evidence в самом alert надёжная correlation
конкретного срабатывания с конкретным Pod невозможна - текстовый `grep` по имени Pod в journal
просто не найдёт совпадения. Добавляем эти поля через тот же `override` механизм, но с
`output: append` вместо `condition: replace`:

```bash
# терминал 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

В `/etc/falco/config.d/` включите JSON-формат и файловый вывод. Falco 0.38+ по умолчанию
подхватывает `config_files` из этой директории; дописывание прямо в `falco.yaml` создаёт
дублирующиеся top-level ключи при повторном запуске и хуже переживает обновление пакета -
`config.d` предназначен именно для локальных дополнений:

```bash
# терминал 1 (control-plane, root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

Подтверждаем структурированно, через `output_fields`, а не текстовым `grep` по имени Pod -
это надёжно работает независимо от того, как именно отформатирована строка `output`:

```bash
# терминал 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# терминал 1 (control-plane, root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## Задание 8. Audit webhook backend

`audit-receiver` уже развёрнут стартовым скриптом. Создайте webhook kubeconfig, указывающий
на его Service; для лабы допустим HTTP, в production webhook требует HTTPS и client
certificate (глава 32).

```bash
# терминал 2: ClusterIP Service audit-receiver
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# терминал 1 (control-plane, root)
RECEIVER_IP=10.111.15.20     # впишите ClusterIP, который вывел терминал 2
cat > /etc/kubernetes/audit/webhook-config.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: audit-receiver
  cluster:
    server: http://${RECEIVER_IP}:8080/audit
users:
- name: kube-apiserver-audit
  user: {}
contexts:
- name: audit-webhook
  context:
    cluster: audit-receiver
    user: kube-apiserver-audit
current-context: audit-webhook
EOF
```

Допишите webhook-флаги в static manifest, **сохранив** уже настроенные флаги file backend
из задания 4 - webhook дополняет локальный лог, а не заменяет его:

```bash
# терминал 1 (control-plane, root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Добавить в command:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

Дождитесь восстановления API и выполните аудируемый запрос:

```bash
# терминал 2: повторяйте readyz, пока не вернёт "ok", затем аудируемый запрос
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

Проверьте, что webhook доставил событие получателю:

```bash
# терминал 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

Промежуточная проверка:

```bash
check_result
```

## Задание 9. Интеграционное задание: обход admission через containerd и обнаружение через Falco

Это задание связывает Supply Chain Security (лаба 111, глава 26) с Runtime Security этой
лабы: admission-проверка (Kyverno) не видит контейнер, если он создан прямо через
containerd, минуя kube-apiserver. Falco, в отличие от admission controller, работает на
уровне kernel syscalls и видит **все** контейнеры на ноде независимо от того, как они были
запущены.

**Важно не путать это с лабой 111**: там policy проверяет криптографическую подпись
(Cosign). Здесь policy проверяет только registry/repository allowlist - более простой
admission control без signature/attestor. Общий принцип для обоих один: admission работает
только на API admission path.

Lab-owned local registry names подготовлены bootstrap-ом (не публичный Docker Hub - controlled
abuse fixture этого задания должен быть safe и lab-owned, а не зависеть от доступности внешнего
registry на момент проверки). Они лежат в `/etc/cks112/registry.env` на control-plane; подключите
их в обоих терминалах:

```bash
# терминал 1 (control-plane, root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # момент начала прогона
install-kyverno
```

```bash
# терминал 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` - та же версия Kyverno, что в лабе 111.)

Создаём native `ValidatingPolicy` с allowlist на trusted registry. Используем Kyverno CEL
Image library (`image(...).registry()`/`.repository()`) для точного сравнения, а не
`startsWith` - иначе `${CKS112_TRUSTED_REPO}-evil` тоже прошёл бы policy, потому что его
image string просто начинается с разрешённой подстроки. Сообщение denial содержит
уникальный маркер `CKS112_TRUSTED_REPO_POLICY`, чтобы BATS позже мог отличить именно эту
policy от любого другого admission webhook/policy в кластере:

```bash
# терминал 2
kubectl apply -f - <<YAML
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods", "pods/ephemeralcontainers"]
      operations: ["CREATE", "UPDATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}') &&
      (!has(object.spec.initContainers) || object.spec.initContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}')) &&
      (!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}'))
    message: "CKS112_TRUSTED_REPO_POLICY: only ${CKS112_TRUSTED_IMAGE} is allowed in runtime-112"
  validationActions: [Deny]
YAML
```

Подтверждаем admission denial для образа вне allowlist:

```bash
# терминал 2 (подождите около 10 секунд после создания policy)
kubectl apply -n runtime-112 -f - > /var/work/tests/artifacts/9/admission-deny.txt 2>&1 <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: blocked-attempt
spec:
  containers:
  - name: app
    image: ${CKS112_UNTRUSTED_IMAGE}
    imagePullPolicy: IfNotPresent
    command: ["sleep", "60"]
YAML
cat /var/work/tests/artifacts/9/admission-deny.txt
# Error from server: ... CKS112_TRUSTED_REPO_POLICY: only ... is allowed in runtime-112
```

Теперь моделируем путь, который admission controller не видит: контейнер создаётся напрямую
в container runtime через CRI, минуя kube-apiserver целиком. Для этого на control-plane есть
хелпер `cks112-run <образ> <id> '<команда>'` (обёртка над `crictl runp/create/start`) и
`cks112-rm <id>` для очистки. Почему не `ctr run`: контейнеры, созданные через `ctr`, не
известны CRI, и Falco для них всегда пишет `container.image.repository = <NA>` - trusted и
untrusted образы были бы неразличимы. Контейнер, созданный через CRI, Falco видит с образом.
Каждый запуск получает один уникальный суффикс `$RUN_ID`, а все созданные им ID используют
этот суффикс, поэтому повторный прогон не столкнётся с остатками предыдущей попытки:

```bash
# терминал 1 (control-plane, root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE уже есть в локальном хранилище containerd после bootstrap - pull не нужен.
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` обязательно: команда `cks112-run ... 'echo CKS112_CTR_BYPASS'` сама
> запускается на хосте, и её command line содержит marker. Без этого условия правило
> сработало бы на хостовый процесс запуска (у него repository пуст, то есть не равен trusted),
> и даже доверенный образ давал бы ложный alert.
>
> Falco показывает для образа не тот тег, с которым запущен контейнер, а первое по алфавиту
> имя образа (образ может иметь несколько имён). Поэтому имена lab-образов используют
> registry-хост `cks112.local:5000`, который сортируется раньше `docker.io`.

Прежде чем писать точное условие, определяем РЕАЛЬНОЕ observed-значение
`%container.image.repository` для доверенного образа на этом containerd/Falco стеке -
не предполагаем его заранее. Разные container runtime/Falco версии могут по-разному
формировать это поле (с hostname registry или без него), поэтому единственный надёжный
способ - запустить доверенный контейнер с временным observe-правилом и посмотреть, что
Falco реально пишет:

```bash
# терминал 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE уже есть локально после bootstrap - pull не нужен.
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

Сохраните значение `$TRUSTED_REPO` (например `cks112/trusted` или
`cks112.local:5000/cks112/trusted` - именно то, что реально вывела ваша Falco/containerd
версия) как evidence, чтобы условие ниже было проверяемо привязано к наблюдаемому значению,
а не к предположению:

```bash
# терминал 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

Теперь добавляем финальное правило вслед за временным observe-правилом (`>>`, не
перезаписывая файл, чтобы не потерять правила из заданий 3 и 7). Условие использует **точное**
сравнение с наблюдаемым `$TRUSTED_REPO`, а не `startswith`/prefix-проверку:
`not container.image.repository startswith "$TRUSTED_REPO"` пропустил бы (не заметил бы)
репозиторий вроде `<TRUSTED_REPO>-evil`, потому что его имя просто НАЧИНАЕТСЯ с разрешённой
подстроки - то есть Falco считал бы его частью allowlist, хотя реально он вне допустимого
repository. Это та же ловушка, которую избегает Kyverno policy выше через `==`, а не
`startsWith`; условие admission и условие Falco должны проверять одно и то же repository
property одинаковым (exact) способом и с одним и тем же наблюдаемым значением, иначе они
не эквивалентны как security control:

```bash
# терминал 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Runtime Bypass of Admission
  desc: Process spawned in a container whose image is outside the runtime-112 trusted registry allowlist, indicating a container started outside kube-apiserver/admission (e.g. via ctr/crictl directly)
  condition: >
    spawned_process and
    container.id != host and
    proc.cmdline contains "CKS112_CTR_BYPASS" and
    container.image.repository != "$TRUSTED_REPO"
  output: >
    CKS112 runtime bypass of admission detected
    (command=%proc.cmdline container_id=%container.id
    repo=%container.image.repository tag=%container.image.tag
    pid=%proc.pid ppid=%proc.ppid user=%user.name)
  priority: CRITICAL
  tags: [cks112, supply_chain, admission_bypass]
EOF
systemctl restart falco && sleep 10
```

Прежде чем повторять bypass с untrusted-образом, проверяем оба контролируемых случая, чтобы
доказать, что сравнение действительно точное, а не prefix-based. Сначала доверенный образ - для
него алерта быть не должно (negative control):

```bash
# терминал 1 (control-plane, root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0: алерта для разрешённого repository нет
cks112-rm $PROBE_ALLOWED
```

Убираем первый container/task перед повтором, чтобы не оставлять "зависший" процесс, и
запускаем второй с новым уникальным ID - для него алерт обязан быть:

```bash
# терминал 1 (control-plane, root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-alpine.log
cks112-rm $BYPASS_2
```

Наконец, доказываем сам prefix-trap: репозиторий, построенный как `${TRUSTED_REPO}-evil`,
НАЧИНАЕТСЯ с той же подстроки, что и разрешённый `$TRUSTED_REPO`, но не равен ему точно.
Если бы Falco condition использовал `startswith` (как в более ранней, неправильной версии
этого правила), этот образ прошёл бы НЕЗАМЕЧЕННЫМ - именно поэтому исправленное условие
`!=` обязано поймать его. Образ prefix-trap подготовлен bootstrap-ом (`$CKS112_PREFIX_IMAGE`,
отдельный digest):

```bash
# терминал 1 (control-plane, root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# терминал 2: забрать файлы задания 9
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **Структура evidence-файлов задания 9.** `falco-bypass-attempt.log` - основной
> объединённый artifact, который проверяет автоматическая приёмка (содержит оба алерта:
> untrusted и prefix-trap, но не должен содержать алерт для trusted repo). Дополнительно
> каждый probe пишет собственный файл для ручной диагностики: `probe-trusted.log` (должен быть
> пустым - это и есть negative control), `probe-alpine.log` и `probe-prefix.log`.

Ключевой вывод этого задания: registry allowlist на admission и Falco на runtime - не
взаимозаменяемые слои, а взаимодополняющие. Admission останавливает путь через Kubernetes
API, но ничего не знает о процессах, запущенных прямо через container runtime на ноде;
Falco не может **заблокировать** создание такого контейнера заранее, но видит его после
запуска независимо от того, какой API (или его отсутствие) был использован. Тот же принцип
применяется к signature verification в лабе 111 - разница только в том, что там policy
проверяет подпись, а здесь просто registry/repository. Дополнительный вывод из
prefix-trap-проверки выше: Falco condition и Kyverno CEL policy должны использовать ОДИНАКОВУЮ
семантику сравнения (`==`/`!=`, а не `startsWith`/prefix), иначе они перестают быть
эквивалентными security-контролями, даже если оба формально проверяют "тот же" repository.

## 10. Обнаружить доступ к `/dev/mem` через file/device-open condition

Задания 3, 7 и 9 строили condition вокруг `spawned_process`/`proc.cmdline` - обнаружение
по ЗАПУСКУ процесса и его аргументам. Здесь используется принципиально другой класс
условия Falco: обнаружение по ОТКРЫТИЮ конкретного файла/устройства, независимо от того,
какой процесс и с какими аргументами командной строки это делает.

Deployment `mem-scanner` (2 реплики) уже развёрнут бутстрапом; обе реплики периодически
открывают `/dev/mem` изнутри контейнера. Путь `/dev/mem` внутри контейнера - synthetic
safe fixture (backing device на самом деле host `/dev/null`, а не реальная физическая
память хоста); для Falco-условия по имени файла (`fd.name = /dev/mem`) это неразличимо -
детектируется сам системный вызов `open`/`openat`/`openat2`. Добавьте правило на
`control-plane`:

```bash
# терминал 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Container access to /dev/mem
  desc: Detect an open of /dev/mem from a container process
  condition: >
    evt.type in (open, openat, openat2) and
    fd.name = /dev/mem and
    container.id != host
  output: >
    CKS112 Container access to /dev/mem
    (container_id=%container.id k8s_pod=%k8s.pod.name k8s_ns=%k8s.ns.name
    proc=%proc.name pid=%proc.pid user=%user.name)
  priority: CRITICAL
  tags: [container, mitre_privilege_escalation, mitre_defense_evasion]
EOF
systemctl restart falco && sleep 10
```

Дождитесь следующего периодического цикла `mem-scanner` (каждые ~15 секунд) и найдите
срабатывание. Идентификатор Pod берите ИЗ самого alert (`k8s_pod=`), а не угадывайте
заранее, какая из двух реплик виновна - это то же принципиальное правило "начинайте с
alert", что и в задании 6:

```bash
# терминал 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # из root
exit   # с control-plane
```

```bash
# терминал 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

Убедившись, что обнаружение подтверждено самим Falco (а не Pod manifest), сохраните Pod,
названный в alert, и убедитесь, что он действительно принадлежит ReplicaSet Deployment
`mem-scanner` до масштабирования:

```bash
# терминал 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

Затем останавливаем workload:

```bash
# терминал 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# ожидается: 0
```

`container.id != host` в условии - не декоративная деталь: без неё правило сработало бы
и на легитимные системные процессы ноды (например, инструменты диагностики памяти),
запущенные вне контейнеров, создавая шумные false positives на каждой ноде кластера.

В конце выполните `check_result`.
