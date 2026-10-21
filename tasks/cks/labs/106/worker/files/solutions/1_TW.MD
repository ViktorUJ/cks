[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 106 - 參考解答:AppArmor 與 seccomp

> Kubernetes 指令(`kubectl`)請在工作機(`worker`)上執行。所有與
> 節點本身有關的事(AppArmor、kubelet、`crictl`),請**直接在節點上**操作:用 `ssh` 登入一
> 次並切換成 root(`sudo -i`)- 這比把每個指令都用單獨的
> `ssh control-plane '...'` 送出更快,在考試中也應該這樣操作。Namespace
> `security-106` 在任務 3 中建立。
>
> ```bash
> ssh control-plane
> sudo -i
> # ... 在節點上的指令 ...
> exit   # 離開 root
> exit   # 從節點回到 worker
> ```
>
> 檢查會從**工作機**(`/var/work/tests/artifacts/<編號>/`)讀取 artifacts,它們
> 只用於實驗 - 考試中沒有。我們從 `worker` 用簡短的指令(`> 檔案`)儲存它們,
> 內容再單獨透過 `cat <檔案>` 查看。

## 1. 搬移並載入 AppArmor profile

Profile 只存在於工作機上。我們把它複製到節點(從 `worker`),然後在節點上
放到定位並載入核心。檔案已經包含旗標 `complain`,因此單單
`apparmor_parser -r` 就足以完成首次載入(不用 `aa-complain`,它和
`aa-enforce` 一樣會解析 `/etc/apparmor.d/` 中的所有檔案,並且會在任務 9 中
仍然損壞的 `k8s-106-broken-profile` 上失敗):

```bash
# 在 worker 上
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# 在節點上
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# 預期:"k8s-106-deny-write":	"complain",
```

## 2. 把 AppArmor profile 切換到 enforce

Profile 目前處於 `complain` 模式(在任務 1 中以這個旗標載入)。我們留在節點上
(以 root 身分),並把既有的 profile 切換到 enforcing mode:

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# 預期:"k8s-106-deny-write":	"enforce",
# 一般的 'aa-status | grep ...' 不會顯示 profile 的模式:在文字輸出中,profile
# 被分組在標題('N profiles are in enforce mode.')下,名稱沒有後綴。
# 要檢查具體的 profile,請使用 'aa-status --pretty-json'(或 '--json')。
exit
exit
```

在完成任務 9 之前,對「這個」profile 不要使用 `aa-enforce`/`aa-complain` 以及
`apparmor-utils` 套件中其他以 Python 寫成、用來修改 profile 的工具:它們內部會呼叫 `apparmor.read_profiles()`,
啟動時會解析
(parse)`/etc/apparmor.d/` 中的**所有**檔案,包括尚未載入、且明顯
損壞的任務 9 中的 `/etc/apparmor.d/k8s-106-broken-profile` - 並在「別人的」檔案上以
parser 錯誤失敗,根本走不到你的 profile。`apparmor_parser`
(二進位檔,而不是 Python 包裝器)直接以「一個」具體檔案呼叫時,只會解析
該檔案,不受這個問題影響 - 正因如此,我們透過 `sed` 手動修改 profile 的旗標
(從 `flags=(...)` 中移除 `complain`),然後透過 `apparmor_parser -r` 重新載入
這個檔案。

`aa-status` 是單獨的狀態檢視工具,而不是修改 profile 的工具,因此與這裡無關。具體 profile 的模式可由 `aa-status --pretty-json` 顯示(已在
實驗節點上驗證,apparmor 3.0.4;`--json` 會以單行給出相同內容,例如
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`)。另一種方式是核心檔案
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles`:那裡的格式是
`name (enforce|complain)`。

## 3. 帶有 Localhost AppArmor 與寫入拒絕的 Pod

建立 namespace 與 Pod。`emptyDir` 保證 `/work` 存在;profile 允許
行程啟動,但禁止在這個目錄中寫入。Node selector 把 Pod 綁定到
profile 確實已載入的節點上。

```yaml
# apparmor-writer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-106
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

```bash
# 在 worker 上
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# 等待 STATUS 變成 Running(重複 get),然後再執行 exec

# Evidence:profile 確實已指派給 PID 1 行程,而不只是寫在 Pod YAML 中。
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# 拒絕「之前」的 positive control:在將要檢查 denial 的同一個 /work 上執行被允許的 read 操作 -
# 沒有這一步,就無法把寫入被拒絕與完全無法運作的 mount/mountPath
# 區分開來(在那種情況下,連讀取都會無法使用)。
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Negative control:denial 必須正是 AppArmor 對寫入的拒絕。
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# 預期非零代碼:Permission denied / Operation not permitted
```

