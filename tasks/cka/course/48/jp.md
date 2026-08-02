[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md)

# 第 48 章。CKA 試験：形式、タイムマネジメント、戦略

> 🟦 **CKA 向けの章。** 速さと段取りの共通テクニックは CKAD（第 47 章）と同じです。
> ここでは CKA の特性に焦点を当てます：troubleshooting (30%)、クラスタの管理、
> ノード上での作業。
>
> **次は何か。** コースの最終章です。知識（第 1-46 章）と速さの戦術（第 47 章）は
> すでに揃っています。あとは、まさに CKA をどう合格するか：この試験は運用と
> troubleshooting に寄っていて、ノードへの SSH での作業と、クラスタ障害の確実な
> 切り分けを求めます。戦略と復習のマップをまとめましょう。

## 48.1. 戦術の面で CKA が CKAD と違うところ

形式は同じ（2 時間、約 15-20 問、66%、ドキュメント参照可、部分点あり）ですが、重点が
違います（第 1 章）：

```mermaid
flowchart TB
    ckad["CKAD (第 47 章)"]
    ckad --> d1["アプリケーション：マニフェスト、<br>設定、プローブ"]

    cka["CKA (この章)"]
    cka --> a1["troubleshooting 30% -<br>クラスタ、ノード、<br>control plane を直す"]
    a1 ~~~ a2["インストール/アップグレード<br>kubeadm、etcd backup"]
    a2 ~~~ a3["ノードへ SSH して作業、<br>systemctl/journalctl/crictl"]
    style ckad fill:#673ab7,color:#fff
    style cka fill:#0f9d58,color:#fff
    style d1 fill:#9c27b0,color:#fff
    style a1 fill:#3cb371,color:#fff
    style a2 fill:#3cb371,color:#fff
    style a3 fill:#3cb371,color:#fff
```

もっとも大きな違い：**CKA では kubectl の外での作業が多い** - ノードそのものの上
（SSH、システムサービス、ファイル）です。Troubleshooting (30%) とクラスタの
インストール/保守は、`/etc/kubernetes/`、`systemctl`、`journalctl`、`crictl`、
`etcdctl` に踏み込むことを要求します。

## 48.2. ドメインの重みと時間の配分

時間は重みに応じて配分してください（第 1 章）：

```mermaid
flowchart LR
    t["2 時間"]
    t --> ts["Troubleshooting 30%<br>→ 約 36 分"]
    t --> ca["Cluster Arch/Install 25%<br>→ 約 30 分"]
    t --> sn["Services & Networking 20%<br>→ 約 24 分"]
    t --> ws["Workloads & Scheduling 15%<br>→ 約 18 分"]
    t --> st["Storage 10% → 約 12 分"]
    style t fill:#326ce5,color:#fff
    style ts fill:#e74c3c,color:#fff
    style ca fill:#4a90d9,color:#fff
    style sn fill:#2ecc71,color:#fff
    style ws fill:#7b68ee,color:#fff
    style st fill:#e8a838,color:#000
```

Troubleshooting と Cluster Architecture を合わせると、試験の半分以上になります。準備の
主力を投じる価値があるのは、まさにそこです。

## 48.3. 最初の数分：同じ設定 + SSH

環境の準備は CKAD と同じ（第 47 章）：alias、`$do`/`$now`、補完、expandtab 付きの vim。
加えて CKA の特性：

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
source <(kubectl completion bash); complete -o default -F __start_kubectl k
echo 'set tabstop=2 shiftwidth=2 expandtab' >> ~/.vimrc; export KUBE_EDITOR=vim
```

```mermaid
flowchart TB
    env["標準の<br>設定 (第 47 章)"] --> ssh["SSH で作業する準備：<br>ssh &lt;node&gt;, sudo -i"]
    ssh --> tools["ノード上で: systemctl,<br>journalctl, crictl,<br>etcdctl, vim でマニフェスト"]
    style env fill:#326ce5,color:#fff
    style ssh fill:#0f9d58,color:#fff
    style tools fill:#f4b400,color:#000
