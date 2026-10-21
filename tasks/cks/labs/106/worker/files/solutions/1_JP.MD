[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 106 - 参考解答: AppArmor と seccomp

> Kubernetes のコマンド (`kubectl`) は作業マシン (`worker`) で実行してください。ノード自体に関すること
> (AppArmor、kubelet、`crictl`) は、**ノード上で直接**行ってください：`ssh` で一度入って
> root になり (`sudo -i`) ます - 各コマンドを個別の
> `ssh control-plane '...'` で送るより速く、試験でもまさにこの進め方をするべきです。Namespace
> `security-106` は課題 3 で作成します。
>
> ```bash
> ssh control-plane
> sudo -i
> # ... ノード上のコマンド ...
> exit   # root から
> exit   # ノードから worker に戻る
> ```
>
> 確認は成果物を**作業マシン** (`/var/work/tests/artifacts/<番号>/`) から読み取ります。これらは
> 実習のためだけに必要で、試験にはありません。`worker` から短いコマンド
> (`> ファイル`) で保存し、内容は別途 `cat <ファイル>` で確認します。

## 1. AppArmor profile の転送とロード

プロファイルは作業マシンにのみあります。(`worker` から) ノードにコピーし、その後ノード上で
所定の場所に置いてカーネルにロードします。ファイルにはすでにフラグ `complain` が含まれているため、最初のロードには
`apparmor_parser -r` だけで十分です (`aa-complain` は使いません。これは `aa-enforce` と同様に
`/etc/apparmor.d/` のすべてのファイルを解析するため、課題 9 のまだ壊れている
`k8s-106-broken-profile` で失敗します)：

```bash
# worker で
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# ノードで
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# 期待される出力: "k8s-106-deny-write":	"complain",
```

## 2. AppArmor profile を enforce に切り替える

Profile は現在 `complain` モードです (課題 1 でそのフラグ付きでロードされました)。ノード上 (root で) に留まり、
既存の profile をまさに enforcing mode に切り替えます：

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# 期待される出力: "k8s-106-deny-write":	"enforce",
# 通常の 'aa-status | grep ...' ではプロファイルのモードは表示されません: テキスト出力では、プロファイルは
# 見出し ('N profiles are in enforce mode.') の下にグループ化され、名前にサフィックスはありません。
# 特定のプロファイルを確認するには 'aa-status --pretty-json' (または '--json') を使用します。
exit
exit
```

課題 9 を終えるまでは、このプロファイルに対して、Python で書かれた `apparmor-utils` パッケージの
`aa-enforce`/`aa-complain` やその他のプロファイル変更ツールを使わないでください：
それらは内部で `apparmor.read_profiles()` を呼び出し、起動時に `/etc/apparmor.d/` の**すべての**
ファイルを解析 (パース) します。課題 9 のまだロードされていない、明らかに
壊れている `/etc/apparmor.d/k8s-106-broken-profile` も含まれ - あなたのプロファイルに到達する前に、
他人のファイルでパーサーエラーを起こして失敗します。`apparmor_parser`
(Python のラッパーではなくバイナリ) は、特定の 1 つのファイルを直接指定して呼び出せば、
そのファイルだけを解析し、この問題の影響を受けません - まさにこのため、プロファイルのフラグを
(`flags=(...)` から `complain` を削除して) `sed` で手動で修正し、そのうえでまさに
このファイルを `apparmor_parser -r` で再ロードします。

`aa-status` はプロファイルの状態を見るための別のツールであり、変更するものではないので、ここには
当てはまりません。特定のプロファイルのモードは `aa-status --pretty-json` で確認できます (実習の
ノード、apparmor 3.0.4 で確認済み；`--json` は同じものを 1 行で返します。たとえば
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`)。代替手段は、カーネルのファイル
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles` です：そこでの形式は
`name (enforce|complain)` です。

## 3. Localhost AppArmor と書き込み拒否を持つ Pod

namespace と Pod を作成します。`emptyDir` が `/work` の存在を保証します；profile はプロセスの
起動を許可しますが、このディレクトリへの書き込みを禁止します。Node selector は、Pod を
profile が実際にロードされているノードに結び付けます。

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
# worker で
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# STATUS が Running になるのを待ち (get を繰り返す)、その後 exec を実行します

# Evidence: プロファイルが Pod YAML に書かれているだけでなく、実際にプロセス PID 1 に割り当てられていること。
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# 拒否の前の Positive control: denial を確認するまさに同じ /work での許可された read 操作 -
# このステップがないと、書き込みの拒否を、mount/mountPath が完全に機能していない場合
# (その場合は読み取りすら不可能です) と区別できません。
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Negative control: denial はまさに AppArmor による書き込みの拒否でなければなりません。
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# ゼロ以外のコードが期待されます: Permission denied / Operation not permitted
```

