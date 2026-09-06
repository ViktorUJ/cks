# Лаба 112 - эталонное решение: Falco, audit-логи и иммутабельность

Все команды Kubernetes выполняются на рабочей машине. Команды с `ssh control-plane`
меняют единственный узел control plane, на котором также запускаются рабочие нагрузки. Контекст:

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6}
```

## 1. Установка Falco с modern eBPF

Установим Falco из официального APT-репозитория. Modern eBPF не требует вручную собирать
или загружать kernel module.

```bash
ssh control-plane 'sudo bash -s' <<'EOF'
set -euo pipefail
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc |
  gpg --dearmor | sudo tee /usr/share/keyrings/falco-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" |
  sudo tee /etc/apt/sources.list.d/falcosecurity.list >/dev/null
sudo apt-get update
sudo env FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' \
  FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
sudo install -d -m 0755 /etc/falco/config.d
sudo tee /etc/falco/config.d/engine-kind.yaml >/dev/null <<'YAML'
engine:
  kind: modern_ebpf
YAML
sudo systemctl enable --now falco
EOF
ssh control-plane 'falco --version; systemctl is-active falco; sudo grep -R modern_ebpf /etc/falco'
```

Если сервис не запускается, сначала посмотрите `sudo journalctl -u falco -b --no-pager`.
Не заменяйте engine на kernel module: в этой лабе требуется именно `modern_ebpf`.

## 2. Стандартное правило для shell в контейнере

```bash
cat <<'EOF' | kubectl apply -f -
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

Сохраните настоящее событие Falco на рабочей машине. При необходимости увеличьте
количество строк `-n`, но не создавайте артефакт вручную.

```bash
ssh control-plane "sudo journalctl -u falco -b --no-pager -n 500 | grep -F 'Terminal shell in container' | tail -1" \
  | tee /var/work/tests/artifacts/2/falco-shell.log
cat /var/work/tests/artifacts/2/falco-shell.log
```

## 3. Локальное правило и контролируемый marker

Falco уже загружает `/etc/falco/falco_rules.local.yaml`; добавим правило именно туда.
`spawned_process` сохраняет совместимость с правилами Falco, а `container` не позволяет
матчить тот же marker, запущенный на хосте.

```bash
ssh control-plane 'sudo tee /etc/falco/falco_rules.local.yaml >/dev/null' <<'YAML'
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
YAML
ssh control-plane 'sudo systemctl restart falco && sudo systemctl is-active falco'

kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
sleep 2
ssh control-plane "sudo journalctl -u falco -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1" \
  | tee /var/work/tests/artifacts/3/falco-custom.log
```

Проверка синтаксиса и результата:

```bash
ssh control-plane 'sudo grep -nE "CKS112 Custom Shell Marker|CKS112_CUSTOM_EVENT|CKS112 custom shell marker" /etc/falco/falco_rules.local.yaml'
cat /var/work/tests/artifacts/3/falco-custom.log
```

## 4. Audit: RequestResponse для ConfigMap, Metadata для Secret

Создадим policy по правилу главы 32: полный request/response пишем только для
нечувствительного `configmaps` в `runtime-112`; для `secrets` берём `Metadata`, чтобы тело Secret
(токены, пароли) не попало в журнал. `None` и `omitStages` действительно сокращают high-volume
noise; финальный catch-all `Metadata` — fallback logging, а не шумоподавление. Порядок правил важен: специфичные правила идут до catch-all.

```bash
ssh control-plane 'sudo tee /etc/kubernetes/audit/policy.yaml >/dev/null' <<'YAML'
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
YAML
ssh control-plane 'sudo install -d -m 0750 /var/log/kubernetes/audit'
```

Отредактируйте `/etc/kubernetes/manifests/kube-apiserver.yaml` на control-plane. В `command`
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

Например, откройте manifest с `ssh control-plane 'sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml'`.
Это static Pod: kubelet автоматически пересоздаст API server. Дождитесь его готовности:

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
ssh control-plane "sudo grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml"
```

Создайте ConfigMap и сгенерируйте оба запроса, затем сохраните по одному подходящему JSON
event как артефакты:

```bash
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
sleep 2

