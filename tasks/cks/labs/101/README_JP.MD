[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 101 - NetworkPolicy: default-deny、分離、EC2 IMDS

## 概要

`NetworkPolicy` は allow-list として動作します。default-deny の後は、必要な通信だけを明示的なルールで復活させます。ルールの強制適用は Calico が担当します。この実習の worker は Terraform が管理する EC2 instance で、その Instance Metadata Service (IMDS) には `http://169.254.169.254/` でアクセスできます。Terraform は HTTP endpoint を明示的に有効にし、安全な probe のために IMDSv1 GET を許可したままにし、response hop limit を `2` に設定します。これにより、default-deny の前は通常の Pod から IMDS へのネットワーク到達性を確認できます。

この実習では、metadata や credentials を読み取ることなく、IMDS endpoint へのネットワーク到達性のみを確認します。実際に受信した `1xx–5xx` の HTTP status はいずれも、IMDS までの TCP/HTTP 経路が存在することを意味します。コード `000` (参考解答のコマンドでは `HTTP:000`、checker の出力では `HTTPCODE:000`) は、transport error/timeout を伴う場合、HTTP レスポンスがないことを意味します。具体的な HTTP status は EC2 の metadata options に依存します。token usage が `required` の場合、有効な IMDSv2 token のない GET は `401` を受け取ります。IMDSv1 が許可されている場合、token なしの GET は IMDSv1 リクエストとして扱われ、通常の HTTP response を受け取ることがあります。

**残存リスク。** worker EC2 には IAM instance profile が付与されており、`latest/meta-data/iam/security-credentials/<role>` への token なしの IMDSv1 GET は、実際に一時的な AWS credentials (AccessKeyId/SecretAccessKey/SessionToken) を返します。これは仮定のリスクではなく、現在の環境の実際の挙動です。ロール自体はほぼ権限のない状態に制限されている (最小権限：`iam:GetRole` で自分自身の IAM ロールを読み取ることすらできない) ため、攻撃者にとって漏洩の実用的な価値は最小限ですが、受講者は次の点を明確に理解する必要があります。同じ構成 (`HttpTokens=optional`、IMDSv1 許可) の production では、同じコマンドが実際の権限を持つ稼働中ロールの実際の credentials を返すことになります。この実習は、probe と、NetworkPolicy を通じてこの脆弱性を見つける学習のために、第 02.1 章のこのアンチパターン (IMDSv1 allowed、response hop limit `2`) をあえて再現しています。production では `HttpTokens=required` (IMDSv2 only) と `HttpPutResponseHopLimit=1` を使用してください。

## デプロイ

管理マシンで環境を起動します：

```bash
TASK=101 make run_cks_task
```

デプロイが正常に完了すると、Terraform が worker へ接続するための SSH コマンドを出力します。形式は次のとおりです：

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

例：

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

接続にはコマンド中のアドレスのみを使用します：

```bash
ssh ubuntu@<IP>
```

SSH がパスワードを求めたら、Terraform が `password=` の後に表示した値を入力します。

**runtime 確認には**、確認対象の identity と同じ labels を持つ一時的な診断用 Pod を使用します。HTTP の確認には curl 入りのイメージ (`curlimages/curl:8.11.1`) が、DNS には nslookup 入りのイメージ (`busybox:1.36.1`) が必要です。確認後は、一時的な Pod と一時的な policy を削除してください。

作業は worker 上で行います。開始前に、念のため namespaces がクリーンであることを確認します：

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

各段階は自分のリソースで自ら確認してください。`check_result` は課題を完了してから実行し、参考解答は自分で試した後、または行き詰まったときにだけ開いてください。

## 目的

最小限の ingress/egress allow-list を設定し、image digest を固定し、AND selector のセマンティクスと IMDS に対する正確な `ipBlock.except` を実証したうえで、通常の Pod と `hostNetwork` の Pod を、普遍的な結果を前提とせずに比較します。

## インフラ

| コンポーネント | 用途 |
| ----- | ----- |
| `cks-101`        | アプリケーションと自分の `NetworkPolicy` 用の namespace |
| `cks-101-legacy` | legacy クライアントのシナリオ用の namespace |
| `imds-control`   | baseline と再度の control probe 用の、policy のない独立した namespace |
| worker EC2       | IMDS `http://169.254.169.254/` を持つ、Terraform 管理の EC2 instance |
| CNI                | Calico |

## 課題

---

|           **1**           | **アプリケーション** |
| :-----: | :----- |
|       やること       | Namespace `cks-101`；Deployments `frontend` と `backend` (`replicas: 1`、`hostNetwork` なし、どちらも同一の `viktoruj/ping_pong@sha256:<64hex>`)；Service `backend` TCP/8080。<br/><br/>**最新の digest の取得方法：**<br/>1. イメージ `viktoruj/ping_pong:latest` から一時的に Pod を起動します。<br/>2. pull と Ready を待ちます。<br/>3. `digest=$(kubectl get pod <pod_name> -o yaml \| grep imageID \| cut -d'@' -f2)` を実行して `sha256:<64hex>` を取得します。<br/>4. 一時的な Pod を削除します。<br/>5. 取得した digest を両方の Deployment に使用します：`viktoruj/ping_pong@sha256:<64hex>`。 |
| 受け入れ基準 | 両方の replicas が Ready、image references が同一、Service に endpoint がある。 |
|        検証        | `kubectl -n cks-101 get deploy,svc,endpoints` を実行し、次を確認します：<br/>1. 両方の Deployment が `1/1 Ready` である。<br/>2. Service `backend` に endpoint がある。<br/><br/>pinned image を確認するには次を実行します：<br/>`kubectl -n cks-101 get deploy frontend backend -o yaml \| grep 'image:'`<br/>両方の Deployment が、`viktoruj/ping_pong@sha256:<64hex>` 形式の同一のイメージを使っている必要があります。 |

---

|           **2**           | **Baseline、default-deny、再度の probe** |
| :-----: | :----- |
|       やること       | Namespace `imds-control` と一時的な curl Pod を作成します。`cks-101` に frontend probe を作成します。**`default-deny` の前に**、2 つの baseline を確認します：frontend → backend と frontend → IMDS に到達できること、そして `imds-control` → IMDS にも到達できること。その後 `default-deny` を作成します。**`default-deny` の後に** IMDS probes を再度実行します：frontend は `HTTP 000` と curl `7`/`28` を受け取る必要があり、`imds-control` は引き続き exit `0` で実際の HTTP `1xx–5xx` を受け取る必要があります。Backend の deny は、DNS を復活させた後の Task 3 で確認します。 |
| 受け入れ基準 | deny の前は backend と IMDS に実際に到達できる。deny の後、frontend → IMDS は `HTTP 000` + curl `7`/`28` となり、独立した `imds-control` は HTTP `1xx–5xx` + exit `0` を維持する。 |
|        検証        | 1. `default-deny` の前：frontend probe から `http://backend:8080/` への curl が、HTTP response + exit `0` を受け取る必要があります。<br/>2. `default-deny` の前：frontend と `imds-control` が、IMDS から実際の HTTP response を受け取る必要があります。<br/>3. `default-deny` を確認します：空の `podSelector`、`Ingress` + `Egress`、allow-rules なし。<br/>4. `default-deny` の後：frontend → IMDS は `HTTP 000` + curl `7`/`28` を返す必要があり、`imds-control` → IMDS は引き続き HTTP `1xx–5xx` + exit `0` を受け取る必要があります。<br/>5. DNS を復活させるまでは backend の deny を確認しないでください - それは Task 3 で確認します。 |

---

|           **3**           | **DNS** |
| :-----: | :----- |
|       やること       | `default-deny` の後、最初の allow-rule として、frontend から `kube-system/kube-dns` のみへのアクセスを、exact UDP/53 と TCP/53 で、`endPort` なしで復活させます。確認用に、`busybox:1.36.1` を使い label `app=frontend` を付けた別の `dns-probe` を作成します。 |
| 受け入れ基準 | DNS の allow-set がちょうど UDP/53 + TCP/53 である；`nslookup kubernetes.default.svc.cluster.local` が動作する。この時点では、backend にはまだ TCP/8080 で到達できてはならない。 |
|        検証        | 1. YAML の `allow-frontend-dns` を確認します：UDP/53 と TCP/53 のみで、`endPort` や追加のポートはありません。<br/>2. `dns-probe` から `nslookup kubernetes.default.svc.cluster.local` を実行します。<br/>3. DNS が成功したら、frontend probe から `http://backend:8080/` へ curl を実行します：Task 4 までは `HTTP 000` + curl `7`/`28` が期待されます。 |

---

|           **4**           | **アプリケーション用の NetworkPolicy** |
| :-----: | :----- |
|       やること       | `allow-frontend-egress-to-backend` と `allow-backend-ingress-from-frontend` を作成します。その後、frontend は `http://backend:8080/` から実際の HTTP response を受け取る必要があります。 |
| 受け入れ基準 | frontend → backend:8080 が許可されている；foreign identity は引き続きブロックされている。 |
|        検証        | Positive：Service DNS 経由の frontend curl。Negative：backend への一時的な egress policy を持つ foreign Pod が、backend ingress を通過できないことを確認します。 |

---

|           **5**           | **IMDS の最終確認** |
| :-----: | :----- |
|       やること       | DNS と application の allow policies を追加した後、frontend Pod と独立した `imds-control` から、同じ IMDS probe を再度実行します。目的は、新しい allow policies が IMDS を開放していないことを実証することです。補助的な artifact ファイルを作成する必要はありません。 |
| 受け入れ基準 | `imds-control`：実際の HTTP `1xx–5xx` + exit `0`；frontend：`HTTP 000` + curl `7`/`28`。 |
|        検証        | 両方の Pod から同じ bounded curl (`-m 5`) を実行し、実際の結果を比較します。`curl -f` は使用しないでください：HTTP `401/403/404/...` もネットワーク到達性を意味します。 |

---

|           **6**           | **Legacy AND と IMDS except** |
| :-----: | :----- |
|       やること       | Namespace `cks-101-legacy` に Deployment `legacy-client` を作成します：replicas=1、hostNetwork なし、イメージ `curlimages/curl:8.11.1`、コマンド `sleep 3600`。namespace `cks-101` に NetworkPolicy `allow-backend-ingress-from-legacy` を作成します：backend を選択し、AND selector (namespaceSelector と podSelector が `from` の同一要素内) を持つ ingress peer を 1 つだけ含み、ポートは TCP/8080 とします。namespace `cks-101-legacy` に NetworkPolicy `allow-legacy-egress` を作成します：app=legacy-client を選択し、ipBlock cidr=0.0.0.0/0 とその唯一の except 169.254.169.254/32 を含み、追加の allow-rules はなし。次を確認します：1) legacy-client から IMDS がブロックされている；2) legacy-client が backend に到達できる；3) 同じ namespace 内で別の label を持つ Pod は ingress を通過できない；4) namespace cks-101 内の label=legacy-client の Pod は ingress を通過できない。確認後、一時的な Pod と一時的な policy を削除します。 |
| 受け入れ基準 | IMDS がブロックされている、実際の legacy-client → backend の通信フローが許可されている、誤った label の Pod または誤った namespace の Pod がブロックされている。 |
|        検証        | 1. `kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml` を実行し、`ipBlock.cidr=0.0.0.0/0` で、唯一の `except` が `169.254.169.254/32` であることを確認します。<br/>2. `kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml` を実行し、`namespaceSelector` と `podSelector` が `from` の同一要素内にあり、ポートが TCP/8080 であることを確認します。<br/>3. `legacy-client` から IMDS への curl は `HTTP 000` と exit `7` または `28` を返す必要があります。<br/>4. `legacy-client` から backend への curl は、実際の HTTP response を受け取る必要があります。<br/>5. `cks-101-legacy` 内の別の label を持つ Pod は、backend への一時的な egress があっても backend ingress を通過してはなりません。<br/>6. namespace `cks-101` 内の `app=legacy-client` を持つ Pod も、backend への一時的な egress があっても backend ingress を通過してはなりません。 |