ゼロ以外の exit code と 'permission denied' というテキストだけでは、まさに AppArmor のこのルールが
作動したことの証明には「なりません」 - 通常の DAC/ファイルシステムのエラーも、shell から見れば
同じに見えます。拒否をまさにこの profile に結びつけるには、kernel audit log を使います；
上の試行の直後に、ノード上でそれを確認します：

```bash
# ノードで
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# 次の形式のレコードが期待されます: ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod: ファイルの作成; 既存のファイルへの書き込みの場合は "w" になります)
exit
exit
```

特定の runtime で `/proc/1/attr/current` が利用できない場合は、それを記録し、この profile についての
Localhost profile の割り当てと、カーネルの `apparmor="DENIED"` を根拠にしてください；
これらの evidence がなく、ゼロ以外のコードだけでは不十分です。それは mount や通常の
Unix のパーミッションでも発生しうるためです。

## 4. 通常の Pod の RuntimeDefault

`RuntimeDefault` は、標準の containerd/runtime のプロファイルを選択する、移植可能な baseline です。
フィールドは Pod レベルで明示的に設定されています。

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
# worker で
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5-6. Localhost seccomp と `unshare` のブロックの実証

ファイルは作業マシンの `/opt/lab106-fixtures/cks-106-deny-unshare.json` にのみあります。
(`worker` から) ノードにコピーし、(ノード上で) kubelet の seccomp root に置きます：

```bash
# worker で
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# ノードで
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

API では seccomp root からの相対パスを指定します：`profiles/cks-106-deny-unshare.json`。

`SYS_ADMIN` はここでは、実習のためだけの意図的な危険な例外です (seccomp なしの control の確認は checker が行います)。custom
filter がなければ、この capability を持つ `unshare -n` は成功する可能性があり；seccomp は `EPERM` を返す必要があります。
これは hardened combination ではありません。`allowPrivilegeEscalation: false` は `no_new_privs` を有効にしますが、
プロセスにすでに付与された capabilities は取り上げないため、このフィールドを `SYS_ADMIN` の
「補償」としては使いません。production では、必要性が証明されない限り、そのような capability は削除されます。
Kubernetes では、capability は接頭辞 `CAP_` なしで `SYS_ADMIN` と書きます。

`unshare -n` (network namespace、`CLONE_NEWNET`) を使い、`unshare -m` (mount
namespace) は使いません。どちらの操作も同じ `CAP_SYS_ADMIN` を必要としますが、BusyBox の `unshare -m` は、
`unshare(2)` が成功した後に、強制的な private propagation のために独立した `mount(2)` syscall を追加で実行します -
そして containerd の default AppArmor-プロファイル (この Pod が受け取る `RuntimeDefault`。
ここでは明示的な `appArmorProfile` が指定されていないため) には、フラグに関する条件のない
`deny mount,` が含まれており、capabilities/seccomp とは無関係に作用します。そのため、
`unshare -m true` は、seccomp が `unshare` をまったく制限していない場合でも AppArmor が原因で `EPERM` で失敗する可能性があり -
そのような probe は 2 つの異なる security control を混ぜてしまいます。`unshare -n` が
呼び出すのは syscall `unshare(2)` 自体のみで、副作用としての `mount()` はありません。

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
# worker で
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# ゼロ以外のコードが期待されます: Operation not permitted / Permission denied
```

## 7. User namespaces: `hostUsers: false` と `uid_map`

`hostUsers: false` は、kubelet に Pod 専用の user namespace を割り当てるよう要求します：コンテナ内の
root (UID 0) は、ホストの非特権の UID 範囲にマッピングされます。`runAsUser` は指定せず、
プロセスが namespace の**内部で**実際に UID 0 として起動するようにします - 最初から権限がないのではなく、
まさに変換を示すのはこのケースです。

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
# worker で
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

コンテナのホスト PID は、コンテナ内の PID とは一致せず、`kubectl` からも直接は見えません。
worker でコンテナ ID を取得し、PID は Pod が実際に動作しているノード上の `crictl inspect` で取得します：

```bash
# worker で
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - プレフィックス containerd:// なしで <ID> をコピーします

# ノードで
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# 例: 15205 - これが <host PID> です
```

ノード上の `/proc/<host PID>/uid_map` は変換を表します：3 つの数 - `<container-uid-start>
<host-uid-start> <length>`。`hostUsers: false` の場合、最初の行は `0` (container UID 0) で始まる必要がありますが、
host-uid-start は **ゼロではない**必要があります - それがホストの非特権の範囲であり、`length` は
標準の per-Pod ブロック `65536` UID です。

