[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 112 - Runtime: Falco、audit ログ、immutable root filesystem

## 目的

この CKS 実習では、ノード上の runtime イベントの監視と、control plane の API の audit ロギングを設定し、
その後 workload を runtime で immutable にします。作業は 1 つのノードで行います：
`control-plane` が workload ノードも兼ねているため、Falco はテスト用の Pod のイベントを見ることができ、
kube-apiserver は static Pod manifest にあります。

## 開始前のセルフチェック

<details>
<summary>1. Kubernetes の audit log が、runtime の検出における Falco の代わりにならないのはなぜか？</summary>

Audit log が記録するのは API server への request レベルのイベント (誰が、何を、いつ `kubectl`/API 経由でリクエストしたか) であり、control plane レベルの evidence です。一方 Falco は、ノード上で動作しているコンテナ内のシステムコール (syscalls) を観察します - たとえば shell を開く、プロセスを spawn する、ファイルに書き込む、などです。`docker exec`/`crictl exec` のような操作や、ノード上での `ctr` による直接の起動は、Kubernetes API をまったく通らず、audit log には入りませんが、Falco には syscall イベントとして見えます。
</details>

<details>
<summary>2. audit policy のレベル `RequestResponse` と `Metadata` の違いは何か、そして Secret にまさに `Metadata` が必要なのはなぜか？</summary>

`RequestResponse` は、リソースの内容を含む、リクエストとレスポンスの両方の完全な本文を記録します。`Metadata` は、リクエストについてのメタデータ (誰が、いつ、どのリソースで、どの verb か) のみを本文なしで記録します。`secrets` ではこれが重要です：`RequestResponse` は、secret 自体の値 (base64 エンコードされていますが、それでも機微なデータ) を、ディスク上の読み取り可能なファイルとして audit log に記録してしまいます - これは新たな漏洩の surface を作ります。`Metadata` は、secret 自体をログにコピーすることなく、forensic の痕跡 (「誰がこの Secret をいつ読んだか」) を提供します。
</details>

<details>
<summary>3. `readOnlyRootFilesystem: true` が、runtime でのコンテナの compromise に対する完全な防御と同等ではないのはなぜか？</summary>

`readOnlyRootFilesystem` は、コンテナの root filesystem への書き込みをブロックし、攻撃者がアプリケーションのバイナリを改変したり、コンテナのディスク上に persistence を設置したりするのを難しくします。しかし、次のことは妨げません：(a) Pod 自身が明示的にマウントする writable な volumes/emptyDir (たとえば `/tmp`)、(b) プロセスのメモリ内での行為の実行 (ディスクへの書き込みなしの RCE)、(c) コンテナ内部からのネットワーク攻撃、(d) すでにマウントされた Secret/ConfigMap の読み取り。rootfs の immutability は防御の 1 つのレイヤーであり、完全な分離ではありません。
</details>

## コースとの関連

- [第 29 章 実行時の振る舞い分析：Falco](../../course/29/jp.md)
- [第 30 章 脅威の検出と攻撃フェーズの調査](../../course/30/jp.md)
- [第 31 章 runtime でのコンテナの immutability](../../course/31/jp.md)
- [第 32 章 Kubernetes の audit ログ](../../course/32/jp.md)
- [第 26 章 レジストリ、署名、成果物の検証](../../course/26/jp.md) - 課題 9 は、registry の allowlist の admission control を、回避を runtime で検出することと結びつけます (signature verification ではありません - それは実習 111 が確認します)。

## インフラ

| コンポーネント | 用途 |
|---|---|
| `k8s-1` | シングルノードの Kubernetes `1.36.0`、containerd、Calico；ノード名 `control-plane` |
| `worker` | `kubectl`、`check_result`、SSH アクセス `ssh control-plane` を備えた作業マシン |
| `runtime-112` | 用意された namespace；すでに Secret `audit-secret` がある |

Bootstrap は、Falco を意図的にインストール**せず**、audit backend も有効に**しません**。ディレクトリ
`/etc/kubernetes/audit`、ログのディレクトリ
`/var/log/kubernetes/audit`、制御された API リクエスト用の Secret を準備するだけです。CNI、
クラスターのバージョン、Secret、課題 4 と 8 以外の Kubernetes の manifest を変更しないでください。

## デプロイ

```bash
TASK=112 make run_cks_task
```

作業マシンで：

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## ノードでの作業方法

2 つのターミナルを開きます：**ターミナル 1** は `ssh control-plane` に続けて `sudo -i` (ノードに対する操作：
Falco、audit、`crictl`、`/proc`)、**ターミナル 2** は作業マシン (`kubectl`、`scp`、確認) です。
ノードで取得した成果物は、`control-plane` 上のファイルに保存し、`scp` コマンドで作業マシンの
`/var/work/tests/artifacts/<課題番号>/` にコピーしてください。

## 課題

containment の前に、blast radius を頭の中で評価しておくと有用です：compromise された Pod の ServiceAccount が
Secrets を読み取れるか、workload を作成できるか、他の
namespace に到達できるか。これは追加の手順として、Pod `falco-shell` の ServiceAccount (`--as=system:serviceaccount:runtime-112:default`) として実行する
`kubectl auth can-i` で素早く確認でき、確認しておくとよいでしょう；必須ではなく、
受け入れ基準には影響せず、テストもされません。

---
| **1** | **workload ノードに Falco をインストールして起動する** |
| :---: | :--- |
| やること | • `control-plane` に、Falco の公式リポジトリから Falco のパッケージをインストールし、サービスを起動します。<br/>• modern eBPF engine を使用します；kernel module を手動でインストールしないでください。<br/>• systemd でサービスを有効にします。 |
| 受け入れ基準 | • `falco --version` が実行できる<br/>• `systemctl is-active falco` が `active` を返す<br/>• 設定に `engine.kind: modern_ebpf` が含まれている |

<details>
<summary>💡 課題 1 のヒント</summary>

Modern eBPF engine は `/etc/falco/falco.yaml` または `/etc/falco/config.d/` の drop-in ファイルの `engine.kind: modern_ebpf` で設定します (legacy engine に必要な個別の kernel module driver ではありません) - インストール後に Falco が起動しない、または起動時に落ちる場合は、`journalctl -u falco-modern-bpf` を確認してください (パッケージは unit `falco-modern-bpf.service` をインストールし、`falco.service` はそれへの alias にすぎません：`systemctl status/restart falco` は動作しますが、`journalctl -u falco` は空です)。eBPF program のロードエラーが出ている場合は、カーネルが非互換である可能性があります。
</details>

---
| **2** | **コンテナ内の標準的な shell イベントを記録する** |
| :---: | :--- |
| やること | • `runtime-112` に、`busybox:1.36` の Pod `falco-shell` を作成し、Running のまま (`sleep 3600`) にして、`stdin: true`、`tty: true` を有効にします。<br/>• その中でインタラクティブな `/bin/sh` を開き、Falco のルール **Terminal shell in container** を待ちます。<br/>• Falco の journal (`control-plane` で読み取れます) から該当する行をノード上のファイルに保存し、`scp` で作業マシンの `/var/work/tests/artifacts/2/falco-shell.log` にコピーします。 |
| 受け入れ基準 | • Pod `falco-shell` が Running である<br/>• 成果物が空でなく、アラートの行 `A shell was spawned in a container with an attached terminal` を含んでいる (Falco 0.45 のテキスト出力では、ルール **Terminal shell in container** がこのようにイベントを出力します；ルール名は JSON 出力にのみあります)<br/>• イベントは Falco が受信したものでなければならず、手で書いたものであってはならない |

<details>
<summary>💡 課題 2 のヒント</summary>

`stdin: true, tty: true` の Pod を作成するだけでは不十分です - Falco がコンテナ内の shell プロセスの spawn をまさに記録するよう、インタラクティブなセッションを実際に開く必要があります (`kubectl exec -it falco-shell -- /bin/sh`)。イベントは、`control-plane` で (worker から SSH 経由で) `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"` で探してください。行を手でファイルに書こうとしないでください - テストは journal の実際の timestamp/形式を期待します。
</details>

---
| **3** | **custom Falco rule を追加して発火させる** |
| :---: | :--- |
| やること | • `control-plane` の `/etc/falco/falco_rules.local.yaml` に、名前 `CKS112 Custom Shell Marker` のルールを追加します。<br/>• コンテナ内で spawn されたプロセスのうち、`proc.cmdline` に `CKS112_CUSTOM_EVENT` を含むものを捕捉する必要があります。<br/>• 正確なフレーズ `CKS112 custom shell marker` を、`container=%container.id`、`pid=%proc.pid`、`ppid=%proc.ppid`、`user=%user.name`、`command=%proc.cmdline` とともに出力する必要があります。<br/>• Falco を再起動します。<br/>• `falco-shell` で、コマンドラインに marker を含む任意の短いコマンドを実行します。たとえば：`kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`。<br/>• `control-plane` の Falco の journal から、この発火の行 (`CKS112 custom shell marker` を含みます) を見つけ、ノード上のファイルに保存して、`scp` で `/var/work/tests/artifacts/3/falco-custom.log` にコピーします。行は本物の journal の行でなければならず、手で書いたものは受け付けられません。 |
| 受け入れ基準 | • ローカルの rules ファイルが存在し、ルール名、marker の条件、調査用の識別子を含んでいる<br/>• Falco のサービスが active である<br/>• 本物の journal の成果物に、marker、container ID、PID が含まれている |

<details>
<summary>💡 課題 3 のヒント</summary>

`falco_rules.local.yaml` の custom rule には、`spawned_process` (または `evt.type=execve`) と `proc.cmdline contains "CKS112_CUSTOM_EVENT"` を使う `condition` が必要です - イベントの種類に関する基本の条件がないと、ルールがまったく発火しないか、誤ったイベントで発火する可能性があります。ファイルを修正した後は、ルールの適用を確定的に確認するために `systemctl restart falco` を実行してください。最近の Falco では `watch_config_files: true` が有効な場合に自動の reload も可能ですが、この実習では明示的な restart を使用します。
</details>

---
| **4** | **audit ロギングを有効にする：ConfigMap は RequestResponse、Secret は Metadata** |
| :---: | :--- |
| やること | • `control-plane` に `/etc/kubernetes/audit/policy.yaml` を作成します。Policy は、core resource `configmaps` について、**namespace `runtime-112` のみ**で `RequestResponse` を記録する必要があります (機微でないリソースでの、制御された forensic の例)。<br/>• core resource `secrets` については、**Secret の本文がログに入らないよう**、`Metadata` のみを使用します。<br/>• 大量/低リスクのトラフィックに対する明示的な `None` ルールと `omitStages: [RequestReceived]` で、ノイズを実際に減らします。<br/>• policy の最後を、ノイズ抑制ではなく *fallback logging* としての、安全な catch-all `Metadata` で終えます。<br/>• static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` に、`--audit-policy-file=/etc/kubernetes/audit/policy.yaml`、`--audit-log-path=/var/log/kubernetes/audit/audit.log`、およびローテーション (`--audit-log-maxage`、`--audit-log-maxbackup`、`--audit-log-maxsize`) を追加します。<br/>• policy ディレクトリとログディレクトリに必要な hostPath の volume/volumeMount を追加します。API が復旧するまで待ちます。<br/>• `runtime-112` に ConfigMap `audit-config` を作成し、それを読み取り (`kubectl get configmap audit-config -n runtime-112 -o json`)、RequestResponse event を `/var/work/tests/artifacts/4/configmap-request-response.json` に保存します。<br/>• 次に `kubectl get secret audit-secret -n runtime-112 -o json` を読み取り、その Metadata event を `/var/work/tests/artifacts/4/secret-metadata.json` に保存します。Events は `control-plane` の audit log から取得します：ノード上に保存して `scp` でコピーしてください。 |
| 受け入れ基準 | • Kube-apiserver が healthy である<br/>• Static manifest に両方の audit フラグとマウントが含まれている<br/>• Policy が `configmaps` に `RequestResponse`、`secrets` に `Metadata` を設定している<br/>• `/var/work/tests/artifacts/4/configmap-request-response.json` に ConfigMap の RequestResponse event がある<br/>• `/var/work/tests/artifacts/4/secret-metadata.json` に、**フィールド `requestObject`/`responseObject` を持たない**、レベル `Metadata` の Secret のイベントがある (Secret の本文はログに記録されていない) |

<details>
<summary>💡 課題 4 のヒント</summary>

audit policy のルールの順序は重要です：Kubernetes は上から下へ、最初に一致するルールを適用します。そのため、`runtime-112` の `configmaps`/`secrets` に対する具体的なルールは、ファイル末尾の一般的な catch-all `Metadata` より前に置く必要があります - catch-all が先にあると、具体的なルールより前にすべてのリクエストを「横取り」します。static manifest を編集した後、kubelet が変更を自分で検出します (`kubectl apply`/restart は不要です) - ただし、続ける前に `kubectl get --raw=/readyz` が再び成功を返すまで待ってください。
</details>

---
| **5** | **root filesystem を読み取り専用にした Pod を作成する** |
| :---: | :--- |
| やること | • `runtime-112` に Pod `immutable-app` を作成します：コンテナ `app`、イメージ `busybox:1.36`、`sleep 3600`。<br/>• コンテナで `securityContext.readOnlyRootFilesystem: true` を有効にします。<br/>• `emptyDir` `writable-tmp` を作成し、`readOnly: true` なしで `/tmp` にマウントします。`hostPath` は使用しないでください。<br/>• `touch /cks-112-write-denied` が失敗し、`touch /tmp/allowed` が成功することを実証します；拒否の結果を `/var/work/tests/artifacts/5/rootfs-write-denied.log` に保存します。 |
| 受け入れ基準 | • Pod が Running である<br/>• Root filesystem が read-only である<br/>• `/tmp` が writable な `emptyDir` である<br/>• Pod に `hostPath` がない<br/>• rootfs への書き込みはブロックされ、`/tmp` には許可される<br/>• 成果物が空でない |

<details>
<summary>💡 課題 5 のヒント</summary>

コマンドがゼロ以外のコードで終了したという事実だけでなく、コマンド `touch /cks-112-write-denied` のエラー出力そのもの (stderr の `Read-only file system`) を保存してください - テストはログの内容を確認します。`emptyDir` (一時的で、Pod とともに存在する) と `hostPath` (ノード上で永続的で、この課題では禁止されている) を混同しないでください - どちらも技術的には writable なディレクトリという課題を「解決」しますが、ここで許可されているのは前者だけです。
</details>

---
| **6** | **alert から isolation までの、最小限の containment の連鎖** |
| :---: | :--- |
| やること | • audit backend を有効にした後、`falco-shell` で、コマンドラインに `CKS112_CUSTOM_EVENT` を含む、制御された長時間動作するプロセスを起動します。たとえば：`kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`。プロセスは 10 分間動作します：動作している間は、その `/proc/<PID>` を取得できます。<br/>• **調査は、Pod manifest からではなく、新しい Falco alert から始めてください。** alert から、short container ID と host PID を取り出します。<br/>• `control-plane` で `crictl ps/inspect/inspectp` を使い、container → Pod sandbox → namespace/Pod を対応づけます；Kubernetes API でノードを特定します。`crictl inspect` と `inspectp` を保存します。<br/>• プロセスが生きている間に、`/proc/<PID>/status`、`cmdline`、`cgroup`、そして PID/PPID/user のツリーを保存します。<br/>• audit log で、`runtime-112/falco-shell` の `pods/exec` event を見つけ、request/response body なしで保存します。<br/>• フェーズを `Execution`、テクニックを `Container Administration Command` として分類し、`evidence-summary.txt` を作成します。`control-plane` で取得したファイルは、`scp` で `/var/work/tests/artifacts/6/` にコピーします。<br/>• 次に、default-deny の ingress+egress `NetworkPolicy` `incident-quarantine` を適用し、compromise された Pod を削除して、失敗することの確認 (ネガティブテスト) を保存します：再度の `kubectl exec` が通らないこと。<br/>• これは最小限の containment の連鎖です：credential の revocation/rotation と完全な remediation には、別の incident-response の手順が必要です。 |
| 受け入れ基準 | • `/var/work/tests/artifacts/6/` に、本物の Falco alert、CRI inspect/inspectp、3 つの `/proc` の成果物、process lineage、`pods/exec` の Metadata audit event、最終的なまとめ、containment の結果がある<br/>• Pod `falco-shell` が存在しない<br/>• `incident-quarantine` がすべての Pod を選択し、ingress+egress を塞いでいる<br/>• 再度の exec が non-zero の exit code になる |

<details>
<summary>💡 課題 6 のヒント</summary>

厳密な作業の順序は、調査の信頼性にとって重要です：Falco alert から始めてください (これが実際に incident response のきっかけになるものです)。すでに知っている Pod 名からではありません - そうでないと、すでに知っていることを確認するだけで、本当の correlation を行っていません。`/proc/<PID>/*` の成果物は、プロセスが生きている間に取得してください - Pod を削除する (最後のステップ) と、その PID の `/proc` は永遠に消えるため、「まず evidence、次に containment」の順序を取り違えると取り返しがつきません。
</details>

---
| **7** | **upstream Falco の macro を override し、output に Pod/namespace の evidence を追加し、JSON をファイルに出力する** |
| :---: | :--- |
| やること | • Falco の標準ルール **Terminal shell in container** は、コンテナ内で shell を正規に開く正当な CI/CD ツール (たとえば `kubectl debug` や、保守スクリプトを持つ sidecar) にも発火してしまいます。ルール自体を編集するのではなく、まさにこのルールのために用意された upstream の macro を override します。<br/>• `/etc/falco/falco_rules.local.yaml` で `user_expected_terminal_shell_in_container_conditions` を再定義し (ルール **Terminal shell in container** 自体ではデフォルトで `(never_true)` です - 別のルール **Run shell untrusted**/"Shell spawned by untrusted binary" に関する `user_shell_container_exclusions` と混同しないでください)、namespace `runtime-112` の特定の Pod `ci-runner` を許可するようにします。<br/>• `container.name` ではなく `k8s.pod.name` と `k8s.ns.name` を使用してください：`container.name` は **コンテナ**の名前 (この課題では `app`) であり、Pod ではありません。コンテナ名による一致は、ほぼ確実に誤った、あるいは広すぎる allowlist になります。<br/>• ルール **Terminal shell in container** の標準の output には `k8s.pod.name`/`k8s.ns.name` が含まれません (upstream の `falco_rules.yaml` を自分で確認してください - そこにはありません)；これらのフィールドがなければ、特定の alert を特定の Pod に確実に correlation することはできません。同じ `override` の仕組みで、ルールの output の末尾に `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` を追加します (`output: append`)。<br/>• `runtime-112` に、インタラクティブな `sh` (`stdin: true`、`tty: true`) を持つ `busybox:1.36` の Pod `ci-runner` を作成し、それに対しては `Terminal shell in container` の alert が生成**されない**一方で、課題 5 の `immutable-app` (除外なし) に対しては alert が引き続き発火することを確認します。<br/>• 別途、`/etc/falco/config.d/cks112-output.yaml` で `json_output: true` と、`file_output.filename: /var/log/falco/events.log` を持つ `file_output.enabled: true` を有効にします；Falco を再起動します。<br/>• テキストの `grep` ではなく、構造化された JSON (`jq .output_fields`) で、記録された `immutable-app` の alert に `k8s.pod.name == "immutable-app"` と `k8s.ns.name == "runtime-112"` が含まれていることを確認します。 |
| 受け入れ基準 | • `falco_rules.local.yaml` に、`k8s.pod.name = "ci-runner"` と `k8s.ns.name = "runtime-112"` を参照する条件を持つ `macro: user_expected_terminal_shell_in_container_conditions` (`never_true` でも `container.name` でもない) と、ルール `Terminal shell in container` に `%k8s.ns.name`/`%k8s.pod.name` を追加する別の `override: output: append` が含まれている<br/>• `ci-runner` の shell は、観察期間中に alert を生成せず、`immutable-app` の shell は生成する<br/>• `config.d/cks112-output.yaml` に `json_output: true` と `file_output: {enabled: true, filename: /var/log/falco/events.log}` が含まれている<br/>• `/var/log/falco/events.log` に、`rule == "Terminal shell in container"` と `output_fields["k8s.pod.name"] == "immutable-app"`、`output_fields["k8s.ns.name"] == "runtime-112"` を持つ有効な JSON の行が含まれている<br/>• 課題 2 の Pod `falco-shell` は、この時点ではすでに削除されており (課題 6)、ここでは使用しない |

