[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)


# ラボ: Karpenter の基礎

## 概要

このラボでは、Amazon EKS クラスターにおけるノードの自動スケーリングツールである **Karpenter** を学びます。Karpenter はアプリケーションのニーズに応じて EC2 インスタンスを動的に作成・削除し、コストとパフォーマンスを最適化します。

**学習内容:**
- 基本的な NodePool と EC2NodeClass の設定方法
- 負荷の変化に応じて Karpenter がノードを自動スケーリングする仕組み
- 制限を通じたリソース管理方法
- 統合とノードサイズの最適化の仕組み
- 設定変更時にノードを更新する方法（drift）
- 異なるワークロードタイプに複数の NodePool を使用する方法

## 目次
- [環境の準備](#環境の準備)
  - [ラボの起動](#ラボの起動)
  - [作成されるリソース](#作成されるリソース)
  - [前提条件](#前提条件)
- [NodePool の基本設定](#nodepool-の基本設定)
  - [Karpenter の動作確認](#karpenter-の動作確認)
  - [テストアプリケーションの作成](#テストアプリケーションの作成)
  - [NodePool と EC2NodeClass の作成](#nodepool-と-ec2nodeclass-の作成)
  - [ノード自動作成の確認](#ノード自動作成の確認)
- [アプリケーションのスケーリング](#アプリケーションのスケーリング)
  - [水平スケーリング](#水平スケーリング)
  - [ノードの自動追加](#ノードの自動追加)
- [リソース制限](#リソース制限)
  - [CPU 制限の設定](#cpu-制限の設定)
  - [制限に関する問題の診断](#制限に関する問題の診断)
- [ノードライフサイクルの管理 (Disruption)](#ノードライフサイクルの管理-disruption)
- [ノードサイズの最適化 (RightSizing)](#ノードサイズの最適化-rightsizing)
  - [最適サイズの自動選択](#最適サイズの自動選択)
  - [要件変更時のノード置換](#要件変更時のノード置換)
- [ノード設定の更新 (Drift)](#ノード設定の更新-drift)
  - [AMI イメージの更新](#ami-イメージの更新)
  - [新しいバージョンへの自動移行](#新しいバージョンへの自動移行)
- [複数の NodePool の使用](#複数の-nodepool-の使用)
  - [Taints と Tolerations によるワークロードの分離](#taints-と-tolerations-によるワークロードの分離)
  - [Job 用の専用ノード](#job-用の専用ノード)
- [リソースのクリーンアップ](#リソースのクリーンアップ)


## 環境の準備

### ラボの起動
[Docker による起動](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)
ラボを起動するには、次のコマンドを実行します。

```bash
TASK=02 make run_eks_task
```

**コマンド実行時に行われること:**
- Terraform/Terragrunt が AWS に必要なインフラストラクチャをすべて自動的にデプロイします
- プロセスには約 15～20 分かかります
- コマンド出力に重要な情報（SSH 接続、リソース名）が表示されます

### 作成されるリソース

コマンドの実行により、次の AWS インフラストラクチャがデプロイされます。

#### ネットワークインフラストラクチャ (VPC)
- リージョン `eu-central-1` に CIDR ブロック `10.10.0.0/16` を持つ **VPC**
- **パブリックサブネット**（インターネットアクセスを持つリソース用）:
  - アベイラビリティゾーン `eu-central-1a` の `eks-AZ-1` (10.10.1.0/24)
  - アベイラビリティゾーン `eu-central-1b` の `eks-AZ-2` (10.10.2.0/24)
- **プライベートサブネット**（内部リソース用）:
  - `eu-central-1a` の EKS ノード用 `private-subnet-1` (10.10.15.0/24)
  - `eu-central-1b` の EKS ノード用 `private-subnet-2` (10.10.16.0/24)
  - `eu-central-1a` の RDS 用 `rds-subnet-1` (10.10.21.0/24)
  - `eu-central-1b` の RDS 用 `rds-subnet-2` (10.10.22.0/24)
- プライベートサブネットからのアウトバウンドインターネットトラフィック用 **NAT Gateway**

#### EKS クラスター
- バージョン `1.34` の **EKS Control Plane**（Kubernetes コントロールプレーン）
- システム Pod 用 **Fargate profile** (kube-system, karpenter)
- バージョン `1.8.1` の **Karpenter**（自動スケーリングコントローラー）
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Karpenter 設定
- 専用リソースを持つ Karpenter コントローラー:
  - CPU: 0.4 コア（requests と limits）
  - Memory: 0.5Gi（requests と limits）
- タグ `karpenter.sh/discovery` によるサブネットの自動検出

#### 追加コンポーネント
- 適切なセキュリティルールを持つ **Security Groups**
- Karpenter と EKS 用の **IAM ロールおよびポリシー**
- AWS サービスとの統合用 **OIDC provider**

#### 主な設定ファイル

すべてのインフラストラクチャパラメーターは `tasks/eks/labs/02/env.hcl` に定義されています。設定を変更するには、このファイル内の対応するパラメーターを編集します。

### 前提条件

以下が設定済みであることを確認してください。
- 適切なアクセス権限を持つ **AWS CLI**
- リージョン `eu-central-1` におけるノード数の増加済みクォータ（必要な場合）

## NodePool の基本設定

### Karpenter の動作確認

**ステップ 1: ワーカーノードへの接続**

コマンド出力から SSH 接続文字列を見つけ、ワーカーノードへ接続します。

```bash
# 出力例:
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # 自分の IP アドレスとパスワードを使用
```

**ステップ 2: Karpenter コントローラーのステータス確認**

Karpenter コントローラーが起動して稼働していることを確認します。

```bash
kubectl get po -n karpenter
```

**期待される結果:**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**ステップ 3: 既存の NodePool と EC2NodeClass の確認**

まだ作成された NodePool がないことを確認します。

```bash
kubectl get nodepools
```

**結果:**
```
No resources found
```

EC2NodeClass を確認します。

```bash
kubectl get ec2nodeclasses
```

**結果:**
```
No resources found
```

**これは何を意味するか:** NodePool と EC2NodeClass は Karpenter の主要リソースです。NodePool は作成するノードを定義し、EC2NodeClass はノードの設定方法（AMI、サブネット、security groups など）を定義します。

### テストアプリケーションの作成

簡単なテストアプリケーションをデプロイします。

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**結果:**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**ステップ 4: Pod の状態確認**

作成した Pod のステータスを確認します。

```bash
kubectl get po -n team-19
```

**結果:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**注意:** Pod は `Pending`（待機）ステータスです。この段階では正常です。

**ステップ 5: 問題の診断**

Pod の詳細情報を確認します。

```bash
kubectl describe po -n team-19
```

**出力の重要な部分:**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**問題の説明:**
- Pod をどのノードにもスケジュールできません
- 既存の 3 ノードはすべてシステム Pod (kube-system, karpenter) 用の Fargate ノードです
- Fargate profile は特定の namespace のみに設定されており、`team-19` は含まれません
- Karpenter が適切な EC2 ノードを作成できるよう、NodePool を作成する必要があります

### NodePool と EC2NodeClass の作成

**ステップ 6: NodePool の作成**

NodePool は Karpenter が作成するノードのパラメーターを定義します。

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # ノードを識別するためのラベル
    spec:
      requirements:
        # サポートされる CPU アーキテクチャ
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # オペレーティングシステム
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # インスタンスタイプ: spot（低価格）または on-demand（安定）
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # インスタンスカテゴリ (t - burstable、m - 汎用、r - メモリ最適化)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # インスタンス世代（2 より大きい = 新しい）
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # インスタンスサイズ
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # AWS 設定を持つ EC2NodeClass への参照
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # ノードの有効期間（30 日）
      expireAfter: 720h # 30 * 24h = 720h
  # NodePool 全体のリソース制限
  limits:
    cpu: 4  # この pool の全ノードで最大 4 CPU
  # 統合（最適化）設定
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # 空または使用率の低いノードを削除
    consolidateAfter: 30s  # ノードが空になってから 30 秒後
EoF

kubectl apply -f default-nodepool.yaml
```

**ステップ 7: Terraform 出力からのパラメーター取得**

`make run_eks_task` コマンドの出力から次の値を見つけます。

```bash
# 出力例:
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**ステップ 8: EC2NodeClass の作成**

EC2NodeClass は AWS 固有のノード設定を定義します。

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # ノード用 IAM ロール（Terraform 出力の自分の値に置き換える）
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # AMI イメージの選択
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023、最新バージョン
  # タグによるサブネットの選択
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 自分のクラスター名に置き換える
  # タグによる security groups の選択
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 自分のクラスター名に置き換える
  # 作成される EC2 インスタンス用タグ
  tags:
      Name: "eks2-viktor-01-default"  # 自分のクラスター名に置き換える
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # 自分のクラスター名に置き換える
  # ディスク設定
  blockDeviceMappings:
    - deviceName: /dev/xvda    # ルートディスク
      ebs:
        volumeType: gp3        # ディスクタイプ (gp3 - 最新、高性能)
        volumeSize: 25Gi       # ディスクサイズ
        iops: 3000             # gp3 の IOPS
        throughput: 125        # MiB/s 単位のスループット
        encrypted: true        # ディスク暗号化
        deleteOnTermination: true  # インスタンス削除時にディスクを削除
EoF

kubectl create -f default-nodeclass.yaml
```

### ノード自動作成の確認

**ステップ 9: リソースステータスの確認**

EC2NodeClass が作成され、準備できていることを確認します。

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**期待される結果:**
```
NAME      READY   AGE
default   True    2m17s
```

NodePool を確認します。

```bash
kubectl get nodepools.karpenter.sh
```

**期待される結果:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**ステータスが READY でない場合:**

EC2NodeClass を診断します。

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**成功時の出力例:**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

NodePool を確認します。

```bash
kubectl describe nodepools.karpenter.sh default
```

**エラーがある場合は、コントローラーのログを確認します。**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**成功時のログ例:**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**ステップ 10: NodeClaim の確認**

NodeClaim はノード作成リクエストです。Karpenter は NodeClaim を作成し、それが実際の EC2 インスタンスになります。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**確認できること:**
- `default-c549s` という名前の NodeClaim が作成されました
- タイプ `t3a.small` のインスタンス（2 vCPU、2GB RAM）が選択されました
- spot インスタンス（低価格）が使用されています
- ノードはゾーン `eu-central-1a` にあります

**ステップ 11: アプリケーション Pod の確認**

これで Pod は正常に起動するはずです。

```bash
kubectl get po -n team-19
```

**結果:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**ステータスが `Running` に変わりました！**

**ステップ 12: クラスターノードの確認**

クラスター内のすべてのノードを確認します。

```bash
kubectl get no
```

**結果:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**注意:**
- 最初の 3 ノードは Fargate（システム Pod 用）です
- 最後のノードは Karpenter が作成した EC2 インスタンスです

### ノード自動削除の確認

**ステップ 13: アプリケーションの削除**

アプリケーションを削除します。

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**結果:**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**ステップ 14: Pod 削除の確認**

```bash
kubectl get po -n team-19
```

**結果:**
```
No resources found in team-19 namespace.
```

**ステップ 15: NodeClaim 削除の待機**

約 30 秒（NodePool の `consolidateAfter` 値）待ってから確認します。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
No resources found
```

**ノードが空になったため、Karpenter が NodeClaim を自動的に削除しました！**

**ステップ 16: ノードの確認**

```bash
kubectl get no
```

**結果:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**EC2 ノードは削除されました！残っているのは Fargate ノードだけです。**

**結論:** Karpenter はノードのライフサイクルを自動管理します。必要時に作成し、不要になると削除することで、コストを最適化します。


## アプリケーションのスケーリング

このセクションでは、負荷の増加時に Karpenter がノードを自動追加する方法を学びます。

### 水平スケーリング

**ステップ 1: テストアプリケーションのデプロイ**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**ステップ 2: 作成されたリソースの確認**

NodeClaim を確認します。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

ノードを確認します。

```bash
kubectl get no
```

**結果:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

Pod を確認します。

```bash
kubectl get po -n team-19
```

**結果:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### ノードの自動追加

**ステップ 3: 6 レプリカへのスケーリング**

アプリケーションのレプリカ数を増やします。

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**結果:**
```
deployment.apps/team19 scaled
```

**ステップ 4: Pod の状態確認**

```bash
kubectl get po -n team-19
```

**結果:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**6 個すべての Pod が正常に起動しました！**

**ステップ 5: NodeClaim の確認**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**注意:** 6 個の Pod をすべて配置するには 1 ノードでは不十分だったため、Karpenter は 2 台目のノード（`default-gm8sj`）を自動追加しました。

**ステップ 6: 16 レプリカへのスケーリング**

さらに負荷を増やします。

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**ステップ 7: Pod の状態確認**

```bash
kubectl get po -n team-19
```

**結果:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**問題:** 一部の Pod が `Pending` ステータスです。なぜでしょうか。理解するために次のセクションへ進みます。

## リソース制限

このセクションでは、一部の Pod が `Pending` のままになる理由を確認し、NodePool におけるリソース制限の管理方法を学びます。

### CPU 制限の設定

**ステップ 1: 現在の NodePool 制限の確認**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**結果:**
```json
{
  "cpu": 4
}
```

**これは何を意味するか:** NodePool には 4 CPU の制限が設定されています。これは、この pool 内の全ノードの CPU 合計が 4 コアを超えられないことを意味します。

**ステップ 2: 既存の NodeClaim の確認**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**分析:**
- タイプ `t4g.small` のノードが 2 台あります
- 各 `t4g.small` は 2 vCPU を持ちます
- 合計: 2 ノード × 2 vCPU = 4 vCPU
- **制限に達しました！** Karpenter はこれ以上ノードを作成できません。

### 制限に関する問題の診断

**ステップ 3: Karpenter ログの確認**

コントローラーのログを確認します。

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**結果:**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**重要なメッセージ:** `"all available instance types exceed limits for nodepool"`

これは、CPU 制限のため Karpenter が新しいノードを作成できないことを示しています。

**ステップ 4: CPU 制限の増加**

CPU 制限を 6 コアに増やします。

```bash
kubectl edit nodepools.karpenter.sh default
```

`limits` セクションを見つけて、値を変更します。

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # 6 に変更
```

変更を保存します（vim では `:wq`、nano では Ctrl+O、Enter、Ctrl+X）。

**ステップ 5: 新しいノード作成の確認**

数秒待ってから NodeClaim を確認します。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**素晴らしい！** Karpenter は 3 台目のノード（`default-gpgn9`）を作成しました。

**ステップ 6: アプリケーション Pod の確認**

```bash
kubectl get po -n team-19
```

**結果:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**16 個すべての Pod が `Running` ステータスになりました！**

### 自動統合の確認

**ステップ 7: レプリカ数の削減**

レプリカ数を 3 に減らします。

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**ステップ 8: Karpenter ログの監視**

リアルタイムでログを監視します。

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**統合に関するメッセージが表示されます。**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**行われていること:**
- Karpenter は使用率の低いノード（`underutilized`）を検出しました
- ノードを削除する決定（`decision: delete`）を行いました
- まずノードに taint `karpenter.sh/disrupted:NoSchedule` を設定します
- Pod を他のノードへ移動します
- ノードを削除します

**ステップ 9: 残存ノードの確認**

約 1 分待ってから確認します。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**残っているのは 1 ノードだけです！** Karpenter は余分なノードを削除し、コストを最適化しました。

### 制限に関する追加情報

制限はさまざまなリソースタイプに設定できます。
- **cpu** — CPU コア数
- **memory** — RAM 容量
- **gpu** — GPU 数（ML/AI ワークロード用）
- **nodes** — 最大ノード数

**複数の制限を持つ設定例:**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

制限の詳細は [Karpenter 公式ドキュメント](https://karpenter.sh/docs/concepts/nodepools/#speclimits)を参照してください。


## ノードライフサイクルの管理 (Disruption)

Karpenter は NodePool 仕様の `consolidateAfter` パラメーターにより、ノードライフサイクルの自動管理をサポートします。

**主要な概念:**

- **consolidateAfter** — ノードが空または使用率が低くなってから削除されるまでの待機時間
- **consolidationPolicy** — 統合ポリシー:
  - `WhenEmpty` — 完全に空のノードのみを削除
  - `WhenEmptyOrUnderutilized` — 空または使用率の低いノードを削除（推奨）

**設定例:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # 解放後 30 秒で削除
```

**仕組み:**

1. Karpenter はノード上のリソース使用状況を継続的に監視します
2. ノードが空または使用率が低くなると、Karpenter はタイマーを開始します
3. 指定時間（`consolidateAfter`）後もノードが不要な場合、Karpenter は次を実行します:
   - ノードに taint `karpenter.sh/disrupted:NoSchedule` を設定します
   - Pod を他のノードへグレースフルに移動します
   - ノードを削除します

**追加パラメーター:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # 同時に 10% を超えるノードを削除しない
```

Disruption の詳細は[公式ドキュメント](https://karpenter.sh/docs/concepts/disruption/)を参照してください。

---

## ノードサイズの最適化 (RightSizing)

Karpenter は Pod の要件に応じて最適なノードサイズを自動選択します。これは「right-sizing」、すなわち最適でコスト効率の高いインスタンスタイプの選択と呼ばれます。

### 最適サイズの自動選択

**ステップ 1: CPU 制限の設定**

NodePool 制限を 10 コアに増やします。

```bash
kubectl edit nodepools.karpenter.sh default
```

次のように変更します。

```yaml
spec:
  limits:
    cpu: 6     # 10 に変更
```

**ステップ 2: 大きな要件を持つアプリケーションのデプロイ**

3 CPU を要求するアプリケーションをデプロイします。

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**ステップ 3: 作成された NodeClaim の確認**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**注意:** Pod が 3 CPU を要求するため、Karpenter は 4 vCPU を持つ `t3.xlarge` インスタンスを選択しました。

**ステップ 4: ノード詳細の確認**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**重要なラベル:**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### 要件変更時のノード置換

**ステップ 5: Pod 要件の削減**

deployment の CPU 要件を変更します。

```bash
kubectl edit deployments.apps -n team-19 team19
```

`resources` セクションを見つけて、次のように変更します。

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # "50m"（50 ミリコア）に変更
        memory: 500Mi
```

変更を保存します。

**ステップ 6: Karpenter ログの監視**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**次の内容が表示されます。**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**行われていること:**
- Karpenter はノードの使用率が低いことを検出しました（`underutilized`）
- ノードを置換する決定（`decision: replace`）を行いました
- より低コストの新しいノードを作成します

**新しい NodeClaim の作成:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**新しいインスタンスの起動:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**ステップ 7: 新しい NodeClaim の確認**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**素晴らしい！** Karpenter は `t3.xlarge`（4 vCPU）を、はるかに低コストな `t4g.small`（2 vCPU）に置き換えました。

**ステップ 8: クリーンアップ**

Deployment を削除します。

```bash
kubectl delete deployments.apps -n team-19 team19
```

NodeClaim が削除されるまで待ちます。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
No resources found
```

**結論:** Karpenter はノードサイズを自動最適化し、アプリケーション要件に適した最もコスト効率のよい選択肢を選びます。


## ノード設定の更新 (Drift)

Drift は、EC2NodeClass 設定の変更時にノードを自動更新するメカニズムです。AMI、security groups、user data、または他のパラメーターを変更すると、Karpenter は既存ノードを更新済み設定の新しいノードに自動的に置き換えます。

### AMI イメージの更新

**ステップ 1: 以前の EKS バージョンの AMI を取得**

EKS バージョン 1.33 用の AMI ID を取得します。

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**結果:**
```
ami-0fc1cdef3ebc3a8fe
```

**ステップ 2: EC2NodeClass への古い AMI の設定**

EC2NodeClass を編集します。

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

`amiSelectorTerms` セクションを見つけて、次のように変更します。

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # 変更前
```

以下に変更します。

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # バージョン 1.33 の特定の AMI ID
```

**ステップ 3: アプリケーションのデプロイ**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**ステップ 4: ノードバージョンの確認**

```bash
kubectl get no
```

**結果:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- バージョン 1.33!
```

**注意:** このノードは（古い AMI からの）Kubernetes バージョン 1.33.5 を使用しています。

### 新しいバージョンへの自動移行

**ステップ 5: AMI 自動選択への復帰**

EC2NodeClass を元に戻して編集します。

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

次のように変更します。

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # 最新バージョンを自動選択
```

**行われていること:**
- Karpenter は EC2NodeClass の変更を検出します
- 既存ノードが古い設定（drift）を使用していることを判定します
- 更新済み AMI を持つ新しいノードを自動的に作成します
- Pod を新しいノードへグレースフルに移動します
- 古いノードを削除します

**ステップ 6: ノード更新の確認**

約 1 分待ってからノードを確認します。

```bash
kubectl get no
```

**結果（約 30 秒後）:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- 新しいバージョン!
```

**結果（約 4 分後）:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**素晴らしい！** Karpenter はノードを更新された AMI バージョン（1.34.2）の新しいノードに自動置換しました。

**ステップ 7: クリーンアップ**

```bash
kubectl delete deployments.apps -n team-19 team19
```

NodeClaim が削除されるまで待ちます。

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
No resources found
```

**結論:** Drift は、手動操作なしで設定変更時にノードを自動更新できます。これは特に次の場合に役立ちます。
- AMI の更新（セキュリティパッチ、新しい Kubernetes バージョン）
- security groups の変更
- user data スクリプトの更新
- IAM ロールの変更

---

## 複数の NodePool の使用

本番環境では、多くの場合ワークロードを異なるノードグループに分割する必要があります。たとえば:
- 専用ノード上の Ingress コントローラー
- 定期的なタスク（jobs）用の高性能ノード
- ML/AI ワークロード用の GPU 搭載ノード
- データベース用の大容量メモリノード

### Taints と Tolerations によるワークロードの分離

**シナリオ:** CPU、メモリ、GPU について大きなリソース要件を持つ定期 job を実行する必要があります。

**要件:**
1. 通常の Pod はこれらのノードに配置されないこと（job のみ）
2. ノードで job が実行中は統合が発生しないこと
3. job が完了したら、ノードを削除すること

### Job 用の専用ノード

**ステップ 1: 専用 NodePool の作成**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # 識別用ラベル
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 日
      # 重要: Taint はこれらのノードで通常の Pod が起動することを防ぎます
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # 対応する toleration を持たない Pod は起動できません
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # 完全に空のノードのみを削除（job 実行中は削除しない）
    consolidateAfter: 10s           # job 完了後にすばやく削除
EoF

kubectl apply -f job-nodepool.yaml
```

**default NodePool との主な違い:**

1. **Taints** — 通常の Pod の起動を防ぎます:
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — ノードは完全に空の場合のみ削除されます（実行中の job は中断されません）

3. **consolidateAfter: 10s** — job 完了後にすばやく削除されます

**ステップ 2: Terraform 出力からのパラメーター取得**

出力で次を見つけます。

```bash
# 例:
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**ステップ 3: job 用 EC2NodeClass の作成**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # 自分の値に置き換える
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 自分のクラスター名に置き換える
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 自分のクラスター名に置き換える
  tags:
      Name: "eks2-viktor-01-job"  # 自分のクラスター名に置き換える
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**ステップ 4: リソースステータスの確認**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**結果:**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**結果:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**ステータスが READY でない場合**は、診断を実行します。

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**ステップ 5: Toleration を持つ Job の実行**

Taint `workType=job` を持つノードで起動できる job を作成します。

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration により、Pod は対応する taint を持つノードで起動できます
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity は、Pod が job NodePool のノードで確実に起動するようにします
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**ステップ 6: NodeClaim 作成の確認**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果:**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**Pod の確認:**

```bash
kubectl get po
```

**結果（実行中）:**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**結果（完了後）:**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**ノードの確認:**

```bash
kubectl get no
```

**結果:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**ステップ 7: ノード自動削除の確認**

job の完了後約 10～15 秒待ち、ノードを確認します。

```bash
kubectl get no
```

**結果:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**ノードは正常に削除されました！** Karpenter は job 完了の 10 秒後にノードを自動削除しました。

**結論:** taints と tolerations を持つ複数の NodePool を使用すると、以下が可能です。
- 異なるタイプのワークロードを分離する
- コストを最適化する（job 完了後にノードをすばやく削除）
- 専用ノードで通常の Pod が起動することを防ぐ
- 異なるタイプのワークロードに対する統合ポリシーを柔軟に管理する



## リソースのクリーンアップ

不要な費用を避けるため、ラボ完了後に作成したすべてのリソースを削除する必要があります。

**ステップ 1: アクティブな NodeClaim がないことを確認**

アクティブな NodeClaim がないことを確認します。

```bash
kubectl get nodeclaims.karpenter.sh
```

**期待される結果:**
```
No resources found
```

**アクティブな NodeClaim がある場合:**

1. ノード上で実行中の Pod がないか確認します。

```bash
kubectl get pods --all-namespaces -o wide
```

2. deployment、pods、または jobs を削除します。

```bash
# deployment 削除の例
kubectl delete deployment -n team-19 team19

# job 削除の例
kubectl delete job testjob
```

3. Pod を削除後、必要に応じて NodeClaim を手動で削除します。

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**ステップ 2: クラスターノードの確認**

Fargate ノードだけが残っていることを確認します。

```bash
kubectl get no
```

**期待される結果:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**すべてのノードは `fargate-` で始まる必要があります。**

**ステップ 3: インフラストラクチャの削除**

ラボ用に作成したすべてのリソースを削除します。

```bash
TASK=02 make delete_eks_task
```

**コマンド出力:**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**削除を確認するには `y` を入力してください。**

**削除されるもの:**
- ワーカーノード (worker)
- Karpenter コントローラーと関連リソース
- SSH キー
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC およびネットワークインフラストラクチャ

**削除プロセスには約 10～15 分かかります。**

---

## まとめ

おめでとうございます！Karpenter の基礎に関するラボを正常に完了しました。

**学習した内容:**

1. **基本設定** — ノードの自動管理のための NodePool と EC2NodeClass の作成
2. **自動スケーリング** — 負荷の増加に応じて Karpenter がノードを動的に追加
3. **制限の管理** — limits による最大リソース量の制御
4. **統合** — コスト最適化のため、空または使用率の低いノードを自動削除
5. **Right-sizing** — Pod 要件に応じた最適なノードサイズの自動選択
6. **Drift** — 設定変更時のノード自動更新（AMI、security groups など）
7. **複数の NodePool** — taints、tolerations、affinity による異なるワークロードタイプの分離

**Karpenter の主な利点:**

- **高速なスケーリング** — ノードが数分ではなく数秒で作成されます
- **コスト最適化** — 最もコスト効率のよいインスタンスタイプを自動選択します
- **柔軟性** — spot と on-demand インスタンス、さまざまなアーキテクチャ（amd64、arm64）をサポートします
- **シンプルさ** — Kubernetes リソースによる宣言的な設定
- **自動化** — ノード管理における手動操作を最小限にします

**追加リソース:**

- [Karpenter 公式ドキュメント](https://karpenter.sh/docs/)
- [Karpenter の Best Practices](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Troubleshooting Guide](https://karpenter.sh/docs/troubleshooting/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

**次のステップ:**

- Karpenter の高度な機能（weighted NodePools、custom AMI、GPU support）を学ぶ
- Karpenter を自分の production アプリケーションと統合する
- Karpenter のモニタリングとアラートを設定する
- spot と on-demand インスタンスの利用状況を分析してコストを最適化する
