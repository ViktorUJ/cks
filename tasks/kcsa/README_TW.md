[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [日本語版](README_JP.md)

# KCSA：Kubernetes and Cloud Native Security Associate 學習資料

**Kubernetes and Cloud Native Security Associate（KCSA）** 認證的完整準備資源：自學課程與完整模擬考試，全部集中在此。

KCSA（Kubernetes and Cloud Native Security Associate）是 CNCF 與 Linux Foundation 推出的 associate 級、職前與概念導向 cloud native 及 Kubernetes 安全認證。此課程位於 KCNA（optional）→ KCSA → CKA → CKS 的學習路徑中：KCSA 說明基礎與威脅模型，CKA 提供 CKS 必備的實作基礎，而 CKS 則進一步培養實作 security skills。沒有正式的先修條件；只需基本理解 `Pod`、`Deployment`、`Service` 與 `kubectl` 即可。

## 此目錄內容

| 部分 | 路徑 | 說明 |
|------|------|-----------|
| **課程** | [`course/`](course/README_TW.md) | 20 章自學課程，涵蓋全部 6 個官方 KCSA 領域 |
| **模擬考試** | [`mock/`](mock/README.md) | 2 份完整模擬考試，各 60 題，採 MCQ 格式 |

KCSA 的練習是選擇題與模擬考試，而非實驗操作。建議路徑：依序閱讀課程各章節，接著在接近正式考試的時間壓力下完成兩份模擬考試。

## 課程

課程（[`course/README_TW.md`](course/README_TW.md)）共 20 章，每章均以 8 種語言發布：英文（`README.md`）、俄文（`ru.md`，權威原文）、西班牙文（`es.md`）、法文（`fr.md`）、德文（`de.md`）、喬治亞文（`ge.md`）、繁體中文（`tw.md`）與日文（`jp.md`）。章節依官方 KCSA 領域分組：

| 領域 | 權重 |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

術語收錄於[詞彙表](course/GLOSSARY_TW.md)。第 1-2 章介紹考試與 cloud native 安全；第 20 章收錄最終應試策略、時間管理與檢查清單。

## 模擬考試

兩份完整模擬考試（[`mock/`](mock/README.md)）模擬真實的 KCSA 考試體驗：

- **Mock 01**（[`mock/01`](mock/01/README.md)）- 60 題，依領域分配。
- **Mock 02**（[`mock/02`](mock/02/README.md)）- 另一組獨立的 60 題，採相同分配方式。

請在 90 分鐘、closed-book 的情境下完成每份模擬考：不使用文件、搜尋、筆記、工具或外部網站。截至最近一次查核，LF Multiple Choice FAQ 列出的及格分數為 75% 或以上；註冊前請向 Linux Foundation 確認目前的 KCSA 報名要求。

## 考試格式與課程版本

KCSA 是選擇題考試：60 題、90 分鐘、及格門檻 75%，沒有 hands-on 任務（註冊前請向 Linux Foundation 確認目前參數，因為可能會變更）。課程範例以 Kubernetes `v1.36` 為準。目前的權重、來源與課綱漂移已記錄於[版本政策](VERSION_POLICY.md)。

## 延伸閱讀

- [Kubernetes 官方文件：Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- CKS 課程 - 下一步可深入學習實務 hardening 與調查。
