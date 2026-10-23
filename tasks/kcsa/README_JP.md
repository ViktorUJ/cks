[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md)

# KCSA: Kubernetes and Cloud Native Security Associate - 学習教材

**Kubernetes and Cloud Native Security Associate (KCSA)** 認定資格の完全な準備教材です。独習コースと完全な模擬試験を、この 1 か所にまとめています。

KCSA (Kubernetes and Cloud Native Security Associate) は、cloud native と Kubernetes のセキュリティに関する CNCF と Linux Foundation のアソシエイトレベル、プリプロフェッショナルかつ概念的な認定資格です。本コースは KCNA (optional) → KCSA → CKA → CKS という学習パスに位置付けられます。KCSA は基礎と脅威モデルを説明し、CKA は CKS に必須の実践的な基盤を提供し、CKS は実践的なセキュリティスキルを発展させます。正式な前提条件はありません。`Pod`、`Deployment`、`Service`、`kubectl` が何であるかを基本的に理解していれば十分です。

## このディレクトリの内容

| 部分 | パス | 内容 |
|------|------|-----------|
| **コース** | [`course/`](course/README_JP.md) | KCSA の公式 6 ドメインすべてを網羅する独習用の全 20 章 |
| **模擬試験** | [`mock/`](mock/README.md) | MCQ 形式の 60 問からなる完全な模擬試験 2 セット |

KCSA の演習は、ラボではなく multiple-choice 問題と模擬試験で構成されます。推奨する学習順序: まずコースの各章を順番に読み進め、その後実際の試験に近い時間制限のもとで模擬試験を 2 回とも受験してください。

## コース

コース ([`course/README_JP.md`](course/README_JP.md)) は全 20 章で構成され、各章は 8 言語で公開されています: 英語版 `README.md`、ロシア語版 `ru.md` (正規のソース)、スペイン語版 `es.md`、フランス語版 `fr.md`、ドイツ語版 `de.md`、ジョージア語版 `ge.md`、繁体字中国語版 `tw.md`、日本語版 `jp.md`。章は公式の KCSA ドメインごとにグループ化されています。

| ドメイン | 配点 |
|---|---:|
| Overview of Cloud Native Security | 14% |
| Kubernetes Cluster Component Security | 22% |
| Kubernetes Security Fundamentals | 22% |
| Kubernetes Threat Model | 16% |
| Platform Security | 16% |
| Compliance and Security Frameworks | 10% |

用語は[用語集](course/GLOSSARY_JP.md)にまとめられています。第 1-2 章では試験と cloud native セキュリティを紹介し、第 20 章では最終的な試験戦略、タイムマネジメント、チェックリストをまとめています。

## 模擬試験

2 つの完全な模擬試験 ([`mock/`](mock/README.md)) は、実際の KCSA 試験を再現します。

- **Mock 01** ([`mock/01`](mock/01/README.md)) - ドメインごとに配分された 60 問。
- **Mock 02** ([`mock/02`](mock/02/README.md)) - 同じ配分で構成された、独立した 60 問のセット。

各模擬試験は、クローズドブックで 90 分間の受験としてください。ドキュメント、検索、メモ、ツール、外部サイトは使用しないでください。最新の確認時点で、LF の Multiple Choice FAQ には合格ラインとして 75% 以上が示されています。登録前に、現在の KCSA 登録要件を Linux Foundation で必ず確認してください。

## 試験形式とコースのバージョン

KCSA は multiple-choice 試験です: 60 問、90 分、合格には 75% が必要で、hands-on タスクはありません (これらのパラメータは変更される可能性があるため、登録前に Linux Foundation で最新の内容を確認してください)。コースの例は Kubernetes `v1.36` を対象としています。現在の配点、情報源、カリキュラムの変動は[バージョンポリシー](VERSION_POLICY.md)に記録されています。

## 参考資料

- [Kubernetes 公式ドキュメント: Security](https://kubernetes.io/docs/concepts/security/)
- [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- CKS コースは、より深い実践的な hardening と調査のための次のステップです。
