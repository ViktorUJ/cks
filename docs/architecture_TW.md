[Русский](architecture_RU.md) · [English](architecture.md) · [Español](architecture_ES.md) · [Français](architecture_FR.md) · [Deutsch](architecture_DE.md) · [ქართული](architecture_GE.md) · 繁體中文 · [日本語](architecture_JP.md) · [首頁](../README_TW.MD)

<a id="architecture"></a>

# 平台架構

實作環境以程式碼定義。Makefile 選擇情境，Terragrunt 協調 Terraform 模組，Terraform 建立必要的 AWS 資源並輸出連線資訊。

自行管理 Kubernetes 的情境透過 **kubeadm** 安裝叢集。**Amazon EKS** 實作則使用 AWS 的受管 Kubernetes。平台依情境建立 VPC、子網路、安全群組、EC2 執行個體（包含 Spot）、S3 及其他所需資源。

<details>
<summary>儲存庫結構</summary>

| 路徑 | 用途 |
|---|---|
| [Makefile](../Makefile) | 啟動、刪除、查看環境及檢查專案的指令 |
| [tasks](../tasks) | 課程、任務、實作練習與模擬考試 |
| [tasks/cka](../tasks/cka) | CKA + CKAD 共同課程、[實作](../tasks/cka/labs)及 [CKA 模擬考試](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [CKAD 模擬考試](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | CKS 課程、[實作](../tasks/cks/labs)與[模擬考試](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Amazon EKS 課程與實作 |
| [tasks/ica](../tasks/ica) | Istio / ICA 課程、實作與模擬考試 |
| [tasks/kcsa](../tasks/kcsa) | KCSA 課程、題目與模擬考試 |
| [tasks/kcna](../tasks/kcna) | [KCNA 模擬考試](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | LFCS 實作型模擬考試 |
| [tasks/hr](../tasks/hr) | HR 實作情境 |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [AWS Certified AI Practitioner 模擬考試](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | 基礎架構定義 |
| [terraform/environments](../terraform/environments) | Terragrunt 設定與環境的本機目錄 |
| [terraform/modules](../terraform/modules) | 可重複使用的 Terraform 模組 |
| [docs](../docs) | 實作目錄、操作指南及補充教材 |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | 專案更新紀錄 |

</details>

<details>
<summary>Kubernetes、執行階段、作業系統與 CNI</summary>

您可以使用 [k8s_self_managment](../terraform/modules/k8s_self_managment) 模組建立自己的情境。它定義自行管理的 Kubernetes 叢集，版本、執行階段、作業系統、AMI 和網路由各情境設定。

專案目前或過去使用過以下選項：

| 元件 | 選項 |
|---|---|
| Kubernetes | 歷史情境使用 1.21-1.34；新練習的版本請查看 `env.hcl` 和課程說明 |
| Container runtime | `containerd`、`containerd_gvizor`；舊情境也使用 `docker` 和 `cri-o` |
| 自行管理叢集的節點作業系統 | 依情境使用 Ubuntu 20.04 LTS 或 22.04 LTS |
| CNI | 依情境使用 Calico 或 Cilium |

平台舊版說明曾列出 Docker 搭配 Kubernetes 1.21-1.23、CRI-O 搭配 1.21-1.29，以及 containerd、`containerd_gvizor` 搭配 1.21-1.33；CKA/CKS 預設 Kubernetes 1.33，CKS 預設 Ubuntu 22.04。這是歷史設定資訊，不是新實作的相容性矩陣。請以所選練習的原始碼決定目前設定；[Kubernetes 發行紀錄](https://kubernetes.io/releases/)可在專案網站查看。

</details>
