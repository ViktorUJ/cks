[Русский](README_RU.MD) · [English](README.MD) · [Español](README_ES.MD) · [Français](README_FR.MD) · [Deutsch](README_DE.MD) · [ქართული](README_GE.MD) · [繁體中文](README_TW.MD) · 日本語

# SRE Learning Platform

<p align="center">
  <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>

**SRE Learning Platform は、コミュニティのエンジニアリングスキル向上と最新の知識の共有を支援するために、独自のコース、実践ラボ、模擬試験を制作するオープンソースの教育プロジェクトです。** 現在は Kubernetes、セキュリティ、Istio、Amazon EKS をはじめ、以下の一覧にある分野の教材を公開しています。プラットフォームは段階的に拡充しており、Prometheus、Elastic Stack、データベースなど、エンジニアが日常的に使う技術のコースも計画しています。

コースや書籍は数多くありますが、技術の進歩は速く、優れた教材でも時間がたつと古くなります。私たちは教材をオープンソースプロジェクトとして育て、技術の変化に合わせた更新、実践による検証、誤りの修正、コミュニティの経験の反映を続けていきたいと考えています。

誰もが学べる環境を目指しています。有料のコースや書籍は、特に学生にとって負担になることがあるため、私たちの教材は無料で公開しています。また、外国語が学習の壁にならないよう、コースを8言語に翻訳しています。

**コミュニティのために、コミュニティとともに。** 新しいテーマやラボの追加、翻訳への協力、修正の pull request を歓迎します。コースやラボについて、役立った点、改善してほしい点、試験準備や実務の課題解決にどの程度役立ったかをお聞かせください。皆さんの経験が、教材を改善し、学習をより有意義にする力になります。

**LinkedIn、Reddit、HackerNoon**、個人ブログ、学習コミュニティなど、さまざまな場所でプラットフォームを紹介し、リンクを共有していただけると嬉しいです。こうした発信によって、より多くの人に教材が届き、コミュニティの成長と知識の共有につながります。 [フィードバックと提案](https://github.com/ViktorUJ/cks/issues) · [連絡先](#contacts).

プラットフォームが役に立ったら、[リポジトリにスターを付けてください](https://github.com/ViktorUJ/cks)。チームにとって嬉しい応援となり、プロジェクトを発展させる励みになります。

## [Docker でクイックスタート](docs/run_from_docker_JP.MD)

## コース、ラボ、模擬試験

| 分野 | コース | ラボ | 模擬試験 |
|---|---|---|---|
| [CKA](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) | [CKA + CKAD 共通コース](tasks/cka/course/README_JP.md) | [ラボ](docs/labs.MD#cka-labs) | [01](tasks/cka/mock/01/README.MD) · [02](tasks/cka/mock/02/README.MD) |
| [CKAD](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/) | [CKA + CKAD 共通コース](tasks/cka/course/README_JP.md) | [ラボ](docs/labs.MD#cka-labs) | [01](tasks/ckad/mock/01/README.md) · [02](tasks/ckad/mock/02/README.md) |
| [CKS](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) | [コース](tasks/cks/course/README_JP.md) | [ラボ](docs/labs.MD#cks-labs) | [01](tasks/cks/mock/01/README.MD) · [02](tasks/cks/mock/02/README.MD) · [03](tasks/cks/mock/03/README.MD) · [04](tasks/cks/mock/04/README.MD) |
| Amazon EKS | [コース](tasks/eks/course/README_JP.md) | [ラボ](docs/labs.MD#eks-labs) | - |
| [Istio / ICA](https://training.linuxfoundation.org/certification/istio-certified-associate-ica/) | [コース](tasks/ica/course/README_JP.md) | [ラボ](docs/labs.MD#ica-labs-istio-certified-associate) | [01](tasks/ica/mock/01/README.MD) · [02](tasks/ica/mock/02/README.MD) |
| [KCSA](https://training.linuxfoundation.org/certification/kubernetes-and-cloud-native-security-associate-kcsa/) | [コース](tasks/kcsa/course/README_JP.md) | - | [01](tasks/kcsa/mock/01/README.md) · [02](tasks/kcsa/mock/02/README.md) |
| [KCNA](https://training.linuxfoundation.org/certification/kubernetes-cloud-native-associate/) | - | - | [01](tasks/kcna/mock/01/README.MD) |
| [LFCS](https://training.linuxfoundation.org/certification/linux-foundation-certified-sysadmin-lfcs/) | - | - | [01](tasks/lfcs/mock/01/README.md) · [02](tasks/lfcs/mock/02/README.md) |
| [AWS Certified AI Practitioner](https://aws.amazon.com/certification/certified-ai-practitioner/) | - | - | [01](tasks/aws_AI_practitioner/mock/01/README.MD) |
| 採用向け実践シナリオ | - | - | [01](tasks/hr/mock/01/README.md) |

ラボ一覧は全言語で共通です。翻訳済みの各ラボにある言語リンクを選んでください。模擬試験は元の言語のままです。

## 資料とサポート

[ドキュメントと手順](docs/README_JP.md) · [プロジェクトへの参加](docs/contributing_JP.md) · [変更履歴](CHANGELOG/CHANGELOG.MD)

<a id="contacts"></a>

## 共同学習とコラボレーション

試験準備のための Telegram チャンネル： [CKA](https://t.me/sre_platform_cka) · [CKS](https://t.me/sre_platform_cks) · [CKAD](https://t.me/sre_platform_ckad).

ご質問、ご提案、協力のご相談： [Email](mailto:viktoruj@gmail.com) · [Telegram](https://t.me/viktor_uj) · [LinkedIn](https://www.linkedin.com/in/viktar-mikalayeu-mns).

## ライセンス

本プロジェクトは [Apache License 2.0](LICENSE) の下で公開されています。