# ConfigMap: полный RequestResponse event (нечувствительные данные).
ssh control-plane "sudo jq -c 'select(.level == \"RequestResponse\" and .objectRef.resource == \"configmaps\" and .objectRef.namespace == \"runtime-112\" and .objectRef.name == \"audit-config\")' /var/log/kubernetes/audit/audit.log | tail -1" \
  | tee /var/work/tests/artifacts/4/configmap-request-response.json

# Secret: только Metadata, без тела.
ssh control-plane "sudo jq -c 'select(.objectRef.resource == \"secrets\" and .objectRef.namespace == \"runtime-112\" and .objectRef.name == \"audit-secret\")' /var/log/kubernetes/audit/audit.log | tail -1" \
  | tee /var/work/tests/artifacts/4/secret-metadata.json
```

Проверьте, что ConfigMap залогирован с телом, а Secret - только на уровне `Metadata` и
**без** `requestObject`/`responseObject`:

```bash
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. Неизменяемый root filesystem

`emptyDir` даёт приложению контролируемое место для runtime-файлов; root filesystem
остается read-only. `hostPath` не нужен и не допускается.

```bash
cat <<'EOF' | kubectl apply -f -
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
set +e
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' \
  2>&1 | tee /var/work/tests/artifacts/5/rootfs-write-denied.log
rootfs_status=${PIPESTATUS[0]}
set -e
[ "$rootfs_status" -ne 0 ]
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. Минимальная цепочка containment от alert до изоляции

Audit backend уже работает, поэтому новый `kubectl exec` оставит API evidence. Запускаем
контролируемый долгоживущий процесс: marker остаётся в command line достаточно долго для
проверки `/proc`. В production подозрительный процесс не запускают повторно; здесь это
безопасная planted evidence одноразовой лабы.

```bash
DIR=/var/work/tests/artifacts/6
mkdir -p "$DIR"
START=$(date -u '+%Y-%m-%d %H:%M:%S')
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
sleep 4

ssh control-plane \
  "sudo journalctl -u falco -b --since '$START' --no-pager | grep -F 'CKS112 custom shell marker' | tail -1" \
  | tee "$DIR/falco-alert.log"
test -s "$DIR/falco-alert.log"

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' "$DIR/falco-alert.log" | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' "$DIR/falco-alert.log" | tail -1)
test -n "$SHORT_ID"
ssh control-plane "sudo test -r /proc/$HOST_PID/status"

CONTAINER_ID=$(ssh control-plane \
  "sudo crictl ps -a -q | awk '/^${SHORT_ID}/ {print; exit}'")
test -n "$CONTAINER_ID"
ssh control-plane "sudo crictl inspect '$CONTAINER_ID'" > "$DIR/cri-container.json"
SANDBOX_ID=$(jq -r '.status.sandboxId // .status.sandboxID // .info.sandboxID // empty' \
  "$DIR/cri-container.json")
ssh control-plane "sudo crictl inspectp '$SANDBOX_ID'" > "$DIR/cri-sandbox.json"

POD=$(jq -r '.status.metadata.name' "$DIR/cri-sandbox.json")
NAMESPACE=$(jq -r '.status.metadata.namespace' "$DIR/cri-sandbox.json")
NODE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
CONTAINER_INIT_PID=$(jq -r '.info.pid // empty' "$DIR/cri-container.json")
printf 'container_init_pid=%s\n' "$CONTAINER_INIT_PID" > "$DIR/cri-mapping.txt"

ssh control-plane "sudo cat /proc/$HOST_PID/status" > "$DIR/proc-status.txt"
ssh control-plane "sudo tr '\\0' ' ' </proc/$HOST_PID/cmdline; echo" > "$DIR/proc-cmdline.txt"
ssh control-plane "sudo cat /proc/$HOST_PID/cgroup" > "$DIR/proc-cgroup.txt"
ssh control-plane "sudo ps -eo pid,ppid,user,lstart,args --forest" > "$DIR/process-tree.txt"
```

Теперь коррелируем API event. Для `pods/exec` достаточно `Metadata`: command из request body
может содержать секрет, поэтому `RequestResponse` здесь не нужен.

```bash
sleep 3
ssh control-plane \
  "sudo jq -c 'select(.level == \"Metadata\" and .verb == \"create\" and .objectRef.resource == \"pods\" and .objectRef.subresource == \"exec\" and .objectRef.namespace == \"runtime-112\" and .objectRef.name == \"falco-shell\")' /var/log/kubernetes/audit/audit.log | tail -1" \
  > "$DIR/audit-exec.json"
