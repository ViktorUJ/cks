[Русский](README_RU.MD) · [English](README.MD) · [Español](README_ES.MD) · [Français](README_FR.MD) · [Deutsch](README_DE.MD) · [ქართული](README_GE.MD) · 繁體中文 · [日本語](README_JP.MD)

# SRE Learning Platform

<p align="center">
  <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>

**SRE Learning Platform 是一個開源教育專案。我們自行製作課程、實作練習與模擬考試，協助社群培養工程技能，並分享與時俱進的知識。** 目前已提供 Kubernetes、安全性、Istio、Amazon EKS，以及下方目錄中其他主題的教材。我們會逐步擴展平台，未來計畫推出 Prometheus、Elastic Stack、資料庫及其他工程師日常使用技術的課程。

市面上的課程和書籍很多，但技術日新月異，再好的教材也會逐漸過時。我們的理念是以開源專案的方式持續發展教材：隨技術演進更新內容、透過實作驗證、修正錯誤，並融入社群經驗。

我們希望每個人都有機會學習。付費課程與書籍並非人人都負擔得起，尤其是學生，因此我們免費提供教材。我們將課程翻譯成八種語言，讓外語不再成為學習的障礙。

**為社群而建，與社群共同成長。** 歡迎新增主題和實作練習、協助翻譯，以及提交修正的 pull request。也請分享您對課程與實作的回饋：哪些內容有幫助、哪些地方可以改進，以及平台對準備考試和解決實際工作問題有多大幫助。您的經驗能協助我們改善教材，讓學習更有價值。

歡迎在 **LinkedIn、Reddit、HackerNoon**、個人部落格、學習社群及其他管道介紹平台並分享連結。這些分享能讓更多人找到教材，也能促進社群成長與知識交流。 [回饋與建議](https://github.com/ViktorUJ/cks/issues) · [聯絡方式](#contacts).

如果平台對您有幫助，歡迎[為儲存庫加上一顆星](https://github.com/ViktorUJ/cks)。這份支持讓團隊感到欣慰，也是持續發展專案的動力。

## [使用 Docker 快速開始](docs/run_from_docker_TW.MD)

## 課程、實作練習與模擬考試

| 學習方向 | 課程 | 實作練習 | 模擬考試 |
|---|---|---|---|
| [CKA](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) | [CKA + CKAD 共同課程](tasks/cka/course/README_TW.md) | [實作練習](docs/labs.MD#cka-labs) | [01](tasks/cka/mock/01/README.MD) · [02](tasks/cka/mock/02/README.MD) |
| [CKAD](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/) | [CKA + CKAD 共同課程](tasks/cka/course/README_TW.md) | [實作練習](docs/labs.MD#cka-labs) | [01](tasks/ckad/mock/01/README.md) · [02](tasks/ckad/mock/02/README.md) |
| [CKS](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) | [課程](tasks/cks/course/README_TW.md) | [實作練習](docs/labs.MD#cks-labs) | [01](tasks/cks/mock/01/README.MD) · [02](tasks/cks/mock/02/README.MD) · [03](tasks/cks/mock/03/README.MD) · [04](tasks/cks/mock/04/README.MD) |
| Amazon EKS | [課程](tasks/eks/course/README_TW.md) | [實作練習](docs/labs.MD#eks-labs) | - |
| [Istio / ICA](https://training.linuxfoundation.org/certification/istio-certified-associate-ica/) | [課程](tasks/ica/course/README_TW.md) | [實作練習](docs/labs.MD#ica-labs-istio-certified-associate) | [01](tasks/ica/mock/01/README.MD) · [02](tasks/ica/mock/02/README.MD) |
| [KCSA](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/) | [課程](tasks/kcsa/course/README_TW.md) | - | [01](tasks/kcsa/mock/01/README.md) · [02](tasks/kcsa/mock/02/README.md) |
| [KCNA](https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/) | - | - | [01](tasks/kcna/mock/01/README.MD) |
| [LFCS](https://training.linuxfoundation.org/certification/linux-foundation-certified-sysadmin-lfcs/) | - | - | [01](tasks/lfcs/mock/01/README.md) · [02](tasks/lfcs/mock/02/README.md) |
| [AWS Certified AI Practitioner](https://aws.amazon.com/certification/certified-ai-practitioner/) | - | - | [01](tasks/aws_AI_practitioner/mock/01/README.MD) |
| 招募實作情境 | - | - | [01](tasks/hr/mock/01/README.md) |

實作目錄共用同一份清單，請在各項已翻譯練習旁選擇語言。模擬考試保留原始語言。

## 資源與協助

[文件與操作指南](docs/README_TW.md) · [參與專案](docs/contributing_TW.md) · [更新紀錄](CHANGELOG/CHANGELOG.MD)

<a id="contacts"></a>

## 共同備考與合作

共同備考的 Telegram 頻道： [CKA](https://t.me/sre_platform_cka) · [CKS](https://t.me/sre_platform_cks) · [CKAD](https://t.me/sre_platform_ckad).

問題、建議與合作： [Email](mailto:viktoruj@gmail.com) · [Telegram](https://t.me/viktor_uj) · [LinkedIn](https://www.linkedin.com/in/viktar-mikalayeu-mns).

## 授權

本專案採用 [Apache License 2.0](LICENSE) 授權。
