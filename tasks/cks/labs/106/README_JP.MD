[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 106 - AppArmor と seccomp: node-local policy と検証可能な拒否

## 目的

この CKS 実習では、Linux カーネルのレベルでコンテナのプロセスを保護する、2 つの独立した仕組みを適用します。
まず、事前に配布された **AppArmor** プロファイルを `complain` から `enforce` に切り替え、
現代的なフィールド `securityContext.appArmorProfile` を通じて Pod に割り当て、書き込みの拒否を実証します。
次に、安全な baseline である `RuntimeDefault` と、システムコール `unshare(2)` をブロックする
custom **seccomp Localhost** プロファイルを割り当てます。

これは、CKA 実習 106 の基本的な `SecurityContext` の続きです：ここでは YAML を書くだけでは不十分です。
Localhost プロファイルは Kubernetes ノード上に存在するため、ノード、Pod の
placement、プロセスの実際の挙動を確認する必要があります。

## Threat model

コンテナ内での RCE を仮定します。compromise の後の問いは「攻撃者が shell を得られたか」ではなく、「その shell が次に何をできるか」、そしてその blast radius がどれほど大きいかです。

課題 1-3 の AppArmor は、オブジェクトと操作を制限します：プロファイルを enforce に切り替え、その後で書き込みの拒否を実証します。こうして、すでに compromise されたプロセスは、コンテナ内で実行されているというだけの理由で無制限の操作を得ることはありません。

課題 4-6 の seccomp は、利用可能なシステムコールを制限します：まず baseline を適用し、次に custom profile を適用し、その後で `unshare(2)` の実際の拒否を確認します。課題 6 にはすでに Pod `sysadmin-control` による negative control が含まれています：同じ capability で seccomp filter がなければ呼び出しが通るため、この比較は compromise の後の境界をまさに示します。

## 開始前のセルフチェック

<details>
<summary>1. AppArmor の `complain` は `enforce` と何が違うか、そしてなぜ `complain` を防御の証拠として示してはいけないのか？</summary>

`complain` モードでは、AppArmor はプロファイル違反をログに記録するだけで、ブロックは**しません** - 禁止されるべき操作はそれでも実行され、ただジャーナルに記録が残るだけです。`enforce` では操作が実際にブロックされます。課題 2 がプロファイルを `enforce` に切り替えることを明示的に求めているのは、`complain` で「ログに違反がある」ことを示しても防御の証明にはならないからです - プロセスは結局その操作を実行できてしまいます。
</details>

<details>
<summary>2. `allowPrivilegeEscalation: false` が、すでに付与された capability `SYS_ADMIN` を取り除かないのはなぜか？</summary>

`allowPrivilegeEscalation: false` は、カーネルのフラグ `no_new_privs` を有効にし、プロセスが `execve` を通じて (たとえば setuid バイナリや file capabilities を通じて) 新しい権限を得ることを禁止します。これは、プロセスがすでに effective/bounding set に持っている権限には影響しません - コンテナが manifest で明示的に capability `SYS_ADMIN` 付きで起動されていれば、`allowPrivilegeEscalation` の値に関係なく、その capability は利用可能なままです。
</details>

<details>
<summary>3. Pod の manifest の `localhostProfile` が、絶対パスではなく相対パスで指定されるのはなぜか？</summary>

Kubelet は、相対パスを自身の seccomp root (デフォルトは `/var/lib/kubelet/seccomp/`) からの相対として自分で解決します。絶対パスを指定すると、kubelet は seccomp root の内部でまさにその絶対パスのファイルを探すことになり、実際のファイルの場所とほぼ確実に一致せず - Pod は `CreateContainerError` を受け取ります。
</details>

## コースとの関連

- [第 16 章 AppArmor](../../course/16/jp.md)
- [第 17 章 seccomp](../../course/17/jp.md)
- [第 03 章 Container Runtime Security](../../course/03/jp.md)

## インフラ

環境は Terragrunt により AWS `eu-central-1` に展開されます。

| コンポーネント | 用途 |
|---|---|
| `vpc` | パブリックサブネットを持つ VPC `10.10.0.0/16` |
| `ssh-keys` | ノードへアクセスするためのキー |
| `k8s-1` | シングルノードの kubeadm クラスター Kubernetes `1.36.0`、containerd、**Calico** |
| `worker` | `kubectl`、`check_result`、`control-plane` としてのノードへの SSH アクセスを備えた作業マシン |

リソースの節約のため、control-plane が唯一の workload ノードです：その `NoSchedule` taint は
解除されています。ノードには label
`security.cks.io/localhost-profiles-106=true` が付けられています。この実習のすべての Pod は、まさに
このノードを選択する必要があります - Localhost プロファイルはこのノードにのみ存在し、scheduler はそれを別のノードに移しません。

Bootstrap が準備したのは**次のものだけ**です：

- 安全な placement のための、ノードの label `security.cks.io/localhost-profiles-106=true`；
- 作業マシン (worker) の `/opt/lab106-fixtures/` に：`k8s-106-deny-write`
  (AppArmor profile) と `cks-106-deny-unshare.json` (custom seccomp profile) のソース。

AppArmor profile も seccomp profile も、workload ノードには**事前にインストールされておらず**、
そのカーネルにもロードされていません - それぞれの転送と最初のロードは、課題 1 と 5 の一部です。
seccomp profile のパスを変更したり、通常の Pod の内部で profile を作成したりしないでください：ノードへの
ファイルの転送は、workload の内部からではなく、ノードの管理者として SSH 経由で自分で行います。

## デプロイ

```bash
TASK=106 make run_cks_task
```

作業マシンに SSH で接続します。コンテキストはすでに設定されています：

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

作業を始める前に、ノードへのアクセスと worker 側の fixtures を確認します：

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## 課題

---
| **1** | **AppArmor profile を転送してロードする** |
| :---: | :--- |
| やること | profile `k8s-106-deny-write` のソースは、作業マシンの `/opt/lab106-fixtures/k8s-106-deny-write` にのみあります。それをノード `control-plane` の `/etc/apparmor.d/k8s-106-deny-write` にコピーし (たとえば `scp` で)、`sudo apparmor_parser -r` でカーネルにロードします。Profile にはすでにフラグ `complain` が含まれています - 2 回目の有効化は不要で、それは課題 2 の仕事です。 |
| 受け入れ基準 | `/etc/apparmor.d/k8s-106-deny-write` がノード上に存在する；`/sys/kernel/security/apparmor/profiles` に名前 `k8s-106-deny-write` の行が含まれている (`complain` か `enforce` かのどちらのモードでも)、つまり profile が単にディスクにコピーされただけでなく、実際にカーネルにロードされている。 |

<details>
<summary>💡 課題 1 のヒント</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` は、ファイルをノードの
一時ディレクトリにコピーします；そこから `sudo` で `/etc/apparmor.d/` に移動してください (通常の
ユーザーは直接そこに書き込む権限がありません)。その後 `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` が profile をコンパイルしてカーネルにロードします - この
ステップがないと、ディスク上のファイルは防御をまったく与えず、
`/sys/kernel/security/apparmor/profiles` にも現れません。
</details>

---
| **2** | **AppArmor profile を enforce に切り替える** |
| :---: | :--- |
| やること | ノード `control-plane` で、課題 1 でロードした profile `k8s-106-deny-write` を `enforce` モードに切り替えます。元のモード `complain` は違反を記録しますが、防御にはなりません。profile を削除したり、名前を変更したりしないでください。 |
| 受け入れ基準 | label `security.cks.io/localhost-profiles-106=true` を持つノードが存在する；`/etc/apparmor.d/k8s-106-deny-write` が利用可能である；`/sys/kernel/security/apparmor/profiles` に行 `k8s-106-deny-write (enforce)` が含まれている。Checker-owned の bootstrap-baseline (実習の提供の前に、同じ profile の一時的なコピーがまだ `complain` だった間に記録されたもの) が、この profile のパターン `/work/**` に対応する書き込みが、そのときは実際に通っていたことを確認している - これがなければ、後の拒否を引き起こしたのがまさに `enforce` への切り替えであることを証明できない。 |

<details>
<summary>💡 課題 2 のヒント</summary>

コマンド `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` は、すでに存在するプロファイルを再ロードします - それが `complain` で、ディスク上のファイルがすでに `enforce` を記述している場合は、このコマンドで十分です。`sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write` で自己確認してください - 出力には明示的に `(enforce)` が表示される必要があります。これを `aa-status` で確認しないでください：このコマンドはプロファイルをセクション見出し (`N profiles are in enforce mode.`) の下にグループ化し、その下にはプロファイル名だけを表示し、各行に `(enforce)`/`(complain)` のサフィックスは付きません - そのようなサフィックスがあるのは `/proc/<pid>/attr/current` とカーネルのファイル `/sys/kernel/security/apparmor/profiles` だけで、`aa-status` のプロファイルのリストにはありません。

課題 9 を終えるまでは、このプロファイルに `aa-enforce`/`aa-complain` を使わないでください：
`apparmor-utils` のこれらの Python ツールは、本来の作業の前に `/etc/apparmor.d/` の**すべての**ファイルを解析 (パース) します。
これには課題 9 のまだ壊れている `k8s-106-broken-profile` も含まれるため、ツールは無関係なファイルでパーサーエラーを起こして失敗します。プロファイルのファイル内のフラグ `complain` を
直接 (`sed` で) 修正し、まさにこのファイルを `apparmor_parser -r` で再ロードしてください -
このバイナリは、`aa-enforce` とは異なり、渡されたファイルだけを解析します。
</details>

---
| **3** | **Localhost AppArmor Pod と書き込みのブロック** |
| :---: | :--- |
| やること | namespace `security-106` と Pod `apparmor-writer` を作成します。Pod は、インフラのノードの label を選択し、ServiceAccount token の automount を無効にし、Pod レベルで `appArmorProfile.type: Localhost`、`localhostProfile: k8s-106-deny-write` を設定する必要があります。`busybox:1.36`、コンテナ `app`、sleep コマンド `sleep 3600`、そして `/work` にマウントした `emptyDir` を使用します。起動後、コマンド `cat /proc/1/attr/current` (インターフェースが利用可能な場合) で effective な profile を確認し、許可された読み取り操作、たとえば `cat /etc/hostname >/dev/null` を実行してから、`/work` にファイルを書き込もうとします；その操作は拒否で終了する必要があります。ノード上で、`journalctl -k \| grep -i apparmor` または `dmesg \| grep -i apparmor` から、profile/process に対する AppArmor の denial を記録してください。 |
| 受け入れ基準 | Pod が起動しており、まさに Localhost profile を使用し、正しい nodeSelector を持つ；プロセスの effective な profile が `k8s-106-deny-write` を enforce mode で示している (`/proc/.../attr/current` が利用可能な場合)；許可された読み取り操作 (たとえば `cat /etc/hostname` や `ls /work`) は通り、checker は `/work` に独自の一意な (per-run) ファイルを独立して書き込み、AppArmor の拒否を受け取る。kernel journal/audit log に、まさにこの試行に関連する (一意なファイル名による) この profile のイベント `apparmor="DENIED"` がある - これにより、ジャーナル内の古い denial イベントによる誤った合格判定 (false pass) を排除する。 |

<details>
<summary>💡 課題 3 のヒント</summary>

`Localhost` タイプのプロファイルの `appArmorProfile` は、2 つの別々のフィールドで指定します：`type: Localhost` と `localhostProfile: k8s-106-deny-write` (パス `/etc/apparmor.d/` なしのプロファイル名) - これは、課題 1 でプロファイルがロードされたときの名前と同じです。Pod が起動しない場合 (CreateContainerError) は、nodeSelector で指定した正しいノード上に、プロファイルが実際にすでにロードされていることを確認してください - AppArmor のプロファイルは node-local であり、自動的には転送されません。
</details>

---
| **4** | **安全な baseline の seccomp RuntimeDefault** |
| :---: | :--- |
| やること | `security-106` に、`busybox:1.36` と `sleep 3600` の Pod `runtime-default` を作成します。Pod レベルで `securityContext.seccompProfile.type: RuntimeDefault` を明示します；Pod は準備されたノードも選択する必要があります。コンテナ内の `/proc/1/status` を確認します：`Seccomp: 2` が期待されます。 |
| 受け入れ基準 | Pod が `Running` で、その Pod-level の securityContext で `RuntimeDefault` が選択されており、プロセスが seccomp filter mode にある。 |

<details>
<summary>💡 課題 4 のヒント</summary>

`/proc/1/status` の `Seccomp: 2` は「filter mode が有効」(SECCOMP_MODE_FILTER) を意味します - これが表示されるはずのものです。`Seccomp: 0` であれば、seccomp filter がまったくない (`Unconfined`) ことを意味します。これは 3 つの seccomp の課題 (4-6) の中で最も単純なものです - 通らない場合は、seccompProfile 自体ではなく nodeSelector に問題がある可能性が高いです。
</details>

---
| **5** | **custom Localhost seccomp profile を転送して使用する** |
| :---: | :--- |
| やること | ソース `cks-106-deny-unshare.json` は、作業マシンの `/opt/lab106-fixtures/cks-106-deny-unshare.json` にのみあります。label `security.cks.io/localhost-profiles-106=true` を持つノードを特定し、そこにディレクトリ `/var/lib/kubelet/seccomp/profiles/` を作成し (まだなければ)、同じ名前で JSON をそこにコピーします。次に、そのノード上の `security-106` に Pod `localhost-seccomp` を作成します。Pod レベルで `seccompProfile.type: Localhost` と、`/var/lib/kubelet/seccomp/` なしの相対パス `profiles/cks-106-deny-unshare.json` を指定します。コンテナ `app` は `busybox:1.36` を使用し、capability `SYS_ADMIN` を受け取り、確認の後も起動したままである必要があります。**この組み合わせを hardened baseline として扱わないでください：** `SYS_ADMIN` は最も危険な capabilities の 1 つであり続け、`allowPrivilegeEscalation: false` はすでに付与された権限を取り上げません。これは capability にフォーカスした実験であり、セキュリティを示すのは具体的な seccomp の deny です。 |
| 受け入れ基準 | JSON profile が転送され、正しいパスでノード上に存在する；正しい nodeSelector を持つ Pod が profile `Localhost:profiles/cks-106-deny-unshare.json` を使用している；JSON profile が `unshare` に対する `SCMP_ACT_ERRNO`/`errnoRet: 1` を含んでいる；コンテナには、実験に必要な `SYS_ADMIN` のみが追加されている。 |

<details>
<summary>💡 課題 5 のヒント</summary>

パス `profiles/cks-106-deny-unshare.json` は、kubelet の seccomp root `/var/lib/kubelet/seccomp/` からの相対パスです。つまり、ノード上の実際のファイルは `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` にある必要があり - まさにそこに、作業マシンからコピーする必要があります (たとえば `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`、その後ノード上で `sudo mkdir -p` と `sudo mv`)。manifest に完全な絶対パスを書かないでください - kubelet が自分でルートを付け加えます。ここで `SYS_ADMIN` が与えられるのは、まさに実験のためです (そもそも `unshare` を呼び出せる capability が必要です)。推奨される実践としてではありません - 学習用のシナリオを production の baseline と混同しないでください。
</details>

---
| **6** | **syscall `unshare(2)` の拒否を実証する** |
| :---: | :--- |
| やること | `localhost-seccomp` のコンテナのコマンドで `unshare -n true` を実行し、期待される拒否の成功した確認を `/tmp/unshare-result` に行 `unshare denied by seccomp` として保存し、その後 `sleep 3600` でコンテナを維持します。`kubectl exec ... -- unshare -n true` を再度実行すると、ゼロ以外のコードを返す必要があります。attack-minded な negative control として、同じノード上に `seccompProfile.type: Unconfined` と同じ唯一の capability `SYS_ADMIN` を持つ Pod `sysadmin-control` を作成します；その `unshare -n true` は成功で終了する必要があります。確認の後、control Pod を削除します。 |
| 受け入れ基準 | Localhost Pod が起動している；`Seccomp: 2`；`unshare` が custom profile によってブロックされる。control Pod では、同じ syscall が、同じ capability で seccomp filter なしの状態で通る。これは、YAML の存在だけでなく、カーネルの挙動を実証する。 |

<details>
<summary>💡 課題 6 のヒント</summary>

`unshare -m true` ではなく、まさに `unshare -n true` (network namespace の unshare、`CLONE_NEWNET`) を
使ってください。`-m` (mount namespace) は `-n` と同様に `CAP_SYS_ADMIN` を必要としますが、
BusyBox の `unshare -m` は、`unshare(2)` が成功した後に、さらに 2 つ目の
独立した `mount(2)` syscall (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`、
private propagation を強制するため - これは、`--propagation unchanged` が明示的に渡されない限りデフォルトで有効な unshare の挙動で、
渡された場合でも `mount()` は呼び出され、ただフラグがゼロになるだけです) を実行します。containerd の標準の AppArmor プロファイル (`RuntimeDefault`、
明示的な `securityContext.appArmorProfile` のない Pod が受け取るもの) には `deny mount,` が含まれており、
フラグに関する条件は一切ありません - この禁止は capabilities とも seccomp とも無関係に作用します。そのため、
`unshare -m true` は、seccomp が `unshare` をまったく制限していない場合でも AppArmor が原因で `EPERM` で失敗する可能性があり、
そのような probe は seccomp による拒否の証拠として信頼できません。`unshare -n` (`CLONE_NEWNET`) が呼び出すのは
syscall `unshare(2)` 自体のみで、その後の `mount()` は一切なく - `localhost-seccomp` も
`sysadmin-control` も同じ `SYS_ADMIN` を使用するため、結果の違いは、AppArmor の副作用ではなく、
まさに seccomp filter によるものだと一意に説明できます。

検証として意味を持たせるためには、コマンドの順序が重要です：まず `unshare -n true` を実行してエラー (ゼロ以外の exit code) で失敗することを確認し、その後でのみ行 `unshare denied by seccomp` を `/tmp/unshare-result` に書いてください - 結果を「想定して」あらかじめ行を書かないでください。Negative control (`sysadmin-control`) は、同じ capability `SYS_ADMIN` を使いつつ `seccompProfile.type: Unconfined` を使う必要があります - `Unconfined` を明示するのを忘れると、Pod がデフォルトで `RuntimeDefault` を受け取る可能性があり (課題 8 の `seccompDefault` が有効な場合)、テストは違いを示しません。
</details>

Linux の capabilities と privilege escalation は別の軸です。`allowPrivilegeEscalation: false` は
`no_new_privs` を有効にし、`execve` を通じて (setuid/setgid や
file capabilities) **新しい**権限を得ることを禁止しますが、bounding/effective set にすでに追加された `SYS_ADMIN` を取り除くことはしません。
通常の業務用 workload には `capabilities.drop: ["ALL"]` を使い、別に
`allowPrivilegeEscalation: false` を使ってください；上の実験は、意図的にそのような baseline ではありません。

---
| **7** | **User namespaces: `hostUsers: false` と `uid_map` による UID の変換** |
| :---: | :--- |
| やること | User namespaces は Kubernetes v1.36 で GA になりました ([第 03 章](../../course/03/jp.md)、[第 18 章](../../course/18/jp.md) と Security Delta v1.36 を参照)。理論では、`hostUsers: false` がコンテナの root を非特権のホスト UID に変換すると説明されています；ここでは、それを実際のプロセスで実証する必要があります。`security-106` に、準備されたノード上で `spec.hostUsers: false`、イメージ `busybox:1.36`、コマンド `sleep 3600` の Pod `userns-probe` を作成します；Pod レベルの `runAsUser` は指定せず、プロセスがコンテナの**内部で** UID 0 として起動するようにします。コンテナ内の `id` (`uid=0`) を確認します。`crictl inspect` (実習 112 と同様) または `kubectl get pod -o jsonpath` + `crictl ps` で、コンテナのプロセスのホスト PID を特定し、その後ノード上で `/proc/<host PID>/uid_map` を読み取ります。両方の出力 (コンテナ内の `id` と `uid_map` の内容) を `/var/work/tests/artifacts/6/userns.txt` に保存します。 |
| 受け入れ基準 | Pod が `Running` で、`spec.hostUsers == false`、準備されたノードを選択している；コンテナ内の `id` が `uid=0(root)` を示す；ノード上の `/proc/<host PID>/uid_map` に `0 <host-uid> <length>` の形式の行が含まれ、`<host-uid>` が **0 ではなく** (コンテナの root が非特権のホスト UID に変換されている)、`<length>` が少なくとも `65536` (標準の per-Pod UID 範囲) である；成果物に evidence の両方の部分が含まれている。 |

<details>
<summary>💡 課題 7 のヒント</summary>

コンテナの内側の `id` は、`hostUsers` に関係なく `uid=0(root)` を示します - これは想定内で、コンテナは自分自身の namespace を見ており、その中では root が確かに UID 0 だからです。実際の防御は外側からしか見えません：ノード自体の `/proc/<host PID>/uid_map` で、コンテナ内の UID 0 がホスト上の大きな非特権 UID に変換されています。ホスト PID を見つけるには `crictl inspect <container-id>` を使用してください - `kubectl get pod` ではなく、まさにそこからです。`kubectl get pod` は Kubernetes オブジェクトについてしか知らず、プロセスのホストレベルの PID は知りません。
</details>

---
| **8** | **kubelet レベルの `seccompDefault: true`: 明示的なプロファイルなしの baseline** |
| :---: | :--- |
| やること | 課題 4-6 のすべての Pod は、manifest で `seccompProfile` を明示しています。現実には、開発者がこのフィールドを忘れることがあります - その場合、node-level の baseline がなければ Pod は `Unconfined` になります。ノード上で `/var/lib/kubelet/config.yaml` の `seccompDefault: true` を有効にし、kubelet を再起動します (`systemctl restart kubelet`)。準備されたノード上の `security-106` に、`busybox:1.36` (`sleep 3600`) の Pod `no-seccomp-field` を作成し、Pod レベルでもコンテナレベルでも、securityContext.seccompProfile を**一切指定しません**。コンテナ内の `/proc/1/status` を通じて、kubelet が `Unconfined` (`Seccomp: 0`) のままにせず、自動的に `RuntimeDefault` (`Seccomp: 2`) を適用したことを確認します。 |
| 受け入れ基準 | `/api/v1/nodes/<node>/proxy/configz` 経由の kubelet の有効な (適用された) 設定の、フィールド `.kubeletconfig.seccompDefault` が `true` である；`systemctl is-active kubelet` が `active` を返し、ノードが `Ready` のままである；Pod `no-seccomp-field` が、spec のどのレベルにも `seccompProfile` を持たない；コンテナ内の `/proc/1/status` が `Seccomp: 2` を示す。 |

<details>
<summary>💡 課題 8 のヒント</summary>

重要な要件は、Pod が Pod レベルでもコンテナレベルでも、`seccompProfile` に「一切」言及していないことです。課題 4-6 の manifest をコピーして、このフィールドを削除し忘れると - テストは本来示すべきこと、つまり `Seccomp: 2` をもたらしたのが (manifest での明示ではなく) まさに node-level の `seccompDefault` であることを実証しません。

チェックでは、ディスク上のファイルのテキストではなく、kubelet に実際に適用された設定を基準にします：
`curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`。
`/var/lib/kubelet/config.yaml` に対する単純な grep では、起動している kubelet がまさにこのファイルを
使っていることは証明されません - コマンドラインフラグや drop-in が、ファイル自体を変更せずに
値を上書きしている可能性があります。ファイルを修正した後は、必ず kubelet を再起動してください -
設定はその場では反映されません。
</details>

---
| **9** | **壊れた AppArmor プロファイルのデバッグと再構築 (`apparmor_parser -r -v`)** |
| :---: | :--- |
| やること | ディスク上には、すでに `/etc/apparmor.d/k8s-106-broken-profile` があります - 構文エラーのあるプロファイルで、カーネルに**一度もロードされたことがありません**。`sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile` (`-Q`/`--skip-kernel-load`: プロファイルの検証/コンパイルを完全に実行しますが、カーネルにはロードしません) または `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile` (`-d`/`--debug`、1 回のみ - 構文の正しさの確認だけ) で、エラーを自分で見つけ、ファイルを修正し、`sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile` でプロファイルをカーネルにロードします。ロードを `aa-status \| grep k8s-106-broken-profile` で確認します。修正**前**のエラー出力と、**後**のロードの確認を `/var/work/tests/artifacts/8/apparmor-debug.txt` に保存します。 |
| 受け入れ基準 | `apparmor-debug.txt` に、修正**前**の試行によるパーサーエラーのテキスト (たとえば `syntax error`) が含まれている；checker-owned の bootstrap-baseline (実習の提供の前に、あなたの artifact とは無関係に記録されたもの) が、元のプロファイルに実際に syntax error が含まれていたことを独立して確認する；ディスク上の `/etc/apparmor.d/k8s-106-broken-profile` に、元の構文エラーがもう含まれていない；`aa-status` が `k8s-106-broken-profile` をロードされたプロファイルの中に示している (`enforce` か `complain` かのどちらのモードでも)；修正されたファイルに対する `apparmor_parser -Q` の再実行がエラーなしで終了する。 |

<details>
<summary>💡 課題 9 のヒント</summary>

`apparmor_parser -p` (`--preprocess`) は、安全な dry-run/構文チェックのモードでは**ありません** - これは単なる
プリプロセスです：`#include` ディレクティブを展開し、結果のプロファイルを stdout に出力するだけで、
それ自体が副作用のないことを保証するものではなく、構文チェックのために設計されたものでもありません。
`-Q`/`--skip-kernel-load` (完全なコンパイル/検証を行いますが、カーネルにはロードしません) または `-d`/`--debug`
(1 回のみ - 構文の正しさの確認だけ) を使用して、副作用なしに安全に
構文エラーを見つけてください。ファイルを修正した後でのみ、実際のカーネルへのロードに
`-r` (reload/load) を使用します。AppArmor の構文は、ブロック内のルールの区切りとしてカンマを要求します - パーサーの出力を調べて、
どの文字がどこで不足しているかを見つけてください。

`-Q`/`-d` の場合でも、`apparmor_parser` は `sudo` で実行してください：実習のノード (apparmor 3.0.4、
Ubuntu) では、権限がないと、パーサーは起動のたびに `/var/cache/apparmor` の policy cache を設定しようとし、
構文の確認の前に "Failed setting up policy cache: Permission denied" で失敗します - プロファイルの実際の構文エラーの代わりに、
権限についての紛らわしいエラーが出ます。これはノード自体で (壊れていることが分かっているプロファイルでも) 確認済みです。
`sudo` なしで実行する必要がある場合は、`-K` (`--skip-cache`: キャッシュなし) を追加してください -
権限のない `apparmor_parser -Q -K` はプロファイルの解析まで進み、実際の
エラーを表示します。ロードと reload (`-r`) は、いずれにせよ権限を必要とします。
</details>

## 検証

作業マシンで次を実行します：

```bash
check_result
```

チェックには Init と 9 個の独立したテストが含まれます。Pod の state を API 経由で読み取り、ノード上の
profile を SSH 経由で確認し、制御された否定的なシナリオを実行します。Localhost
Pod が作成されない場合は、まず `kubectl describe pod` を確認してください：通常の原因は、相対パスの代わりに
絶対パスを使っていること、または profile のないノードに Pod が割り当てられていることです。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=106 make delete_cks_task
```