jq -e 'has("requestObject") | not' "$DIR/audit-exec.json"

cat > "$DIR/evidence-summary.txt" <<EOF
alert_rule=CKS112 Custom Shell Marker
namespace=$NAMESPACE
pod=$POD
node=$NODE
runtime=containerd
container_id=$CONTAINER_ID
container_init_pid=$CONTAINER_INIT_PID
host_pid=$HOST_PID
audit_verb=create
audit_subresource=exec
attack_phase=Execution
technique=Container Administration Command
containment=quarantine-and-delete
EOF
```

Сначала сохраняем evidence, затем изолируем namespace на сетевом уровне и удаляем
скомпрометированный Pod. Это минимальная containment-цепочка, а не полное расследование:
credential revocation/rotation, поиск других workload и восстановление owner/controller выполняются отдельным IR-процессом. Последняя команда доказывает отрицательный outcome, а не ищет конкретный текст ошибки.

```bash
cat <<'EOF' | kubectl apply -f -
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
wait "$INCIDENT_EXEC_PID" 2>/dev/null || true
set +e
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT' \
  >"$DIR/post-containment-exec.log" 2>&1
EXEC_EXIT=$?
set -e
printf 'pod=deleted\nnetworkpolicy=incident-quarantine\nexec_exit=%s\n' "$EXEC_EXIT" \
  > "$DIR/containment.txt"
test "$EXEC_EXIT" -ne 0
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
ssh control-plane 'sudo tee -a /etc/falco/falco_rules.local.yaml >/dev/null' <<'YAML'

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
YAML
ssh control-plane 'sudo systemctl restart falco'
```

Создайте Pod с интерактивным shell под именем, которое теперь исключено:

```bash
kubectl apply -n runtime-112 -f - <<'YAML'
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
YAML
kubectl wait -n runtime-112 --for=condition=Ready pod/ci-runner --timeout=60s
kubectl exec -n runtime-112 -it ci-runner -- sh -c 'echo shell-open; sleep 2'
```

Отдельно проверьте, что `falco-shell` (без исключения) продолжает давать alert - override
не должен тихо погасить правило целиком:

```bash
kubectl exec -n runtime-112 -it falco-shell -- sh -c 'echo shell-open; sleep 2'
ssh control-plane "sudo journalctl -u falco -b --no-pager -n 200 | grep 'Terminal shell in container'"
```

Стандартный output правила **Terminal shell in container** не содержит `k8s.pod.name`/
`k8s.ns.name` (можно убедиться самостоятельно: `sudo grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
на control-plane покажет `output` без этих полей). Без Pod/namespace evidence в самом
alert надёжная correlation конкретного срабатывания с конкретным Pod невозможна - текстовый
`grep` по имени Pod в journal просто не найдёт совпадения. Добавляем эти поля через тот же
`override` механизм, но с `output: append` вместо `condition: replace`:

```bash
ssh control-plane 'sudo tee -a /etc/falco/falco_rules.local.yaml >/dev/null' <<'YAML'

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
YAML
ssh control-plane 'sudo systemctl restart falco'
```

В `/etc/falco/config.d/` включите JSON-формат и файловый вывод. Falco 0.38+ по умолчанию
подхватывает `config_files` из этой директории; дописывание прямо в `falco.yaml` через
`tee -a` создаёт дублирующиеся top-level ключи при повторном запуске и хуже переживает
обновление пакета - `config.d` предназначен именно для локальных дополнений:

```bash
ssh control-plane 'sudo mkdir -p /var/log/falco /etc/falco/config.d'
ssh control-plane 'sudo tee /etc/falco/config.d/cks112-output.yaml >/dev/null' <<'YAML'
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
YAML
ssh control-plane 'sudo systemctl restart falco'
```

Подтверждаем структурированно, через `output_fields`, а не текстовым `grep` по имени Pod -
это надёжно работает независимо от того, как именно отформатирована строка `output`:

```bash
kubectl exec -n runtime-112 -it falco-shell -- sh -c 'echo shell-open; sleep 2'
sleep 2
ssh control-plane "sudo tail -n 20 /var/log/falco/events.log" \
  | jq -c 'select(.rule == "Terminal shell in container")' | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "falco-shell", "ns": "runtime-112"}
```