<details>
<summary>💡 課題 7 のヒント</summary>

2 つの異なる override の仕組みは混同しやすいです：`macro` の override はルールの発火の条件 (誰を除外するか) を変え、`output` の `append` の override は出力の形式 (何を出力するか) だけを変えます - この課題には両方が必要で、`- macro: ...` と `- rule: ... / override: / output: append` の別々のブロックで書きます。`user_expected_terminal_shell_in_container_conditions` の綴りを文字どおり確認してください - Falco には、異なるルール用の名前の似た macro がいくつかあり (課題で言及されている `user_shell_container_exclusions` は別のルールのものです)、誤った macro を使ってもロードエラーにはなりませんが、allowlist は単に機能しません。
</details>

---
| **8** | **ローカルファイルの代わりに/と併せて audit webhook backend を使う** |
| :---: | :--- |
| やること | • bootstrap がすでに用意した HTTP レシーバー `audit-receiver` (ポート `8080` の Deployment + Service、イメージ `ghcr.io/mendhak/http-https-echo:40`) を使用します。これは audit イベントを受信します。<br/>• `control-plane` に、kubeconfig 形式で `server: http://<ClusterIP (レシーバー)>:8080/audit` を持つ `/etc/kubernetes/audit/webhook-config.yaml` を作成します (実習では HTTP で構いません；production の webhook には HTTPS と client certificate が必要です - 第 32 章を参照)。<br/>• static manifest `kube-apiserver.yaml` に `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` と `--audit-webhook-batch-max-wait=1s` (実習での観察のための、短縮された batch の遅延) を追加し、課題 4 ですでに設定した `--audit-policy-file` と `--audit-log-path` を維持します - webhook は local file backend を補完するものであり、置き換えるものではありません。<br/>• API の復旧後、任意の監査対象のリクエスト (たとえば `kubectl get configmap audit-config -n runtime-112`) を実行し、イベントが配信されたことを `audit-receiver` のログで確認します。 |
| 受け入れ基準 | • `audit-receiver` が Service とともに Running である<br/>• `webhook-config.yaml` が、この Service を指す `server` を持つ有効な kubeconfig である<br/>• kube-apiserver の static manifest に `--audit-webhook-config-file` と `--audit-webhook-batch-max-wait`、さらに課題 4 の file backend のフラグが保持されている<br/>• 変更後に kube-apiserver が healthy である<br/>• `audit-receiver` のログに、受信した HTTP リクエストの本文として、フィールド `objectRef` を持つ JSON 形式の audit event が少なくとも 1 つ含まれている |