非零 exit code 與文字 'permission denied' 本身「並不」能證明正是
AppArmor 的這條規則起了作用 - 一般的 DAC/檔案系統錯誤,從 shell 的角度看起來
完全一樣。請透過 kernel audit log 把拒絕與這個 profile 連結起來;在上述嘗試之後,立刻
在節點上查看:

```bash
# 在節點上
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# 預期會有形如這樣的記錄:... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod:建立檔案;寫入既有檔案時會是 "w")
exit
exit
```

如果 `/proc/1/attr/current` 在具體的 runtime 中無法使用,請記錄這一點,並依據
Localhost profile 的指派,再加上針對該 profile 的 kernel `apparmor="DENIED"`;
沒有這些 evidence,單單一個非零代碼是不夠的,因為 mount 或一般的
Unix 權限也可能產生它。

## 4. 一般 Pod 的 RuntimeDefault

`RuntimeDefault` 是可攜的 baseline,它選用標準的
containerd/runtime profile。這個欄位在 Pod 層級明確設定。

```yaml
# runtime-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
# 在 worker 上
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp 與證明 `unshare` 被阻擋

檔案只存在於工作機上的 `/opt/lab106-fixtures/cks-106-deny-unshare.json`。
把它複製到節點(從 `worker`),並放進 kubelet 的 seccomp root(在節點上):

```bash
# 在 worker 上
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# 在節點上
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

在 API 中,指定相對於 seccomp root 的路徑:`profiles/cks-106-deny-unshare.json`。

`SYS_ADMIN` 在這裡是僅限實驗的、刻意設置的危險例外(沒有 seccomp 的 control 檢查由 checker 負責)。沒有自訂
filter 時,帶有這個 capability 的 `unshare -n` 可能會成功;seccomp 必須回傳 `EPERM`。
這不是 hardened 的組合。`allowPrivilegeEscalation: false` 會啟用 `no_new_privs`,但
不會收回已經授予行程的 capabilities,因此我們不把這個欄位當作
對 `SYS_ADMIN` 的「補償」。在 production 中,如果沒有經過證明的
必要性,就應該移除這樣的 capability。在 Kubernetes 中,capability 寫作 `SYS_ADMIN`,不帶前綴 `CAP_`。

我們使用 `unshare -n`(network namespace,`CLONE_NEWNET`),而「不是」`unshare -m`(mount
namespace)。這兩個操作需要同樣的 `CAP_SYS_ADMIN`,但 BusyBox 的 `unshare -m`
在成功執行 `unshare(2)` 之後,還會額外執行獨立的 `mount(2)` 系統呼叫,
用於強制 private propagation - 而 containerd 預設的 AppArmor profile(`RuntimeDefault`,
由於這裡沒有指定明確的 `appArmorProfile`,所以這個 Pod 會取得它)包含
`deny mount,`,沒有任何針對旗標的條件,與 capabilities/seccomp 無關。因此
`unshare -m true` 可能因為 AppArmor 而以 `EPERM` 失敗,即使 seccomp 根本沒有
限制 `unshare` - 這樣的 probe 會混淆兩種不同的 security control。`unshare -n`
只呼叫系統呼叫 `unshare(2)` 本身,沒有附帶的 `mount()`。

```yaml
# localhost-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      if unshare -n true 2>/tmp/unshare.err; then
        echo 'unshare unexpectedly succeeded' >/tmp/unshare-result
        exit 1
      fi
      grep -Eqi 'operation not permitted|permission denied' /tmp/unshare.err
      echo 'unshare denied by seccomp' >/tmp/unshare-result
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

```bash
# 在 worker 上
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# 預期非零代碼:Operation not permitted / Permission denied
```

## 7. User namespaces:`hostUsers: false` 與 `uid_map`

`hostUsers: false` 要求 kubelet 為 Pod 配置獨立的 user namespace:容器「內部」的 root(UID 0)
會對應到主機上非特權的 UID 範圍。我們不設定
`runAsUser`,讓行程確實以 namespace「內部」的 UID 0 啟動 - 正是這種
情況展示了轉換,而不是一開始就沒有權限。

```yaml
# userns-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-probe
  namespace: security-106
spec:
  hostUsers: false
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# 在 worker 上
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

容器的 host PID 既不等於容器內的 PID,也無法直接透過
`kubectl` 看到。我們在 worker 上取得容器 ID,並在實際執行該 Pod 的節點上,透過 `crictl inspect` 取得 PID:

```bash
# 在 worker 上
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - 複製 <ID>,不帶前綴 containerd://

# 在節點上
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# 例如:15205 - 這就是 <host PID>
```

節點上的 `/proc/<host PID>/uid_map` 描述了轉換:三個數字 - `<container-uid-start>
<host-uid-start> <length>`。對於 `hostUsers: false`,第一行必須以 `0` 開頭
(container UID 0),但 host-uid-start 必須**不為零** - 這就是
主機上非特權的範圍,而 `length` 是標準的 per-Pod `65536` 個 UID 區塊。

