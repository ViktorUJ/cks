[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 109 - etcd での Secret の暗号化と最小限のアクセス

## 目的

この CKS 実習では、encryption at rest のない Kubernetes Secret が etcd に読み取り可能な bytes として保存されていること
(base64 は暗号化ではない) を実証し、`EncryptionConfiguration` を通じて `aescbc` を有効にし、
static `kube-apiserver` に接続し、古い Secret を書き直し、
RBAC と `automountServiceAccountToken` でデータへのアクセスを制限します。

`aescbc` がここで選ばれているのは、試験での `EncryptionConfiguration` と re-encryption の
手順を練習するためだけです。現在の Kubernetes のドキュメントは AES-CBC を弱いものとみなし、
padding-oracle 攻撃のリスクのため推奨していません；`aesgcm` も自動化された鍵のローテーションを必要とします。
production では、最新のドキュメントと threat model に従って provider を選択してください；外部の key manager がある場合は KMS v2 が望ましいです
([第 21 章](../../course/21/jp.md) を参照)。

## Threat model

Encryption at rest は storage compromise から守ります：攻撃者が、たとえば backup や volume snapshot を通じて、etcd の snapshot または storage layer への read-only アクセスを得たが、認可された API アクセスは持っていないと仮定します。課題 1 は、まさにこの初期のリスクを、etcd の raw 読み取りによって実証します。

encryption at rest を有効にした後、課題 2-4 は、そのようなアクセスの blast radius を減らします：直接読み取られたデータが Secret を明らかにしてはなりません。これは万能の防御ではなく、API へのアクセス制御の代わりでもありません。

攻撃者が Secret を読み取る権限を持つ正当な API アクセスを持っている場合、encryption at rest はこの脅威からは守ってくれません：API は復号後の値を返します。そのため、課題 5 では RBAC と automount を別途制限し、そのような権限を持つ workload の identity の blast radius を減らします。

## 開始前のセルフチェック

<details>
<summary>1. `Secret.data` の base64 が暗号化ではないのはなぜか？</summary>

base64 は単なるエンコーディングで、鍵なしで元に戻せます：バイト列自体にアクセスできる人は誰でも (たとえば etcd の raw 読み取りを通じて)、暗号操作なしで値を即座にデコードできます。暗号化には元に戻すための鍵が必要です - base64 にはその性質がまったくありません。
</details>

<details>
<summary>2. `identity` provider が、最初ではなく providers のリストの最後に置かれる必要があるのはなぜか？</summary>

`EncryptionConfiguration` の providers は、既存のレコードの読み取りのために順番に試され、最初の provider が新しいデータの書き込みに使われます。`identity` (つまり「暗号化なし」) が最初にあると、リストに `aescbc` があっても、すべての新しいレコードが暗号化されないまま書き込まれます。`identity` を最後に置けば、古い (まだ移行されていない) plaintext のレコードを読み取れる一方、すべての新しいレコードが最初の provider によって暗号化されることが保証されます。
</details>

<details>
<summary>3. 新しい暗号化鍵を追加した直後に、古い鍵を単純に削除してはいけないのはなぜか？</summary>

etcd の既存のレコードは、明示的に書き直される (re-encryption) までは古い鍵で暗号化されたままです。すべてのレコードが新しい鍵で書き直される前に古い鍵を active な `EncryptionConfiguration` から外すと、API server は現在の provider chain で残っている古いレコードを復号できなくなり、それらのレコードは古い鍵が設定に戻されるまで読み取れなくなります。設定から鍵を削除しても、key material が物理的に破壊されるわけではありません：保存しておいた古い鍵を provider chain に再び追加すれば、アクセスは回復します。データの不可逆的な喪失が起こるのは、key material 自体が本当に失われた、または破壊された場合のみです (たとえば、削除する前に鍵がどこにも保存されていなかった場合)。順序：新しい鍵を最初に追加 → すべての Secret を書き直す → すべてのレコードが新しい鍵を使っていることを確認 → rollback のために古い鍵を安全な場所に保存 → その後で初めて設定から外す。
</details>

## インフラ

環境は Terragrunt により AWS `eu-central-1` に展開されます：

| コンポーネント | 用途 |
|---|---|
| `vpc` | パブリックサブネットを持つ VPC `10.10.0.0/16` |
| `ssh-keys` | worker と control-plane 用の SSH キー |
| `k8s-1` | シングルノードの kubeadm control-plane：Kubernetes **1.36.0**、containerd、**Calico** |
| `worker` | `kubectl` を備えた作業マシン；control-plane (`ssh control-plane`) には、試験と同じ標準の `etcdctl` 3.6.0 がインストールされている |

Control-plane は意図的に通常の Pod を受け付けます - 別の Kubernetes worker は作成されません。
課題の開始前に、bootstrap が namespace `encryption-109` と無害な
`legacy-secret` を作成します。この Secret は EncryptionConfiguration の**前に**作成されているため、
plaintext の状態の制御された証明として機能します。

ノードに対する操作は、試験と同様に control-plane 自体で行います：そこに入り
(`ssh control-plane`)、そこで作業して、抜けます (`exit`)；`kubectl` は作業マシンから実行します。etcd の raw レコードは、
kubeadm の証明書 `/etc/kubernetes/pki/etcd/` (`ca.crt`、`server.crt`、`server.key`) を使って、Kubernetes のドキュメントにある標準の `etcdctl` で
読み取ります。コマンドの用意された例は、
参考解答の「ドキュメントで例を見つける場所」セクションにあります。

## デプロイ

```bash
TASK=109 make run_cks_task
```

作業マシンに接続します。コンテキスト `cluster1-admin@cluster1` はすでに設定されています。

```bash
time_left
check_result
```

## 課題

---
| **1** | **Secret の初期の plaintext を実証する** |
| :---: | :--- |
| やること | • 暗号化を有効にする前に、raw レコード `/registry/secrets/encryption-109/legacy-secret` を標準の `etcdctl get ... --print-value-only` で取得します<br/>• control-plane に入り (`ssh control-plane`)、試験と同様にそこで作業します：出力を `strings` に通し、結果を control-plane 上のファイル (`/tmp/plaintext-proof.txt`) に保存して、`scp` コマンドで作業マシンの `/var/work/109/plaintext-proof.txt` にコピーします |
| 受け入れ基準 | • ファイルに、初期の raw レコードの `strings` の完全な出力が含まれ (marker `cks-109-legacy-plaintext` を含め、bootstrap のスナップショットと一致する)、`k8s:enc:` を含まない<br/>• 手で入力した文字列は受け付けられない<br/>• これは初期状態の証明である：`Secret.data` は base64 であり、encryption at rest ではない |

<details>
<summary>💡 課題 1 のヒント</summary>

この課題は課題 2 の前に最初に行う必要があります - EncryptionConfiguration を有効にして Secret を書き直すと、plaintext の証明は消え、後から記録することはできません。フラグ `--cacert/--cert/--key` を持つ `etcdctl` のコマンドは、Kubernetes の公式ドキュメント (ページ Encrypting Confidential Data at Rest の「Verify that newly written data is encrypted」セクション) から取ります；kubeadm の証明書のパス：`/etc/kubernetes/pki/etcd/ca.crt`、`server.crt`、`server.key`。正確なリンクは、参考解答の「ドキュメントで例を見つける場所」セクションにあります。
</details>

---
| **2** | **Secret 用の EncryptionConfiguration を作成する** |
| :---: | :--- |
| やること | • control-plane で `/etc/kubernetes/enc/encryption-config.yaml` を、owner `root:root`、mode `0600` で作成します<br/>• 形式：`apiserver.config.k8s.io/v1`、`EncryptionConfiguration`<br/>• `secrets` に対して、最初の provider として、**ランダムな 32 bytes** の名前付き base64 鍵を持つ `aescbc` を設定し、続いて `identity: {}` を設定します |
| 受け入れ基準 | • ファイルが `root:root` mode `0600` で、ディレクトリが `root:root` mode `0700` である<br/>• `secrets` の主な有効な provider が、32 bytes の正しい named base64 鍵を持つ**最初の** `aescbc` である<br/>• `identity` は、legacy plaintext のための一時的な fallback として最後にのみ許容される<br/>• ファイル/ディレクトリへの symlink は禁止 |

<details>
<summary>💡 課題 2 のヒント</summary>

鍵は `head -c 32 /dev/urandom | base64` で生成してください - まさに 32 バイトです (32 文字の base64 文字列ではありません。エンコーディングにより長くなります)。自己確認してください：`echo -n "<あなたの-base64-鍵>" | base64 -d | wc -c` はちょうど `32` を返す必要があります。
</details>

---
| **3** | **config を static kube-apiserver に接続する** |
| :---: | :--- |
| やること | • `/etc/kubernetes/manifests/kube-apiserver.yaml` を慎重に変更します：flag `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`、read-only の `volumeMount` `/etc/kubernetes/enc`、および対応する `hostPath` volume `/etc/kubernetes/enc` を追加します<br/>• 編集の前に manifest の backup を保存します |
| 受け入れ基準 | • 稼働中の manifest に flag、mount、hostPath が含まれている<br/>• static Pod の restart の後、`kubectl get --raw='/readyz'` が `ok` を返す |

<details>
<summary>💡 課題 3 のヒント</summary>

3 つの個別の変更が同時に必要です：フラグ `--encryption-provider-config` 自体、`volumeMounts` (コンテナ内) と `volumes` (Pod spec レベルの hostPath) - 3 つのうちどれかを忘れると、CrashLoopBackOff (フラグがコンテナから見えないファイルを指している) になるか、単にフラグが渡されないことになります。backup は `/etc/kubernetes/manifests` の**外**に保存してください。たとえば `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`。Kubelet は static manifests のディレクトリにある隠しファイルではない追加のファイルを読み取ります；隣にある `kube-apiserver.yaml.bak` が 2 つ目の static Pod と見なされ、新しい設定の適用を妨げる可能性があります。
</details>

---
| **4** | **Re-encrypt して ciphertext を実証する** |
| :---: | :--- |
| やること | • API server の準備ができた後、`encryption-109` に literal `token=cks-109-fresh-ciphertext` を持つ Secret `encrypted-secret` を作成します<br/>• 以前に存在していたすべての Secret を API 経由で書き直します (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)<br/>• 両方の Secret を API と raw etcd で確認します<br/>• この確認の後にのみ、一時的な `identity` fallback を削除し、static kube-apiserver を再起動して、`/readyz` と両方の Secret の読み取りを再び確認します |
| 受け入れ基準 | • `legacy-secret` と `encrypted-secret` が、元の値で API 経由で読み取れる<br/>• それぞれの raw value が `k8s:enc:aescbc:v1:` で始まる<br/>• Legacy marker が raw etcd にもう見えない<br/>• bootstrap の Secret 全体の元の payload/UID が保持されており、すべてのレコードが最初の有効な鍵で暗号化されている<br/>• 最終ファイルの鍵が、両方の canary Secret の ciphertext を復号できる<br/>• 最終的な設定に `identity` がなく、API が healthy である |

<details>
<summary>💡 課題 4 のヒント</summary>

順序が重要です：`encrypted-secret` を作成 → `kubectl replace` で既存のすべての Secret を書き直す → 両方 (legacy と encrypted) の raw etcd を確認 → その後でのみ設定から `identity` を外す。`legacy-secret` が書き直される前に `identity` を外すと、API server は provider chain 経由で古い plaintext のレコードをもう読み取れず、`legacy-secret` は利用できなくなります。
</details>

---
| **5** | **RBAC を最小化し、automount を無効にする** |
| :---: | :--- |
| やること | • `encryption-109` に、`automountServiceAccountToken: false` を持つ ServiceAccount `secret-reader` を作成します<br/>• Role `secret-reader-109` は、Secret `encrypted-secret` のみに対する `get` だけを与える必要があります<br/>• それを同名の RoleBinding で紐づけます<br/>• この ServiceAccount を使う、`automountServiceAccountToken: false`、イメージ `registry.k8s.io/pause:3.10` の Pod `secret-reader-109` を作成します |
| 受け入れ基準 | • ServiceAccount の標準のグループを含む effective な RBAC が、`encryption-109` の `get encrypted-secret` を許可し、他の Secret 操作 (他の namespace の Secret へのアクセスを含む) を禁止している<br/>• Role/RoleBinding が正確である<br/>• Pod が、1 つの `pause:3.10` で Running であり、自動または手動でマウントされた ServiceAccount token や、その他の credential を持つソース (Secret/hostPath/CSI/PVC volumes、Secret env/envFrom) がない<br/>• 無害な emptyDir/ConfigMap volumes は許容される<br/>• Pod と ServiceAccount の両方で `automountServiceAccountToken: false` |

<details>
<summary>💡 課題 5 のヒント</summary>

Role で `resourceNames: ["encrypted-secret"]` を使用してください - このフィールドがないと、リソース `secrets` に対する `get`/`list` は、`legacy-secret` を含む namespace のすべての Secret へのアクセスを与え、least-privilege の要件に反します。`pause:3.10` は Kubernetes API をまったく必要としないダミーのイメージ なので、automount は 2 つのレベル (SA と Pod) で、機能への影響なしに無効にされます。
</details>

## 検証

```bash
check_result
```

チェックには Init と 5 個の必須テストが含まれます。テスト 4 は、設定ファイルの存在だけでなく、新しい etcd レコードと以前の
etcd レコードの実際の ciphertext `k8s:enc:aescbc:v1:` と、最終的な設定に migration 専用の `identity` がないことを確認します。実際の環境での大量の re-encryption の前には、snapshot、鍵の
ローテーション計画、管理されたメンテナンスウィンドウが必要です；この実習は production の runbook ではありません。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)