<details>
<summary>💡 課題 8 のヒント</summary>

`webhook-config.yaml` は kubeconfig の形式 (`clusters`/`users`/`contexts` を持つ) であり、フィールド `server` を持つ任意の YAML ではありません - ファイルの構造が kubeconfig の schema に合っていないと、kube-apiserver はそれを解析できず、まったく起動しません。webhook は file backend を補完するのであって、置き換えるのではないことを忘れないでください - 課題 4 の `--audit-policy-file`/`--audit-log-path` のフラグを削除すると、課題 4 のテストが通らなくなります。
</details>

---
| **9** | **統合課題：containerd を直接使って admission allowlist を回避し、その試みを Falco で検出する** |
| :---: | :--- |
| やること | • この課題は、Supply Chain Security ([実習 111](../111/README_JP.MD) と [第 26 章](../../course/26/jp.md) を参照) を、この実習の Runtime Security と結びつけます。**実習 111 との重要な違い**：そこでは `ImageValidatingPolicy` が**暗号署名** (Cosign) を確認します。ここでは policy が確認するのは **registry/repository の allowlist** (許可された registry、signature/attestor なし) だけです - より単純ですが、同じく実際の admission control であり、同じ原則を持ちます：それは API の admission の経路でのみ動作し、それを経由しない操作は見えません。<br/>• この課題の Controlled abuse fixture は、公開の Docker Hub ではなく、実習が所有するローカルの registry です：bootstrap は `control-plane` のローカルの containerd content store に、異なる digest を持つ 3 つの image をすでに用意し、その名前を `/etc/cks112/registry.env` に保存しています (`CKS112_REGISTRY=cks112.local:5000`、`CKS112_TRUSTED_REPO=cks112/trusted`、`CKS112_UNTRUSTED_REPO=cks112/untrusted`、`CKS112_TRUSTED_IMAGE`、`CKS112_UNTRUSTED_IMAGE`、`CKS112_PREFIX_IMAGE`) - 課題の最初でこのファイルを読み込み (`source`)、これらの値のみを使用してください。<br/>• Kyverno をインストールし (`install-kyverno`、実習 111 と同様)、`ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL、`apiVersion: policies.kyverno.io/v1`) を作成します。これは `image(c.image).registry()`/`.repository()` (Kyverno の CEL Image library) を通じて、`runtime-112` の、image が `registry: $CKS112_REGISTRY` と `repository: $CKS112_TRUSTED_REPO` に正確に等しくない任意の Pod を**拒否**します - `cks112/trusted-evil` のような似た名前を通さないよう、`startsWith` ではありません。policy に、一意の拒否メッセージ (denial) (たとえば `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`) を付けます。<br/>• この経路を確認します：image `$CKS112_UNTRUSTED_IMAGE` (allowlist にない) を持つ Pod `blocked-attempt` を適用し、admission denial の出力を `9/admission-deny.txt` に保存します。<br/>• 次に `control-plane` で、`cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'` によって (image は bootstrap からすでにローカルに存在し、再度の pull は不要です)、API server を通らず、admission controller からも見えない経路をシミュレートします (helper は CRI を通じて detached モードで自分で起動します；再確認のために一意の ID を使用し、その後 `cks112-rm <id>` でコンテナを削除してください)。<br/>• **Falco のルールを書く前に、あなたの containerd/Falco の構成における、信頼された `$CKS112_TRUSTED_IMAGE` についてのフィールド `%container.image.repository` の実際の observed 値を特定してください** - このフィールドはバージョンによって異なる形で形成されるため (registry の hostname を含む場合も含まない場合もあります)、形式をあらかじめ仮定しないでください：安全な marker を持つ一時的なルールで値をログに出力し、`$TRUSTED_REPO` として保存します (evidence を `9/observed-trusted-repo.txt` に保存します)。<br/>• `falco_rules.local.yaml` に、custom rule `CKS112 Runtime Bypass of Admission` を追加します。これは、`proc.cmdline` に `CKS112_CTR_BYPASS` を含み、**かつ** `container.image.repository` が allowlist に含まれない、spawn されたプロセスを捕捉し、プロセスの識別子とともに `container.image.repository` を出力します。観察された値との**正確な**比較 `container.image.repository != "$TRUSTED_REPO"` を使用してください (`startswith`/prefix の確認ではありません：`not container.image.repository startswith "$TRUSTED_REPO"` は、`<observed-value>-evil` のような repository を通してしまいます (つまり気づきません)。その名前が許可された部分文字列で始まるだけだからです - 上の Kyverno の policy が `startsWith` ではなく `==` で避けているのと同じ誤りです)。<br/>• さらに、制御された 2 つのケースを両方とも確認します：信頼された `$CKS112_TRUSTED_IMAGE` はルールを発火させてはいけません (repository の基準についてのみ - marker `CKS112_CTR_BYPASS` 自体は、別途確認できます)。一方、repository が `<observed-value>-evil` の image は発火させなければなりません - これがまさに、比較が prefix ベースではなく正確であることの証明です。<br/>• 発火を `9/falco-bypass-attempt.log` に保存します (`control-plane` で取得したファイルは、`scp` で `/var/work/tests/artifacts/9/` にコピーします)。 |
| 受け入れ基準 | • Kyverno がインストールされ Available である<br/>• `ValidatingPolicy require-trusted-registry-runtime-112` が `apiVersion: policies.kyverno.io/v1`、validation action `Deny` で存在し、`image(...).registry()`/`.repository()` を正確な (`startsWith` ではない) 比較に使用し、その `message`/`messageExpression` に一意のマーカー `CKS112_TRUSTED_REPO_POLICY` が含まれている<br/>• Pod `blocked-attempt` が作成されず (admission denial)、`9/admission-deny.txt` にまさにこのマーカーが含まれている (一般的な admission エラーではない)<br/>• `9/observed-trusted-repo.txt` に、信頼された image についての `%container.image.repository` の、実際に観察された値が含まれている<br/>• `falco_rules.local.yaml` に、`container.image.repository` に対する**正確な** (`startswith`/prefix ではない) 条件を持ち、まさにこの観察された値を使用する、ルール `CKS112 Runtime Bypass of Admission` が含まれている<br/>• `9/falco-bypass-attempt.log` に、`CKS112_CTR_BYPASS` と allowlist 外の image repository (観察された値に接尾辞 `-evil` を付けたもの) を持つ、空でない発火が含まれている - この repository は prefix-trap としてわざと選ばれている：許可された文字列で始まっているにもかかわらず、検出される必要がある |

