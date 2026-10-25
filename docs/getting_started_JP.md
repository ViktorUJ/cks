[Русский](getting_started_RU.md) · [English](getting_started.md) · [Español](getting_started_ES.md) · [Français](getting_started_FR.md) · [Deutsch](getting_started_DE.md) · [ქართული](getting_started_GE.md) · [繁體中文](getting_started_TW.md) · 日本語 · [ホーム](../README_JP.MD)

<a id="quick-start"></a>

# はじめにと必要条件

コースを読むだけならリポジトリを開けば十分です。実践環境の実行には AWS とプラットフォームのツールが必要です。クラウドリソースはご自身の AWS アカウントに課金されるため、練習後はシナリオの手順に従って環境を削除してください。

## 1. ツールを準備する

依存関係を含む準備済みの Docker イメージを利用できます。

```bash
sudo docker run -it viktoruj/runner
```

[Docker の起動手順](run_from_docker_JP.MD) · [動画による手順](https://youtu.be/Xh6sWzafBmw)

[![Docker でプラットフォームを実行](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "Docker でプラットフォームを実行")

<details>
<summary>ローカルインストールの要件</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- 設定済みの [AWS プロファイル](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)、または別の認証方法。
- [アクセスキー](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)を持つ [IAM ユーザー](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)、または [IAM ロール](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)。シナリオのリソースを作成、削除する権限が必要です。元の設定では VPC、EC2、IAM、EKS に対する広い権限を想定しています。[AWS アクセスポリシー](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)を参照してください。

上記はプラットフォームのドキュメントに記載されていた元の最低バージョンです。追加のツールや provider の要件は、選択したシナリオと Terraform 設定を確認してください。

</details>

## 2. リポジトリを取得して AWS を設定する

以下は Docker コンテナ内、またはツールをインストールしたマシンで実行してください。

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

AWS へのアクセスを設定します。[terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl) にご自身の `backend_bucket` を指定し、必要なら `region` と `backend_region` を変更してください。シナリオの `env.hcl` でもリージョンと設定を確認します。詳しくは [Docker の手順](run_from_docker_JP.MD)を参照してください。

## 3. 演習を選んで起動する

CKA + CKAD の最初の総合ラボの例：

```bash
TASK=101 make run_cka_task
```

[ラボ 101](../tasks/cka/labs/101/README_JP.MD) を開き、Terraform の出力に従って接続し、課題を実施してください。

## 4. 環境を削除する

演習後はその削除手順に従い、次を実行してください。

```bash
TASK=101 make delete_cka_task
```

ほかの演習では番号を置き換え、[コマンドリファレンス](commands_JP.md)の対応する分野のコマンドを使用してください。
