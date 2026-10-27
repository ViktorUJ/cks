[Русский](usage_scenarios_RU.md) · [English](usage_scenarios.md) · [Español](usage_scenarios_ES.md) · [Français](usage_scenarios_FR.md) · [Deutsch](usage_scenarios_DE.md) · [ქართული](usage_scenarios_GE.md) · 繁體中文 · [日本語](usage_scenarios_JP.md) · [首頁](../README_TW.MD)

<a id="usage"></a>

# 使用情境與影片

<details>
<summary>CKA + CKAD 與 CKS 實作：從啟動到驗證</summary>

1. 從[實作目錄](labs.MD)選擇練習並閱讀說明。已翻譯的檔案位於 `tasks/cka/labs/<number>/README_TW.MD` 或 `tasks/cks/labs/<number>/README_TW.MD`。
2. 檢查 `env.hcl` 的區域、執行個體類型與環境參數。手動指定 `ami_id` 時，映像必須符合區域和執行個體架構；自動選擇時請依情境設定。
3. 建立環境：`TASK=101 make run_cka_task` 或 `TASK=101 make run_cks_task`。
4. 在 Terraform 輸出中找出 SSH 指令。綜合實作通常從 `worker` 工作機開始，部分情境則從控制平面節點開始。請使用該情境提供的 `worker_pc_ip`、`master_external_ip` 或完整連線指令。
5. 使用 `ubuntu` 連線。金鑰登入使用 `ssh ubuntu@<IP> -i <key_path>`；若環境輸出密碼，請使用 `ssh ubuntu@<IP>` 並在提示時輸入。
6. 必要時，在對應機器上確認初始化已完成：`tail -f /var/log/cloud-init-output.log`。
7. 完成任務。綜合實作請在工作機執行 `check_result`，並依練習說明的方式驗證。
8. 閱讀參考解答。實作 101：[CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_TW.MD) 與 [CKS](../tasks/cks/labs/101/worker/files/solutions/1_TW.MD)。其他練習的解答位置可能不同，請使用目錄或說明中的連結。
9. 完成刪除章節要求的前置清理，再刪除環境：`TASK=101 make delete_cka_task` 或 `TASK=101 make delete_cks_task`。

若要清空本機環境目錄後重新啟動，請使用 `run_cka_task_clean` 或 `run_cks_task_clean`。雲端資源仍須透過 `delete_*` 刪除。

</details>

<details>
<summary>CKA、CKAD、CKS、ICA 與 HR 實作型模擬考試</summary>

一般操作流程：

1. 選擇考試編號，開啟 `tasks/<track>/mock/<number>/` 中的 README。
2. 必要時修改 `env.hcl` 支援的參數：作業系統（`ubuntu_version`）、EC2 購買模式（`spot` 或 `ondemand`）及執行個體類型。
3. 使用 `TASK=<number> make run_<track>_mock` 啟動。若需先清空本機目錄，使用 `run_<track>_mock_clean`。
4. 在 Terraform 輸出找出 `worker_pc_ip` 或 SSH 指令，以 `ubuntu` 及該環境的金鑰或密碼連線。
5. 開啟任務並從工作機操作。存取叢集節點時，請依考試說明使用 `ssh <node_name>`。
6. 若環境支援，使用 `time_left` 查看剩餘時間，以 `check_result` 驗證結果。
7. 完成嘗試後，查看下方的解答與測試。
8. 使用 `TASK=<number> make delete_<track>_mock` 刪除環境。

| 方向 | 考試 01 任務 | 解答 | 自動檢查 |
|---|---|---|---|
| CKA | [說明](../tasks/cka/mock/01) | [解答](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [說明](../tasks/ckad/mock/01) | [解答](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [說明](../tasks/cks/mock/01) | [解答](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [說明](../tasks/ica/mock/01) | [解答](../tasks/ica/mock/01/worker/files/solutions) | [測試目錄](../tasks/ica/mock/01/worker/files/tests) |
| HR | [說明](../tasks/hr/mock/01) | [解答](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

操作影片與解析：

- CKA: [啟動模擬考試](https://www.youtube.com/watch?v=P-YYX4CTWIg), [考試 01 解答](https://youtu.be/IZsqAPpbBxM).
- CKS: [啟動模擬考試](https://youtu.be/_GbsBOMaJ9Q), [解答解析](https://youtu.be/I8CPwcGbrG8).
- CKAD: [啟動模擬考試](https://youtu.be/7X4Y9QhbTsk), [解答解析](https://youtu.be/yQK7Ca8d-yw).
- HR: [情境操作影片](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS：完成實作練習</summary>

1. 在 [EKS 目錄](labs.MD#eks-labs)選擇編號並閱讀說明。
2. 檢查 `env.hcl`，再執行 `TASK=101 make run_eks_task`，將編號替換為所選實作。
3. 在 Terraform 輸出找出 `worker_pc_ip` 或 SSH 指令，依說明使用 `ubuntu` 及金鑰或密碼連線。
4. 完成任務並驗證結果。綜合實作提供 `check_result`。
5. 查看說明或目錄所連結的解答，例如[實作 101 解答](../tasks/eks/labs/101/worker/files/solutions/1_TW.MD)。
6. 完成刪除章節的前置清理，再以正確編號執行 `TASK=101 make delete_eks_task`。

</details>

其他情境： [Istio / ICA 實作](../tasks/ica/README_TW.MD), [LFCS 第 01 回模擬考試](../tasks/lfcs/mock/01), [KCSA 測驗教材](../tasks/kcsa/README_TW.md), [KCNA 第 01 回模擬考試](../tasks/kcna/mock/01/README.MD), [AWS Certified AI Practitioner 第 01 回模擬考試](../tasks/aws_AI_practitioner/mock/01/README.MD).
