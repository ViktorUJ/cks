[Русский](getting_started_RU.md) · [English](getting_started.md) · [Español](getting_started_ES.md) · [Français](getting_started_FR.md) · [Deutsch](getting_started_DE.md) · [ქართული](getting_started_GE.md) · 繁體中文 · [日本語](getting_started_JP.md) · [首頁](../README_TW.MD)

<a id="quick-start"></a>

# 入門與環境需求

閱讀課程只需要開啟儲存庫。執行實作環境則需要 AWS 和平台工具。建立的雲端資源會向您的 AWS 帳戶計費，練習後請依情境說明刪除環境。

## 1. 準備工具

您可以使用已包含相依套件的 Docker 映像：

```bash
sudo docker run -it viktoruj/runner
```

[Docker 啟動說明](run_from_docker_TW.MD) · [操作影片](https://youtu.be/Xh6sWzafBmw)

[![透過 Docker 執行平台](images/run_via_docker.gif)](https://youtu.be/Xh6sWzafBmw "透過 Docker 執行平台")

<details>
<summary>本機安裝需求</summary>

- [GNU Make](https://www.gnu.org/software/make/) ≥ 4.2.1.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) ≥ 1.6.6.
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) ≥ 0.54.8.
- [jq](https://jqlang.github.io/jq/download/) ≥ 1.6.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html) > 2.2.30.
- 已設定的 [AWS 設定檔](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)或其他驗證方式。
- 具有[存取金鑰](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)的 [IAM 使用者](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)，或 [IAM 角色](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)，且有權建立與刪除情境資源。原始設定預期具備 VPC、EC2、IAM 與 EKS 的廣泛權限；請參閱 [AWS 存取政策](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)。

以上是平台文件原先列出的最低版本。其他工具與 provider 需求，請查看所選情境及其 Terraform 設定。

</details>

## 2. 取得儲存庫並設定 AWS

請在 Docker 容器內，或已安裝工具的電腦上執行以下指令：

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

設定 AWS 存取。在 [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl) 填入自己的 `backend_bucket`，必要時修改 `region` 和 `backend_region`。也請檢查情境 `env.hcl` 的區域與參數。詳細設定見 [Docker 指南](run_from_docker_TW.MD)。

## 3. 選擇並啟動練習

以下以 CKA + CKAD 第一項綜合實作為例：

```bash
TASK=101 make run_cka_task
```

開啟[實作 101](../tasks/cka/labs/101/README_TW.MD)，使用 Terraform 輸出的資訊連線並完成任務。

## 4. 刪除環境

練習後請先依該練習的刪除說明操作，再執行：

```bash
TASK=101 make delete_cka_task
```

其他練習請替換編號，並使用[指令參考](commands_TW.md)中對應方向的指令。
