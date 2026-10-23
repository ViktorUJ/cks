[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 112 - 參考解答：Falco、audit 日誌與不可變性

像考試中一樣工作。打開**兩個終端機**，並在實驗結束之前保持兩者開啟：

- **終端機 1 - control-plane:**`ssh control-plane`，然後 `sudo -i`(之後在節點上的所有指令
  都以 root 身分執行，不用 `sudo`)。唯一的 control plane 節點也執行 workload。
- **終端機 2 - 工作機**：這裡是 `kubectl`、`scp` 與檢查。

在節點上取得的 artifacts，儲存在 control-plane 上的 `/tmp/art/<任務編號>/` 中，並
用 `scp` 指令複製到工作機的 `/var/work/tests/artifacts/<編號>/`。

## 在文件中哪裡可以找到範例

| 需要什麼 | 頁面與章節 |
| :--- | :--- |
| 從 apt 安裝 Falco(金鑰、repository、`apt-get install -y falco`)、變數 `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`、`systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| 覆寫 Falco 的規則與 macros(`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy(等級 `None`/`Metadata`/`Request`/`RequestResponse`、`omitStages`、`rules`)、旗標 `--audit-policy-file`、`--audit-log-path`、`--audit-log-maxage/-maxbackup/-maxsize`、`hostPath` 的掛載、webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` 與 `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| Deny-all `NetworkPolicy` | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

在工作機上的第一次啟動(終端機 2):

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

在節點上的第一次啟動(終端機 1):

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. 以 modern eBPF 安裝 Falco

我們從官方 APT repository 安裝 Falco(指令取自 Falco 文件的 Install
頁面)。Modern eBPF 不需要手動建置或載入 kernel module。

```bash
# 終端機 1(control-plane,root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**請用單獨的指令執行安裝：**`apt-get` 會清空終端機的輸入緩衝區，因此
緊接在它之後貼上的幾行會遺失。

```bash
# 終端機 1(control-plane,root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# 終端機 1(control-plane,root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# 套件安裝的是 unit falco-modern-bpf.service,而 falco.service 只是指向它的 alias;
# `systemctl enable falco` 透過 alias 會以錯誤結束,因此我們啟用真正的 unit。
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

需要 `sleep 20`，是因為第一次啟動時，modern eBPF probe 會經過多次
重試才打開(在 journal 中可以看到幾行 `Opening 'syscall' source`)：在它
打開之前，Falco 不會記錄事件，而任務 2 中的 shell 可能不會被發現。如果
沒有 alert，請幾秒鐘後重複 `exec`。

如果服務無法啟動，請先查看 `journalctl -u falco-modern-bpf -b --no-pager`。
不要把 engine 換成 kernel module：本實驗要求的正是 `modern_ebpf`。

## 2. 容器中 shell 的標準規則

```bash
# 終端機 2(工作機)
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
# 在 shell 內:exit
```

儲存真正的 Falco 事件：它取自 control-plane 上的 journal。Falco 寫入事件時
會有輕微的延遲，因此退出 shell 之後請等幾秒鐘。不要手動
建立 artifact:

```bash
# 終端機 1(control-plane,root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# 終端機 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. 本機規則與受控的 marker

Falco 已經會載入 `/etc/falco/falco_rules.local.yaml`；我們正是把規則加到那裡。
`spawned_process` 保持與 Falco 規則的相容性，而 `container` 讓同一個在主機上啟動的 marker
不會被比對到。

```bash
# 終端機 1(control-plane,root)
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
# 終端機 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# 終端機 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# 終端機 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

在解答中每次 `restart falco` 之後都有 `sleep 10`:Falco 載入規則與容器 metadata
大約需要 5 秒，在那之前發生的事件，它不會寫入 journal。

## 4. Audit:ConfigMap 使用 RequestResponse,Secret 使用 Metadata

我們依第 32 章的規則建立 policy：只對 `runtime-112` 中非敏感的 `configmaps` 記錄完整的
request/response；對 `secrets` 使用 `Metadata`，讓 Secret 的內容
(token、密碼)不會進入日誌。`None` 與 `omitStages` 確實減少高流量的
雜訊；最後的 catch-all `Metadata` 是 fallback logging，而不是降噪。規則的順序很重要：
具體的規則排在 catch-all 之前。檔案的結構取自文件中的範例(Audit
policy 一節)。

```bash
# 終端機 1(control-plane,root)
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

在 control-plane 上編輯 `/etc/kubernetes/manifests/kube-apiserver.yaml`(`vim`)。在容器 `kube-apiserver` 的
`command` 中加入：

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

在同一個容器的 `volumeMounts` 中加入：

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

在 `spec.volumes` 中加入：

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
# 終端機 1(control-plane,root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

這是 static Pod:kubelet 會自動重新建立 API server(大約一分鐘，在那之前
`kubectl` 會回應 `connection refused`)。請等待它就緒：

```bash
# 終端機 2:請重複執行,直到指令回傳 "ok"
kubectl get --raw=/readyz
```

```bash
# 終端機 1:確認旗標已寫入實際使用的 manifest
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

建立 ConfigMap 並產生這兩個請求，然後各儲存一個符合的 JSON event
作為 artifacts:

```bash
# 終端機 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# 終端機 1(control-plane,root)
# ConfigMap:完整的 RequestResponse event(非敏感資料)。
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret:只有 Metadata,沒有內容。
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# 終端機 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

確認 ConfigMap 是連同內容一起記錄的，而 Secret 只在 `Metadata` 等級，並且
**沒有** `requestObject`/`responseObject`:

```bash
# 終端機 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. 不可變的 root filesystem

`emptyDir` 為應用程式提供受控的 runtime 檔案位置；root filesystem
保持 read-only。不需要 `hostPath`，也不允許使用。

```bash
# 終端機 2
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

證明兩種特性，並儲存拒絕的訊息：

```bash
# 終端機 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. 從 alert 到隔離的最小 containment 鏈

Audit backend 已經在運作，因此新的 `kubectl exec` 會留下 API evidence。我們啟動
受控的、長時間執行的行程：marker 會在命令列中停留足夠長的時間，以便
檢查 `/proc`。在 production 中，不會再次執行可疑的行程；這裡則是
一次性實驗中安全的 planted evidence。

```bash
# 終端機 1(control-plane,root):執行開始的時間點(時間取自 control-plane,
# 之後也在那裡讀取 journal)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# 終端機 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

接下來，在行程存活期間，一切都在 control-plane 上進行：取得 alert，並從中取出 container id 與
host pid(從 alert 開始，而不是猜測):

```bash
# 終端機 1(control-plane,root)
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

現在對 API event 做 correlation。較新版本的 `kubectl exec` 運作在 WebSocket 之上，因此在 audit 中它
顯示為 `get`(在 SPDY fallback 時則為 `create`)，兩種都可以。對於 `pods/exec`,
`Metadata` 就足夠：request body 中的 command 可能包含 secret，因此這裡不需要 `RequestResponse`。

```bash
# 終端機 1(control-plane,root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# 終端機 2:取回鏈上的所有檔案並組成最終的 summary
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

先保存 evidence，然後在網路層級隔離 namespace，並刪除
被入侵的 Pod。這是最小的 containment 鏈，而不是完整的調查：
credential 的撤銷/輪替、尋找其他 workload 以及恢復 owner/controller 是由
單獨的 IR 流程完成的。最後一個指令證明的是負向的 outcome，而不是尋找具體的
錯誤文字。

```bash
# 終端機 2
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
# exec_exit=1(不是 0)
```

## 7. Override 上游 macro 並輸出為 JSON/檔案

標準規則 **Terminal shell in container** 也會對合法的
工具觸發。針對特定環境的例外，正確的位置不是編輯
規則本身，而是 override 正是這條規則所保留的上游 macro:
`user_expected_terminal_shell_in_container_conditions`(預設為 `(never_true)`，也就是
沒有例外)。不要把它與名稱相似的 `user_shell_container_exclusions` 混淆 -
那個屬於單獨的規則 **Run shell untrusted**("Shell spawned by untrusted
binary")，不影響 **Terminal shell in container**。請使用 `k8s.pod.name` 與
`k8s.ns.name`，而不是 `container.name`:`container.name` 是**容器**的名稱(這裡是
`app`)，而不是 Pod 的名稱，依容器名稱比對，幾乎總會得到錯誤或過
寬的 allowlist。

```bash
# 終端機 1(control-plane,root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

建立一個帶有互動式 shell 的 Pod，使用現在被排除的名稱：

```bash
# 終端機 2
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

另外確認任務 5 的 `immutable-app`(沒有例外)仍然會產生 alert - override
不應悄悄地把整條規則關掉：

```bash
# 終端機 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# 終端機 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

規則 **Terminal shell in container** 的標準 output 不包含 `k8s.pod.name`/
`k8s.ns.name`(可以在 control-plane 上確認：`grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
會顯示不含這些欄位的 `output`)。如果 alert 本身沒有 Pod/namespace evidence，就無法可靠地
把具體的觸發與具體的 Pod 做 correlation - 在 journal 中依 Pod 名稱做文字 `grep`
就是找不到相符的。我們透過同樣的 `override` 機制加入這些欄位，但使用
`output: append` 而不是 `condition: replace`:

```bash
# 終端機 1(control-plane,root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

在 `/etc/falco/config.d/` 中啟用 JSON 格式與檔案輸出。Falco 0.38+ 預設
會載入這個目錄中的 `config_files`；直接補寫到 `falco.yaml` 會在重複執行時產生
重複的 top-level 鍵，而且在套件更新時較難保留 -
`config.d` 正是為本機的補充設定而設計的：

```bash
# 終端機 1(control-plane,root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

我們以結構化的方式透過 `output_fields` 確認，而不是對 Pod 名稱做文字 `grep` -
無論 `output` 這一行是如何格式化的，這都能可靠地運作：

```bash
# 終端機 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# 終端機 1(control-plane,root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## 8. Audit webhook backend

`audit-receiver` 已經由啟動腳本部署。請建立指向它的 Service 的
webhook kubeconfig；實驗中允許使用 HTTP，在 production 中 webhook 需要 HTTPS 與 client
certificate(第 32 章)。

```bash
# 終端機 2:Service audit-receiver 的 ClusterIP
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# 終端機 1(control-plane,root)
RECEIVER_IP=10.111.15.20     # 填入終端機 2 輸出的 ClusterIP
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

把 webhook 旗標補寫到 static manifest,**同時保留**任務 4 中已經設定的 file backend
旗標 - webhook 是補充本機的 log，而不是取代它：

```bash
# 終端機 1(control-plane,root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# 在 command 中加入:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

等待 API 恢復，並執行會被稽核的請求：

```bash
# 終端機 2:重複執行 readyz,直到回傳 "ok",然後是會被稽核的請求
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

確認 webhook 把事件送達了接收器：

```bash
# 終端機 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

中間檢查：

```bash
check_result
```

## 9. 整合任務：透過 containerd 繞過 admission 並透過 Falco 偵測

這個任務把 Supply Chain Security(實驗 111，第 26 章)與本
實驗的 Runtime Security 連結起來：如果容器是直接透過
containerd 建立的，繞過 kube-apiserver,admission 檢查(Kyverno)就看不到它。Falco 與 admission controller 不同，它運作在
kernel syscalls 層級，會看到節點上的**所有**容器，與它們是如何
啟動的無關。

**重要：不要把這與實驗 111 混淆**：在那裡 policy 檢查密碼學簽章
(Cosign)。在這裡，policy 只檢查 registry/repository allowlist - 更簡單的
admission control，沒有 signature/attestor。兩者的共同原則是：admission 只在
API admission 路徑上運作。

Lab-owned 的本機 registry 名稱由 bootstrap 準備(不是公開的 Docker Hub - 這個任務的 controlled
abuse fixture 必須是安全且 lab-owned 的，而不是依賴檢查當下外部
registry 的可用性)。它們位於 control-plane 上的 `/etc/cks112/registry.env`；請在兩個終端機中
載入它們：

```bash
# 終端機 1(control-plane,root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # 執行開始的時間點
install-kyverno
```

```bash
# 終端機 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` - 與實驗 111 中相同版本的 Kyverno。)

建立帶有 trusted registry allowlist 的 native `ValidatingPolicy`。我們使用 Kyverno CEL
Image library(`image(...).registry()`/`.repository()`)做精確比較，而不是
`startsWith` - 否則 `${CKS112_TRUSTED_REPO}-evil` 也會通過 policy，因為它的
image 字串只是以允許的子字串開頭。denial 的訊息包含
唯一的標記 `CKS112_TRUSTED_REPO_POLICY`，讓 BATS 之後能夠把正是這個
policy 與叢集中任何其他 admission webhook/policy 區分開來：

```bash
# 終端機 2
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

確認對 allowlist 之外的映像的 admission denial:

```bash
# 終端機 2(建立 policy 之後請等待約 10 秒)
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

現在模擬 admission controller 看不到的路徑：容器直接在
container runtime 中透過 CRI 建立，完全繞過 kube-apiserver。為此，control-plane 上有
helper `cks112-run <映像> <id> '<指令>'`(`crictl runp/create/start` 的包裝器)以及
用於清理的 `cks112-rm <id>`。為什麼不用 `ctr run`：透過 `ctr` 建立的容器，CRI 不知道它們，
而 Falco 對它們總是寫下 `container.image.repository = <NA>` - trusted 與
untrusted 的映像就無法區分。透過 CRI 建立的容器，Falco 能連同映像一起看到它。
每次執行都會得到一個唯一的後綴 `$RUN_ID`，而它建立的所有 ID 都使用
這個後綴，因此重複執行時不會撞上上一次嘗試留下的東西：

```bash
# 終端機 1(control-plane,root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE 在 bootstrap 之後已經存在於本機的 containerd 儲存區 - 不需要 pull。
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` 是必須的：指令 `cks112-run ... 'echo CKS112_CTR_BYPASS'` 本身
> 就是在主機上啟動的，它的命令列包含 marker。沒有這個條件，規則
> 會對主機上啟動的行程觸發(它的 repository 為空，也就是不等於 trusted),
> 即使是受信任的映像也會產生誤報的 alert。
>
> Falco 為 image 顯示的不是容器啟動時所用的 tag，而是依字母順序第一個
> image 名稱(一個映像可以有多個名稱)。因此 lab 映像的名稱使用
> registry host `cks112.local:5000`，它的排序早於 `docker.io`。

在撰寫精確的條件之前，先確定在這個 containerd/Falco 堆疊上，受信任映像的欄位
`%container.image.repository` 的「真實」observed 值 -
不要事先假設。不同的 container runtime/Falco 版本可能以不同的方式
形成這個欄位(帶有 registry 的 hostname 或不帶)，因此唯一可靠的
方法是用臨時的 observe 規則啟動受信任的容器，並查看
Falco 實際寫下的內容：

```bash
# 終端機 1(control-plane,root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE 在 bootstrap 之後已經存在於本機 - 不需要 pull。
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

把值 `$TRUSTED_REPO`(例如 `cks112/trusted` 或
`cks112.local:5000/cks112/trusted` - 正是你的 Falco/containerd
版本實際輸出的內容)儲存為 evidence，讓下面的條件以可驗證的方式綁定到觀察到的值，
而不是假設：

```bash
# 終端機 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

現在在臨時的 observe 規則之後加入最終的規則(`>>`，不要
覆寫檔案，以免遺失任務 3 與 7 的規則)。條件使用與觀察到的 `$TRUSTED_REPO` 的**精確**
比較，而不是 `startswith`/prefix 檢查：
`not container.image.repository startswith "$TRUSTED_REPO"` 會放過(沒有發現)
像 `<TRUSTED_REPO>-evil` 這樣的 repository，因為它的名稱只是「以」允許的
子字串「開頭」 - 也就是說，Falco 會把它當作 allowlist 的一部分，儘管它實際上不在允許的
repository 之內。這正是上面的 Kyverno policy 透過 `==` 而不是
`startsWith` 所避免的同一個陷阱；admission 的條件與 Falco 的條件必須以相同的(exact)方式、
並使用相同的觀察到的值來檢查同一個 repository
屬性，否則它們作為 security control 就不等價：

```bash
# 終端機 1(control-plane,root)
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

在用 untrusted 映像重複繞過之前，先檢查兩種受控的情況，以
證明比較確實是精確的，而不是基於 prefix 的。先用受信任的映像 - 對
它不應該有 alert(negative control):

```bash
# 終端機 1(control-plane,root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0:允許的 repository 沒有 alert
cks112-rm $PROBE_ALLOWED
```

在重複之前移除第一個 container/task，以免留下「卡住的」行程，並
以新的唯一 ID 啟動第二個 - 對它，alert 必須出現：

```bash
# 終端機 1(control-plane,root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-untrusted.log
cks112-rm $BYPASS_2
```

最後，證明 prefix-trap 本身：以 `${TRUSTED_REPO}-evil` 建構的 repository,
「以」與允許的 `$TRUSTED_REPO` 相同的子字串「開頭」，但並不精確相等。
如果 Falco condition 使用 `startswith`(如這條規則的單純版本)，這個 image 就會「不被發現地」
通過 - 這正是為什麼修正後的條件
`!=` 必須抓到它。Prefix-trap 映像由 bootstrap 準備(`$CKS112_PREFIX_IMAGE`,
獨立的 digest):

```bash
# 終端機 1(control-plane,root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# 終端機 2:取回任務 9 的檔案
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **任務 9 的 evidence 檔案結構。**`falco-bypass-attempt.log` - 主要的
> 合併 artifact，由自動驗收檢查(包含兩個 alert:
> untrusted 與 prefix-trap，但不應包含針對 trusted repo 的 alert)。此外，
> 每個 probe 都會寫自己的檔案供手動診斷：`probe-trusted.log`(必須為
> 空 - 這正是 negative control)、`probe-untrusted.log` 與 `probe-prefix.log`。

這個任務的關鍵結論：admission 上的 registry allowlist 與 runtime 上的 Falco，不是
可以互相替換的層，而是互補的。Admission 阻擋經過 Kubernetes
API 的路徑，但對直接透過節點上 container runtime 啟動的行程一無所知；
Falco 無法事先**阻擋**這樣的容器的建立，但在它
啟動之後就能看到它，與所使用的是哪個 API(或沒有 API)無關。同樣的原則
也適用於實驗 111 中的 signature verification - 差別只在於那裡 policy
檢查的是簽章，而這裡只是 registry/repository。從上面 prefix-trap
檢查中得到的附加結論：Falco condition 與 Kyverno CEL policy 必須使用「相同的」
比較語意(`==`/`!=`，而不是 `startsWith`/prefix)，否則它們就不再是
等價的 security controls，即使兩者在形式上檢查的是「同一個」repository。

## 10. 透過 file/device-open condition 偵測對 `/dev/mem` 的存取

任務 3、7 與 9 圍繞 `spawned_process`/`proc.cmdline` 建構 condition - 依
行程的「啟動」與它的參數來偵測。這裡使用的是本質上不同類別的
Falco 條件：依「開啟」具體檔案/裝置來偵測，與
哪個行程、以什麼命令列參數執行此操作無關。

Deployment `mem-scanner`(2 個 replica)已經由 bootstrap 部署；兩個 replica 都會定期
在容器內開啟 `/dev/mem`。容器內的路徑 `/dev/mem` 是 synthetic
safe fixture(其背後的裝置實際上是主機的 `/dev/null`，而不是主機真實的實體
記憶體)；對依檔名(`fd.name = /dev/mem`)的 Falco 條件來說，這是無法區分的 -
偵測的是系統呼叫 `open`/`openat`/`openat2` 本身。在
`control-plane` 上加入規則：

```bash
# 終端機 1(control-plane,root)
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

等待 `mem-scanner` 的下一個週期(大約每 15 秒一次)，並找出
觸發的事件。Pod 的識別碼請取自 alert 本身(`k8s_pod=`)，而不是事先猜測
兩個 replica 中哪一個有問題 - 這與任務 6 中「從
alert 開始」是同樣的原則：

```bash
# 終端機 1(control-plane,root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 終端機 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

在確認偵測是由 Falco 本身(而不是 Pod manifest)證實之後，在縮減之前儲存 alert 中
指名的 Pod(儲存的 JSON 中會看到 owner 鏈：Deployment
`mem-scanner` 的 ReplicaSet)：

```bash
# 終端機 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

然後停止 workload:

```bash
# 終端機 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# 預期:0
```

條件中的 `container.id != host` 不是裝飾性的細節：沒有它，規則也會對
節點上合法的系統行程(例如記憶體診斷工具)觸發，而這些行程
是在容器之外執行的，這會在叢集的每個節點上產生吵雜的 false positives。

最後執行 `check_result`。