## Задание 8. Audit webhook backend

`audit-receiver` уже развёрнут стартовым скриптом. Создайте webhook kubeconfig, указывающий
на его Service; для лабы допустим HTTP, в production webhook требует HTTPS и client
certificate (глава 32).

```bash
RECEIVER_IP=$(kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}')
ssh control-plane "sudo tee /etc/kubernetes/audit/webhook-config.yaml >/dev/null" <<EOF
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
ssh control-plane 'sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml.bak-webhook'
ssh control-plane "sudoedit /etc/kubernetes/manifests/kube-apiserver.yaml"
# Добавить в command:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

Дождитесь восстановления API и выполните аудируемый запрос:

```bash
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 5; done
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
sleep 3
```

Проверьте, что webhook доставил событие получателю:

```bash
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

Финальная проверка:

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

Устанавливаем Kyverno (та же версия, что в лабе 111):

```bash
ssh control-plane 'sudo install-kyverno'
```

Создаём native `ValidatingPolicy` с allowlist на trusted registry. Используем Kyverno CEL
Image library (`image(...).registry()`/`.repository()`) для точного сравнения, а не
`startsWith` - иначе `docker.io/library/busybox-evil` тоже прошёл бы policy, потому что его
image string просто начинается с разрешённой подстроки. Сообщение denial содержит
уникальный маркер `CKS112_TRUSTED_REPO_POLICY`, чтобы BATS позже мог отличить именно эту
policy от любого другого admission webhook/policy в кластере:

```bash
kubectl apply -f - <<'YAML'
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods"]
      operations: ["CREATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == 'docker.io' &&
        image(c.image).repository() == 'library/busybox')
    message: "CKS112_TRUSTED_REPO_POLICY: only docker.io/library/busybox is allowed in runtime-112"
  validationActions: [Deny]
YAML
```

Подтверждаем admission denial для образа вне allowlist:

```bash
mkdir -p /var/work/tests/artifacts/9
kubectl apply -n runtime-112 -f - 2>&1 | tee /var/work/tests/artifacts/9/admission-deny.txt <<'YAML' || true
apiVersion: v1
kind: Pod
metadata:
  name: blocked-attempt
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "60"]
YAML
grep -q 'CKS112_TRUSTED_REPO_POLICY' /var/work/tests/artifacts/9/admission-deny.txt
```

Теперь моделируем путь, который admission controller не видит: контейнер запускается
прямо через `ctr` в containerd namespace `k8s.io` (тот же namespace, что kubelet использует
для Pod), минуя kube-apiserver целиком. Каждый запуск использует **уникальный** container
ID (`cks112-bypass-1`, затем `cks112-bypass-2` после перезапуска Falco) и запускается
detached (`-d`), чтобы повторный прогон не столкнулся с ещё существующим предыдущим
container/task:

```bash
ssh control-plane 'sudo ctr -n k8s.io images pull docker.io/library/alpine:3.20'
ssh control-plane 'sudo ctr -n k8s.io run -d docker.io/library/alpine:3.20 cks112-bypass-1 \
  sh -c "echo CKS112_CTR_BYPASS; sleep 5"'
```

Добавляем custom rule, которая ловит именно этот сценарий: процесс с нашим marker **и**
image repository вне allowlist - то есть not просто любой alpine-процесс, а конкретно
попытка обойти ту же policy, что уже была применена на admission. Условие использует
**точное** сравнение `container.image.repository != "library/busybox"`, а не
`startswith`/prefix-проверку: `not container.image.repository startswith "library/busybox"`
пропустил бы (не заметил бы) репозиторий вроде `library/busybox-evil`, потому что его имя
просто НАЧИНАЕТСЯ с разрешённой подстроки - то есть Falco считал бы его частью allowlist,
хотя реально он вне допустимого repository. Это та же ловушка, которую избегает Kyverno
policy выше через `==`, а не `startsWith`; условие admission и условие Falco должны
проверять одно и то же repository property одинаковым (exact) способом, иначе они не
эквивалентны как security control:

