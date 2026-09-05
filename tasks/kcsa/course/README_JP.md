[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md)

# KCSA: cloud native と Kubernetes セキュリティの実践的な独習ガイド

KCSA (Kubernetes and Cloud Native Security Associate) は、cloud native と Kubernetes のセキュリティに関する CNCF と Linux Foundation のアソシエイトレベル、プリプロフェッショナルかつ概念的な認定資格です。本コースは KCNA (optional) → KCSA → CKA → CKS という学習パスに位置付けられます。KCSA は基礎と脅威モデルを説明し、CKA は CKS に必須の実践的な基盤を提供し、CKS は実践的なセキュリティスキルを発展させます。正式な前提条件はありません。`Pod`、`Deployment`、`Service`、`kubectl` が何であるかを基本的に理解していれば十分です。

> **CKA および CKS へのリンクについて。** スタンドアロンの KCSA アーカイブには CKA および CKS のディレクトリは含まれません。そのため、スタンドアロン配布では KCSA 内部のリンクはクリック可能なままとし、CKA/CKS へのコース横断参照は相対 URL を持たない通常のテキストとして公開されます。monorepo ビルドでは、隣接するコースへの有効なリンクまたは安定した絶対 URL として生成できます。

> **試験形式とサンプルのバージョン。** KCSA は multiple choice 試験です。2026 年 9 月 1 日に確認した Linux Foundation の規則によると、標準 MCQ (multiple choice question) 試験は 60 問で構成され、90 分間で、合格には 75% が必要です。hands-on タスクはありません。これらのパラメータは変更される可能性があるため、登録前に必ず最新の LF 要件を再確認してください。コースの例は Kubernetes `v1.36` を対象としています。現在の配点、情報源、カリキュラムの変動は[バージョンポリシー](../VERSION_POLICY.md)に記録されています。

## コースの構成

各トピックは番号付きのディレクトリで、正規のロシア語原文は `ru.md` です。各章について、英語版 `README.md`、スペイン語版 `es.md`、フランス語版 `fr.md`、ドイツ語版 `de.md`、ジョージア語版 `ge.md`、繁体字中国語版 `tw.md`、日本語版 `jp.md` も公開されています。章は KCSA ドメインごとにグループ化され、色分けされています。

- 🟦 Overview of Cloud Native Security - 14%
- 🟥 Kubernetes Cluster Component Security - 22%
- 🟩 Kubernetes Security Fundamentals - 22%
- 🟪 Kubernetes Threat Model - 16%
- 🟨 Platform Security - 16%
- 🟫 Compliance and Security Frameworks - 10%
- ⬜ 導入、基礎、試験対策

KCSA の演習は、ラボではなく multiple-choice 問題と模擬試験で構成されます。このファイルは、統合された学習パスと試験ナビゲーションを提供します。用語は[用語集](GLOSSARY_JP.md)にまとめられています。

## 公式試験カリキュラム

| ドメイン | 配点 |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

## 目次

### パート 0. 導入と基礎 ⬜

1. [導入: KCSA 試験、形式、認定資格の段階における位置、バージョン](01/jp.md)
2. [Cloud native とセキュリティが重要な理由](02/jp.md)

### パート 1. Overview of Cloud Native Security - 14% 🟦

3. [クラウドセキュリティの 4C: Cloud、Cluster、Container、Code](03/jp.md)
4. [クラウドプロバイダーとインフラストラクチャのセキュリティ](04/jp.md)
5. [セキュリティ制御、フレームワーク、分離技術](05/jp.md)
6. [アーティファクト、イメージ、コードのセキュリティ](06/jp.md)

### パート 2. Kubernetes Cluster Component Security - 22% 🟥

7. [control plane のセキュリティ: API Server、Controller Manager、Scheduler、Etcd](07/jp.md)
8. [ノードのセキュリティ: Kubelet、Container Runtime、KubeProxy](08/jp.md)
9. [Pod、コンテナネットワーク、storage、クライアントのセキュリティ](09/jp.md)

### パート 3. Kubernetes Security Fundamentals - 22% 🟩

10. [認証と認可](10/jp.md)
11. [Pod Security Standards と Pod Security Admission](11/jp.md)
12. [Secrets](12/jp.md)
13. [Network Policy、分離、セグメンテーション](13/jp.md)
14. [Audit Logging](14/jp.md)

### パート 4. Kubernetes Threat Model - 16% 🟪

15. [信頼境界、データフロー、脅威モデリング](15/jp.md)
16. [Kubernetes の脅威カテゴリ](16/jp.md)

### パート 5. Platform Security - 16% 🟨

17. [サプライチェーン、イメージレジストリ、admission control](17/jp.md)
18. [Observability、PKI、connectivity、service mesh](18/jp.md)

### パート 6. Compliance and Security Frameworks - 10% 🟫

19. [コンプライアンスとセキュリティフレームワーク](19/jp.md)

### パート 7. 試験対策 ⬜

20. [KCSA 試験: 戦略、タイムマネジメント、チェックリスト](20/jp.md)

## 演習

- 📝 [KCSA 模擬試験](../mock) - 英語の Mock 01 と Mock 02 は、独自の演習用に MCQ 形式で利用できます。問題はドメインの配点に従って配分されています。KCSA 向けの terragrunt/bats ラボは作成されません。

まず章 01-02 から始め、その後ドメインを順に進めてください。最終的な戦略とチェックリストは[第 20 章](20/jp.md)にまとめられています。

## 参考資料

- [Kubernetes 公式ドキュメント: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- CKS コースは、より深い実践的な hardening と調査のための次のステップです。