<details>
<summary>💡 課題 9 のヒント</summary>

この課題の重要な考え方：`cks112-run` (CRI を通じて直接コンテナを作成する `crictl` のラッパー) は、kube-apiserver を迂回して containerd にアクセスするため、あらゆる admission controller (Kyverno を含む) も迂回します - これは、admission control が保護するのは Kubernetes API を通る経路だけであり、ノード全体ではないことの実演です。あなたの Falco ルールは、1 つの `condition` 内で `and` により次を確認する必要があります：コンテナのプロセス (`container.id != host` - ホスト上の起動コマンド自体にも marker が含まれます)、marker `CKS112_CTR_BYPASS`、そして allowlist 外の repository - marker だけを確認すると、ルールは、cmdline が似た正当なテストプロセスにも発火します。
</details>

---
| **10** | **別のクラスの Falco 条件で `/dev/mem` へのアクセスを検出し、workload を停止する** |
| :---: | :--- |
| やること | • 課題 3、7、9 は、`spawned_process`/`proc.cmdline` に対する条件 - プロセスの起動による検出を使いました。ここでは、原理的に別のクラスの Falco condition が必要です：**ファイル/デバイスのオープン**による検出です。<br/>• `runtime-112` には、すでに Deployment `mem-scanner` (2 つの replica) があり、両方の replica がコンテナ内から定期的に `/dev/mem` を開きます - 通常のアプリケーションの workload にはそうする理由がなく、そのようなアクセスは、危険な設定やコンテナの分離を回避しようとする試みを示す強い指標です。コンテナ内の `/dev/mem` のパスは synthetic で安全な fixture です (backing device は実際にはホストの `/dev/null` であり、ホストの実際の物理メモリではありません)；Falco にとってはそれは関係ありません - ルールは、その背後に実際にどのデバイスがあるかに関係なく、ファイル名 `fd.name = /dev/mem` による `open`/`openat`/`openat2` のシステムコール自体を検出します。<br/>• `control-plane` の `/etc/falco/falco_rules.local.yaml` に、条件 `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`、priority `CRITICAL` のルール `CKS112 Container access to /dev/mem` を追加し、output に `container_id=%container.id`、`k8s_pod=%k8s.pod.name`、`k8s_ns=%k8s.ns.name` を含めます。Falco を再起動します。<br/>• journal で発火を見つけ、それを通じて**具体的な** Pod を特定します (名前から推測せず - alert 自体の `k8s_pod` を使用します)；具体的な alert から、どの replica が記録されたイベントを作成したかを特定します。アラートの行をノード上に保存し、`scp` で `/var/work/tests/artifacts/10/falco-devmem.log` にコピーします。<br/>• containment の前に、見つかった Pod の JSON (`kubectl get pod <alert の pod> -n runtime-112 -o json`) を `/var/work/tests/artifacts/10/detected-pod.json` に保存します。<br/>• `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` を実行し、最終的な状態 (`kubectl get deployment mem-scanner -n runtime-112 -o json`) を `/var/work/tests/artifacts/10/scaled-down.json` に保存します。 |
| 受け入れ基準 | • `falco_rules.local.yaml` に、名前 `CKS112 Container access to /dev/mem` のルールが含まれ、条件が `fd.name = /dev/mem` (`proc.cmdline`/spawned_process ではない) と `container.id != host` で、priority が `CRITICAL` である<br/>• Falco が active である<br/>• `10/detected-pod.json` に、containment の前の実際の Pod と owner chain が記録されている<br/>• `10/falco-devmem.log` が、このルールと空でない `k8s_pod` を持つ、journal の本物の行である<br/>• Deployment `mem-scanner` が `replicas: 0` にスケールされている<br/>• `10/scaled-down.json` が `spec.replicas == 0` を確認している |