```bash
ssh control-plane 'sudo tee -a /etc/falco/falco_rules.local.yaml >/dev/null' <<'YAML'

- rule: CKS112 Runtime Bypass of Admission
  desc: Process spawned in a container whose image is outside the runtime-112 trusted registry allowlist, indicating a container started outside kube-apiserver/admission (e.g. via ctr/crictl directly)
  condition: >
    spawned_process and
    proc.cmdline contains "CKS112_CTR_BYPASS" and
    container.image.repository != "library/busybox"
  output: >
    CKS112 runtime bypass of admission detected
    (command=%proc.cmdline container_id=%container.id
    image=%container.image.repository:%container.image.tag
    pid=%proc.pid ppid=%proc.ppid user=%user.name)
  priority: CRITICAL
  tags: [cks112, supply_chain, admission_bypass]
YAML
ssh control-plane 'sudo systemctl restart falco'
```

Прежде чем повторять bypass с alpine, проверяем оба контролируемых случая, чтобы доказать,
что сравнение действительно точное, а не prefix-based:

```bash
ssh control-plane 'sudo ctr -n k8s.io images pull docker.io/library/busybox:1.36'
ssh control-plane 'sudo ctr -n k8s.io run -d docker.io/library/busybox:1.36 cks112-probe-allowed \
  sh -c "echo CKS112_CTR_BYPASS; sleep 5"'
sleep 3
ssh control-plane "sudo journalctl -u falco -b --no-pager -n 50 | grep 'CKS112 runtime bypass of admission.*cks112-probe-allowed'" \
  || echo "OK: no alert for allowed repository library/busybox, as expected"
ssh control-plane 'sudo ctr -n k8s.io task kill cks112-probe-allowed 2>/dev/null; \
  sudo ctr -n k8s.io task rm cks112-probe-allowed 2>/dev/null; \
  sudo ctr -n k8s.io container rm cks112-probe-allowed 2>/dev/null' || true
```

Убираем первый container/task перед повтором, чтобы не оставлять "зависший" процесс, и
запускаем второй с новым уникальным ID:

```bash
ssh control-plane 'sudo ctr -n k8s.io task kill cks112-bypass-1 2>/dev/null; \
  sudo ctr -n k8s.io task rm cks112-bypass-1 2>/dev/null; \
  sudo ctr -n k8s.io container rm cks112-bypass-1 2>/dev/null' || true

ssh control-plane 'sudo ctr -n k8s.io run -d docker.io/library/alpine:3.20 cks112-bypass-2 \
  sh -c "echo CKS112_CTR_BYPASS; sleep 5"'
sleep 3
ssh control-plane "sudo journalctl -u falco -b --no-pager -n 200 | grep 'CKS112 runtime bypass of admission'" \
  | tee /var/work/tests/artifacts/9/falco-bypass-attempt.log

ssh control-plane 'sudo ctr -n k8s.io task kill cks112-bypass-2 2>/dev/null; \
  sudo ctr -n k8s.io task rm cks112-bypass-2 2>/dev/null; \
  sudo ctr -n k8s.io container rm cks112-bypass-2 2>/dev/null' || true
```

Наконец, доказываем сам prefix-trap: репозиторий `library/busybox-evil` НАЧИНАЕТСЯ с той же
подстроки, что и разрешённый `library/busybox`, но не равен ему точно. Если бы Falco
condition использовал `startswith` (как в более ранней, неправильной версии этого правила),
этот образ прошёл бы НЕЗАМЕЧЕННЫМ - именно поэтому исправленное условие `!=` обязано
поймать его:

```bash
ssh control-plane 'sudo ctr -n k8s.io images tag docker.io/library/alpine:3.20 docker.io/library/busybox-evil:1.0'
ssh control-plane 'sudo ctr -n k8s.io run -d docker.io/library/busybox-evil:1.0 cks112-prefix-trap \
  sh -c "echo CKS112_CTR_BYPASS; sleep 5"'
sleep 3
ssh control-plane "sudo journalctl -u falco -b --no-pager -n 50 | grep 'CKS112 runtime bypass of admission.*busybox-evil'" \
  | tee -a /var/work/tests/artifacts/9/falco-bypass-attempt.log

ssh control-plane 'sudo ctr -n k8s.io task kill cks112-prefix-trap 2>/dev/null; \
  sudo ctr -n k8s.io task rm cks112-prefix-trap 2>/dev/null; \
  sudo ctr -n k8s.io container rm cks112-prefix-trap 2>/dev/null' || true
```

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

В конце выполните `check_result`.