```

> **CKA で重要なこと。** 多くの問題は kubectl 経由ではなく **ノード上で** 解きます。
> control plane/worker への `ssh`、`sudo`、`/etc/kubernetes/` のファイル編集、
> `journalctl -u kubelet` や `crictl ps` の確認ができるようにしておいてください。
> ノードでの作業のあとは「自分の」マシンに戻ることを忘れないでください。

## 48.4. CKA の主要な問題と、どこで復習するか

配点の高い典型的な問題と、コースの章：

| 問題 | 章 |
|---------|-------|
| クラスタをインストール / ノードを追加 (kubeadm) | 35 |
| クラスタをアップグレード (upgrade、cordon/drain) | 36 |
| etcd のバックアップ/リストア | 37 |
| RBAC：ロールとバインディング | 38 |
| CSR で証明書を発行 / kubeconfig | 39 |
| control plane を直す (static pods) | 15、45 |
| ノードが NotReady (kubelet/runtime/CNI) | 45、30 |
| Service/DNS が動かない (Endpoints、CoreDNS) | 7、31、46 |
| NetworkPolicy | 34 |
| Deployment、スケジューリング、リソース | 5、8、12-14 |
| PV/PVC、StorageClass | 25-26 |

```mermaid
flowchart LR
    core["CKA 準備の中核"]
    core --> tshoot["troubleshooting:<br>アプリケーション (44)、<br>control plane/ノード (45)、<br>ネットワーク (46)"]
    core --> install["kubeadm (35)、<br>upgrade (36)、<br>etcd (37)"]
    core --> sec["RBAC (38)、<br>証明書 (39)"]
    style core fill:#326ce5,color:#fff
    style tshoot fill:#e74c3c,color:#fff
    style install fill:#4a90d9,color:#fff
    style sec fill:#0f9d58,color:#fff
```

## 48.5. タイマー下での troubleshooting 戦略

troubleshooting が 30% なのですから、アルゴリズムを反射になるまで練習してください
（第 44-46 章）：

```mermaid
flowchart LR
    q["troubleshooting の問題"]
    q -->|"Pod が動かない"| pod["get → describe →<br>logs --previous →<br>exec (第 44 章)"]
    q -->|"kubectl が応答しない /<br>コンポーネント"| cp["ノード上で: crictl/journalctl,<br>/etc/kubernetes の<br>マニフェスト (第 45 章)"]
    q -->|"ノードが NotReady"| node["ssh: systemctl/journalctl<br>kubelet, runtime,<br>CNI, swap (第 45 章)"]
    q -->|"ネットワーク/Service"| net["層ごとに: IP → DNS →<br>Endpoints →<br>ポリシー (第 46 章)"]
    style q fill:#f4b400,color:#000
    style pod fill:#0f9d58,color:#fff
    style cp fill:#326ce5,color:#fff
    style node fill:#673ab7,color:#fff
    style net fill:#db4437,color:#fff
```

当て推量はやめて、第 44-46 章の決定木を適用してください。素早い切り分け（どの層 /
どのコンポーネントか）のほうが、まれな細部の知識より重要です。

## 48.6. タイムマネジメントと試験のルール

全体の戦略は CKAD と同じ（第 47 章）：3 周する、重みを見る、詰まらない、確認の時間を
残す。CKA の特性：

- **重い問題（etcd restore、upgrade、インストール）は時間を多く食います** - 間に合うか
  を見積もり、難しい 1 問のために易しい数問を犠牲にしないでください。
- **ノードでの作業のあとは元のコンテキストに戻ってください** - 忘れて次の問題を
  「違う場所で」やってしまいがちです。
- **破壊的な操作（etcd の restore、drain）は確認してください** - 間違えたときの代償が
  大きいです。
- **kubernetes.io のドキュメントは参照可** - kubeadm upgrade、etcd backup、CSR の
  ページを手元に置いておきましょう：正確なコマンドはコピーすると便利です。

```mermaid
flowchart LR
    p1["1 周目: 速く取れる点<br>(RBAC、Pod、Service)"] --> p2["2 周目: 重いもの<br>(etcd、upgrade、install)"] --> p3["3 周目: 確認、<br>とくに破壊的なもの"]
    style p1 fill:#0f9d58,color:#fff
    style p2 fill:#326ce5,color:#fff
    style p3 fill:#673ab7,color:#fff
```

## 48.7. CKA でのミス トップ

```mermaid
flowchart TB
    e1["ノードから戻るのを忘れた →<br>違うコンテキストで<br>問題を解いている"]
    e2["namespace/コンテキストが違う"]
    e3["etcd/upgrade で詰まり、<br>易しい問題を捨てた"]
    e4["違うマニフェストを直した /<br>static pod が起動したか<br>確認しなかった"]
    e5["確認なしの破壊的操作<br>(restore、drain)"]
    e6["基本を暗記せず<br>docs で探している"]
    e1 ~~~ e2 ~~~ e3 ~~~ e4 ~~~ e5 ~~~ e6
    style e1 fill:#db4437,color:#fff
    style e2 fill:#db4437,color:#fff
    style e3 fill:#db4437,color:#fff
    style e4 fill:#db4437,color:#fff
    style e5 fill:#db4437,color:#fff
    style e6 fill:#db4437,color:#fff
