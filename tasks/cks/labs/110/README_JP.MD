[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 110 - gVisor RuntimeClass、Cilium WireGuard、Istio mTLS

## 目的

この CKS 実習では、workload を保護する 3 つの独立したレイヤーを構築します：`runsc` による sandboxed runtime
**gVisor**、ノード間の Cilium WireGuard 暗号化、そして Istio の service-to-service
mTLS です。最後に、設定を見るだけでなく、観察可能な結果によってそれらを実証します：
gVisor の kernel view の違い、HTTP marker を含まない WireGuard パケット、そして mesh からの呼び出しと
mesh の外の plaintext クライアントからの呼び出しの結果の違いです。

## 開始前のセルフチェック

<details>
<summary>1. gVisor の userspace kernel は、仮想マシンの guest kernel と原理的に何が違うか?</summary>

gVisor (`runsc`) は、独自の Linux syscalls のサブセットを userspace で実装し、コンテナのシステムコールを横取りして、ホストのカーネルに直接渡さずに自分で処理します - コンテナのプロセスは別の「カーネル」を見ます (異なる `uname -r`、一部の syscalls の異なる挙動)。Guest kernel (たとえば Kata Containers) は、軽量な VM の中で完全な Linux カーネルを起動します - より強い分離ですが、gVisor にはない完全な仮想化のオーバーヘッドがあります。
</details>

<details>
<summary>2. WireGuard の peer が認証するのは正確には何か、そしてなぜそれが ServiceAccount の identity と同じではないのか?</summary>

WireGuard は、Cilium が各ノードのために生成した暗号鍵を通じて、クラスターのノード (nodes) を認証します - 暗号化は node-to-node のトンネルのレベルで行われます。これはノード間の通信をネットワークレベルでの盗聴から守りますが、その通信の中の特定の Pod/ServiceAccount の identity とは無関係です - Cilium WireGuard は、アプリケーションレベルで送信者が「誰か」を確認せず、「どのノードか」だけを確認します。
</details>

<details>
<summary>3. mesh 内でステータス 200 の `curl` が成功しても、plaintext client が実際にブロックされたことの証明にならないのはなぜか?</summary>

mesh の内部での成功したレスポンスが証明するのは、2 つの sidecar 間の mTLS 接続が動作していることだけです - これは positive control です。STRICT が mesh ではないトラフィックを実際にブロックしていることを証明するには、別の negative control が必要です：sidecar のないクライアントが同じサービスにアクセスしようとして、拒否されること。1 つの成功したテストでは不十分で - 両方が必要です：mesh の identity には allowed、plaintext には denied。
</details>

## コースとの関連

- [第 22 章。Container Runtime Sandbox](../../course/22/jp.md)
- [第 23 章。Pod-to-Pod の暗号化と mTLS](../../course/23/jp.md)

## インフラ

Terragrunt が `eu-central-1` に Kubernetes `1.36.0` を作成します：

| コンポーネント | 用途 |
|---|---|
| `k8s-1` control-plane | 通常の containerd workload ノード、Cilium、ノード間パケットのキャプチャ用の `tcpdump` |
| `k8s-1` worker `gvisor` | containerd、インストール済みの `runsc`、CRI handler `runsc` を持つ別のノード |
| CNI | **Cilium** (Helm release `cilium` を持つ Cilium CLI でインストール)；WireGuard は課題 4 まで意図的に無効 |
| `worker` | `kubectl`、`cilium`、`istioctl`、`check_result`、ノードへの SSH aliases を備えた作業マシン |

2026-08-31 に確認済みのマトリックス (ビルドのたびに照合してください)：学習用の Kubernetes は
`1.36.0`；Cilium の data plane は、サポートされている lab ビルドで、その
Kubernetes `1.36` との互換性は最新の requirements matrix で確認する必要があります；Cilium CLI `0.19.7`
(Cilium `1.17+` と互換)；Istio `1.30.4` (ブランチ `1.30` は Kubernetes
`1.32-1.36` を公式にサポート)。試験のバージョンは、ここでは lab tooling の互換性を決めません；LF のデータによれば
現在は `v1.34` で、試験の前に別途確認されます。

bootstrap の後、2 つの workload placement label が利用できます：

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Control-plane は tolerations なしの通常の Pod に利用できます。gVisor ノードには、さらに taint
`sandbox.runtime/gvisor=true:NoSchedule` が付けられています：そこにスケジュールされるのは、この taint を許容する Pod だけです
(`RuntimeClass gvisor` を持つ Pod は、クラスの `scheduling.tolerations` から必要な toleration を受け取ります)。

Namespace `sandbox-110` と `market` はすでに存在します。`market` には、あらかじめ
label `istio-injection=enabled` が付けられています；Istio control plane はインストールされていません。worker から
sandbox ノードにアクセスするには alias `k8s110_node_gvisor` を、control-plane には
`k8s110_controlPlane_1` を使用します。

## デプロイ

```bash
TASK=110 make run_cks_task
```

作業マシンに接続し、用意されたコンテキストを選択します：

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

作業を始める前に、証拠用のディレクトリを作成します：

```bash
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 課題

---
| **1** | **containerd runtime を設定し、runsc 用の RuntimeClass を作成する** |
| :---: | :--- |
| やること | • `k8s110_node_gvisor` では、バイナリ `runsc` はすでにインストールされていますが、bootstrap は `/etc/containerd/config.toml` から、`runtime_type = "io.containerd.runsc.v1"` を持つセクション `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` を意図的に取り除いています - これは壊れた config.toml という、試験で典型的な状況です。<br/>• このセクションを元に戻し (バックアップは `/etc/containerd/config.toml.bak` にあります。または手動で書き足してください)、`sudo systemctl restart containerd` を実行します。<br/>• 正確な `handler: runsc` を持つ `RuntimeClass` `gvisor` を作成します。<br/>• `scheduling` で、このクラスの Pod が通常のノードに決して配置されないよう `nodeSelector` `sandbox.runtime/gvisor: "true"` を設定し、gVisor ノードの taint (`sandbox.runtime/gvisor=true:NoSchedule`) 用の `tolerations` も設定します。そうしないと Pod はそこに配置されません。 |
| 受け入れ基準 | • ノード上で `containerd` が active で、`config.toml` に `runtime_type = "io.containerd.runsc.v1"` を持つ動作する `runtimes.runsc` セクションがある<br/>• `kubectl get runtimeclass gvisor` が存在し、handler が `runsc` で、`scheduling` に gVisor ノードの taint 用の `nodeSelector` と `tolerations` がある<br/>• `/var/work/tests/artifacts/1/runsc-runtime.txt` に正確な行 `RuntimeClass gvisor: handler runsc` がある |

<details>
<summary>💡 課題 1 のヒント</summary>

バックアップ `/etc/containerd/config.toml.bak` は最も早い復旧の方法ですが、元に戻す前にその内容を確認してください (現在のファイルとの `diff`)。具体的に何が欠けているのかを理解するためです。セクション `runtimes.runsc` を復元した後は、必ず `systemctl restart containerd` を実行してください - ファイルを編集しただけでは、すでに動作しているプロセスに変更は適用されません。
</details>

---
| **2** | **gVisor の sandbox 内の Pod** |
| :---: | :--- |
| やること | • `sandbox-110` に、`runtimeClassName: gvisor`、コンテナ `app`、イメージ `busybox:1.36` の Pod `gvisor-sandbox` を作成します。<br/>• Pod に `nodeSelector` `sandbox.runtime/gvisor: "true"` と、gVisor ノードの taint 用の `tolerations` を明示的に指定します (RuntimeClass の `scheduling` と同じもの；それらがなくても Kubernetes は RuntimeClass から自分で追加しますが、manifest にはそれが見えません)。<br/>• コンテナ内で、文字列 `CKS110-WIREGUARD-MARKER` を返す HTTP server を `8080` で起動します。<br/>• `8080` の Service `gvisor-echo` を作成し、この Pod を選択します。<br/>• ServiceAccount token の automount を無効にします。<br/>• Pod から `uname -r` と `dmesg` を成果物に記録します：gVisor sandbox 内の `dmesg` は、ノードの実際のカーネルログではなく、`Starting gVisor...` という行で始まります - これは `uname -r` の違いとは別の、分離の直接の証明です。 |
| 受け入れ基準 | • Pod が `sandbox.runtime/gvisor=true` のノードで `Running` であり、Service がそれを選択し、`/var/work/tests/artifacts/2/gvisor-kernel.txt` に行 `gvisor uname -r: <実際の値>` と、`dmesg` の出力からの行 `Starting gVisor` が含まれている |

<details>
<summary>💡 課題 2 のヒント</summary>

Pod が起動しない場合 (CreateContainerError/RuntimeCreateError)、課題 1 が完全に終わっていない可能性が高いです - RuntimeClass は、動作している containerd handler を実際に指している必要があります。使用している `busybox:1.36` には applet `httpd` があります - 最小限の HTTP server には `httpd -f -p 8080 -h /www` を使用してください (applet の有無は `busybox --list | grep '^httpd$'` で確認できます)。
</details>

---
| **3** | **通常の runc Pod との比較** |
| :---: | :--- |
| やること | • `sandbox-110` に `runc-baseline` を作成します：`busybox:1.36`、コンテナ `app`、`sleep 3600`。<br/>• `runtimeClassName` なし、nodeSelector `lab.cks.io/role: control-plane` あり、SA token なし。<br/>• その `uname -r` を gVisor Pod と比較し、両方の結果を `/var/work/tests/artifacts/3/runtime-comparison.txt` に保存します。 |
| 受け入れ基準 | • Baseline Pod が control-plane で `Running` であり、`runtimeClassName` を持たない<br/>• その release が gVisor の release と異なる<br/>• 成果物に、実際の値を持つ行 `gvisor uname -r:` と `runc uname -r:` の両方がある |

<details>
<summary>💡 課題 3 のヒント</summary>

この Pod は、nodeSelector `lab.cks.io/role: control-plane` によって、意図的に別のノード (control-plane で、gvisor ノードではない) に配置されます - これは単なる「任意の通常の Pod」ではなく、既知の配置場所との制御された比較です。両方の Pod で `uname -r` が同じだった場合は、`gvisor-sandbox` が本当に `runtimeClassName: gvisor` を使っているか確認してください。
</details>

---
| **4** | **Cilium transparent encryption を有効にする** |
| :---: | :--- |
| やること | • まず、Kubernetes、Cilium agent、Cilium CLI のバージョンを `/var/work/tests/artifacts/4/tool-versions.txt` に記録し、data plane が Kubernetes `1.36` をサポートしていることを確認します。<br/>• `cilium install` が作成した既存の Helm release で WireGuard を有効にします：`cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`。<br/>• agents を再起動します (`kubectl -n kube-system rollout restart daemonset/cilium`)：Helm は ConfigMap のみを変更し、DaemonSet のテンプレートは以前のままだからです。<br/>• `cilium-config` (`enable-wireguard: "true"`) と、両方の Cilium agents の準備状態を確認します。<br/>• ConfigMap の直接の patch は、確認済みの rollback を必須とする短時間の学習用 baseline プローブとしてのみ許容されます。リモートのワークフロー `cilium encrypt enable` は使用しないでください。<br/>• agent 側の `cilium-dbg encrypt status` と `cilium-dbg debuginfo --output json` を `/var/work/tests/artifacts/4/cilium-encrypt-status.txt` に保存します (`cilium-dbg status` にはフラグ `--all-encryption` がありません)。 |
| 受け入れ基準 | • Version evidence が存在し、DaemonSet `kube-system/cilium` の実際のイメージと一致している<br/>• Cilium agents (DaemonSet) が完全に Ready である<br/>• Status が WireGuard を示し、同時に IPsec を示していない<br/>• Debuginfo JSON に、ノード間の状態の peer/allowed-IP (または remote-node) の evidence が含まれている<br/>• ConfigMap `kube-system/cilium-config` に、Helm values から適用された effective な設定として `enable-wireguard: "true"` が含まれている<br/>• 設定が 1 つの agent Pod の restart を生き残る (checker が Pod を再起動して、status を再確認する) |

<details>
<summary>💡 課題 4 のヒント</summary>

WireGuard を有効にするための永続的な source-of-truth として、一時的な CLI コマンド `cilium encrypt enable` ではなく、既存の release `cilium` の Helm values を使用してください - 後者は agent の restart や Helm release のアップデートを生き残らない可能性があり、テストは設定が restart を生き残ることをまさに確認します。`cilium-dbg` は、worker 上の個別のローカルバイナリとしてではなく、`kubectl exec` で agent の Pod の内部から呼び出します。`cilium-dbg status` には `--all-encryption` フラグは「ありません」 - 詳細な peer/allowed-IP の evidence には `cilium-dbg debuginfo --output json` を使用してください。
</details>

---
| **5** | **ノード間に plaintext がないことを実証する** |
| :---: | :--- |
| やること | • 同じノード間 flow について、BEFORE/AFTER の baseline の証明を作成します。<br/>• **Baseline (WireGuard 無効):** control-plane で、リモートノードの IP (`host <remote-node-ip>`、`udp port 51871` による事前のフィルターなし) に対して `tcpdump` を起動します；一時的に WireGuard を無効にし (`cilium-config` の `enable-wireguard: "false"`、`rollout restart daemonset/cilium`)；`runc-baseline -> gvisor-echo` へのリクエストを実行します；この baseline の capture を保存し、plaintext の `CKS110-WIREGUARD-MARKER` が見えることを確認します。<br/>• **After (WireGuard 有効):** `enable-wireguard: "true"` を復元し、Ready になるのを待って、同じキャプチャ scope (`host <remote-node-ip>`、ポートフィルターなし) で 同じリクエストを繰り返します。<br/>• Capture は control-plane で (ノード上のファイルに) 取得し、その後 `scp` で作業マシンの `/var/work/tests/artifacts/5/wireguard-tcpdump.txt` にコピーします：その中には、WireGuard の UDP/`51871` だけが見え、plaintext の marker は見えない必要があります。 |
| 受け入れ基準 | • 同じ peer/interface scope での最終的な (post-change の) capture に UDP/`51871` が含まれるが、`CKS110-WIREGUARD-MARKER` は**含まれない**<br/>• 異なるノード間の呼び出しが、HTTP レスポンスで marker を正常に受け取る<br/>• Checker は同じ peer/interface scope で post-change の capture を自分で繰り返し (あらかじめ `udp port 51871` だけに限定せず)、さらに WireGuard を自分で一時的に無効にして復元し、plaintext の状態の同じ flow が実際に wire 上で marker を露出させることの、独自の baseline の確認を得る |

<details>
<summary>💡 課題 5 のヒント</summary>

トラフィックは、Pod の仮想インターフェース/veth や Cilium の内部インターフェース `cilium_wg0` ではなく、ノードの実際の物理ネットワークインターフェース (たとえば `eth0`) でキャプチャしてください - `cilium_wg0` は WireGuard トンネルの構造上、すでに復号されたトラフィックを運びます (それがその役割です)。そのため、`any` でのキャプチャは、物理 NIC で暗号化が正常に動作していても、そこで marker を見てしまいます。具体的な物理インターフェースは `ip route get <remote-node-ip>` で特定し、まさにそれを使用してください。キャプチャが WireGuard の暗号化の前の Pod の経路の「内側」で行われると、node-to-node の暗号化が有効かどうかにかかわらず plaintext の HTTP が見えます。`tcpdump` は、HTTP リクエストを実行した後ではなく、実行する前にバックグラウンドで起動してください。`udp port 51871` のみによるキャプチャフィルターは、plaintext の TCP を結果からあらかじめ除外するため、その不在を証明しません - 同じ scope が WireGuard の有効化の前後の違いを実際に示せるよう、ポートフィルターなしで `host <remote-node-ip>` を使用してください。Checker は、リクエストと同時に自分の `tcpdump` を実行します (一時的な WireGuard の無効化と、確認済みのその後の復元による baseline プローブを含みます) - あなたの artifact は学習用として有用ですが、唯一の証明ではありません：確認の時点で暗号化が実際に動作していなければ、checker の live capture は、あなたのファイルの内容に関係なくそれを検出します。
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| やること | • 用意された `istioctl` から、固定された Istio `1.30.4` をインストールし (minimal profile で十分です)、control plane のバージョンを記録します。<br/>• `market` に `market-api` Deployment と Service `market-api` を作成します：アプリケーションは `8080` で listen し、service port は `http` と名付けます。`market-api` は gVisor ノードで動作する必要があります：`nodeSelector` `lab.cks.io/role: gvisor` と、その taint (`sandbox.runtime/gvisor=true:NoSchedule`) 用の toleration。<br/>• `market` に injected な Deployment `market-client` を、`default` に plaintext Pod `mesh-outside` を作成します；3 つの workload はすべて Running である必要があります - `PeerAuthentication` STRICT は**なし**で。<br/>• **Baseline:** `market-api` への同じ outside の plaintext リクエストは HTTP 200 を受け取る必要があります (mTLS はまだ要求されていません)；この baseline のレスポンスを別に保存します。<br/>• namespace `market` の `PeerAuthentication` `market-strict` を `mtls.mode: STRICT` で適用し、同じ outside リクエストを繰り返します：sidecar のない plaintext client は成功したアプリケーションのレスポンスを受け取ってはならず、in-mesh のリクエストは HTTP 200 を受け取る必要があります。<br/>• status/headers/exit code を `artifacts/6/market-inside.txt` と `market-outside.txt` に保存します (`market-outside.txt` の末尾に行 `exit_code=<curl の終了コード>` を追記します)；特定の socket error の文字列に合わせないでください。 |
| 受け入れ基準 | • Namespace が `istio-injection=enabled` を保持している<br/>• `PeerAuthentication market-strict` が `STRICT` を持つ<br/>• mesh の内部では HTTP 200 があり、mesh の外の plaintext の呼び出しは成功した HTTP レスポンスを受け取らない (curl が失敗し、2xx がなく、ファイル内の `exit_code` が non-zero) - エラーの正確なテキストに関係なく<br/>• 両方の証明が保存されており、`market-inside.txt` に `exit_code=0` が含まれている<br/>• plaintext client を sidecar で置き換えないこと：STRICT の拒否を証明するのはまさに sidecar の不在である。<br/>• Checker はさらに BEFORE/AFTER を自分で繰り返す：同じ policy を一時的に `PERMISSIVE` に切り替え、同じ plaintext リクエストを繰り返して 200 を要求する - これにより、以前の拒否が、独立した DNS/network の問題ではなく、まさに STRICT mTLS によるものだったことを証明する<br/>• その後 checker が `STRICT` を復元する |

<details>
<summary>💡 課題 6 のヒント</summary>

Service port の名前は、まさに `http` でなければなりません (`market-api` やその他のものではなく) - Istio は、プロトコルを判定し sidecar を通じてトラフィックを正しく処理するために、named port convention を使用します。`market-client` は、namespace が `istio-injection=enabled` を受け取った後に作成します - Deployment がこの label より前に作成された場合、sidecar は自動的には追加されず、injection のために (Deployment ではなく) Pod を作り直す必要があります。
</details>

## 検証

```bash
check_result
```

チェックには `0 Init` と 6 個の必須テストが含まれます。テスト 1-3 は
`RuntimeClass`、placement、`uname` の実際の違いを確認します；テスト 4-5 は WireGuard の
status、ノード間のリクエスト、tcpdump に marker がないことを確認します；テスト 6 は両方の
mTLS の呼び出しをやり直し、成果物を確認します。Istio の Pods がまだ作成中の場合は、
injected な workload が `2/2 Running` になる `kubectl get pods -n market` まで待ってください。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=110 make delete_cks_task
```
