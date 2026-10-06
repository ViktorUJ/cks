[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 122 - ドリル：Pod のスケジューリング

## 概要

Workloads & Scheduling ドメインのスピードトレーニングです：nodeSelector、
nodeAffinity、requests/limits、PriorityClass、taints/tolerations に関する短く独立した課題群。
クラスタは単一ノード構成で、label（ラベル）と taint は唯一のノードに付けます。

課題は試験形式で書かれており、`check_result` コマンドで自動的に検証されます。
ドリルの目的は理論の解説ではなく、スピードと筋肉記憶です：Pod のスケジューリング管理で
「手を慣らし」、試験のペースに間に合わせることです。

> **重要：**課題 6（taint）は最後に実施してください - `NoSchedule` taint は
> toleration を持たない Pod のスケジューリングを妨げます。

## 目的

次のコース章の内容を定着させます：

- [第 12 章。Pod のスケジューリング：nodeName、nodeSelector、affinity](../../course/12/README.md) - nodeSelector と nodeAffinity による Pod のノードへの割り当て
- [第 13 章。Taints と tolerations](../../course/13/README.md) - taints による Pod の排斥と tolerations による許容
- [第 14 章。リソース：requests、limits、LimitRange、ResourceQuota](../../course/14/README.md) - コンテナ単位の CPU/メモリの requests と limits
- [第 15 章。Static Pods、PriorityClass、複数のスケジューラ](../../course/15/README.md) - PriorityClass による Pod の優先度

## 何をするのか、なぜするのか

| ブロック | 課題 | スキル |
|------|--------|-------|
| **ノードへの割り当て** | label `disk=ssd`、Pod `sel`（nodeSelector）、Pod `aff`（nodeAffinity） | Pod を必要なノードへ向ける（第 12 章） |
| **リソースと優先度** | Pod `res`（requests/limits）、PriorityClass `high-prio` + Pod `prio` | requests/limits とスケジューリング優先度（第 14、15 章） |
| **Taints と tolerations** | taint `dedicated=special:NoSchedule` + Pod `tol` | taint によるノードの分離と toleration による許容（第 13 章） |

## インフラ

環境は Terragrunt により AWS（`eu-central-1`）に展開され、次の要素で構成されます：

| コンポーネント | 説明                                                                      |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | パブリックサブネットを持つ VPC `10.10.0.0/16`                                     |
| `ssh-keys` | ノードへアクセスするための SSH キー                                                |
| `k8s-1`    | Kubernetes `1.35.2`（kubeadm）、CNI Calico、metrics-server、単一ノード；namespace `sched` は事前に作成済み |
| `worker`   | `kubectl` と `check_result` を備えた作業マシン                                    |

インスタンス：`t4g.medium`（master）、Ubuntu `22.04`。クラスタは単一ノード構成で、master の
taint は解除されています（`control-plane` taint を削除）。そのため Pod は master 上に直接スケジュールされます。

## デプロイ

```bash
TASK=122 make run_cka_task
```

作成が完了したら、SSH で作業マシン（worker）に接続し、そこから課題を進めてください。
`kubectl` はすでに `cluster1-admin@cluster1` コンテキストに設定されています。

作業マシンで使える便利なコマンド：

```bash
time_left       # 残り時間
check_result    # 解答をチェックする
```

## 課題

唯一のノードの名前は変数に入れておくと便利です：
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`。

---
|        **1**        | **ノードへのラベル**                                          |
| :-----------------: | :----------------------------------------------------------- |
| やること            | ノードに label（ラベル）`disk=ssd` を付けてください（`kubectl label node $NODE disk=ssd`）。 |
| 受け入れ基準        | - ノードに label `disk=ssd` がある。 |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Pod `sel`（ns `sched`、イメージ `viktoruj/ping_pong:latest`）を `nodeSelector: disk=ssd` 付きで作成してください - この Pod はその label を持つノードにのみスケジュールされます。 |
| 受け入れ基準        | - Pod `sel` が `Running` 状態で、`nodeSelector` が `disk=ssd`。 |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Pod `aff`（ns `sched`、イメージ `viktoruj/ping_pong:latest`）を required nodeAffinity 付きで作成してください：キー `disk`、演算子 `In`、値 `[ssd]`（`requiredDuringSchedulingIgnoredDuringExecution`）。 |
| 受け入れ基準        | - Pod `aff` が `Running` 状態で、nodeAffinity が設定されている。 |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| やること            | Pod `res`（ns `sched`、イメージ `viktoruj/ping_pong:latest`）を作成し、コンテナに requests `cpu=100m`、`memory=64Mi` と limits `cpu=200m`、`memory=128Mi` を設定してください。 |
| 受け入れ基準        | - Pod `res` が `Running` 状態で、`cpu` と `memory` の limits が設定されている。 |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| やること            | PriorityClass `high-prio` を値 `value: 1000` で作成し（`kubectl create priorityclass high-prio --value=1000`）、続いて Pod `prio`（ns `sched`、イメージ `viktoruj/ping_pong:latest`）を `priorityClassName: high-prio` 付きで作成してください。 |
| 受け入れ基準        | - PriorityClass `high-prio` の `value=1000`；<br/>- Pod `prio` が `Running` 状態で `priorityClassName: high-prio`。 |
---
|        **6**        | **Taint + toleration**（最後に）                             |
| :-----------------: | :----------------------------------------------------------- |
| やること            | ノードに taint `dedicated=special:NoSchedule` を付け（`kubectl taint node $NODE dedicated=special:NoSchedule`）、続いて Pod `tol`（ns `sched`、イメージ `viktoruj/ping_pong:latest`）を対応する toleration 付きで作成してください（`key=dedicated`、`operator=Equal`、`value=special`、`effect=NoSchedule`）。**この課題は最後に実施してください** - taint は残りの Pod のスケジューリングを妨げます。 |
| 受け入れ基準        | - ノードに taint `dedicated=special:NoSchedule` がある；<br/>- Pod `tol` が `Running` 状態。 |
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

Workloads & Scheduling ドメイン（CKA の 15%） - nodeSelector/affinity、リソース、
PriorityClass、taints/tolerations の反復練習です。

## クラスタとリソースの削除

```bash
TASK=122 make delete_cka_task
```
