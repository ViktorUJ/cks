[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 115 - Cilium bootstrap、kube-proxy replacement、Mutual Authentication

> **Advanced / production track。正式な CKS Core exam の要件には含まれません。**
> この実習は CKS の試験範囲を超えており、production のスキルとして有用です：
> Cilium を、kube-proxy の完全な代替としてゼロからインストールすることと、SPIRE を基盤とする
> Cilium Mutual Authentication です。試験の準備のみを行う場合は、実習 101-114 を優先してください。

## 概要

この実習の control-plane は `kubeadm init --skip-phases=addon/kube-proxy` で立ち上げられており、`kube-proxy` の
DaemonSet も、**CNI もインストールされていません**。Node は、あなた自身が Cilium をインストールするまで `NotReady` のままです。
これは意図的なものです：この実習全体が、kube-proxy の完全な代替 (`kubeProxyReplacement`) としての Cilium の手動インストール、
WireGuard の transparent encryption の段階的な有効化、SPIRE を基盤とする Cilium Mutual Authentication を扱います。
各ステップは、すでに用意されたものとして渡されるのではなく、個別にインストールして確認します。

`cilium`/`hubble` CLI はすでに worker にインストールされており、実際のクラスター
(`~/.kube/config`) を指していますが、クラスターへの Cilium のインストール自体はあなたが行います。

## デプロイ

```bash
TASK=115 make run_cks_task
```

デプロイ後、Terraform の出力 (`worker_pc_ssh`) にあるコマンドで SSH 接続します。
ログイン直後の Node は `NotReady` になります - これは想定される baseline であり、エラーではありません。

## 目的

すでに起動している kube-proxy なしの kubeadm クラスターに、Cilium を kube-proxy の完全な代替としてインストールし、
WireGuard encryption を有効にし、Cilium Mutual Authentication (SPIRE) を有効にして、
2 つの namespace 間で mutual authentication の成功を要求する `CiliumNetworkPolicy` を書きます。

## インフラ

| コンポーネント | 用途 |
| ----- | ----- |
| control-plane EC2 | 実習の提供時点で、kube-proxy も CNI もない kubeadm クラスター |
| `ingress-115` | mutual authentication を通る必要がある client の namespace |
| `app-115` | `authentication.mode: required` を持つ CiliumNetworkPolicy で保護された backend の namespace |
| worker EC2 | `cilium`/`hubble` CLI、設定済みの kubeconfig |

## 課題

---

|           **1**           | **Baseline: kube-proxy なし、CNI なし** |
| :-----: | :----- |
|       やること       | • 何かをインストールする前に、クラスターの現在の状態を確認します |
| 受け入れ基準 | • `kube-proxy` の DaemonSet が存在しない<br/>• Cilium のインストール前に、最初の `NotReady` が観察される<br/>• Checker は、すべての課題の完了後、過去の `NotReady` ではなく、kube-proxy の不在と API の利用可能性を確認する |
|        検証        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`。`kubectl get nodes` -> `NotReady` (CNI なし)。 |

---

|           **2**           | **kube-proxy の代替としての Cilium のインストール** |
| :-----: | :----- |
|       やること       | • worker にインストールされている `cilium` CLI バージョン `v0.19.7` で、Cilium の agent/chart バージョン `1.20.1` を、`kubeProxyReplacement=true` と、本物の API server を指す明示的な `k8sServiceHost`/`k8sServicePort` (Service の ClusterIP ではありません - kube-proxy がないと、Cilium 自身が起動するまで、ClusterIP `kubernetes.default` への通信は API server に届きません) でインストールします |
| 受け入れ基準 | • `KubeProxyReplacement: True/Strict` (agent の `cilium-dbg status` で)<br/>• Node が `Ready` になる<br/>• ClusterIP Service に kube-proxy なしで到達できる |
|        検証        | `cilium status --wait`、`kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`、続いて `kubectl get nodes` -> `Ready`。テスト用の Pod から：`curl https://kubernetes.default.svc.cluster.local/` が HTTP response (connection error ではない) を受け取る必要があります。 |

---

|           **3**           | **WireGuard transparent encryption** |
| :-----: | :----- |
|       やること       | • すでにインストールされた Cilium の上で `encryption.enabled=true`、`encryption.type=wireguard` を有効にします (`cilium upgrade` で、ゼロからの再インストールではありません) |
| 受け入れ基準 | • `cilium-dbg status` に `Encryption: Wireguard` があり、Cilium ConfigMap に `enable-wireguard: "true"` がある<br/>• 課題 2 の経路がリグレッションしていない<br/>• シングルノードの環境は、有効化された WireGuard の設定を確認できるが、暗号化されたノード間トラフィックは実証しない (Peers: 0) |
|        検証        | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`。課題 2 の curl を繰り返します - 再び HTTP response を受け取る必要があります。 |

---

|           **4**           | **Cilium Mutual Authentication (SPIRE)** |
| :-----: | :----- |
|       やること       | • Cilium の helm chart 自体を通じて、組み込みの SPIRE のインストールを有効にします：`authentication.mutual.spire.enabled=true`、`authentication.mutual.spire.install.enabled=true` |
| 受け入れ基準 | • `spire-server` の StatefulSet と `spire-agent` の DaemonSet が、namespace `cilium-spire` で要求されたすべての Ready な replicas を持つ |
|        検証        | `kubectl get pods -A \| grep spire` - 両方の種類の Pod が `Running` かつ Ready の状態である。 |

> **環境の特記事項。** クラスターには StorageClass がないため、SPIRE サーバーには一時的な
> ストレージが必要です (`authentication.mutual.spire.install.server.dataStorage.enabled=false`)。イメージ
> `spire-server` は uid 1000 で動作し、`root:755` の hostPath ディレクトリにソケットを作成できません -
> root で起動してください (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`)。
> また、chart は `authentication.enabled=true` を要求します。詳細は参考解答にあります。

