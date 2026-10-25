[Русский](commands_RU.md) · [English](commands.md) · [Español](commands_ES.md) · [Français](commands_FR.md) · [Deutsch](commands_DE.md) · [ქართული](commands_GE.md) · [繁體中文](commands_TW.md) · 日本語 · [ホーム](../README_JP.MD)

<a id="commands"></a>

# コマンドリファレンス

すべてのコマンドはリポジトリのルートで実行します。`TASK` は選択したラボや模擬試験の番号です。同じ環境の起動、Terraform 出力の確認、削除には、同じ `TASK`、`USER_ID`、`ENV_ID` を使用してください。

末尾が `_clean` のコマンドは、処理の前に対応する環境のローカルディレクトリを空にします。クラウドリソースを `delete_*` で削除する操作の代わりにはなりません。

<details>
<summary>CKA + CKAD：ラボと CKA 模擬試験</summary>

CKA + CKAD 共通コースの総合ラボは `cka_task` コマンドで起動します。

| コマンド | 操作 |
|---|---|
| `TASK=101 make run_cka_task` | 作成： [ラボ CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | ラボ環境を削除 |
| `TASK=101 make run_cka_task_clean` | ローカル環境ディレクトリを空にしてラボを起動 |
| `TASK=101 make output_cka_task` | Terraform の出力を表示 |
| `TASK=01 make run_cka_mock` | 作成： [模擬試験 CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | 模擬試験環境を削除 |
| `TASK=01 make run_cka_mock_clean` | ローカル環境ディレクトリを空にして試験を起動 |
| `TASK=01 make output_cka_mock` | Terraform の出力を表示 |

</details>

<details>
<summary>CKAD：模擬試験</summary>

| コマンド | 操作 |
|---|---|
| `TASK=01 make run_ckad_mock` | 作成： [模擬試験 CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | 模擬試験環境を削除 |
| `TASK=01 make run_ckad_mock_clean` | ローカル環境ディレクトリを空にして試験を起動 |
| `TASK=01 make output_ckad_mock` | Terraform の出力を表示 |

</details>

<details>
<summary>CKS：ラボと模擬試験</summary>

| コマンド | 操作 |
|---|---|
| `TASK=101 make run_cks_task` | 作成： [ラボ CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | ラボ環境を削除 |
| `TASK=101 make run_cks_task_clean` | ローカル環境ディレクトリを空にしてラボを起動 |
| `TASK=101 make output_cks_task` | Terraform の出力を表示 |
| `TASK=01 make run_cks_mock` | 作成： [模擬試験 CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | 模擬試験環境を削除 |
| `TASK=01 make run_cks_mock_clean` | ローカル環境ディレクトリを空にして試験を起動 |
| `TASK=01 make output_cks_mock` | Terraform の出力を表示 |

</details>

<details>
<summary>Istio / ICA：ラボと模擬試験</summary>

| コマンド | 操作 |
|---|---|
| `TASK=01 make run_ica_task` | 作成： [ラボ ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | ラボ環境を削除 |
| `TASK=01 make run_ica_task_clean` | ローカル環境ディレクトリを空にしてラボを起動 |
| `TASK=01 make output_ica_task` | Terraform の出力を表示 |
| `TASK=01 make run_ica_mock` | 作成： [模擬試験 ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | 模擬試験環境を削除 |
| `TASK=01 make run_ica_mock_clean` | ローカル環境ディレクトリを空にして試験を起動 |
| `TASK=01 make output_ica_mock` | Terraform の出力を表示 |

</details>

<details>
<summary>Amazon EKS：ラボ</summary>

| コマンド | 操作 |
|---|---|
| `TASK=101 make run_eks_task` | 作成： [ラボ EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | ラボ環境を削除 |
| `TASK=101 make run_eks_task_clean` | ローカル環境ディレクトリを空にしてラボを起動 |
| `TASK=101 make output_eks_task` | Terraform の出力を表示 |

EKS 環境を削除する前に、ラボで指定された事前のクリーンアップを行ってください。Kubernetes コントローラーや手動で作成した一部のリソースは、Terraform destroy の前に削除する必要があります。

</details>

<details>
<summary>LFCS：模擬試験</summary>

| コマンド | 操作 |
|---|---|
| `TASK=01 make run_lfcs_mock` | 作成： [模擬試験 LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | 模擬試験環境を削除 |
| `TASK=01 make run_lfcs_mock_clean` | ローカル環境ディレクトリを空にして試験を起動 |
| `TASK=01 make delete_lfcs_mock_clean` | ローカル環境ディレクトリを空にして試験を削除 |
| `TASK=01 make output_lfcs_mock` | Terraform の出力を表示 |

</details>

<details>
<summary>HR：実践シナリオ</summary>

| コマンド | 操作 |
|---|---|
| `TASK=01 make run_hr_mock` | 作成： [HR シナリオ 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | シナリオ環境を削除 |
| `TASK=01 make run_hr_mock_clean` | ローカル環境ディレクトリを空にしてシナリオを起動 |
| `TASK=01 make output_hr_mock` | Terraform の出力を表示 |

</details>

<details>
<summary>KCNA、KCSA、AWS Certified AI Practitioner：テスト教材</summary>

対応するセクションを開いて手順に従ってください。

- [KCNA：模擬試験 01](../tasks/kcna/mock/01/README.MD).
- [KCSA：コース、問題、模擬試験](../tasks/kcsa/README_JP.md).
- [AWS Certified AI Practitioner：模擬試験 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>開発とチェック</summary>

`make lint` - pre-commit でプロジェクトに設定されたチェックを実行します。

</details>
