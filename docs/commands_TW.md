[Русский](commands_RU.md) · [English](commands.md) · [Español](commands_ES.md) · [Français](commands_FR.md) · [Deutsch](commands_DE.md) · [ქართული](commands_GE.md) · 繁體中文 · [日本語](commands_JP.md) · [首頁](../README_TW.MD)

<a id="commands"></a>

# 指令參考

所有指令都在儲存庫根目錄執行。`TASK` 是所選實作或模擬考試的編號。啟動、查看 Terraform 輸出及刪除同一環境時，請使用相同的 `TASK`、`USER_ID` 和 `ENV_ID`。

以 `_clean` 結尾的指令會在操作前清空對應環境的本機目錄。這不能取代使用 `delete_*` 刪除雲端資源。

<details>
<summary>CKA + CKAD：實作與 CKA 模擬考試</summary>

CKA + CKAD 共同課程的綜合實作使用 `cka_task` 指令啟動。

| 指令 | 操作 |
|---|---|
| `TASK=101 make run_cka_task` | 建立 [實作 CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | 刪除實作環境 |
| `TASK=101 make run_cka_task_clean` | 清空本機環境目錄後啟動實作 |
| `TASK=101 make output_cka_task` | 顯示 Terraform 輸出 |
| `TASK=01 make run_cka_mock` | 建立 [模擬考試 CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | 刪除模擬考試環境 |
| `TASK=01 make run_cka_mock_clean` | 清空本機環境目錄後啟動考試 |
| `TASK=01 make output_cka_mock` | 顯示 Terraform 輸出 |

</details>

<details>
<summary>CKAD：模擬考試</summary>

| 指令 | 操作 |
|---|---|
| `TASK=01 make run_ckad_mock` | 建立 [模擬考試 CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | 刪除模擬考試環境 |
| `TASK=01 make run_ckad_mock_clean` | 清空本機環境目錄後啟動考試 |
| `TASK=01 make output_ckad_mock` | 顯示 Terraform 輸出 |

</details>

<details>
<summary>CKS：實作與模擬考試</summary>

| 指令 | 操作 |
|---|---|
| `TASK=101 make run_cks_task` | 建立 [實作 CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | 刪除實作環境 |
| `TASK=101 make run_cks_task_clean` | 清空本機環境目錄後啟動實作 |
| `TASK=101 make output_cks_task` | 顯示 Terraform 輸出 |
| `TASK=01 make run_cks_mock` | 建立 [模擬考試 CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | 刪除模擬考試環境 |
| `TASK=01 make run_cks_mock_clean` | 清空本機環境目錄後啟動考試 |
| `TASK=01 make output_cks_mock` | 顯示 Terraform 輸出 |

</details>

<details>
<summary>Istio / ICA：實作與模擬考試</summary>

| 指令 | 操作 |
|---|---|
| `TASK=01 make run_ica_task` | 建立 [實作 ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | 刪除實作環境 |
| `TASK=01 make run_ica_task_clean` | 清空本機環境目錄後啟動實作 |
| `TASK=01 make output_ica_task` | 顯示 Terraform 輸出 |
| `TASK=01 make run_ica_mock` | 建立 [模擬考試 ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | 刪除模擬考試環境 |
| `TASK=01 make run_ica_mock_clean` | 清空本機環境目錄後啟動考試 |
| `TASK=01 make output_ica_mock` | 顯示 Terraform 輸出 |

</details>

<details>
<summary>Amazon EKS：實作</summary>

| 指令 | 操作 |
|---|---|
| `TASK=101 make run_eks_task` | 建立 [實作 EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | 刪除實作環境 |
| `TASK=101 make run_eks_task_clean` | 清空本機環境目錄後啟動實作 |
| `TASK=101 make output_eks_task` | 顯示 Terraform 輸出 |

刪除 EKS 環境前，請先完成實作說明要求的前置清理。部分資源由 Kubernetes 控制器或手動建立，必須在執行 Terraform destroy 前刪除。

</details>

<details>
<summary>LFCS：模擬考試</summary>

| 指令 | 操作 |
|---|---|
| `TASK=01 make run_lfcs_mock` | 建立 [模擬考試 LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | 刪除模擬考試環境 |
| `TASK=01 make run_lfcs_mock_clean` | 清空本機環境目錄後啟動考試 |
| `TASK=01 make delete_lfcs_mock_clean` | 清空本機環境目錄後刪除考試 |
| `TASK=01 make output_lfcs_mock` | 顯示 Terraform 輸出 |

</details>

<details>
<summary>HR：實作情境</summary>

| 指令 | 操作 |
|---|---|
| `TASK=01 make run_hr_mock` | 建立 [HR 情境 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | 刪除情境環境 |
| `TASK=01 make run_hr_mock_clean` | 清空本機環境目錄後啟動情境 |
| `TASK=01 make output_hr_mock` | 顯示 Terraform 輸出 |

</details>

<details>
<summary>KCNA、KCSA 與 AWS Certified AI Practitioner：測驗教材</summary>

請開啟對應章節並依說明操作：

- [KCNA：第 01 回模擬考試](../tasks/kcna/mock/01/README.MD).
- [KCSA：課程、題目與模擬考試](../tasks/kcsa/README_TW.md).
- [AWS Certified AI Practitioner：第 01 回模擬考試](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>開發與檢查</summary>

`make lint` - 透過 pre-commit 執行專案已設定的檢查。

</details>
