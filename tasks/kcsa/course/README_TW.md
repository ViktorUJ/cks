[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [日本語版](README_JP.md)

# KCSA：cloud native 與 Kubernetes 安全實務自學指南

KCSA（Kubernetes and Cloud Native Security Associate）是 CNCF 與 Linux Foundation 推出的 associate 級、職前與概念導向 cloud native 及 Kubernetes 安全認證。此課程位於 KCNA（optional）→ KCSA → CKA → CKS 的學習路徑中：KCSA 說明基礎與威脅模型，CKA 提供 CKS 必備的實作基礎，而 CKS 則進一步培養實作 security skills。沒有正式的先修條件；只需基本理解 `Pod`、`Deployment`、`Service` 與 `kubectl` 即可。

> **關於 CKA 與 CKS 的連結。** 獨立的 KCSA 封存不包含 CKA 與 CKS 目錄。因此，在 standalone-distribution 中，KCSA 內部的連結維持可點擊，而對 CKA/CKS 的 cross-course references 則以不含相對 URL 的純文字發布。在 monorepo-build 中，可將其產生為前往相鄰課程的可用連結，或穩定的 absolute URLs。

> **考試格式與範例版本。** KCSA 是 multiple choice 考試。根據 2026 年 9 月 1 日查核的 Linux Foundation 規則，標準 MCQ 考試（multiple choice question，選擇題）包含 60 題、時長 90 分鐘，通過門檻為 75%；沒有 hands-on 題目。註冊前務必再次確認 LF 的目前要求，因為這些參數可能變更。課程範例以 Kubernetes `v1.36` 為準。目前的權重、來源與課綱漂移已記錄於[版本政策](../VERSION_POLICY.md)。

## 課程架構

每個主題都是一個編號目錄，其權威俄文原始檔為 `ru.md`。每個章節均已發布英文 `README.md`、西班牙文 `es.md`、法文 `fr.md`、德文 `de.md`、喬治亞文 `ge.md`、繁體中文 `tw.md` 與日文 `jp.md`。章節依 KCSA 領域分組並以色彩標示：

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ 導論、基礎與考試準備

KCSA 的練習是選擇題與模擬考試，而非實驗操作。此檔案提供單一的備考路線與考試導覽。術語收錄於[詞彙表](GLOSSARY_TW.md)。

## 官方考試大綱

| 領域 | 權重 |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## 目錄

### 第 0 部分：導論與基礎 ⬜

1. [導論：KCSA 考試、格式、認證階梯中的位置、版本](01/tw.md)
2. [Cloud native 與安全性為何重要](02/tw.md)

### 第 1 部分：Overview of Cloud Native Security - 14% 🟦

3. [雲端安全的 4C：Cloud、Cluster、Container、Code](03/tw.md)
4. [雲端供應商與基礎架構安全](04/tw.md)
5. [控制措施、框架與隔離技術](05/tw.md)
6. [成品、映像檔與程式碼安全](06/tw.md)

### 第 2 部分：Kubernetes Cluster Component Security - 22% 🟥

7. [control plane 安全：API Server、Controller Manager、Scheduler、Etcd](07/tw.md)
8. [節點安全：Kubelet、Container Runtime、KubeProxy](08/tw.md)
9. [Pod、容器網路、storage 與用戶端安全](09/tw.md)

### 第 3 部分：Kubernetes Security Fundamentals - 22% 🟩

10. [驗證與授權](10/tw.md)
11. [Pod Security Standards 與 Pod Security Admission](11/tw.md)
12. [Secrets](12/tw.md)
13. [Network Policy、隔離與分段](13/tw.md)
14. [Audit Logging](14/tw.md)

### 第 4 部分：Kubernetes Threat Model - 16% 🟪

15. [信任邊界、資料流與威脅模型](15/tw.md)
16. [Kubernetes 威脅類別](16/tw.md)

### 第 5 部分：Platform Security - 16% 🟨

17. [Supply chain、映像檔登錄檔與 admission control](17/tw.md)
18. [Observability、PKI、connectivity 與 service mesh](18/tw.md)

### 第 6 部分：Compliance and Security Frameworks - 10% 🟫

19. [合規與安全框架](19/tw.md)

### 第 7 部分：考試準備 ⬜

20. [KCSA 考試：策略、時間管理、檢查清單](20/tw.md)

## 練習

- 📝 [KCSA 模擬考試](../mock) - 提供英文 Mock 01 與 Mock 02，採 MCQ 格式，供獨立練習使用。題目依領域權重分配；不會為 KCSA 建立 terragrunt/bats labs。

先從第 01-02 章開始，然後依序學習各領域。最終策略與檢查清單收錄於[第 20 章](20/tw.md)。

## 延伸閱讀

- [Kubernetes 官方文件：Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- CKS 課程 - 下一步可深入學習實務 hardening 與調查。