## 削除

```bash
TASK=109 make delete_cks_task
```

## 追加：KMS v2 と鍵ローテーションの完全なライフサイクル

**KMS v2 (オプションの walkthrough)。** 外部の KMS-plugin は、`EncryptionConfiguration` の
provider `kms` として API server に接続されます；その endpoint はローカルの Unix socket で、provider の鍵には
安定した名前が付けられます。たとえば `kms-v2-primary`。KMS v2 では、API server は plugin を通じて暗号化された seed (外部の
**KEK** でラップされたもの) を受け取り、それに基づいて個々のオブジェクトを暗号化するための鍵を導出します。KMS v2 は
API server のレベルで seed/DEK を使用し、各 Secret ごとに KMS を個別に呼び出すわけではありません。
etcd には、Secret の ciphertext と鍵の復元に必要なデータが保存されます。したがって KEK は etcd にはありません；KMS の可用性、ACL、backup は
セキュリティモデルの一部になります。最小限の**例示用の** provider (endpoint は
インストールされた plugin に対応している必要があります) は次のようになります：

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

新しいレコード用に provider を最初に追加し、socket を static `kube-apiserver` にマウントして、
re-encryption の前に plugin の health を待ちます。実際の構成では、
サポートされている plugin と、使用している Kubernetes のバージョンのドキュメントにある最新の `kms` v2 の形式を使用してください；
この実習は KMS-plugin を立ち上げず、動作する socket も提供しません。

**provider の鍵の完全なローテーション。** 課題 4 で行った plaintext から最初の
`aescbc` 鍵への移行は、完全な鍵のローテーションではありません。完全なローテーションの手順：(1) 保護された etcd snapshot を作成し、
古い鍵が保存されていて rollback のために利用できることを確認する；(2) 新しい鍵を
`aescbc.keys` の先頭に追加し、古い鍵を 2 番目に残して、API server を再起動する；(3)
新しい最初の鍵で暗号化されるように、既存の Secret を API 経由で書き直す；
(4) 抜き取りで、そして次にすべての raw etcd レコードで、プレフィックス
`k8s:enc:aescbc:v1:<新しい鍵の名前>:` を確認する；(5) 完全な移行、backup、
読み取りの確認が終わった後にのみ、古い鍵を削除し、API server を再起動して、`/readyz`
と Secret を再び確認する。KMS v2 では、これと同等に、まず primary の KEK/plugin を切り替え、
re-encryption を行い、その後で初めて古い KEK を KMS の手順に従って使用から外します。
