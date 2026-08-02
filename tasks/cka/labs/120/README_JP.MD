[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 120 - ドリル：Services とネットワーク

## 概要

Services & Networking 領域のスピードトレーナーです。Service（ClusterIP、NodePort、
headless）、Ingress、NetworkPolicy の作成に関する短くて独立した課題に加えて、
JSONPath のブロックがあります。

課題は試験形式で書かれており、`check_result` コマンドで自動的に検証されます。
ドリルの目的は理論の解説ではなく、スピードと筋肉の記憶です：手を慣らし、
試験のペースに間に合わせること。JSONPath 課題の解答ファイルは
`/home/ubuntu/answers/` に保存されます。

## 目的

次のコース章の内容を定着させます：

- [第 7 章。Services：ClusterIP、NodePort、LoadBalancer、Endpoints](../../course/07/README.md) - Service のタイプ、`expose` による publish、Endpoints
- [第 31 章。Service の内部、DNS と CoreDNS](../../course/31/README.md) - headless-Service（`clusterIP: None`）、DNS 名
- [第 32 章。Ingress と Ingress コントローラー](../../course/32/README.md) - ホストとパスによる backend-Service へのルーティング
- [第 34 章。NetworkPolicy](../../course/34/README.md) - default-deny、podSelector、policyTypes

## 何をし、なぜするのか

| ブロック | 課題 | スキル |
|------|--------|-------|
| **Services** | Deployment `web`、ClusterIP、NodePort、headless | さまざまな Service タイプでワークロードを素早く公開する（第 7、31 章） |
| **ルーティングと分離** | Ingress `web-ing`、NetworkPolicy `deny-all` | ホストによる Ingress ルールとトラフィックの default-deny（第 32、34 章） |
| **JSONPath** | Service `web-np` の nodePort → ファイルへ | タイマー下で `-o jsonpath` によりデータを抽出する（第 47 章） |

## インフラ

環境は Terragrunt により AWS（`eu-central-1`）に展開され、次の要素で構成されます：

| コンポーネント | 説明                                                             |
|------------|----------------------------------------------------------------------|
| `vpc`      | パブリックサブネットを持つ VPC `10.10.0.0/16`                          |
| `ssh-keys` | ノードへアクセスするための SSH キー                                    |
| `k8s-1`    | Kubernetes `1.35.2`（kubeadm）、CNI Calico、metrics-server、単一ノード |
| `worker`   | `kubectl` と `check_result` を備えた作業マシン                        |

インスタンス：`t3.medium`（master）、Ubuntu `22.04`。クラスタは単一ノード構成で、master の
taint は解除されています（`control-plane` taint を削除）。そのため Pod は master 上に直接スケジュールされます。

## デプロイ

```bash
TASK=120 make run_cka_task
```

作成が完了したら、SSH で作業マシン（worker）に接続し、そこから課題を進めてください。
`kubectl` はすでに `cluster1-admin@cluster1` コンテキストに設定されています。

作業マシンで使える便利なコマンド：

```bash
time_left       # 残り時間
check_result    # 解答をチェックする
```

## 課題

---
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace（名前空間）`net` を作成し、その中に Deployment `web` をコンテナイメージ `viktoruj/ping_pong:latest`、2 レプリカで作成してください（`kubectl create ns net`、`kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`）。 |
| 受け入れ基準        | - Deployment `web`（ns `net`）：2 つの ready なレプリカ。 |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Deployment `web` を ClusterIP タイプの Service（サービス）として、`web-svc` という名前でポート 80 で公開してください（`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`）。 |
| 受け入れ基準        | - Service `web-svc`（ns `net`）：Endpoints が空でない。 |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| やること            | `web` 用に NodePort タイプの Service `web-np` を、固定の `nodePort: 30080` で作成してください（`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`）。 |
| 受け入れ基準        | - Service `web-np`：type `NodePort`、`nodePort` 30080。 |
---
|        **4**        | **Headless-Service**                                        |
| :-----------------: | :----------------------------------------------------------- |
| やること            | `web` の Pod 用に、`clusterIP: None` を指定した headless-Service `web-h` を作成してください（セレクター `app=web`）。headless-Service は仮想 IP を介さず、DNS レコードを直接 Pod に配ります。 |
| 受け入れ基準        | - Service `web-h`：`clusterIP` = `None`。 |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `net` に Ingress `web-ing` を作成してください：ホスト `web.local`、パス `/` を backend-Service `web-svc` のポート 80 へ向けます（`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`）。 |
| 受け入れ基準        | - ホストルール `web.local` → backend Service `web-svc`、ポート 80。 |
---
|        **6**        | **NetworkPolicy（default-deny）**                            |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `net` に NetworkPolicy `deny-all` を、空の `podSelector: {}`（すべての Pod に適用）と `policyTypes: [Ingress]` で作成してください - このポリシーはすべての入力トラフィックを拒否します。 |
| 受け入れ基準        | - NetworkPolicy `deny-all`：`policyTypes` に `Ingress` が含まれ、`podSelector` が空。 |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Service `web-np` の `nodePort` を `-o jsonpath` で取得し、`/home/ubuntu/answers/nodeport.txt` に保存してください（パスは `{.spec.ports[0].nodePort}`）。 |
| 受け入れ基準        | - `nodeport.txt` の値が Service `web-np` の `.spec.ports[0].nodePort` と一致する。 |
---

## 結果のチェック

作業マシンで自動チェックを実行します：

```bash
check_result
```

スクリプトがテストを実行し、いくつの課題が完了したかを表示します。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)

## 模擬試験のカバー範囲

Services & Networking 領域（CKA 20% / CKAD 20%） - Service、Ingress、
NetworkPolicy の基本的な反復練習です。

## クラスタとリソースの削除

```bash
TASK=120 make delete_cka_task
```
