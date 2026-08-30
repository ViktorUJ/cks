# Лаба 112 - эталонное решение: Falco, audit-логи и иммутабельность

Все команды Kubernetes выполняются на рабочей машине. Команды с `ssh control-plane`
меняют единственную workload/control-plane ноду. Контекст:

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5}
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
  output: "CKS112 custom shell marker (user=%user.name command=%proc.cmdline container=%container.id)"
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

## 4. RequestResponse audit для Secret

Создадим policy: первое правило имеет приоритет и фиксирует полный request/response для
всех `secrets` core API group; fallback `Metadata` сохраняет расследовательский контекст,
не записывая тела остальных запросов.

```bash
ssh control-plane 'sudo tee /etc/kubernetes/audit/policy.yaml >/dev/null' <<'YAML'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
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

Сгенерируйте API-запрос и сохраните ровно один подходящий JSON event как артефакт:

```bash
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
sleep 2
ssh control-plane "sudo jq -c 'select(.level == \"RequestResponse\" and .objectRef.resource == \"secrets\" and .objectRef.namespace == \"runtime-112\" and .objectRef.name == \"audit-secret\")' /var/log/kubernetes/audit/audit.log | tail -1" \
  | tee /var/work/tests/artifacts/4/secret-request-response.json
jq '{level, verb, objectRef, requestObject, responseObject}' \
  /var/work/tests/artifacts/4/secret-request-response.json
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

check_result
```
