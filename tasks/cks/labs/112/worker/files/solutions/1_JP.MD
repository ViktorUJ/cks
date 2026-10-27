[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 112 - 参考解答：Falco、audit ログ、immutability

試験と同じように作業します。**2 つのターミナル**を開き、実習の終わりまで両方を開いたままにしてください：

- **ターミナル 1 - control-plane:** `ssh control-plane`、続いて `sudo -i` (以降、ノード上のすべてのコマンドは
  root で、`sudo` なしで実行します)。唯一の control plane ノードは workload も実行します。
- **ターミナル 2 - 作業マシン：** ここで `kubectl`、`scp`、確認を行います。

ノードで取得した成果物は、control-plane の `/tmp/art/<課題番号>/` に保存され、
`scp` コマンドで作業マシンの `/var/work/tests/artifacts/<番号>/` にコピーされます。

## ドキュメントで例を見つける場所

| 必要なもの | ページとセクション |
| :--- | :--- |
| apt からの Falco のインストール (鍵、リポジトリ、`apt-get install -y falco`)、変数 `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`、`systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| Falco のルールと macro の override (`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy (レベル `None`/`Metadata`/`Request`/`RequestResponse`、`omitStages`、`rules`)、フラグ `--audit-policy-file`、`--audit-log-path`、`--audit-log-maxage/-maxbackup/-maxsize`、`hostPath` のマウント、webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` と `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| Deny-all `NetworkPolicy` | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

作業マシンでの最初の実行 (ターミナル 2)：

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

ノードでの最初の実行 (ターミナル 1)：

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. modern eBPF での Falco のインストール

Falco を公式の APT リポジトリからインストールします (Falco のドキュメントの Install ページのコマンド)。
Modern eBPF は、kernel module を手動でビルドしたりロードしたりする必要がありません。

```bash
# ターミナル 1 (control-plane、root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**インストールは別のコマンドとして実行してください：** `apt-get` はターミナルの入力バッファを破棄するため、
その直後に貼り付けた行は失われます。

```bash
# ターミナル 1 (control-plane、root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# ターミナル 1 (control-plane、root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# パッケージは unit falco-modern-bpf.service をインストールし、falco.service はそれへの alias にすぎません；
# alias に対する `systemctl enable falco` はエラーで終了するため、実際の unit を有効にします。
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

`sleep 20` が必要なのは、初回の起動時に modern eBPF の probe が数回の
再試行を伴って開かれるためです (journal に `Opening 'syscall' source` という行が複数見えます)：開かれるまでは
Falco はイベントを記録せず、課題 2 の shell が見逃される可能性があります。アラートが
出ない場合は、数秒後に `exec` をやり直してください。

サービスが起動しない場合は、まず `journalctl -u falco-modern-bpf -b --no-pager` を確認してください。
engine を kernel module に置き換えないでください：この実習では、まさに `modern_ebpf` が必要です。

## 2. コンテナ内の shell に対する標準のルール

```bash
# ターミナル 2 (作業マシン)
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
# shell の中で: exit
```

本物の Falco のイベントを保存してください：それは control-plane の journal から取得します。Falco は
少し遅れてイベントを書き込むため、shell を抜けた後、数秒待ってください。成果物を
手で作らないでください：

```bash
# ターミナル 1 (control-plane、root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# ターミナル 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. ローカルのルールと制御された marker

Falco はすでに `/etc/falco/falco_rules.local.yaml` をロードしています；ルールはまさにそこに追加します。
`spawned_process` は Falco のルールとの互換性を保ち、`container` は、ホスト上で起動された
同じ marker にマッチしてしまうことを防ぎます。

```bash
# ターミナル 1 (control-plane、root)
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
# ターミナル 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# ターミナル 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# ターミナル 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

解答では、各 `restart falco` の後に `sleep 10` を置いています：Falco はルールとコンテナのメタデータを
ロードするのに約 5 秒かかり、それより前に起きたイベントは journal に書き込みません。

## 4. Audit: ConfigMap は RequestResponse、Secret は Metadata

第 32 章のルールに従って policy を作成します：リクエスト/レスポンスの完全な記録は、`runtime-112` の
機微でない `configmaps` についてのみ行い、`secrets` には `Metadata` を使用して、Secret の本文
(token、パスワード) がログに入らないようにします。`None` と `omitStages` は、大量の
ノイズを実際に減らします；最終的な catch-all の `Metadata` は fallback logging であり、ノイズ抑制ではありません。ルールの順序は重要です：
具体的なルールが catch-all の前に来ます。ファイルの構造は、ドキュメントの例 (セクション Audit
policy) からのものです。

```bash
# ターミナル 1 (control-plane、root)
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

control-plane の `/etc/kubernetes/manifests/kube-apiserver.yaml` を編集します (`vim`)。コンテナ `kube-apiserver` の
`command` に次を追加します：

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

同じコンテナの `volumeMounts` に次を追加します：

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

`spec.volumes` に次を追加します：

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
# ターミナル 1 (control-plane、root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

これは static Pod です：kubelet が API server を自動的に再作成します (約 1 分、それまでは
`kubectl` は `connection refused` を返します)。準備ができるまで待ってください：

```bash
# ターミナル 2: コマンドが "ok" を返すまで繰り返します
kubectl get --raw=/readyz
```

```bash
# ターミナル 1: フラグが稼働中の manifest に入っている
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

ConfigMap を作成して両方のリクエストを生成し、それぞれ 1 つずつ適切な JSON event を
成果物として保存します：

```bash
# ターミナル 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# ターミナル 1 (control-plane、root)
# ConfigMap: 完全な RequestResponse event (機微でないデータ)。
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret: Metadata のみ、本文なし。
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# ターミナル 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

ConfigMap が本文とともに記録され、Secret はレベル `Metadata` のみで、
`requestObject`/`responseObject` が**ない**ことを確認します：

```bash
# ターミナル 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. immutable な root filesystem

`emptyDir` は、アプリケーションに runtime ファイル用の制御された場所を与えます；root filesystem は
read-only のままです。`hostPath` は不要であり、許可されません。

```bash
# ターミナル 2
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

両方の性質を実証し、拒否のメッセージを保存します：

```bash
# ターミナル 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. alert から isolation までの、最小限の containment の連鎖

Audit backend はすでに動作しているため、新しい `kubectl exec` は API の evidence を残します。制御された
長時間動作するプロセスを起動します：marker は、`/proc` を確認するのに十分な長さ、command line に残ります。
production では、疑わしいプロセスを再度起動することはありません；ここでは、使い捨ての実習のための
安全な planted evidence です。

```bash
# ターミナル 1 (control-plane、root): 実行開始の時刻 (journal を後で読み取る
# control-plane から時刻を取得します)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# ターミナル 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

以降はすべて、プロセスが生きている間に control-plane で行います：alert を取得し、そこから container id と
host pid を取り出します (推測するのではなく、alert から始めます)：

```bash
# ターミナル 1 (control-plane、root)
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

次に API event を correlation します。最近の `kubectl exec` は WebSocket 上で動作するため、audit では
`get` (SPDY の fallback の場合は `create`) として見えます。どちらでも構いません。`pods/exec` には
`Metadata` で十分です：request body の command には secret が含まれる可能性があるため、ここでは `RequestResponse` は不要です。

```bash
# ターミナル 1 (control-plane、root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# ターミナル 2: 連鎖のすべてのファイルを取得し、最終的な summary を組み立てる
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

まず evidence を保存し、次に namespace をネットワークレベルで隔離して、
compromise された Pod を削除します。これは最小限の containment の連鎖であり、完全な調査ではありません：
credential の revocation/rotation、他の workload の探索、owner/controller の復旧は、
別の IR の手順で行います。最後のコマンドは、特定のエラーのテキストを探すのではなく、
失敗という結果 (ネガティブな結果) を実証します。

```bash
# ターミナル 2
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
# exec_exit=1 (0 ではない)
```

## 7. upstream の macro の override と JSON/ファイルへの出力

標準のルール **Terminal shell in container** は、正当な
ツールにも発火します。環境固有の例外を設けるための正しい場所は、ルール自体の編集ではなく、
まさにこのルール用に予約された upstream の macro の override です：
`user_expected_terminal_shell_in_container_conditions` (デフォルトは `(never_true)` で、
つまり例外はありません)。名前の似た `user_shell_container_exclusions` と混同しないでください -
それは別のルール **Run shell untrusted** ("Shell spawned by untrusted
binary") に関するもので、**Terminal shell in container** には影響しません。`container.name` ではなく `k8s.pod.name` と
`k8s.ns.name` を使用してください：`container.name` は**コンテナ**の名前 (ここでは
`app`) であり、Pod ではありません。コンテナ名による一致は、ほぼ確実に誤った、あるいは広すぎる
allowlist になります。

```bash
# ターミナル 1 (control-plane、root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

現在除外されている名前で、インタラクティブな shell を持つ Pod を作成します：

```bash
# ターミナル 2
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

別途、課題 5 の `immutable-app` (除外なし) が引き続き alert を出すことを確認してください - override が
ルール全体を黙って無効にしてはなりません：

```bash
# ターミナル 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# ターミナル 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

ルール **Terminal shell in container** の標準の output には `k8s.pod.name`/
`k8s.ns.name` が含まれません (control-plane で確認できます：`grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
は、これらのフィールドのない `output` を示します)。alert 自体に Pod/namespace の evidence がなければ、
特定の発火を特定の Pod に確実に correlation することはできません - journal での Pod 名のテキストの `grep` は
一致を見つけられません。これらのフィールドを、同じ `override` の仕組みで、ただし
`condition: replace` の代わりに `output: append` で追加します：

```bash
# ターミナル 1 (control-plane、root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

`/etc/falco/config.d/` で JSON 形式とファイル出力を有効にします。Falco 0.38+ はデフォルトで、このディレクトリの
`config_files` を読み込みます；`falco.yaml` に直接追記すると、再実行時に
トップレベルのキーが重複し、パッケージの更新にも耐えにくくなります -
`config.d` は、まさにローカルの追加のためのものです：

```bash
# ターミナル 1 (control-plane、root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

Pod 名に対するテキストの `grep` ではなく、`output_fields` を通じて構造化された形で確認します -
これは、`output` の行がどのような形式であっても確実に動作します：

```bash
# ターミナル 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# ターミナル 1 (control-plane、root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## 8. Audit webhook backend

`audit-receiver` は起動スクリプトによってすでにデプロイされています。その Service を指す webhook の kubeconfig を
作成します；実習では HTTP で構いません。production の webhook には HTTPS と client
certificate が必要です (第 32 章)。

```bash
# ターミナル 2: Service audit-receiver の ClusterIP
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# ターミナル 1 (control-plane、root)
RECEIVER_IP=10.111.15.20     # ターミナル 2 が出力した ClusterIP を入力します
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

課題 4 ですでに設定した file backend のフラグを**維持した**まま、webhook のフラグを
static manifest に追記します - webhook はローカルのログを補完するものであり、置き換えるものではありません：

```bash
# ターミナル 1 (control-plane、root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command に追加します:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

API が復旧するまで待ち、監査対象のリクエストを実行します：

```bash
# ターミナル 2: readyz が "ok" を返すまで繰り返し、その後、監査対象のリクエストを実行します
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

webhook が受信側にイベントを配信したことを確認します：

```bash
# ターミナル 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

中間確認：

```bash
check_result
```

## 9. 統合課題：containerd 経由の admission の回避と Falco による検出

この課題は、Supply Chain Security (実習 111、第 26 章) を、この実習の Runtime Security と
結びつけます：admission の確認 (Kyverno) は、コンテナが containerd を通じて直接、
kube-apiserver を迂回して作成された場合、それを見ることができません。Falco は、admission controller とは異なり、
kernel syscalls のレベルで動作し、起動された方法に関係なく、ノード上の**すべての**コンテナを見ることができます。

**これを実習 111 と混同しないでください**：そこでは policy が暗号署名 (Cosign) を確認します。
ここでは policy が確認するのは registry/repository の allowlist だけで、signature/attestor のない、より単純な
admission control です。両者に共通する原則は 1 つです：admission は API admission の経路でのみ動作します。

実習が所有するローカルの registry の名前は、bootstrap が用意しています (公開の Docker Hub ではありません - この課題の controlled
abuse fixture は、確認の時点で外部の registry が利用できるかどうかに依存せず、安全で実習が所有するものでなければなりません)。
それらは control-plane の `/etc/cks112/registry.env` にあります；両方のターミナルで読み込んでください：

```bash
# ターミナル 1 (control-plane、root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # 実行開始の時刻
install-kyverno
```

```bash
# ターミナル 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` は、実習 111 と同じバージョンの Kyverno です。)

trusted registry への allowlist を持つ native `ValidatingPolicy` を作成します。正確な比較のために、
`startsWith` ではなく Kyverno CEL Image library (`image(...).registry()`/`.repository()`) を使用します -
そうでないと、`${CKS112_TRUSTED_REPO}-evil` も、その image の文字列が許可された部分文字列で始まっているというだけで
policy を通ってしまいます。denial のメッセージには一意のマーカー `CKS112_TRUSTED_REPO_POLICY` が含まれ、
BATS が後で、まさにこの policy を、クラスター内の他の admission webhook/policy と
区別できるようにします：

```bash
# ターミナル 2
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

allowlist 外の image に対する admission denial を確認します：

```bash
# ターミナル 2 (policy の作成後、約 10 秒待ってください)
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

次に、admission controller から見えない経路をシミュレートします：コンテナは、CRI を通じて
container runtime に直接作成され、kube-apiserver を完全に迂回します。そのために control-plane には
ヘルパー `cks112-run <image> <id> '<コマンド>'` (`crictl runp/create/start` のラッパー) と、
クリーンアップ用の `cks112-rm <id>` があります。なぜ `ctr run` ではないのか：`ctr` で作成されたコンテナは
CRI に知られておらず、Falco はそれらについて常に `container.image.repository = <NA>` と書き込み - trusted と
untrusted の image が区別できなくなります。CRI を通じて作成されたコンテナは、Falco には image 付きで見えます。
各実行は 1 つの一意の接尾辞 `$RUN_ID` を持ち、それによって作成されるすべての ID はこの
接尾辞を使うため、再実行しても前回の試行の残りと衝突しません：

```bash
# ターミナル 1 (control-plane、root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE は bootstrap の後、すでにローカルの containerd のストレージにあります - pull は不要です。
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` は必須です：コマンド `cks112-run ... 'echo CKS112_CTR_BYPASS'` 自体が
> ホスト上で実行され、その command line に marker が含まれます。この条件がないと、ルールは
> ホスト上の起動プロセスに発火し (その repository は空で、つまり trusted と等しくありません)、
> 信頼された image でも誤った alert を出してしまいます。
>
> Falco が image について表示するのは、コンテナが起動されたときの tag ではなく、アルファベット順で最初の
> image 名です (image は複数の名前を持つことがあります)。そのため、実習の image の名前は
> `docker.io` より前に並ぶ registry ホスト `cks112.local:5000` を使用しています。

正確な条件を書く前に、あなたの containerd/Falco の構成で、信頼された image についての
`%container.image.repository` の実際の observed 値を特定します -
あらかじめ仮定しないでください。container runtime/Falco のバージョンによって、このフィールドの
形成のされ方 (registry の hostname の有無) が異なる可能性があるため、唯一確実な
方法は、一時的な observe ルールを付けて信頼されたコンテナを起動し、Falco が実際に何を書き込むか
を見ることです：

```bash
# ターミナル 1 (control-plane、root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE は bootstrap の後、すでにローカルにあります - pull は不要です。
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

値 `$TRUSTED_REPO` (たとえば `cks112/trusted` や
`cks112.local:5000/cks112/trusted` - あなたの Falco/containerd のバージョンが実際に出力したもの) を evidence として保存し、
以下の条件が、仮定ではなく観察された値に検証可能な形で結びつくようにします：

```bash
# ターミナル 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

では、一時的な observe ルールの後に、最終的なルールを追加します (`>>` で、
課題 3 と 7 のルールを失わないようファイルを上書きしません)。条件は、観察された `$TRUSTED_REPO` との**正確な**
比較を使用し、`startswith`/prefix の確認は使いません：
`not container.image.repository startswith "$TRUSTED_REPO"` は、
`<TRUSTED_REPO>-evil` のような repository を見逃して (通して) しまいます。その名前が単に許可された
部分文字列で始まっているからです - つまり Falco はそれを allowlist の一部とみなしますが、実際には許可された
repository の外です。これは、上の Kyverno policy が `startsWith` ではなく `==` で避けているのと同じ罠です；
admission の条件と Falco の条件は、同じ repository の
property を、同じ (exact) 方法で、同じ観察された値を使って確認する必要があり、そうでなければ
security control として同等ではありません：

```bash
# ターミナル 1 (control-plane、root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Runtime Bypass of Admission
  desc: Process spawned in a container whose image is outside the runtime-112 trusted registry allowlist, indicating a container started outside kube-apiserver/admission (e.g. via crictl/CRI directly)
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

untrusted の image で回避を繰り返す前に、制御された 2 つのケースを確認し、
比較が prefix ベースではなく本当に正確であることを証明します。まず信頼された image - これに対しては
アラートがあってはなりません (negative control)：

```bash
# ターミナル 1 (control-plane、root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0: 許可された repository にはアラートがない
cks112-rm $PROBE_ALLOWED
```

「ハングした」プロセスが残らないよう、繰り返す前に最初の container/task を取り除き、
新しい一意の ID で 2 つ目を起動します - これに対してはアラートが必ずあるはずです：

```bash
# ターミナル 1 (control-plane、root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-untrusted.log
cks112-rm $BYPASS_2
```

最後に、prefix-trap そのものを実証します：`${TRUSTED_REPO}-evil` として構築された repository は、
許可された `$TRUSTED_REPO` と同じ部分文字列で始まりますが、それとは正確には等しくありません。
Falco の condition が (このルールの素朴な書き方のように) `startswith` を使っていたら、この image は
気づかれずに通ってしまっていたでしょう - だからこそ、修正された `!=` の条件は、それを捕捉する必要があります。prefix-trap の image は
bootstrap が用意しています (`$CKS112_PREFIX_IMAGE`、
別の digest)：

```bash
# ターミナル 1 (control-plane、root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# ターミナル 2: 課題 9 のファイルを取得する
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **課題 9 の evidence ファイルの構成。** `falco-bypass-attempt.log` は、自動的な受け入れが確認する
> 主な統合された artifact です (untrusted と prefix-trap の両方のアラートを含み、trusted の repo のアラートは
> 含んではなりません)。さらに、各 probe は手動の診断用に独自のファイルを書き込みます：`probe-trusted.log` (空で
> あるべきです - これがまさに negative control です)、`probe-untrusted.log`、`probe-prefix.log`。

この課題の重要な結論：admission での registry allowlist と runtime での Falco は、
互いに置き換えられる層ではなく、互いに補完し合う層です。Admission は Kubernetes
API を通る経路を止めますが、ノード上の container runtime を通じて直接起動されたプロセスについては何も知りません；
Falco は、そのようなコンテナの作成を事前に**ブロック**することはできませんが、どの API を使ったか (あるいは使わなかったか)
に関係なく、起動した後にそれを見ます。同じ原則は、
実習 111 の signature verification にも当てはまります - 違いは、そこでは policy が署名を
確認し、ここでは単に registry/repository を確認することだけです。上の prefix-trap の確認からの追加の結論：Falco の condition と
Kyverno の CEL policy は、同じ比較のセマンティクス (`==`/`!=`、`startsWith`/prefix ではなく) を使う必要があり、そうでなければ、
どちらも形式的には「同じ」repository を確認していても、同等の security control ではなくなります。

## 10. file/device-open condition による `/dev/mem` へのアクセスの検出

課題 3、7、9 は、`spawned_process`/`proc.cmdline` を中心に condition を作りました - プロセスの
起動とその引数による検出です。ここでは、原理的に別のクラスの Falco の
条件を使用します：どのプロセスが、どのコマンドライン引数でそれを行うかに関係なく、特定のファイル/デバイスのオープンによる検出です。

Deployment `mem-scanner` (2 つの replica) は bootstrap によってすでにデプロイされています；両方の replica が定期的に
コンテナ内から `/dev/mem` を開きます。コンテナ内の `/dev/mem` のパスは synthetic で
安全な fixture です (backing device は実際にはホストの `/dev/null` であり、ホストの実際の物理
メモリではありません)；ファイル名による Falco の条件 (`fd.name = /dev/mem`) にとっては、それは区別できません -
検出されるのは、システムコール `open`/`openat`/`openat2` 自体です。`control-plane` にルールを追加します：

```bash
# ターミナル 1 (control-plane、root)
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

`mem-scanner` の次の定期的なサイクル (約 15 秒ごと) を待ち、発火を見つけます。
Pod の識別子は alert 自体 (`k8s_pod=`) から取得してください。2 つの replica のどちらが原因かを
事前に推測しないでください - これは、課題 6 と同じ「alert から始める」という原則です：

```bash
# ターミナル 1 (control-plane、root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # root から
exit   # control-plane から
```

```bash
# ターミナル 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

検出が (Pod manifest ではなく) Falco 自体によって確認されたら、alert に
名指しされた Pod を、スケールの前に保存します (保存された JSON には owner の連鎖が表示されます：Deployment `mem-scanner` の
ReplicaSet)：

```bash
# ターミナル 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

その後、workload を停止します：

```bash
# ターミナル 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# 期待される結果: 0
```

条件の `container.id != host` は飾りの詳細ではありません：これがないと、ルールは、
コンテナの外で実行されている、ノードの正当なシステムプロセス (たとえば、メモリ診断ツール) にも発火し、
クラスターのすべてのノードで、ノイズの多い false positives を生み出します。

最後に `check_result` を実行します。
