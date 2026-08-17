[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 119 - スピードドリルと JSONPath

## 概要

CKA/CKAD 向けのスピードトレーナー：オブジェクト（Pod、Deployment、Service、ConfigMap、Secret）を
命令型で作成する短くて同じ形式の課題と、`-o jsonpath` 専用のブロック -
クラスタのオブジェクトからデータを取り出してファイルへ保存します。

課題は試験形式で書かれており、`check_result` コマンドで自動的に検証されます。
このドリルの目的は理論の解説ではなく、スピードと筋肉記憶です：命令型コマンドで
「手を慣らし」、試験のペース（1 問あたり約 6-8 分）に収めることです。
JSONPath 課題の解答ファイルは `/home/ubuntu/answers/` に保存します。

## 目的

次のコース章の内容を定着させます：

- [第 3 章。kubectl の使い方：命令型と宣言型のアプローチ](../../course/03/README.md) - 高速な命令型コマンド、`--dry-run=client -o yaml`、オブジェクトのジェネレーター
- [第 47 章。CKAD 試験：JSONPath と kubectl の生産性](../../course/47/README.md) - `-o jsonpath` によるデータ抽出、custom-columns、`--sort-by`
- [第 48 章。CKA 試験：タイムマネジメントと戦略](../../course/48/README.md) - 時間配分と解く順番

## 何をするのか、なぜするのか

| ブロック | 課題 | スキル |
|------|--------|-------|
| **ドリル** | namespace、Deployment、Service、ConfigMap、Secret | 命令型コマンドのスピード、`--dry-run`（第 3 章） |
| **JSONPath** | ノードのバージョン、Pod のイメージ、Service の ClusterIP → ファイルへ | `-o jsonpath`、タイマー下でのデータ抽出（第 47 章） |

## インフラ

環境は Terragrunt により AWS（`eu-central-1`）に展開され、次の要素で構成されます：

| コンポーネント | 説明                                                            |
|------------|----------------------------------------------------------------------|
| `vpc`      | パブリックサブネットを持つ VPC `10.10.0.0/16`                          |
| `ssh-keys` | ノードへアクセスするための SSH キー                                     |
| `k8s-1`    | Kubernetes `1.35.2`（kubeadm）、CNI Calico、metrics-server、単一ノード   |
| `worker`   | `kubectl` と `check_result` を備えた作業マシン                          |

インスタンス：`t4g.medium`（master）、Ubuntu `22.04`。クラスタは単一ノード構成で、master の
taint は解除されています（`control-plane` taint を削除）。そのため Pod は master 上に直接スケジュールされます。

## デプロイ

```bash
TASK=119 make run_cka_task
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
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace（名前空間）`drill` を作成してください - 他の課題のオブジェクトはこの中に置きます（`kubectl create namespace drill`）。 |
| 受け入れ基準        | - namespace `drill` が存在する。 |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `drill` の中で、イメージ `viktoruj/ping_pong:latest`、3 レプリカの Deployment `api` を作成してください（`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`）。 |
| 受け入れ基準        | - `drill` の Deployment `api`：ready なレプリカが 3 つある。 |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Deployment `api` を ClusterIP タイプの Service（サービス）として、`api-svc` という名前でポート 80 に公開してください（`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`）。 |
| 受け入れ基準        | - Service `api-svc`（ns `drill`）：Endpoints が空でない。 |
---
|        **4**        | **ConfigMap と Secret**                                      |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `drill` の中で、キー `APP_COLOR=blue` を持つ ConfigMap `cfg` と、キー `PASSWORD`（値は任意）を持つ Secret `sec` を作成してください。`--from-literal` を使ってください。 |
| 受け入れ基準        | - `cfg.data.APP_COLOR=blue`；<br/>- Secret `sec` にキー `PASSWORD` がある。 |
---
|        **5**        | **JSONPath：ノードのバージョン**                              |
| :-----------------: | :----------------------------------------------------------- |
| やること            | すべてのノードの `kubeletVersion` を `-o jsonpath` で取得し、結果をファイル `/home/ubuntu/answers/versions.txt` に保存してください（パスは `{.items[*].status.nodeInfo.kubeletVersion}`）。 |
| 受け入れ基準        | - `versions.txt` の内容が、ノードに対する `jsonpath` の出力と一致する。 |
---
|        **6**        | **JSONPath：Pod のイメージ**                                  |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `drill` のすべての Pod のコンテナイメージを `-o jsonpath` で取得し、`/home/ubuntu/answers/images.txt` に保存してください（パスは `{.items[*].spec.containers[*].image}`）。 |
| 受け入れ基準        | - `images.txt` のイメージの集合が、`drill` の Pod に対する `jsonpath` の出力と一致する。 |
---
|        **7**        | **JSONPath：Service の ClusterIP**                            |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Service `api-svc` の ClusterIP を `-o jsonpath` で取得し、`/home/ubuntu/answers/api-ip.txt` に保存してください（パスは `{.spec.clusterIP}`）。 |
| 受け入れ基準        | - `api-ip.txt` の値が Service `api-svc` の `.spec.clusterIP` と一致する。 |
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

CKA と CKAD のすべての模擬試験で求められる、スピードと JSONPath の基本スキルです。

## クラスタとリソースの削除

```bash
TASK=119 make delete_cka_task
```