---

|           **5**           | **必須の mutual authentication を持つ CiliumNetworkPolicy** |
| :-----: | :----- |
|       やること       | • `ingress-115` (client) と `app-115` (backend、label `app=backend`、Service `backend`) を作成します<br/>• `app-115` に `CiliumNetworkPolicy backend-auth-required` を作成します：`app=backend` に対する `endpointSelector`、namespace `ingress-115` からの ingress のみ、そしてその ingress ルールに `authentication.mode: required` |
| 受け入れ基準 | • Policy が backend を正確に選択し、`authentication.mode: required` を持つ、TCP/80 での `ingress-115` からの ingress ルールを 1 つだけ含む<br/>• 追加の ingress ルールや迂回経路がない<br/>• 分離された Lab 115 の環境には、backend に影響を与える他の namespaced/global の network policies がない<br/>• Service `backend` が Ready な Pod `backend` を指している |
|        検証        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - `ingress[0]` 内の `authentication.mode: required` を確認します。 |

---

|           **6**           | **Positive/negative control: 認証された identity は許可され、無関係なものは許可されない** |
| :-----: | :----- |
|       やること       | • policy の効果を実際のトラフィックで確認します：`ingress-115` の client は、(SPIRE ベースの mutual auth handshake の成功の後に) `backend` に到達できる必要があります<br/>• 「誤った」namespace (`ingress-115` ではなく `app-115`；backend 自身へのトラフィックは Cilium が常に通します) の別の Pod は、ブロックされる必要があります |
| 受け入れ基準 | • 分離されたミラーの backend では、baseline が両方の client を許可し、policy のコピーを適用した後は `ingress-115` のみが許可される<br/>• 稼働中の backend が、許可された client には応答し、`app-115` と新しい独立した namespace の client は拒否する<br/>• Cilium の BPF auth map に、client/backend の identity の正確なペアについて `spire` が含まれている |
|        検証        | `ingress-115` の client Pod から `http://backend.app-115.svc.cluster.local/` への `curl` -> HTTP response。client の label を持たない `app-115` の Pod からの同じ curl -> connection error。 |

## 検証

```bash
check_result
```

Checker は、稼働中の `app-115/backend-auth-required` を**決して外しません**。baseline の確認のために、使い捨ての namespace `cks-115-*` に一時的なミラーの backend と Service を作成し、まず policy なしで許可されたトラフィックを確認し、その後で確認済みの CiliumNetworkPolicy のコピーをミラーの backend にのみ適用します。実際の backend、EndpointSlice、BPF auth map 内の SPIRE identities の正確なペア、そして無関係な namespace の client の拒否は、別途確認されます。作成されたすべての Pod、Service、policy、一時的な namespace は、cleanup の確認とともに削除されます。

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=115 make delete_cks_task
```