---

|           **7**           | **hostNetwork の観察** |
| :-----: | :----- |
|       やること       | イメージ `curlimages/curl:8.11.1`、label `app=frontend`、`spec.hostNetwork=true` を持つ `hostnetwork-probe` を作成します。通常の frontend Pod で使ったのと同じ IMDS curl を、この Pod から実行します。実際の観察結果を Task 5 と比較します。補助的な artifact ファイルを作成する必要はありません。 |
| 受け入れ基準 | Pod が Ready、`hostNetwork=true`、実際の IMDS probe が実行されている。hostNetwork について、普遍的な期待結果は想定されない：挙動は CNI とノードの構成に依存します。 |
|        検証        | `hostNetwork: true` を確認し、続いて bounded IMDS curl (`-m 5`) と `echo $?` を実行します。実際の観察結果を、Task 5 の通常の Pod と比較します。 |

## 検証

```bash
check_result
```

Checker は独自の `imds-control` namespace と probes を作成して削除します：`cks-101` の deny の前後に、policy のない独立した namespace から実際の IMDS が応答することを確認します。前回の試行で残った control リソースを信用せず、自分で行う baseline/runtime の確認の代わりにもなりません。許可される通信を広げる追加の policy は、エラーになります。

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=101 make delete_cks_task
```
