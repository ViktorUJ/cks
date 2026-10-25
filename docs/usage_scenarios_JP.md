[Русский](usage_scenarios_RU.md) · [English](usage_scenarios.md) · [Español](usage_scenarios_ES.md) · [Français](usage_scenarios_FR.md) · [Deutsch](usage_scenarios_DE.md) · [ქართული](usage_scenarios_GE.md) · [繁體中文](usage_scenarios_TW.md) · 日本語 · [ホーム](../README_JP.MD)

<a id="usage"></a>

# 利用シナリオと動画

<details>
<summary>CKA + CKAD と CKS のラボ：起動から検証まで</summary>

1. [ラボ一覧](labs.MD)から演習を選び、説明を読んでください。翻訳済みの説明は `tasks/cka/labs/<number>/README_JP.MD` または `tasks/cks/labs/<number>/README_JP.MD` にあります。
2. `env.hcl` のリージョン、インスタンスタイプ、設定を確認します。`ami_id` を手動設定する場合は、リージョンとアーキテクチャに合うイメージを指定してください。自動選択の場合はシナリオの設定に従います。
3. `TASK=101 make run_cka_task` または `TASK=101 make run_cks_task` で環境を作成します。
4. Terraform の出力で SSH コマンドを確認します。総合ラボは通常 `worker` 作業用マシン、一部のシナリオはコントロールプレーンのノードから始めます。シナリオが示す `worker_pc_ip`、`master_external_ip`、接続コマンドを使ってください。
5. `ubuntu` で接続します。鍵を使う場合は `ssh ubuntu@<IP> -i <key_path>`。パスワードが表示される環境では `ssh ubuntu@<IP>` で接続し、入力を求められたらパスワードを入力します。
6. 必要に応じて、対象マシンで初期設定の完了を確認します：`tail -f /var/log/cloud-init-output.log`。
7. 課題を実施します。総合ラボでは作業用マシンで `check_result` を実行し、説明にある検証方法に従ってください。
8. 参考解答を確認します。ラボ 101 は [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_JP.MD) と [CKS](../tasks/cks/labs/101/worker/files/solutions/1_JP.MD) です。他の演習では場所が異なる場合があるため、一覧や説明のリンクを使ってください。
9. 削除セクションで指定された事前のクリーンアップを行い、`TASK=101 make delete_cka_task` または `TASK=101 make delete_cks_task` で環境を削除します。

ローカル環境ディレクトリを空にして再起動する場合は `run_cka_task_clean` または `run_cks_task_clean` を使います。クラウドリソースの削除には `delete_*` が必要です。

</details>

<details>
<summary>CKA、CKAD、CKS、ICA、HR の実技形式の模擬試験</summary>

基本的な流れ：

1. 試験番号を選び、`tasks/<track>/mock/<number>/` の README を開きます。
2. 必要に応じて、`env.hcl` の対応する設定を変更します：OS（`ubuntu_version`）、EC2 購入方式（`spot` または `ondemand`）、インスタンスタイプ。
3. `TASK=<number> make run_<track>_mock` で起動します。ローカルディレクトリを空にして起動する場合は `run_<track>_mock_clean` を使います。
4. Terraform の出力で `worker_pc_ip` または SSH コマンドを確認し、指定された鍵かパスワードを使って `ubuntu` で作業用マシンに接続します。
5. 課題を開き、作業用マシンから操作します。ノードには試験の説明に従って `ssh <node_name>` で接続してください。
6. 対応する環境では `time_left` で残り時間、`check_result` で結果を確認します。
7. 挑戦後に、下記の解答とテストを確認します。
8. `TASK=<number> make delete_<track>_mock` で環境を削除します。

| 分野 | 試験 01 の課題 | 解答 | 自動チェック |
|---|---|---|---|
| CKA | [説明](../tasks/cka/mock/01) | [解答](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [説明](../tasks/ckad/mock/01) | [解答](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [説明](../tasks/cks/mock/01) | [解答](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [説明](../tasks/ica/mock/01) | [解答](../tasks/ica/mock/01/worker/files/solutions) | [テストディレクトリ](../tasks/ica/mock/01/worker/files/tests) |
| HR | [説明](../tasks/hr/mock/01) | [解答](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

動画による手順と解説：

- CKA: [模擬試験の起動](https://www.youtube.com/watch?v=P-YYX4CTWIg), [試験 01 の解答](https://youtu.be/IZsqAPpbBxM).
- CKS: [模擬試験の起動](https://youtu.be/_GbsBOMaJ9Q), [解答の解説](https://youtu.be/I8CPwcGbrG8).
- CKAD: [模擬試験の起動](https://youtu.be/7X4Y9QhbTsk), [解答の解説](https://youtu.be/yQK7Ca8d-yw).
- HR: [シナリオの操作動画](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS：ラボに取り組む</summary>

1. [EKS 一覧](labs.MD#eks-labs)から番号を選び、説明を読みます。
2. `env.hcl` を確認し、選択した番号に置き換えて `TASK=101 make run_eks_task` を実行します。
3. Terraform の出力で `worker_pc_ip` または SSH コマンドを確認し、説明に従って鍵かパスワードを使い `ubuntu` で接続します。
4. 課題を実施し、結果を検証します。総合ラボでは `check_result` を利用できます。
5. 説明や一覧の解答を参照します。例えば[ラボ 101 の解答](../tasks/eks/labs/101/worker/files/solutions/1_JP.MD)があります。
6. 削除セクションの事前クリーンアップを行い、正しい番号で `TASK=101 make delete_eks_task` を実行します。

</details>

その他のシナリオ： [Istio / ICA ラボ](../tasks/ica/README_JP.MD), [LFCS 模擬試験 01](../tasks/lfcs/mock/01), [KCSA テスト教材](../tasks/kcsa/README_JP.md), [KCNA 模擬試験 01](../tasks/kcna/mock/01/README.MD), [AWS Certified AI Practitioner 模擬試験 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