```

## 48.8. CKA の前の最終チェックリスト

- [ ] kubeadm init/join ができ、ノード準備の手順を知っている（第 35 章）；
- [ ] cordon/drain/uncordon を伴うクラスタの upgrade ができる（第 36 章）；
- [ ] etcd snapshot save/restore のコマンドを暗記している（第 37 章）；
- [ ] RBAC を確実に作成し、`auth can-i --as` で確認できる（第 38 章）；
- [ ] CSR の approve と kubeconfig の設定ができる（第 39 章）；
- [ ] マニフェスト + crictl/journalctl で control plane を直せる（第 15、45 章）；
- [ ] SSH でノードの NotReady を切り分けられる（第 45 章）；
- [ ] ネットワークを層ごとにデバッグでき、Endpoints/DNS を理解している（第 46 章）；
- [ ] alias/補完/vim を設定し、反射でコンテキストを切り替えられる（第 47 章）；
- [ ] タイマー付きでモック試験を通した。

```mermaid
flowchart LR
    know["知識 (第 1-46 章)"] --> tactics["戦術 (第 47-48 章)"] --> mock["タイマー付きのモック"] --> pass["CKA 合格"]
    style know fill:#326ce5,color:#fff
    style tactics fill:#0f9d58,color:#fff
    style mock fill:#f4b400,color:#000
    style pass fill:#673ab7,color:#fff
```

## 48.9. ミニ用語集

- **troubleshooting ドメイン** - CKA の 30%、もっとも比重が大きい；アプリケーション/
  クラスタ/ネットワークを直すこと。
- **ノード上での作業** - SSH + systemctl/journalctl/crictl/etcdctl（CKA の特性）。
- **3 周する** - 時間の戦略（易しい → 重い → 確認）。
- **破壊的な操作** - etcd の restore、drain：とくに確認すること。
- **コンテキストに戻る** - ノードでの作業のあと、元のマシンで続けること。
- **モック試験** - 自動採点付き、タイマー下でのリハーサル。

## 48.10. 本章のまとめ

- CKA は形式上は CKAD と同じ（2 時間、約 17 問、66%、部分点あり）ですが、
  troubleshooting (30%) と管理業務に寄っています - kubectl の外、SSH でのノード上の
  作業が多いです。
- 時間は重みに応じて：troubleshooting + cluster architecture で試験の 50% 超なので、
  そこに主な焦点を置きます。
- 環境の準備は同じ（第 47 章）+ ノード上での SSH/systemctl/journalctl/crictl/
  etcdctl への備え；ノードでの作業のあとは元のコンテキストに戻ること。
- 主要な問題：kubeadm の install/upgrade、etcd の backup/restore、RBAC、CSR、
  control plane とノードの修復、ネットワークのデバッグ - 48.4/48.5 のマップで復習を。
- Troubleshooting は当て推量ではなく決定木で解きます（第 44-46 章）。
- タイムマネジメント：3 周する、重いもの（etcd/upgrade）で詰まらない、破壊的な操作は
  確認する。

## 48.11. これがどう役に立つか：試験と実際の仕事で

**試験で (CKA)。** この章は、すべてを合格の戦略にまとめたものです：重みに応じた時間の
配分、ノード上で作業する備え、troubleshooting の決定木、そしてチェックリスト。第 47 章
（共通の戦術）と第 1-46 章の知識と合わせて、これが合格点をもたらします。

**実際の仕事で。** CKA のスキルは、そのまま管理者/SRE の日常業務です：クラスタを立てて
アップグレードし、etcd をバックアップし、アクセス権を設定し、落ちた control plane や
ノードを直し、ネットワーク障害を切り分ける。試験は本番でやることをそのまま問います -
だからこそ CKA の準備は、エンジニアとしてのあなたの価値を直接高めます。

## 48.12. 自己チェックの質問

1. CKA の戦術は CKAD とどう違いますか。なぜノード上で作業する備えが重要なのですか？
2. 2 時間をドメインごとにどう配分し、準備の主力をどこに投じますか？
3. ノード上ではどのツールが必要で、なぜ元のコンテキストに戻るのを忘れてはいけないのですか？
4. CKA の配点の高い主要な問題と、その復習に使う章を挙げてください。
5. タイマー下で troubleshooting の問題を素早く切り分けるにはどうしますか？
6. なぜ破壊的な操作（etcd の restore、drain）はとくに確認が必要なのですか？
7. あなたの最終チェックリストで、まだ反射になるまで練習できていないものは何ですか？

## コースの結び

おめでとうございます - CKA + CKAD の合同コースを最後まで走り抜けました。クラスタの
アーキテクチャとワークロードから、ネットワーク、ストレージ、セキュリティ、管理、
troubleshooting まで Kubernetes を解きほぐし、両方の試験の戦術も知っています。残るは
いちばん大事なこと - **手** です：コマンドが反射になるまで、タイマー付きでラボと
モック試験を通してください。知識 + 練り上げた速さ = CKA と CKAD の合格です。

一方の試験に的を絞って準備するには、ガイドを使ってください：
[CKA](../CKA_JP.md) · [CKAD](../CKAD_JP.md)。

🧪 ラボ 119（速度と JSONPath のドリル）: [tasks/cka/labs/119](../../labs/119/README_JP.MD)

🧪 CKA のモック試験: [tasks/cka/mock](../../mock)

---
[目次](../README_JP.md) · [第 47 章](../47/jp.md)
