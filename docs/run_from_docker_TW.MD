[Русский](run_from_docker_RU.MD) · [English](run_from_docker.MD) · [Español](run_from_docker_ES.MD) · [Français](run_from_docker_FR.MD) · [Deutsch](run_from_docker_DE.MD) · [ქართული](run_from_docker_GE.MD) · 繁體中文 · [日本語](run_from_docker_JP.MD) · [首頁](../README_TW.MD)

# 使用 Docker 快速開始

預先準備好的 Docker 映像包含執行實作練習與實作型模擬考試所需的相依套件和工具。以下以啟動 CKA 第 01 回模擬考試為例。

[操作影片](https://youtu.be/Xh6sWzafBmw)

## 1. 啟動容器

在已安裝 Docker 的電腦上執行：

```bash
sudo docker run -it viktoruj/runner
```

後續所有指令都請在容器內執行。

## 2. 複製儲存庫

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. 設定 Terraform 狀態儲存

開啟 [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl)。將 `backend_bucket` 替換為您自己的 S3 儲存貯體名稱，用來儲存 Terraform 狀態。視需要調整基礎架構區域 `region` 與狀態儲存區域 `backend_region`：

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

也請檢查所選情境 `env.hcl` 檔案中的區域與參數。

## 4. 設定 AWS 存取憑證

將下列預留值替換為您自己的存取金鑰：

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

若使用臨時憑證，請同時設定 `AWS_SESSION_TOKEN`。

## 5. 檢查 AWS 配額

環境可能需要多個 EC2 執行個體。在 AWS 主控台開啟 **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)**，檢查所用區域及執行個體系列的配額：

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** 適用於 On-Demand。
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** 適用於 Spot。

這些配額以 vCPU 數量計算，而非執行個體數量。如果可用配額不足以執行所選情境，請申請提高配額。使用其他執行個體系列時，請檢查對應的配額。

## 6. 啟動練習情境

單一環境：

```bash
TASK=01 make run_cka_mock
```

指定使用者或多個獨立環境：

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

依照 Terraform 輸出的資訊連線至工作機，並遵循[考試說明](../tasks/cka/mock/01/README.MD)。

若要進行其他練習，請在[實作目錄](labs.MD)或[首頁](../README_TW.MD)選擇方向與編號。啟動指令可參閱[指令參考](commands_TW.md)。

## 7. 練習結束後刪除環境

建立的資源會向您的 AWS 帳戶計費。請先完成情境 README 要求的前置清理，再刪除環境。

單一環境：

```bash
TASK=01 make delete_cka_mock
```

指定使用者的環境：

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

請使用與啟動情境時相同的 `TASK`、`USER_ID` 和 `ENV_ID` 值。

[獨立環境與 CMDB](environments_TW.md) · [使用情境](usage_scenarios_TW.md)
