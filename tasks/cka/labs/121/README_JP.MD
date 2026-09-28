[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 121 - ドリル：RBAC

## 概要

RBAC のスピード練習：ServiceAccount、Role/RoleBinding、
ClusterRole/ClusterRoleBinding、そして `kubectl auth can-i` による実効権限の
確認を扱う短い独立した課題です。namespace `rbac` はあらかじめ作成されています。

課題は試験形式で書かれており、`check_result` コマンドで自動的に検証されます。
このドリルの目的は理論の解説ではなく、スピードと筋肉記憶です：RBAC オブジェクトを
命令型で作る「手を慣らす」ことと、試験のペースに間に合わせることです。

## 目的

次のコース章の内容を定着させます：

- [第 21 章。ServiceAccount；認証、認可、admission](../../course/21/README.md) - ServiceAccount、authn/authz/admission の連鎖
- [第 38 章。RBAC：Role、ClusterRole と binding](../../course/38/README.md) - Role/ClusterRole、RoleBinding/ClusterRoleBinding、`auth can-i` による権限確認

## 何をするか、そしてなぜ

| ブロック | 課題 | スキル |
|------|--------|-------|
| **Namespaced RBAC** | ServiceAccount `app-sa`、Role `pod-reader`、RoleBinding `read-pods` | Role + binding による namespace 内の権限（第 38 章） |
| **Cluster-wide RBAC** | ClusterRole `cr-viewer`、ClusterRoleBinding `crb-viewer` | ClusterRole によるクラスタ規模のリソース（nodes）へのアクセス（第 38 章） |
| **権限の確認** | `app-sa` に対する `kubectl auth can-i` | ServiceAccount の実効権限の素早い検証（第 21 章） |

## インフラ

環境は Terragrunt を使って AWS（`eu-central-1`）に展開され、次の構成です：

| コンポーネント | 説明                                                                        |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | パブリックサブネットを持つ VPC `10.10.0.0/16`                                     |
| `ssh-keys` | ノードへアクセスするための SSH 鍵                                                 |
| `k8s-1`    | Kubernetes `1.35.2`（kubeadm）、CNI Calico、metrics-server、単一ノード；namespace `rbac` はあらかじめ作成済み |
| `worker`   | `kubectl` と `check_result` を備えた作業マシン                                   |

インスタンス：`t4g.medium`（master）、Ubuntu `22.04`。クラスタは単一ノードで、master は
「テイント解除済み」（`control-plane` taint が外されている）ため、Pod は直接そこにスケジュールされます。

## デプロイ

```bash
TASK=121 make run_cka_task
```

作成後は作業マシン（worker）に SSH で接続し、そこから課題を進めてください。
`kubectl` は context `cluster1-admin@cluster1` に設定済みです。

作業マシンで使える便利なコマンド：

```bash
time_left       # 残り時間
check_result    # 解答をチェックする
```

## 課題

---
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `rbac` に ServiceAccount `app-sa` を作成してください（`kubectl -n rbac create serviceaccount app-sa`）。 |
| 受け入れ基準        | - namespace `rbac` に ServiceAccount `app-sa` が存在する。 |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `rbac` に、リソース `pods` に対する `get,list,watch` 権限を持つ Role `pod-reader` を作成してください（`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`）。 |
| 受け入れ基準        | - Role `pod-reader` が `pods` に対して `get`/`list`/`watch` を与える。 |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| やること            | namespace `rbac` に RoleBinding `read-pods` を作成し、Role `pod-reader` を subject の ServiceAccount `app-sa` に結び付けてください（`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`）。 |
| 受け入れ基準        | - RoleBinding `read-pods` が Role `pod-reader` と subject `app-sa` を参照している。 |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| やること            | クラスタ規模のリソース `nodes` に対する `get,list` 権限を持つ ClusterRole `cr-viewer` を作成してください（`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`）。 |
| 受け入れ基準        | - ClusterRole `cr-viewer` が `nodes` に対して `get`/`list` を与える。 |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| やること            | ClusterRoleBinding `crb-viewer` を作成し、ClusterRole `cr-viewer` を namespace `rbac` の subject である ServiceAccount `app-sa` に結び付けてください（`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`）。 |
| 受け入れ基準        | - ClusterRoleBinding `crb-viewer` が ClusterRole `cr-viewer` と subject `rbac/app-sa` を参照している。 |
---
|        **6**        | **権限の確認（auth can-i）**                                |
| :-----------------: | :----------------------------------------------------------- |
| やること            | `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa` を使って `app-sa` の実効権限を確認してください：`rbac` での `get pods`、`get nodes`、そして `rbac` での `delete pods`。binding が正しく付与されていることを確かめてください。 |
| 受け入れ基準        | - namespace `rbac` での `get pods` = `yes`；<br/>- `get nodes` = `yes`；<br/>- namespace `rbac` での `delete pods` = `no`。 |
---

## 結果のチェック

作業マシンで自動チェックを実行します：

```bash
check_result
```

スクリプトがテストを走らせ、いくつの課題が完了したかを表示します。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)

## 模擬試験のカバー範囲

CKA の Cluster Architecture（RBAC）ドメインと CKAD の Application Security - Role/ClusterRole と
ServiceAccount との binding の反復練習です。

## クラスタとリソースの削除

```bash
TASK=121 make delete_cka_task
```