```bash
# 在節點上(以 root 身分)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (host-uid-start 每個 Pod 都不同,重點是不為 0)
exit
exit
```

把 `uid_map` 這一行儲存到 artifact(在 `worker` 上):

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

如果 `host-uid-start` 等於 `0` - 表示 user namespace 沒有套用(例如由於
不相容的 containerd/runc,或實際套用的 Pod 中缺少 `hostUsers: false`)- 這就不是 hardening,而是主機上一般的 root。作為比較:沒有
`hostUsers: false` 的一般 Pod,其 `/proc/<host-PID>/uid_map` 檔案同樣存在,但行程仍然留在
host(initial)user namespace 中。因此 mapping 從 UID 0 -> host UID 0 開始(通常
是形如 `0 0 4294967295` 的行,例如節點上的 `cat /proc/1/uid_map`),而不是從
非特權的 per-Pod host UID 開始。對於帶有 `hostUsers: false` 的 `userns-probe`,預期的是
相反的結果:`0 <非零的-host-uid> <per-pod-範圍>`。

## 8. kubelet 上的 `seccompDefault: true`

先前所有的 Pod 都明確設定了 `seccompProfile`。這裡我們檢查 node-level baseline:
如果開發者忘了這個欄位,kubelet 必須自己套用 `RuntimeDefault`,而不是
讓行程保持 `Unconfined`。在節點上修改 kubelet 的設定:

```bash
# 在節點上
ssh control-plane
sudo -i
grep -q '^seccompDefault:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^seccompDefault:.*/seccompDefault: true/' /var/lib/kubelet/config.yaml \
  || echo 'seccompDefault: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

```bash
# 在 worker 上:API 中的 Node 名稱不是 /etc/hosts 中的別名 'control-plane',而是節點真實的名稱(ip-10-...)
kubectl get nodes     # Ready
```

建立完全沒有提到 `seccompProfile` 的 Pod - 無論是 Pod 層級還是 container 層級:

```yaml
# no-seccomp-field.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-seccomp-field
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# 在 worker 上
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- kubelet 自己套用了 RuntimeDefault,manifest 中沒有這個欄位

# 透過 kubelet「實際套用」的設定自行檢查,而不是透過磁碟上檔案的文字 - drop-in 或
# 命令列旗標可能在不改動 config.yaml 本身的情況下覆寫該值:
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

沒有 `seccompDefault: true` 時,同一個 manifest 會得到 `Seccomp: 0`(`Unconfined`)- 如果需要確認差異,
只要回退旗標並重新建立 Pod 就很容易驗證。

## 9. 除錯損壞的 AppArmor profile

`/etc/apparmor.d/k8s-106-broken-profile` 已經在磁碟上,但從未被載入:其中在規則 `deny /work/** w` 之後
缺少逗號。首先在不載入核心的情況下找出錯誤。`-p`/`--preprocess` 在這裡「不適用」- 它是 preprocessing(把
`#include` 展開到 stdout),而不是安全的 dry-run/syntax-check。我們使用 `-Q`/`--skip-kernel-load`
(完整的編譯/檢查,不載入核心)或 `-d`/`--debug`
(一次 - 只做 syntax check)。

Artifact `apparmor-debug.txt` 必須包含**原始的** parser 錯誤,因此
我們在修正之前就儲存它(在 `worker` 上):

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

即使是僅編譯的 `-Q` 檢查,我們也使用 `sudo`:在實驗節點(apparmor 3.0.4,Ubuntu)上,
沒有權限時 parser 每次啟動都會嘗試設定 `/var/cache/apparmor` 中的 policy cache,
並在檢查語法「之前」就以 "Failed setting up policy cache (/var/cache/apparmor):
Permission denied" 失敗 - 你會得到關於權限的誤導性錯誤,而不是
真正的語法錯誤,而且 `apparmor-debug.txt` 不會包含需要的文字
"syntax error"。這已在節點本身上驗證過,包括在確定損壞的 profile 上。
不帶 `sudo` 的替代方式是加上 `-K`/`--skip-cache`(`apparmor_parser -Q -K ...`):不做
快取時,parser 能夠進行到解析 profile。這個實驗選擇 `sudo`,是為了與後面的 `-r` 保持
統一的 workflow,而 `-r` 無論如何都需要權限。

在節點上修正:AppArmor 規則必須以逗號結尾。然後把
修正後的 profile 載入核心 - 正是 `-r -v`(reload + verbose),而不是 `-Q`/`-p`,後者
什麼也不會載入:

```bash
# 在節點上
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# 預期:"k8s-106-broken-profile":	"enforce",
```

最終檢查,確認檔案現在有效、沒有錯誤:

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

現在在 `worker` 上,把修正「之後」的載入確認補寫到同一個 artifact:

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

最後執行(在 `worker` 上):

```bash
check_result
```
