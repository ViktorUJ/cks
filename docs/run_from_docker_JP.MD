[Русский](run_from_docker_RU.MD) · [English](run_from_docker.MD) · [Español](run_from_docker_ES.MD) · [Français](run_from_docker_FR.MD) · [Deutsch](run_from_docker_DE.MD) · [ქართული](run_from_docker_GE.MD) · [繁體中文](run_from_docker_TW.MD) · 日本語 · [ホーム](../README_JP.MD)

# Docker でクイックスタート

用意済みの Docker イメージには、実践ラボや実技形式の模擬試験を実行するための依存関係とツールが含まれています。以下では CKA 模擬試験 01 を起動する例を紹介します。

[動画による手順](https://youtu.be/Xh6sWzafBmw)

## 1. コンテナを起動する

Docker がインストールされたマシンで実行します。

```bash
sudo docker run -it viktoruj/runner
```

以降のコマンドはすべてコンテナ内で実行してください。

## 2. リポジトリをクローンする

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. Terraform の状態保存先を設定する

[terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl) を開きます。`backend_bucket` を Terraform の状態を保存するご自身の S3 バケット名に置き換えてください。必要に応じて、インフラストラクチャのリージョン `region` と状態保存先のリージョン `backend_region` も変更します。

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

選択したシナリオの `env.hcl` でも、リージョンと設定を確認してください。

## 4. AWS へのアクセスを設定する

プレースホルダーを、ご自身のアクセスキーに置き換えます。

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

一時的な認証情報を使用する場合は、`AWS_SESSION_TOKEN` も設定してください。

## 5. AWS のクォータを確認する

環境によっては複数の EC2 インスタンスが必要です。AWS コンソールの **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** で、使用するリージョンとインスタンスファミリーのクォータを確認してください。

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** は On-Demand 用です。
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** は Spot 用です。

これらのクォータはインスタンス数ではなく vCPU 数で計算されます。選択したシナリオに対してクォータが不足する場合は、引き上げを申請してください。別のインスタンスファミリーを使用する場合は、対応するクォータを確認します。

## 6. シナリオを起動する

単一の環境の場合：

```bash
TASK=01 make run_cka_mock
```

特定のユーザー、または複数の独立した環境の場合：

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Terraform の出力にある接続情報を使って作業用マシンに接続し、[試験の説明](../tasks/cka/mock/01/README.MD)に従ってください。

別の演習を行う場合は、[ラボ一覧](labs.MD)または[ホーム](../README_JP.MD)から分野と番号を選びます。起動コマンドは[コマンドリファレンス](commands_JP.md)を参照してください。

## 7. 練習後に環境を削除する

作成したリソースの料金はご自身の AWS アカウントに請求されます。シナリオの README に記載された事前のクリーンアップを行ってから、環境を削除してください。

単一の環境の場合：

```bash
TASK=01 make delete_cka_mock
```

特定のユーザーの環境の場合：

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

シナリオを起動したときと同じ `TASK`、`USER_ID`、`ENV_ID` の値を使用してください。

[独立した環境と CMDB](environments_JP.md) · [利用シナリオ](usage_scenarios_JP.md)