<details>
<summary>💡 課題 10 のヒント</summary>

この条件を課題 3/7/9 と混同しないでください - そこでは `spawned_process`/`execve` がコマンドラインによるプロセスの起動を捕捉しますが、ここでは `open`/`openat`/`openat2` が、どのプロセスが、どのコマンドライン引数でそれを行うかに関係なく、特定のファイル/デバイスのオープンを捕捉します。`container.id != host` は、`/dev/mem` へのアクセスが別の理由で必要になりうる、ノード自体 (コンテナ内ではない) の正当なシステムプロセスを除外します。alert を見つける前に Deployment をスケールしないでください - まず Falco による検出、次に containment です。そうでないと、事前に名前で Pod を選ぶのではなく、まさに監視を通じて Pod を見つけたことを証明できません。まず Falco alert を取得し、その `k8s_pod` だけから、このイベントを作成した具体的な replica を特定してください。
</details>

## 検証

```bash
check_result
```

チェックには Init と 10 個の独立したテストが含まれます。Falco と
kube-apiserver の状態 (SSH 経由)、API オブジェクト、CRI/`/proc` の evidence、audit correlation、containment、
rootfs への書き込みの実際の拒否を確認します。static Pod manifest を変更した後は、必要がなければ
kubelet を再起動しないでください：kubelet が変更を自分で検出します。API が一時的に利用できない場合は、`kubectl get --raw=/readyz` が成功するまで待ってください。
`kube-apiserver.yaml` の backup は、`/etc/kubernetes/manifests` の外にのみ保存してください：kubelet はこのディレクトリの、先頭にドットのないファイルをすべて読み取ります。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=112 make delete_cks_task
```
