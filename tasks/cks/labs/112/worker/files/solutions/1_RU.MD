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
нечувствительного ресурса `configmaps`; для `secrets` берём `Metadata`, чтобы тело Secret
(токены, пароли) не попало в журнал; завершаем безопасным catch-all `Metadata`. Порядок
правил важен: специфичные правила идут до catch-all.

```bash
ssh control-plane 'sudo tee /etc/kubernetes/audit/policy.yaml >/dev/null' <<'YAML'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 1. ConfigMap: контролируемый forensic-пример на нечувствительном ресурсе.
- level: RequestResponse
  resources:
  - group: ""
    resources: ["configmaps"]
# 2. Secret важен для расследования, но его body в журнал не пишем.
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 3. Безопасный default для остального API.
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

## 6. Расследование от alert до containment

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
скомпрометированный Pod. Последняя команда доказывает отрицательный outcome, а не ищет
конкретный текст ошибки.

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

check_result
```
