[Русский](architecture_RU.md) · [English](architecture.md) · [Español](architecture_ES.md) · [Français](architecture_FR.md) · [Deutsch](architecture_DE.md) · [ქართული](architecture_GE.md) · [繁體中文](architecture_TW.md) · 日本語 · [ホーム](../README_JP.MD)

<a id="architecture"></a>

# プラットフォームの構成

実践環境はコードで定義されています。Makefile がシナリオを選択し、Terragrunt が Terraform モジュールを連携させ、Terraform が必要な AWS リソースを作成して接続情報を出力します。

セルフマネージド Kubernetes のシナリオでは **kubeadm** でクラスターを構築します。**Amazon EKS** のラボは AWS のマネージド Kubernetes を使います。シナリオに応じて VPC、サブネット、セキュリティグループ、EC2 インスタンス（Spot を含む）、S3 などを作成します。

<details>
<summary>リポジトリの構成</summary>

| パス | 用途 |
|---|---|
| [Makefile](../Makefile) | 環境の起動、削除、表示と、プロジェクトのチェックに使うコマンド |
| [tasks](../tasks) | コース、課題、ラボ、模擬試験 |
| [tasks/cka](../tasks/cka) | CKA + CKAD 共通コース、[ラボ](../tasks/cka/labs)、[CKA 模擬試験](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [CKAD 模擬試験](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | CKS コース、[ラボ](../tasks/cks/labs)、[模擬試験](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Amazon EKS のコースとラボ |
| [tasks/ica](../tasks/ica) | Istio / ICA のコース、ラボ、模擬試験 |
| [tasks/kcsa](../tasks/kcsa) | KCSA のコース、問題、模擬試験 |
| [tasks/kcna](../tasks/kcna) | [KCNA 模擬試験](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | LFCS の実技形式の模擬試験 |
| [tasks/hr](../tasks/hr) | HR シナリオ |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [AWS Certified AI Practitioner 模擬試験](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | インフラストラクチャの定義 |
| [terraform/environments](../terraform/environments) | Terragrunt の設定と環境のローカルディレクトリ |
| [terraform/modules](../terraform/modules) | 再利用可能な Terraform モジュール |
| [docs](../docs) | ラボ一覧、手順、補足教材 |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | プロジェクトの変更履歴 |

</details>

<details>
<summary>Kubernetes、ランタイム、OS、CNI</summary>

独自のシナリオには [k8s_self_managment](../terraform/modules/k8s_self_managment) モジュールを利用できます。セルフマネージド Kubernetes クラスターを定義し、バージョン、ランタイム、OS、AMI、ネットワークは各シナリオで設定します。

現在または過去に、以下の構成を使用しています。

| コンポーネント | 選択肢 |
|---|---|
| Kubernetes | 過去のシナリオは 1.21-1.34。新しい演習のバージョンは `env.hcl` とコースの説明を参照 |
| Container runtime | `containerd`、`containerd_gvizor`。古いシナリオでは `docker` と `cri-o` も使用 |
| セルフマネージドクラスターのノード OS | シナリオに応じて Ubuntu 20.04 LTS または 22.04 LTS |
| CNI | シナリオに応じて Calico または Cilium |

以前の説明には、Docker と Kubernetes 1.21-1.23、CRI-O と 1.21-1.29、containerd および `containerd_gvizor` と 1.21-1.33 の組み合わせが記載されていました。また、CKA/CKS の既定値は Kubernetes 1.33、CKS の OS は Ubuntu 22.04 でした。これらは過去の設定であり、新しいラボの互換性マトリックスではありません。現在の設定は演習のソースを確認してください。[Kubernetes のリリース履歴](https://kubernetes.io/releases/)はプロジェクトのサイトにあります。

</details>
