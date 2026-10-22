[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 111 - image の分析、静的な修正、supply-chain evidence

## 目的

この CKS 実習では、コンテナアプリケーションについて、再現可能な evidence の成果物を集めます：
脆弱性レポートと静的アナライザーのレポート、`Dockerfile` と workload の manifest の安全な修正、
2 つの SBOM、依存関係のバージョンの検索、image の署名の検証です。成果は
単なるターミナルの出力ではありません：各レポートは指定された場所に保存され、
監査に使える状態でなければなりません。

これは security tooling と supply chain に関する CKS の課題であり、CKA の演習ではありません。成果物の大半は
worker 上でローカルに分析されます；クラスターを追加で使用するのは、課題 1c、4、5b、9a-9c です (live な Deployment、Ready/Available と HTTP の smoke test を確認する hardened な Deployment、Kyverno の policy と Pod)。

## Threat model

この実習は、いくつかの独立した脅威を通じて supply chain への信頼をモデル化します。悪意のある
コードや image に含まれる既知の脆弱性は、image、Dockerfile、manifest のそれぞれのレベルで、スキャナー Trivy、kubesec、
kube-linter、Hadolint によって検出されます。

layer に誤って残された secret や token には、別の確認が必要です：secret
scanning (たとえば Trivy の secret scanning) と、image の history の確認 (`docker history`、
layer の抽出) です。SBOM は別の目的に対応します - コンポーネントとパッケージのバージョンの棚卸しです；
supply-chain の調査 (たとえば脆弱なライブラリを見つける) には役立ちますが、
layer の history から secret を見つけるための信頼できる仕組みではなく、secret
scanning の代わりにもなりません。稼働中の設定にもう secret が含まれていなくても、
layer の history には残っている可能性があります。

mutable-tag tampering の脅威とは、デプロイ後に、変更されていないタグ付きの参照のもとで、
別の悪意のある image を差し替えられることです。だからこそ digest pinning は
課題 3-5 で重要です：これは image の名前とタグだけでなく、image の具体的な内容を固定します。

課題 7 の署名の検証は、特定の digest が信頼された
key/identity によって署名されている (signature integrity) ことを証明します。一方、課題 1 の Trivy scan が示すのは、現在の vulnerability DB の下で
その detection coverage に入る既知の脆弱性が検出されなかったことです
(Trivy 自身が、precision を優先する trade-off を文書化しており、false
negatives がありえます - 「0 findings」は脆弱性がないことの formal proof ではありません)。これらは別の
防御の軸です：どちらも他方の代わりにはなりません。脆弱性と署名は別のものだからです。署名は
provenance/attestation
(たとえば、artifact が何からどのように構築されたかについての SLSA 形式の build metadata) と同じでは**ありません**：`cosign
verify` は署名の真正性を確認するのであって、ビルドの完全な履歴ではありません - attestation には
Sigstore が別のコマンド `cosign attest`/`cosign verify-attestation` を提供しており、この実習では
使用しません。

ローカルの `cosign verify` (課題 7) 自体は enforcement ではありません：それは、確認の時点での特定の image reference の
署名を証明しますが、CI を迂回して、署名されていない、あるいは別の方法で署名された image を、直接の `kubectl apply` で起動することは
妨げません。admission-time の確認 (課題 9a-9c) だけが、署名を Pod のクラスターへの
受け入れの必須条件にします - これが、「署名を確認した」と「クラスターは署名されていない
image を起動しない」の違いです。

この性質を実証するには注意が必要です：すでに存在する Deployment を再度 `kubectl apply` しても、template が変わっていなければ新しい Pod は作成されないため、
`Running` は、「policy がまさにこの image を許可した」ではなく、「policy の前に作成された古い Pod」を
意味する可能性があります (課題 9b は `creationTimestamp` を明示的に確認します)。同様に、署名のない
DENY が性質を証明するのは、確認する digest が、署名された image と同じ repository に
実際に存在し pullable である場合だけです (課題 9c) - そうでなければ、admission は署名がないからではなく、
registry に manifest がないことを理由に拒否するかもしれません。

## 開始前のセルフチェック

<details>
<summary>1. SBOM が、image layer に残された secret を見つけるための信頼できる仕組みではないのはなぜか？</summary>

SBOM が解決するのは、コンポーネントとパッケージのバージョンの棚卸し (何がインストールされていて、どのバージョンか) です - これはパッケージマネージャーのメタデータの構造的な分析であり、layer のファイルの内容にある任意の文字列/secret を探すものではありません。たとえば、ビルド中に環境変数 ENV や一時ファイルに残された secret は、最終的な layer に含まれなくなった後でも layer の history に残る可能性があります - それには SBOM ではなく、別のツール (secret scanning、`docker history`、layer の抽出) が必要です。
</details>

<details>
<summary>2. Trivy scan (課題 1) が証明することと、Cosign の署名 (課題 9a-9c) が証明することの違いは何か？</summary>

確認の時点で、現在の vulnerability DB と Trivy の検出ロジックの下では、スキャンは、その detection coverage に入る既知の脆弱性を検出しませんでした - これは、Trivy が見ることのできる範囲での image の内容の品質/安全性についてのものです。Trivy のドキュメント自体が、precision (false positives の最小化) を優先する trade-off を明示しており、false negatives がありえます - つまり「0 findings」は、脆弱性が完全にないことの formal な証明と同等ではありません。Cosign の署名が証明するのは signature integrity です - 特定の digest が信頼された鍵/identity によって署名されている、つまり権限のある誰かが、それがまさにデプロイされるべき artifact であることを確認した、ということです。これは provenance/attestation (完全なビルドの履歴 - 何から、誰によって、どのように artifact が構築されたか) と同じでは**ありません**：attestation には Sigstore に別のコマンド (`cosign attest`/`cosign verify-attestation`) があり、この実習では使いません。image は完全に安全 (0 CVE) でありながら署名されていないことも、署名されていながら未知の脆弱性を含むこともあります。これらは 2 つの独立した防御の軸です。
</details>

<details>
<summary>3. CI でのローカルの `cosign verify` が、誰かが署名されていない image を `kubectl apply` でデプロイすることを妨げないのはなぜか？</summary>

ローカル (たとえば CI pipeline) で実行される `cosign verify` は、署名を確認してその結果を呼び出した人に返す、単なる 1 つのコマンドです。これは Kubernetes API の admission の経路には組み込まれていません - クラスターにアクセスできる誰かが、CI を完全に迂回して、任意の image で単に `kubectl apply` を実行することを妨げるものは何もありません。クラスター自体に policy として組み込まれた admission-time の確認 (課題 9a-9c) だけが、署名を受け入れの**必須の**条件にします - これが「確認した」と「クラスターが物理的に通さない」の違いです。
</details>

## インフラ

環境は Terragrunt により AWS `eu-central-1` に作成されます。

| コンポーネント | 用途 |
|---|---|
| `vpc` | パブリックサブネットを持つ VPC `10.111.0.0/16` |
| `ssh-keys` | ノードへのアクセス |
| `k8s-1` | シングルノードの kubeadm Kubernetes `1.36.0`、containerd、**Calico** |
| `worker` | 分析用のワークステーション、`kubectl`、`check_result`、security tools |

インフラは CKA スタイルです：唯一の control-plane ノードで workload が許可されており、
`cks.io/lab=111` が付けられています。主なコマンドと security tools は worker で実行します。
Kubernetes クラスターは、hardened な workload と admission-time の署名 policy を確認するための target environment として使用されます：
課題 4 が `catalog` をデプロイし、課題 9b/9c が positive/negative の admission プローブを実行します。

worker では、次の固定されたバージョンがあらかじめ利用できます：

| ツール | バージョン | 用途 |
|---|---:|---|
| Trivy | `0.74.0` | image の CVE とパッケージの一覧 |
| kubesec | `2.14.0` | Kubernetes YAML の security score |
| kube-linter | `0.8.3` | Kubernetes YAML の policy lint |
| Hadolint | `2.12.0` | Dockerfile の lint |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON (`bom` のネイティブ形式) |
| Cosign | `3.1.3` | OCI image の署名の signing と verification |

Helm と `install-kyverno` も worker で利用できますが、Kyverno は意図的に**インストールされていません**：
そのインストールは、実習 108 と同様に、課題 9 の一部です。`install-kyverno` は Kyverno
`1.19`/chart `3.9.0` を固定します；upstream の公式 support matrix では、このバージョンは Kubernetes
`1.33-1.35` ですが、このクラスターは `1.36` です。これはテストされた範囲の外にある、意識的な lab 固有の例外であり
(実習 108 の前例と同様)、公式のサポートが保証されているわけではありません - Kyverno を更新するときは、この例外を解除してください。

## 前提条件と制約

**podman と registry は環境にすでに設定されています。** image のビルドと公開には `podman` を使用してください
(試験のリストにあるツール；rootless で、ユーザー `ubuntu` として)。課題 3 と 9c では、worker からもクラスターからも
アクセスできる registry に image をビルドして**公開**する必要があります (immutable な参照
`repo@sha256:...` は registry から取得され、ローカルの image ID は使えません)。そのような registry -
control-plane 上の `registry:2` - は bootstrap によって立ち上げられています：

- アドレス：`<IP control-plane>:5000`、worker の `/etc/cks111/registry` に記録されています；
- プロトコルは VPC 内の通常の HTTP です：worker の podman とノードの containerd は、これを
  insecure registry として設定済みで (フラグ `--tls-verify=false` は不要です)、Kyverno の `ImageValidatingPolicy` には
  `credentials.allowInsecureRegistry: true` が必要です；
- データはノードのローカル PV (`/var/lib/cks111-registry`) に保存されるため、registry の Pod の
  再起動後も保持されます；
- 公開した image の digest は `podman push --digestfile` から取得し、manifest の存在は
  `/v2/` へのリクエストで確認してください (この registry には `docker buildx imagetools` のような HTTPS 専用のツールは使えません)；
- コマンドの詳細な手順は、[解答](worker/files/solutions/1_JP.MD)のステップ「0. 準備」にあります。

**Docker Hub の制限。** 同じ IP からの匿名の pull には制限があります (6 時間で約 100 リクエスト)。
`check_result` がそれに当たらないよう、bootstrap は実習の image を一度ローカルキャッシュにダウンロードし
(`nginx:1.27.3-alpine` と課題 1b/1c の候補)、Trivy と Syft は再スキャン時に、同じ参照 `名前@sha256:...` で
このキャッシュから image を取得し、Docker Hub にはアクセスしません。`bom` は registry からしか image を
読み取れないため、起動ごとにいくつかのリクエストを行います。
それでも Docker Hub が `TOOMANYREQUESTS` を返した場合は、待つ (制限のウィンドウはスライディングです) か、
自分のアカウントで `podman login docker.io` を実行してください。

**Cosign と鍵のパスワード。** `cosign generate-key-pair` と `cosign sign --key` は鍵の
パスワードを尋ねます；学習用のペアでは空のままにでき (`export COSIGN_PASSWORD=""`)、
コマンドが入力待ちにならないようにできます。

**`trivy sbom` と OS のない SBOM (課題 8)。** multi-arch image についての `bom` の SPDX には、
OS の情報が含まれません：Trivy は `Detected OS family="none"` と出力し、脆弱性を検出しません (`Results` が空)。
そのため課題 8 では、課題 7 の CycloneDX をスキャンします - そこには `operating-system` コンポーネントがあり、
`trivy sbom` は空でない `Results` を返します。

## デプロイ

```bash
TASK=111 make run_cks_task
```

worker に接続し、コンテキストを選択します：

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

初期状態では、`Dockerfile` と `deployment.yaml` は意図的に安全ではありません。作業用の成果物は
`/var/work/tests/artifacts/<番号>/` にのみ作成してください。

## 課題

`nginx:1.27.3-alpine` は mutable tag であり、固定された参照ではありません。まず、Trivy JSON の `Metadata.RepoDigests[0]` から正規の registry manifest digest を取得し、immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (以下 `$IMAGE`) を使用してください。独自の hardened image については、まず image をクラスターから利用できる registry にビルドして公開し、次にその manifest digest を使用します；ローカルの image ID と layer の DiffID は registry の manifest digest ではありません。

---
| **1** | **Trivy: image の脆弱性レポート** |
| :---: | :--- |
| やること | • immutable な `$IMAGE` を、OS と library の脆弱性を含めて Trivy でスキャンします。<br/>• 構造化された JSON を `/var/work/tests/artifacts/1/trivy-report.json` に保存します。 |
| 受け入れ基準 | • **ファイル：** 空でなく、JSON が `jq` で解析でき、`Results` と、分析対象の image の immutable reference が含まれている。<br/>• **新規の確認：** checker が同じ image に対して `trivy image` を自分で繰り返し、この新しいスキャンが `ArtifactName` で一致して成功することを要求する。<br/>• 手書きで、構文的には有効な JSON は通らない。 |

<details>
<summary>💡 課題 1 のヒント</summary>

`$IMAGE` は 2 段階で作ります：まず `nginx:1.27.3-alpine` (通常の tag) をスキャンし、**この**最初の JSON レポートから `Metadata.RepoDigests[0]` を取り出し、次に `nginx:1.27.3-alpine@sha256:<digest>` でコマンドを組み直して、immutable な参照をスキャンします - この 2 つ目のレポートを最終版として保存する必要があります。Trivy の出力の `ImageID`/`DiffID` を registry の digest の代わりに使わないでください - これらは**ローカルな**識別子で、registry の manifest digest とは一致しません。
</details>

---
| **1b** | **Multi-image CVE triage: 特定の CVE を含む image を見つける** |
| :---: | :--- |
| やること | • `~/cks-111/candidates.txt` を開きます - そこには、実習の bootstrap 時に、あなたの実習のインスタンスごとに個別に決められた、3 つの immutable な image reference (`CANDIDATE_1/2/3`) と、目的の `TARGET_CVE` があります。<br/>• **3 つすべての** image を Trivy でスキャンし、どれが実際に `TARGET_CVE` を含んでいるかを見つけます。<br/>• まさにその image の JSON レポートを `/var/work/tests/artifacts/1b/target-scan.json` に保存します。<br/>• 行 `OFFENDING_IMAGE=<この image の完全な参照>` を `/var/work/tests/artifacts/1b/answer.txt` に保存します。 |
| 受け入れ基準 | • **答え：** `answer.txt` が、実際の Trivy スキャンに `TARGET_CVE` が含まれる `CANDIDATE_N` をまさに指している。<br/>• **レポート：** `target-scan.json` が、同じ image についての本物の Trivy の出力である (checker 自身がスキャンを繰り返して比較する)。 |

<details>
<summary>💡 課題 1b のヒント</summary>

`TARGET_CVE` は実習のインスタンスごとに異なります - 事前に埋め込まれているのではなく、provisioning 時に live の Trivy vulnerability DB から計算されるため、このファイルにはあなた自身の答えがあります。タグの名前から推測しないでください (「一番古いものがおそらく脆弱」) - 3 つすべてを実際にスキャンし、JSON の中の `VulnerabilityID` の正確な一致を見つけてください。image ごとに 1 つのコマンド：`trivy image --format json "$ref" | tee scan.json`、続いて `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json` - `null` はその特定の CVE がこの image にないことを意味します (他の CVE が含まれていても構いません - それは確認されません)。
</details>

---
| **1c** | **CRITICAL severity による workload image の triage** |
| :---: | :--- |
| やること | • namespace `cks-111` には、すでに 4 つの Deployment (label `cks.io/task=1c`) がデプロイされており、それぞれが 1 つの immutable な digest 固定の image を持っています。<br/>• これらの live な Deployments から image references を取得し (タグの名前から推測しないでください)、**4 つすべての** image を `--severity CRITICAL` で Trivy でスキャンし、それぞれの一意の CRITICAL `VulnerabilityID` の数を数えます。<br/>• CRITICAL の数が最も多い Deployment (「最も脆弱」) と、最も少ない 2 つの Deployment (「最も脆弱でない 2 つ」) を特定します。それらの名前を `/var/work/tests/artifacts/1c/ranking.txt` に `MOST_VULNERABLE=<deployment-name>`、`LEAST_VULNERABLE_1=<deployment-name>`、`LEAST_VULNERABLE_2=<deployment-name>` として書きます。<br/>• 最も脆弱な Deployment の image について、**まさに Trivy で** (`trivy image --format cyclonedx`) CycloneDX SBOM を `1c/cyclonedx.json` に生成します。<br/>• その後 remediate します：`replicas > 0` を最も脆弱でない 2 つの Deployment にのみ残し、残りの 2 つ (最も脆弱なものを含む) は `replicas: 0` にスケールします。 |
| 受け入れ基準 | • **Ranking:** checker が 4 つすべての live images の Trivy CRITICAL スキャンを自分で繰り返して ranking を再計算する - `ranking.txt` は、古い/推測したものではなく、この新しいスキャンと一致している必要がある。<br/>• **SBOM:** `cyclonedx.json` が、まさに Trivy による有効な CycloneDX ドキュメントであり、実際に最も脆弱な Deployment の image に関するものである。<br/>• **Remediation:** ちょうど 2 つの Deployment (新しいスキャンで最も脆弱でないもの) が `replicas > 0` を持ち、残りの 2 つは `replicas: 0` である。 |

<details>
<summary>💡 課題 1c のヒント</summary>

image references は `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...` のような形式のコマンドで取得してください - どの image が「新しい」か「安全」かを Deployment の名前から推測しようとしないでください。数えるためのコマンド：`trivy image --scanners vuln --severity CRITICAL --format json <ref>`、続いて `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`。CycloneDX には、まさに `trivy image --format cyclonedx --output <file> <ref>` を使用してください - Syft ではありません (Syft はすでに課題 7 で別の image に使われており、ここでは明示的に Trivy が求められています)。スケーリングは `kubectl scale deployment/<name> -n cks-111 --replicas=0` で行います (残すものには `--replicas=1`)。
</details>

---
| **2** | **静的解析の初期レポート** |
| :---: | :--- |
| やること | • 修正の前に (課題 3 の開始後はこれら 3 つのファイルのどれにも触れずに) 結果を保存します：Hadolint を `2/hadolint-before.txt` に、kubesec JSON を `2/kubesec-before.json` に、kube-linter JSON を `2/kube-linter-before.json` に。<br/>• これらは、元の初期の `Dockerfile`/`deployment.yaml` に対して直接実行してください。<br/>• レポートファイルでは `\|\| true` でエラーを隠さないでください：linter のゼロ以外の exit code は想定内です。 |
| 受け入れ基準 | • **成果物：** 3 つとも存在する；Hadolint に findings があり、kubesec に `scoring` があり、kube-linter がフィールド `Reports` と `Summary` を持つ有効な KubeLinter の JSON オブジェクトである；修正前は `Reports` に findings が含まれる。<br/>• **baseline との照合：** checker が、3 つの成果物すべての内容を、provisioning 時に、受講者に渡される前の元の初期ファイルに対して取得した独自の baseline と比較する。<br/>• 手書きで、構文的には有効なレポートは通らない。 |

<details>
<summary>💡 課題 2 のヒント</summary>

問題を検出したときの linter のゼロ以外の exit code は、想定される挙動であり、あなたのコマンドの誤りではありません。`set -e` でスクリプトが止まらないようにするためだけに呼び出しを `|| true` で包む場合は、コマンドの出力が、それでもファイルに保存され (`|| true` の前に `tee` やリダイレクトで)、失われないことを確認してください。
</details>

---
| **3** | **findings に従って Dockerfile を修正する** |
| :---: | :--- |
| やること | • `/home/ubuntu/cks-111/Dockerfile` を修正します：ベース image を immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` で固定します。<br/>• URL を持つ `ADD` を使用せず、token を `ENV` に保存せず、`sudo` をインストールしないでください。<br/>• 非特権の `USER` を追加します (uid が `0` ではない)。`COPY` を使用し、パッケージの再現可能なインストールは必要な場合にのみ行います。<br/>• ほかの命令の隣に `ARG CKS_SIGNATURE_TEST=signed` と `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` を追加します - これは、課題 9c で必要になる、ここで確認した security の性質を変えずに別の digest を保証するための、image の唯一の制御された差異の箇所です。<br/>• 修正後、Hadolint の成功した出力を `3/hadolint-after.txt` に保存します。 |
| 受け入れ基準 | • **Dockerfile:** `latest` がなく、remote の `ADD` が削除され、`API_TOKEN`/`TOKEN` が残っておらず、non-root の `USER` があり、`ARG CKS_SIGNATURE_TEST` と `LABEL cks.signature-test` がある。<br/>• **Hadolint:** 最終的な report に `DL3007`、`DL3013`、`DL3020`、`DL3045` が含まれない。 |

<details>
<summary>💡 課題 3 のヒント</summary>

`CKS_SIGNATURE_TEST` の `ARG`/`LABEL` は、現在の Hadolint の findings とは無関係に見えるかもしれません - これは意図的にここで事前に追加するもので、(ずっと後の) 課題 9c が、Dockerfile を再度書き換えることなく `--build-arg` で物理的に異なる image をビルドできるようにするためです。その有用性が 9c でしか分からなくても、今この 2 行を追加してください。
</details>

---
| **4** | **kubesec と kube-linter に従って workload の YAML を修正する** |
| :---: | :--- |
| やること | • まず課題 3 の hardened image をビルドして公開し、次に `deployment.yaml` にその immutable な manifest reference `registry/.../catalog@sha256:<manifest-digest>` を指定します (upstream の nginx ではありません)。<br/>• Pod レベルで `automountServiceAccountToken: false`、`runAsNonRoot: true`、`seccompProfile: RuntimeDefault` を追加します。<br/>• コンテナで `allowPrivilegeEscalation: false`、`readOnlyRootFilesystem: true`、`capabilities.drop: ["ALL"]`、CPU と memory の requests/limits を設定します。<br/>• nginx については、temp、pid/run、cache、config のパスに writable な `emptyDir`/tmpfs をマウントし、起動前に config を準備します。<br/>• `privileged` を削除し、Deployment を適用して、Ready/Available と成功した HTTP リクエストを確認します。<br/>• 新しいレポート `4/kubesec-after.json` と `4/kube-linter-after.json` を保存します。 |
| 受け入れ基準 | • **image:** YAML が、upstream の nginx ではなく、`USER 101` を持つ digest 固定の hardened image を使用している。<br/>• **manifest:** 必要なフィールド、init container `prepare-nginx-config`、writable な mounts が存在する；`privileged` がない。<br/>• **動作：** Deployment が Available で、HTTP リクエストが成功する。<br/>• **レポート：** 最終的な 2 つのレポートがどちらも有効な JSON である。 |

<details>
<summary>💡 課題 4 のヒント</summary>

`readOnlyRootFilesystem: true` では、nginx が通常書き込むすべてのディレクトリに writable なパスが必要です：`/tmp`、`/var/run` (PID ファイル)、`/var/cache/nginx` (キャッシュ)、`/etc/nginx/conf.d` (config が起動時に生成される場合)。1 つでも抜かすと、コンテナは起動しても、nginx が最初にそこへ何かを書き込もうとしたときに落ちます。Init container `prepare-nginx-config` は、メインのコンテナが起動する前に、デフォルトの config を別の writable volume にコピーするために必要です - だからこそ、受け入れ基準で別途言及されています。
</details>

---
| **5** | **パッケージのバージョンの検索** |
| :---: | :--- |
| やること | • `$IMAGE` に対して、Trivy をすべてのパッケージの一覧モードで使用します。<br/>• コマンド、immutable な image reference、`Metadata.RepoDigests[0]` からの正規の `nginx@sha256:<manifest-digest>`、そして少なくとも 3 行の `名前=バージョン` を `/var/work/tests/artifacts/5/version-search.txt` に保存します。<br/>• 検索を手作業のリストで代用しないでください：evidence には、`trivy image --list-all-pkgs` を含むコマンドの行が含まれている必要があります。 |
| 受け入れ基準 | • **成果物：** コマンド、immutable な `nginx:1.27.3-alpine@sha256:...`、Trivy からの `repo_digest=nginx@sha256:...`、そして少なくとも 3 組の package/version が含まれている。<br/>• **新規の確認：** checker が同じ image に対して `trivy image --list-all-pkgs` を自分で繰り返し、`repo_digest=` と、保存された少なくとも 3 組の `name=version` が、この新しいスキャンと一致することを要求する。<br/>• 手書きで、構文的にはもっともらしいリストは通らない。 |

<details>
<summary>💡 課題 5 のヒント</summary>

フラグの名前はまさに `--list-all-pkgs` であり、`--list-packages` や似たものではありません - コマンドが動作しない場合は、`trivy image --help` でフラグの正確な名前を確認してください。コマンドの実際の出力をファイルに保存してください (たとえば `tee` で)。いくつかの package=version の行を「記憶で」手で書き直さないでください - テストは、データがツールから来たことの証明として、コマンド自体の行を探します。
</details>

---
| **5b** | **workload の image でパッケージのバージョンを見つけ、問題のあるコンテナを削除する** |
| :---: | :--- |
| やること | • namespace `cks-111` には、すでに 3 つのコンテナ (`c1`、`c2`、`c3`) を持つ Deployment `pkg-audit-app` がデプロイされており、それぞれが独自の immutable な digest 固定の image を使っています。<br/>• 3 つの image のうち、ちょうど 2 つに、特定のバージョンの同じパッケージが存在します - あなたの実習のインスタンスについての `TARGET_PACKAGE`/`TARGET_VERSION` は provisioning 時に動的に決められ、埋め込まれた値はありません。<br/>• live の Deployment から 3 つの image references をすべて取得し、それぞれに `bom generate` を実行します (各 SBOM は `/var/work/tests/artifacts/5b/bom/` に別々に保存してください)。<br/>• どの 2 つのコンテナが実際に同じ package/version を含んでいるかを特定し、見つけた組を `5b/answer.txt` に `TARGET_PACKAGE=<name>` と `TARGET_VERSION=<version>` として書きます。<br/>• まさにこの 2 つの問題のあるコンテナを Deployment から削除し (`kubectl edit`/修正した manifest の `kubectl apply` で)、「クリーンな」コンテナだけが残り、Deployment が `Available` のままであるようにします。 |
| 受け入れ基準 | • **答え：** `answer.txt` が、元の 3 つの image のうちちょうど 2 つに存在する実際の package/version を挙げている (推測ではない)。この 2 つの image には共通のパッケージが多数ある：3 つ目の image にない任意の 1 組の `name=version` でよい。<br/>• **SBOM:** `5b/bom/` に、この発見を裏付ける本物の `bom generate` の出力が少なくとも 1 つある。<br/>• **独立した確認：** checker が、元の candidate images (provisioning 時に保存されたもの) に対して独立に `bom generate` を実行し、あなたの答えをこの独立した実行と照合する。<br/>• **Deployment:** 最終的な Deployment に「クリーンな」コンテナだけが含まれ、`Available` のままである。 |

<details>
<summary>💡 課題 5b のヒント</summary>

コマンドは、3 つの image references のそれぞれに対して個別に `bom generate --format json --output <file> --image <ref>` です。SBOM を 2 つずつ比較してください：同じ `name`/`versionInfo` の組が 2 つのコンテナの SBOM にあり、3 つ目には存在しない (または別のバージョンである) 場合、そのパッケージは「問題あり」とみなされます。image の名前/タグから推測しようとしないでください - 一部の image の組は「似ている」ように見えても、パッケージの実際の一致は、実際の SBOM の比較によってのみ決まります。Deployment を編集するときは、image を変更するだけでなく、`spec.template.spec.containers` からコンテナ全体を削除してください。
</details>

---
| **6** | **bom による SPDX SBOM** |
| :---: | :--- |
| やること | • immutable な `$IMAGE` (課題 1 で使ったのと同じ `tag@digest` で、bare tag の `nginx:1.27.3-alpine` ではありません) に対して、ツール `bom` で SPDX JSON SBOM を生成します；`/var/work/tests/artifacts/6/bom.spdx.json` に保存します。<br/>• ファイル `6/bom-command.txt` に、正確な `--image $IMAGE` を持つ、実行したコマンドを書きます。 |
| 受け入れ基準 | • **SBOM:** 有効な JSON で、`spdxVersion` を持ち、配列 `packages` を含む；`documentDescribes` が参照する top-level パッケージの 1 つが、課題 1 の `$IMAGE` と**同じ** manifest digest を (`versionInfo`/`name` を通じて) 識別している。<br/>• **コマンド：** `bom-command.txt` に正確な immutable な `$IMAGE` が含まれ、`bom generate` を使っている。<br/>• 別の image (課題 1 の `$IMAGE` とは無関係なもの) の SBOM は、`bom-command.txt` が偽造されていても通らない。<br/>• **新規の確認：** checker がさらに、同じ image について同じ `bom` で SBOM を自分で再生成し、あなたの SBOM のパッケージの集合 (`name`/`versionInfo`) が、この新しい実行と一致することを要求する - top-level パッケージが 1 つだけの、最小限の手書きの SPDX ドキュメントは通らない。 |

<details>
<summary>💡 課題 6 のヒント</summary>

コマンド `bom generate -o <output.json> -i <image>` - 出力ファイルを指定するために必ずフラグ `-o` を付けてください。そうしないと出力は stdout に行きます。`bom` の出力形式は、その独自の SPDX JSON であり、Syft が生成できる SPDX とは細部が異なります - 標準の同じ形式を生成する際に、これら 2 つの異なるツールを混同しないでください。
</details>

---
| **7** | **Syft による CycloneDX SBOM と Cosign の検証** |
| :---: | :--- |
| やること | • 課題 1 と同じ immutable な `$IMAGE` (`nginx:1.27.3-alpine@sha256:<manifest-digest>`) に対して、Syft で CycloneDX JSON SBOM を生成し、`7/syft.cdx.json` に保存します。<br/>• 次に、公開 image `gcr.io/distroless/static-debian13:nonroot` の署名を keyless の Cosign で確認し、成功した完全な出力を `7/cosign-verify.txt` に保存します。<br/>• Distroless には issuer `https://accounts.google.com` と identity `keyless@distroless.iam.gserviceaccount.com` を使用します。 |
| 受け入れ基準 | • **Syft SBOM:** `bomFormat: CycloneDX`、空でない `components`、`metadata.component.type == "container"`、そして課題 1 の同じ `$IMAGE` の manifest digest に等しい `metadata.component.version` - 別の image (bare tag、alpine、busybox など) の SBOM は通らない。<br/>• **Cosign:** `gcr.io/distroless/static-debian13:nonroot` に対する実際の `cosign verify` コマンド (これが現在サポートされているタグです。サフィックス `-debian13` のない `gcr.io/distroless/static:nonroot` は、Distroless の公式 README によれば deprecated で、もう更新されません) が、指定された issuer/identity で exit code `0` で終了し、完全な出力が `7/cosign-verify.txt` に保存されている。<br/>• **新規の確認：** checker がさらに、同じ image について同じ Syft で SBOM を自分で再生成し、あなたの SBOM のコンポーネントの集合 (`name`/`version`) が、この新しい実行と一致することを要求する - top-level コンポーネントが 1 つだけの、最小限の手書きの CycloneDX ドキュメントは通らない。 |

<details>
<summary>💡 課題 7 のヒント</summary>

Syft は、フラグ `-o cyclonedx-json` で CycloneDX を生成します (同じツールの SPDX 出力と混同しないでください)。Distroless の keyless verification には、鍵も `cosign generate-key-pair` も必要ありません - 課題で指定された正確な issuer/identity の文字列を使って、`cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` を使用してください - どちらかに誤字があると、検証エラーになります。
</details>

---
| **8** | **`trivy sbom`: 用意された SBOM ファイルの脆弱性をスキャンする** |
| :---: | :--- |
| やること | • 課題 7 の CycloneDX SBOM (`7/syft.cdx.json`) は、image の構成とその OS を記述していますが、それ自体には脆弱性についての結論は含まれていません。<br/>• まさにこの SBOM ファイルを (image を直接ではなく) ツール `trivy sbom` でスキャンし、構造化された JSON を `/var/work/tests/artifacts/8/sbom-scan.json` に保存します。<br/>• コマンドは、`$IMAGE` を再スキャンするのではなく、SBOM ファイルを入力として明示的に受け取る必要があります；そのコマンドのテキストを `/var/work/tests/artifacts/8/sbom-scan-command.txt` に保存します。 |
| 受け入れ基準 | • **ファイル：** 空でなく、JSON が `jq` で解析でき、`ArtifactType` = `cyclonedx`、`Results` が空でなく、見つかった脆弱性を含んでいる。<br/>• **コマンド：** `sbom-scan-command.txt` に、`7/syft.cdx.json` へのパスを持つコマンド `trivy sbom` が含まれている。<br/>• **新規の確認：** checker がこのファイルに対して `trivy sbom` を自分で繰り返す。 |

<details>
<summary>💡 課題 8 のヒント</summary>

コマンドは `trivy sbom <sbom ファイルへのパス>` であり、`trivy image <ファイルへのパス>` ではありません - これらは入力のロジックが異なる別のサブコマンドです。SBOM ファイルのパスを誤って `trivy image` に渡すと、Trivy はそれを image reference の名前として解釈しようとし、エラーまたは予期しない挙動になります。
</details>

---
| **9a** | **Kyverno: インストールして、trusted signature の `ImageValidatingPolicy` を作成する** |
| :---: | :--- |
| やること | • `install-kyverno` で Kyverno をインストールし、`admission controller` の準備ができるまで待ちます。<br/>• ローカルの鍵ペアを `cosign generate-key-pair` で生成します (学習用のペアで、production の鍵ではありません)。<br/>• 課題 4 の**自分の** hardened image (`$HARDENED_IMAGE`、upstream の nginx ではありません) に、あなたの private key で署名し、`cosign sign` の出力を `9a/cosign-sign.txt` に保存します。<br/>• `ImageValidatingPolicy` `require-signed-catalog-images` を作成します。これは、あなたの `$HARDENED_IMAGE` の repository にある image を持つすべての Pod (`pods/ephemeralcontainers` の UPDATE とすべての container lists を含む) に対して、あなたの public key で `verifyImageSignatures` を確認し、署名されていない/署名が無効な image を**拒否します** (`validationActions: [Deny]`)。 |
| 受け入れ基準 | • **Kyverno:** インストールされ、その admission controller が `Available` である。<br/>• **署名：** `9a/cosign-sign.txt` に、まさに `$HARDENED_IMAGE` の署名の成功した出力が含まれている；実際のコマンド `cosign verify --key cosign.pub "$HARDENED_IMAGE"` が成功で終了する。<br/>• **Policy:** 適用された `ImageValidatingPolicy require-signed-catalog-images` が存在し、`apiVersion: policies.kyverno.io/v1`、`validationActions: [Deny]`、public key、`verifyImageSignatures` を持っている。<br/>• **適用範囲：** その `matchImageReferences` が、安全でないプレフィックス `$HARDENED_REPO*` ではなく、まさに `$HARDENED_REPO:*` と `$HARDENED_REPO@*` に限定されている。 |

<details>
<summary>💡 課題 9a のヒント</summary>

`cosign generate-key-pair` は、カレントディレクトリに `cosign.key`/`cosign.pub` を作成します - 課題 7 の keyless verification とは異なり、いかなる OIDC issuer にも結びつかない学習用のペアです。private key は `/home/ubuntu/cks-111` の外に保管してください。このディレクトリは課題 9c で Docker build context として再利用されるため、その中に残された `cosign.key` は、`COPY . /usr/share/nginx/html` によって、公開される image のファイルシステムにそのまま入ってしまいます。policy の `matchImageReferences` は、クラスター全体ではなく、まさにあなたの repository (`$HARDENED_REPO`) に作用を限定する必要があります - そうでないと policy は、Kubernetes のシステムコンポーネントを含む、署名のないすべての Pod をブロックします。
</details>

---
| **9b** | **Fresh signed ALLOW: policy の作成後の新しい Pod** |
| :---: | :--- |
| やること | • 課題 9a の policy は、署名された `$HARDENED_IMAGE` を許可する必要があります - しかし、すでに存在する Deployment を再度 `kubectl apply` しても、これは**証明されません**：template が変わっていなければ、新しい ReplicaSet/Pod は作成されないことがあり、`Running` は単に、policy の前に作成された古い Pod である可能性があります。<br/>• **新しい**、以前には存在しなかったオブジェクトを作成します：`kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 3600`。<br/>• この Pod の `creationTimestamp`、9a の policy の `creationTimestamp`、そして最終的な `status.phase`/`Ready` condition を `9b/signed-admission-check.json` に保存します。 |
| 受け入れ基準 | • **Pod:** `signed-admission-check` が存在し、まさに `$HARDENED_IMAGE` を使用している；それに対して `cosign verify --key cosign.pub "$HARDENED_IMAGE"` が成功し、`status.phase` が `Failed` ではなく、`Ready` 条件が `True` に達している。<br/>• **成果物：** `9b/signed-admission-check.json` にこの image が含まれ、Pod の `creationTimestamp` が `ImageValidatingPolicy require-signed-catalog-images` の `creationTimestamp` **以降**である。<br/>• これは、policy の作成前から残っている古い Pod ではなく、検証可能な形で署名された image の、policy の後の新しい admission を実証する。 |

<details>
<summary>💡 課題 9b のヒント</summary>

この確認のために、課題 4 の Deployment `catalog` を再利用しないでください - 課題で指定されているとおり、新しい Pod 名で、文字どおり新しい `kubectl run` を使用してください。2 つの timestamp (Pod と policy) は UTC の ISO8601 文字列であり、通常の文字列として辞書順に比較できます (`[[ "2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z" ]]` は、bash でこの形式に対して正しく動作します)。
</details>

---
| **9c** | **Signature-specific DENY: 同じ repository に実際に存在する、署名されていない digest** |
| :---: | :--- |
| やること | • `$HARDENED_IMAGE` と同じ repository に、**2 つ目の** tag (たとえば `${HARDENED_TAG%:*}:unsigned-1.0`) をビルドして公開し、署名はしません。<br/>• この image は、すでに署名された `$HARDENED_IMAGE` と同じ digest ではなく、**物理的に異なる artifact** である必要があります：変更なしで同じ `Dockerfile`/context をビルドすると、reproducible/cached なビルドが同一の digest を生成することがあり、その場合「署名されていない」タグは実際にはすでに署名された artifact を指し、`cosign verify` が予期せず通ってしまいます。<br/>• build-arg (たとえば、Dockerfile の対応する `ARG`/`LABEL` を使った `--build-arg CKS_SIGNATURE_TEST=unsigned-1`) による制御された差異を加え、`$UNSIGNED_DIGEST != $HARDENED_DIGEST` の証明を `9c/digest-comparison.txt` に明示的に保存します。<br/>• registry の manifest digest を、課題 3 と同じ方法 (`podman push --digestfile`) で取得し、同じ repository の `$UNSIGNED_IMAGE` を組み立てます。<br/>• この digest が**存在して pullable である**こと (registry への `HEAD` または `GET` による `/v2/catalog/manifests/<digest>` リクエストが成功する) と、あなたの鍵による有効な署名を**持たない**こと (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` がエラーで終了する) を明示的に実証し、両方の出力を `9c/unsigned-exists.txt` と `9c/unsigned-not-signed.txt` に保存します。<br/>• その後、この `$UNSIGNED_IMAGE` を持つ Pod `catalog-unsigned-probe` を作成し、admission denial を `9c/admission-deny.txt` に保存します。 |
| 受け入れ基準 | • **成果物：** `9c/digest-comparison.txt` に `hardened_digest=`、`unsigned_digest=`、`unsigned_image=` (`$HARDENED_IMAGE` と同じ repository の完全な `tag@digest` 参照で、本当に異なる digest を持つもの) が含まれている。<br/>• **checker の確認：** `unsigned_image` を registry で自分で解決し、自分の `cosign verify` で有効な署名がないことを確認し、この image を持つ独自の新しい Pod を作成して、自分の policy の一意の validation message `catalog image must have a valid release signature` を要求する。<br/>• このメッセージだけが有効とみなされ、任意の admission エラーでは不十分である：他の policy による一般的な admission/signature error は PASS にならず、`manifest unknown`/registry lookup のエラーも不十分である。<br/>• 実際の admission control を伴わない手書きの evidence ファイルは PASS にならない - checker は、確認する実際の image を指すものとしての `unsigned_image=` を除いて、どのテキストファイルも信用しない。 |

<details>
<summary>💡 課題 9c のヒント</summary>

ここでは、証明の順序がその信頼性にとって重要です：まず `$UNSIGNED_IMAGE` が存在し pullable であることを証明し (そうでないと、その後の denial は署名についてのものではなく単に "manifest unknown" かもしれません)、次に署名の不在を証明し、その後にのみ Pod を作成しようとします。`digest-comparison.txt` の digest の比較が一致を示す場合は、内容の実際の差異を作ってください (たとえば、`CKS_SIGNATURE_TEST` の build-arg を別の値に変更して再ビルドします)。
</details>

## 検証

```bash
check_result
```

チェックには `Init` と、14 個の独立した評価対象のテストが含まれます (課題 9 は 9a/9b/9c に分割されています)。名前の存在だけでなく、ファイルと
JSON の内容を確認します。Trivy、SBOM、Cosign には外部の registry へのリクエストが必要です；
registry が一時的に利用できない場合は、該当するコマンドをやり直してください。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=111 make delete_cks_task
```
