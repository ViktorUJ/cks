[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 114 - Kubeconfig の contexts、client certificates、API exposure

## 概要

受講者に渡される kubeconfig には、複数の contexts が含まれています：動作する `cluster1-admin@cluster1` と、
意図的に動作しない 2 つ (`staging-admin@staging`、`legacy-admin@legacy`) で、後者は存在しない
API server を指しています。ログイン直後の `current-context` は、動作しない `staging-admin@staging` に設定されています。これは
意図的に、実際の試験で起こる状況を再現したもので、候補者に複数の
context を持つ kubeconfig が渡され、どれが動作するのかを自分で見極める必要があります。

これとは別に、同じ kubeconfig には、本物の、実際に生成された自己署名の client certificate
(`client-certificate-data`/`client-key-data`) を持つユーザー `cluster9-admin` があります。この証明書は、クラスター内で
いかなる権限も与えません (apiserver はその CA を信頼していません)。課題は、kubeconfig の
client certificate を、それで認証するためではなく、読み取って分析することを学ぶものです。

また、この実習は Service の攻撃対象領域を減らす古典的なシナリオも扱います：まず意図的に
`NodePort` Service (control-plane ノードの IP から外部に到達可能) を作成し、次にそれを
`ClusterIP` に縮小して、その効果を両方向で実際に実証します。

## デプロイ

管理マシンで環境を起動します：

```bash
TASK=114 make run_cks_task
```

デプロイが正常に完了すると、Terraform が worker へ接続するための SSH コマンドを出力します：

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Terraform の出力にあるアドレスだけを使用して接続します：

```bash
ssh ubuntu@<IP>
```

作業は worker で行います。各段階は自分で確認してください。`check_result` は課題を完了した後に実行し、
参考解答は自分で試した後、または行き詰まったときにだけ開いてください。

## 目的

複数のコンテキストを含む kubeconfig を安全に扱い、client certificate を認証に使用することなく
抽出して検証し、`NodePort` -> `ClusterIP` の切り替えを通じて Service の exposure を
意識的に管理できるようになります。

## インフラ

| コンポーネント | 用途 |
| ----- | ----- |
| kubeconfig (`~/.kube/config`) | 4 つの context：動作するもの 1 つ (`cluster1-admin@cluster1`)、decoy 2 つ (`staging-admin@staging`、`legacy-admin@legacy`)、実際の client certificate を持つもの 1 つ (`cluster9-admin@cluster1`) |
| `cks-114` | あなたの backend アプリケーションと Service の namespace |
| control-plane EC2 | シングルノードの kubeadm クラスター、CNI Calico |

## 課題

---

|           **1**           | **Kubeconfig context inventory** |
| :-----: | :----- |
|       やること       | • `kubectl config get-contexts` を実行し、現在の (動作しない) `current-context` を特定します。<br/>• 実際に動作する context を見つけ、それに切り替えます：`kubectl config use-context <name>`。 |
| 受け入れ基準 | • `current-context` == `cluster1-admin@cluster1`。<br/>• この context から、API server へのリクエストが実際に通る (単にファイルに存在するだけではない)。 |
|        検証        | `kubectl config current-context`、続いて `kubectl get nodes` - connection error ではなく、ノードの実際の一覧を返す必要があります。 |

---

|           **2**           | **Client certificate extraction** |
| :-----: | :----- |
|       やること       | • kubeconfig からユーザー `cluster9-admin` の `client-certificate-data` を取り出し、base64 をデコードして、`openssl x509` で証明書を解析します。<br/>• 結果を `/var/work/tests/artifacts/task2-cert.txt` に、形式 `KEY=VALUE` で、1 行に 1 つの値として保存します：`SHA256_FP`、`SUBJECT`、`ISSUER`、`NOTBEFORE`、`NOTAFTER`。 |
| 受け入れ基準 | • 成果物の 5 つの値すべてが、`cluster9-admin` の元の bootstrap 証明書から抽出されるものと一致する。<br/>• Checker が、元の fingerprint、kubeconfig 内の証明書が変更されていないこと、そして 5 つすべてのフィールドを照合する。 |
|        検証        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` は `sha256 Fingerprint=AA:BB:...` を出力します。成果物にはコロンなしの hex を書いてください (大文字小文字は問いません)。 |

---

|           **3**           | **Baseline: NodePort exposure** |
| :-----: | :----- |
|       やること       | • namespace `cks-114` を作成します。<br/>• Deployment `backend` (たとえばイメージ `viktoruj/ping_pong:alpine`、`SRV_PORT=80`、label `app=backend`) を作成します。<br/>• ポート 80 で、明示的な `nodePort: 30114` を持つ、タイプ `NodePort` の Service `kubernetes-public` を作成します。<br/>• `default/kubernetes` Service には**触れないでください**。 |
| 受け入れ基準 | • Backend が、worker から (クラスターの外から) `<node-internal-ip>:30114` で、またクラスター内部から `kubernetes-public.cks-114.svc.cluster.local` で、実際に到達できる。<br/>• `default/kubernetes` が `ClusterIP` のままである。<br/>• 課題 4 は後でこの同じ Service を `ClusterIP` に変えるため、実習の終わりには NodePort の状態はもう観察できない：NodePort の過去のフェーズは、2 つの HTTP 200 プローブ (worker から、および Pod からの DNS 経由)、backend/EndpointSlice の確認、そして Service と Deployment の UID を保持する monitor によって確認される。<br/>• まず課題 3 を完全に行い、両方の live プローブが成功した後に monitor が作成するファイル `/var/lib/cks-lab114-checker/nodeport-phase-seen` を待ってください。課題 4 はその後に行ってください。このファイルは、同じ Service/Deployment についての過去のフェーズの確認です。 |
|        検証        | worker から (クラスターの外から)：`curl http://<node-internal-ip>:30114/` -> HTTP 200。<br/>クラスターの内部から (curl 入りの一時的な Pod)：`curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200。ノードの IP：`kubectl get nodes -o wide`。 |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP** |
| :-----: | :----- |
|       やること       | • `kubernetes-public` のタイプを `ClusterIP` に変更します。<br/>• 覚えておいてください：API server は、タイプ `ClusterIP` のとき明示的に指定された `nodePort` を許可しません - このフィールドは明示的に取り除くのが確実です (`kubectl edit svc kubernetes-public` で `nodePort` の行を削除するか、`/spec/ports/0/nodePort` に対して `op: remove` を指定した JSON patch を使います)。 |
| 受け入れ基準 | • 外部の経路 `<node-internal-ip>:30114` が、トランスポートレベルでブロックされている (connection refused/timeout)。<br/>• クラスター内部の経路は引き続き動作する。<br/>• Backend Pod が Ready のままである。 |
|        検証        | worker から：`curl -m5 http://<node-internal-ip>:30114/` -> 接続エラー (HTTP コードではない)。<br/>クラスターの内部から：`curl http://kubernetes-public.cks-114.svc.cluster.local/` -> 以前と同じ HTTP 200。<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`、どのポートにも `nodePort` がない。 |

## 検証

```bash
check_result
```

Checker は、`current-context` とそれを通じた API への live リクエストを確認し、`cluster9-admin` の証明書を独立して抽出して解析し、
元の bootstrap の fingerprint と照合し、あなたの成果物と比較します。また、Service DNS 経由でクラスター内部の HTTP 200 プローブを実行し、Deployment、EndpointSlice、`default/kubernetes` が変更されていないことを確認します。NodePort の過去のフェーズは、Service の切り替え前の 2 つの live プローブを持つ root-owned の monitor が確認します。ClusterIP の状態では、checker は live の DNS と NodePort のトランスポートでの拒否を確認します。

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=114 make delete_cks_task
```