```bash
# ノードで (root で)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (host-uid-start は Pod ごとに異なります。重要なのは 0 でないことです)
exit
exit
```

`uid_map` の行を成果物に保存します (`worker` で)：

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

`host-uid-start` が `0` の場合 - user namespace は適用されていません (たとえば、
containerd/runc の非互換性や、実際に適用された Pod に `hostUsers: false` がないことが原因です) -
これは hardening ではなく、ホスト上の通常の root です。比較のために：`hostUsers: false` のない
通常の Pod でも、ファイル `/proc/<host-PID>/uid_map` は存在しますが、プロセスは
host (initial) user namespace に留まります。そのため、マッピングは UID 0 -> host UID 0 で始まります (通常は
`0 0 4294967295` のような行で、たとえばノード上の `cat /proc/1/uid_map`)、非特権の
per-Pod host UID からではありません。`hostUsers: false` を持つ `userns-probe` では、その逆が期待されます：
`0 <ゼロでない-host-uid> <per-pod の範囲>`。

## 8. kubelet の `seccompDefault: true`

これまでのすべての Pod は `seccompProfile` を明示的に指定していました。ここでは node-level の baseline を確認します：
開発者がこのフィールドを忘れた場合、kubelet が自分で `RuntimeDefault` を適用し、
プロセスを `Unconfined` のままにしないようにします。ノード上で kubelet の設定を修正します：

```bash
# ノードで
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
# worker で: API の Node の名前は /etc/hosts の別名 'control-plane' ではなく、ノードの実際の名前 (ip-10-...) です
kubectl get nodes     # Ready
```

Pod level にも container level にも `seccompProfile` への言及が一切ない Pod を作成します：

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
# worker で
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- kubelet が manifest のフィールドなしで、自分で RuntimeDefault を適用しました

# ディスク上のファイルのテキストではなく、kubelet に実際に適用された設定で自己確認します -
# drop-in やコマンドラインのフラグが、config.yaml 自体を変更せずに
# 値を上書きしている可能性があります:
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

`seccompDefault: true` がなければ、同じ manifest は `Seccomp: 0` (`Unconfined`) になります - 違いを確認する必要があれば、
フラグを元に戻して Pod を再作成すれば簡単に確かめられます。

## 9. 壊れた AppArmor プロファイルのデバッグ

`/etc/apparmor.d/k8s-106-broken-profile` はすでにディスク上にありますが、一度もロードされていません：
ルール `deny /work/** w` の後のカンマが欠けています。まず、カーネルにロードせずにエラーを見つけます。
`-p`/`--preprocess` はここでは適して「いません」 - これは preprocessing (`#include` を
stdout に展開する) であり、safe dry-run/syntax-check ではありません。`-Q`/`--skip-kernel-load`
(カーネルにロードしない完全なコンパイル/検証) または `-d`/`--debug`
(1 回のみ - syntax check だけ) を使用します。

成果物 `apparmor-debug.txt` には**元の**パーサーエラーが含まれている必要があるため、
修正の前に保存します (`worker` で)：

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

compile-only の確認 `-Q` でも `sudo` を使います：実習のノード (apparmor 3.0.4、Ubuntu) では、
権限がないと、パーサーは起動のたびに `/var/cache/apparmor` の policy cache を設定しようとし、
構文の確認の前に "Failed setting up policy cache (/var/cache/apparmor):
Permission denied" で失敗します - 実際の構文エラーの代わりに権限についての紛らわしいエラーが出て、
`apparmor-debug.txt` に必要なテキスト "syntax error" が含まれなくなります。ノード自体で
(明らかに壊れたプロファイルでも) 確認済みです。
`sudo` なしの代替手段は、`-K`/`--skip-cache` を追加すること (`apparmor_parser -Q -K ...`) です：
キャッシュなしでは、パーサーはプロファイルの解析まで進みます。この実習で `sudo` を選んだのは、その後の
`-r` と同じワークフローにするためで、`-r` はいずれにせよ権限を必要とします。

ノードで修正します：AppArmor のルールはカンマで終わる必要があります。その後、修正した
プロファイルをカーネルにロードします - まさに `-r -v` (reload + verbose) で、何もロードしない
`-Q`/`-p` ではありません：

```bash
# ノードで
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# 期待される出力: "k8s-106-broken-profile":	"enforce",
```

ファイルがエラーなしで有効になったことの最終確認：

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

では `worker` で、修正の後のロードの確認を、同じ成果物に追記します：

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

最後に (`worker` で) 次を実行します：

```bash
check_result
```
