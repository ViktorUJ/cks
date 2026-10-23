[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 113 - kubeadm による Kubernetes クラスターの upgrade (minor upgrade)

## 目的

この CKS 実習では、`kubeadm` を使って、自己管理型 (self-managed) クラスターの実際の minor-upgrade を行います：
まず control-plane、次に worker ノードを、正しい順序で、すでに動作している workload の
計画外の downtime なしに行います。クラスターは Kubernetes `1.35.x` から始まります；あなたの課題は、両方のノードを
`1.36.x` に移行することです。その際、公式の `kubeadm upgrade` の手順に従い、パッケージリポジトリ
`pkgs.k8s.io` を新しい minor に切り替えます。

## 開始前のセルフチェック

<details>
<summary>1. `kubeadm upgrade` が、任意の順序ではなく、control-plane の upgrade を worker ノードより必ず先に要求するのはなぜか？</summary>

control-plane での `kubeadm upgrade apply` は、API server とその他の control-plane コンポーネントのバージョンを更新します；このバージョンが、クラスターの version skew policy の基準になります。API server に対して新しすぎる kubelet を持つ worker ノードは、サポートされる skew に違反する可能性があります (kubelet は kube-apiserver より新しくてはなりません)。control-plane を先に更新することで、worker が同じバージョンに移行するとき、API server がすでに目的のバージョンになっていることが保証されます - これは任意の推奨事項ではなく、Kubernetes の version skew policy の要件です。
</details>

<details>
<summary>2. patch の更新は切り替えがなくても動作するのに、新しい minor に移行するときは apt リポジトリ `pkgs.k8s.io` の切り替えが必須なのはなぜか？</summary>

`packages.cloud.google.com`/`apt.kubernetes.io` からの移行以降、`pkgs.k8s.io` は、すべてのバージョンを含む単一のリポジトリではなく、**minor バージョンごとに別のリポジトリ** (`core:/stable:/v1.35`、`core:/stable:/v1.36` など) として構成されています。すでに接続されている repo `v1.35` の中では、`1.35.x` の patch リリースしか利用できません。`apt install kubeadm=1.36.x-*` が `1.36` のバージョンを見つけられるようにするには、まず `sources.list.d/kubernetes.list` で repo `core:/stable:/v1.36` を接続する必要があります (変更するのは URL 内のバージョンだけです；署名鍵 `Release.key` を含む keyring は以前のままです)。
</details>

<details>
<summary>3. クラスターの upgrade の前の `kubectl drain` が、単なる「良い習慣」ではなく、具体的に何に対する防御なのか？</summary>

control-plane での `kubeadm upgrade` は、コンポーネント (kube-apiserver、controller-manager、scheduler) の static Pod の manifest を再作成し、どのノードでも kubelet の upgrade にはその restart が必要です - その時点で、ノードは一時的に Pod の status を正しく報告し、新しい Pod を受け付ける能力を失います。`drain` は、この一時的なノードの機能停止がアプリケーションの downtime にならないよう、通常の workload の Pod を事前に他のノードに移します (または evicted とします)。`drain` がないと、更新されるノード上の Pod は、それを補う他のノードへの移動なしに、restart の間利用できなくなる可能性があります。
</details>

## コースとの関連

- [第 13 章 脆弱性に対処するための Kubernetes のアップデート](../../course/13/jp.md)

## インフラ

Terragrunt が `eu-central-1` に、self-managed の Kubernetes `1.35.4`、containerd、
Calico CNI を作成します：

| コンポーネント | 用途 |
|---|---|
| `k8s-1` control-plane | 通常の Pod を許可する通常の control-plane ノード (single control-plane で、専用の 2 つ目の control-plane ノードはなし) |
| `k8s-1` worker `worker1` | 同じ開始バージョンの通常の worker ノード |
| `worker` | `kubectl`、`check_result`、クラスターの両方のノードへの SSH アクセスを備えた作業マシン |

upgrade の目的のバージョンは `1.36.x` (実習の時点で利用可能な最新の patch) で、つまり
課題を終えた後、クラスターは、他の core 実習 101-112 と同じ training baseline のバージョンになります。
minor バージョンのスキップ (たとえば `1.35` → `1.37` への直接の移行) は
kubeadm がサポートしておらず、この実習ではそのような移行は必要ありません。

ノードへのアクセスには、エイリアス `k8s113_controlPlane_1` と `k8s113_node_worker1` を使用します。

Namespace `upgrade-113` には、Deployment `canary` (2 つの replica) がすでにデプロイされています - これは
downtime がないことの指標です。upgrade の全期間を通じて、少なくとも 1 つの replica が
`Available` のままである必要があります；各ノードの `uncordon` の後と最後には、Deployment が
`2/2` に戻る必要があります。Bootstrap は、両方の replica を異なる
ノードに事前に配置し (required `podAntiAffinity`)、`minAvailable: 1` の `PodDisruptionBudget` を作成します。

## デプロイ

```bash
TASK=113 make run_cks_task
```

作業マシンに接続し、用意されたコンテキストを選択します：

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

作業を始める前に、証拠用のディレクトリを作成します：

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## 課題

---
| **1** | **control-plane を目的の minor に upgrade する** |
| :---: | :--- |
| やること | • `k8s113_controlPlane_1` に入ります (`ssh`、続いて `sudo -i`)。<br/>• apt リポジトリ `pkgs.k8s.io` を `core:/stable:/v1.35` から `core:/stable:/v1.36` に切り替えます：`/etc/apt/sources.list.d/kubernetes.list` で、URL 内のバージョンだけを変更します (Kubernetes のドキュメントに記載されているとおりで、keyring は以前のままです)。<br/>• パッケージ `kubeadm` を `1.36.x` に更新し、`kubeadm upgrade plan` を実行してから、`kubeadm upgrade apply v1.36.x` を実行します。<br/>• `apply` が成功した後にのみ、このノードの `kubectl drain` を実行します。<br/>• パッケージ `kubelet`/`kubectl` を `1.36.x` に更新し、`kubelet` を再起動してから、`kubectl uncordon` を実行します。 |
| 受け入れ基準 | • control-plane で、`kubeadm version`、`kubelet --version`、ローカルの `kubectl version --client`、API server のバージョン (`kubectl version`) が `v1.36.x` と報告する。<br/>• control-plane ノード (`kubectl get no` の `<cp-ノード名>`) が `Ready` ステータスである。<br/>• コマンド `kubeadm upgrade apply` の完全な出力 (`SUCCESS` の行と目的のバージョンを含む) が、作業マシンの `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt` に文字どおり保存されている (コマンドはノード上で実行され、出力はノード上のファイルに書き込まれ、その後 `scp` でコピーされる)。 |

<details>
<summary>💡 課題 1 のヒント</summary>

順序は極めて重要です：まず `apt-mark unhold kubeadm` → パッケージを更新 → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`、そして `apply` が成功した後にのみ、`drain` と `kubelet`/`kubectl` の更新を行います。`kubeadm upgrade apply` を呼び出す前に `kubelet` を更新する必要はなく、公式の手順でも推奨されていません。`kubeadm upgrade apply` の出力は、後から記憶で復元するのではなく、ノード上のファイル (`> /tmp/kubeadm-upgrade-apply.txt 2>&1`) に保存してください - テストは、単語 `SUCCESS` を含む文字どおりのテキストを探します。
</details>

---
| **2** | **worker ノードを目的の minor に upgrade する** |
| :---: | :--- |
| やること | • `k8s113_node_worker1` (`ssh`、`sudo -i`) で、同様に `pkgs.k8s.io` を `core:/stable:/v1.36` に切り替え、`kubeadm` を更新します。<br/>• `kubeadm upgrade node` を実行します (`apply` ではありません - それは control-plane 専用のコマンドです)。<br/>• このノードの `kubectl drain` を (ノード自体ではなく、作業マシンから) 実行します。<br/>• `kubelet`/`kubectl` を更新し、`kubelet` を再起動して、`kubectl uncordon` を実行します。 |
| 受け入れ基準 | • worker ノードで、`kubeadm version`、`kubelet --version`、ローカルの `kubectl version --client` が `v1.36.x` と報告する。<br/>• `kubectl get nodes` が、worker ノードについて `kubeletVersion` に `v1.36.x` を、ステータスに `Ready` を示す。<br/>• `kubeadm upgrade node` の出力がノード上のファイルに保存され、`scp` で作業マシンの `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt` にコピーされている。 |

<details>
<summary>💡 課題 2 のヒント</summary>

`kubeadm upgrade node` は、まさに worker ノード (と追加の control-plane ノード) 用のコマンドであり、`kubeadm upgrade apply` は最初の/唯一の control-plane ノード専用です。この課題は、課題 1 が完全に終わり、control-plane がすでに `1.36.x` で `Ready` になった後にのみ始めてください - そうでないと version skew policy に違反します。
</details>

---
| **3** | **正しい upgrade の順序を守る** |
| :---: | :--- |
| やること | • worker ノードの upgrade (課題 2) を始める前に、control-plane の upgrade (課題 1) を、uncordon まで含めて完全に実行します。<br/>• この課題は、クラスター内での個別の操作を必要としません：順序は、checker-owned のクラスターの状態とバージョンの monitor によって自動的に確認されます。 |
| 受け入れ基準 | • Checker-owned の monitor が、初期の `1.35.x` baseline を記録している。<br/>• 次に、worker が `1.35.x` のままで、control-plane の `1.36.x` への完全な移行 (`Ready` と schedulable を含む) が記録され、その後にのみ worker ノードの upgrade の開始が記録される。<br/>• 状態は monitor の再起動後も維持される；baseline がない、または 60 秒を超える観察の途切れは、認められない。 |

<details>
<summary>💡 課題 3 のヒント</summary>

control-plane の前に worker ノードの upgrade をすでに始めている (あるいは終えている) 場合は、立ち止まってください。worker を `1.35.x` のパッケージに戻す (ダウングレードする) 簡単な方法はなく、正しい方法は、control-plane の upgrade を完了させてから、worker ノードの upgrade を続ける/やり直すことです。重要なのは、worker ノードの次の upgrade が (いつ始められても)、control-plane の upgrade が完全に完了した後に行われなければならないことです。`kubectl get node <cp-ノード名>` (`kubectl get no` に表示される control-plane の名前) が `v1.36.x` と `Ready` を示すまで、課題 2 を始めないでください。
</details>

---
| **4** | **既存の workload に downtime がないことを実証する** |
| :---: | :--- |
| やること | • 課題 1-2 を実行している間、作業マシンの別のセッションで、namespace `upgrade-113` の Deployment `canary` の可用性を数秒ごとに問い合わせるループを実行します。<br/>• 各問い合わせの行を、`available=N` を含む形式 (たとえば `available=2`) で `/var/work/tests/artifacts/4/canary-availability.log` に追記します。<br/>• 両方のノードの upgrade の全期間を通じて、問い合わせを続けます。 |
| 受け入れ基準 | • Deployment `canary` が最終的に `2/2` の利用可能な replica を持ち、元の Deployment/PDB と required の Pod anti-affinity が維持されている。<br/>• downtime がないことは、checker-owned の monitor が、まさに `upgrade-113` の Pod Ready と CRI コンテナによって確認する；API/SSH/CRI のエラーはゼロではなく UNKNOWN として扱われる。<br/>• 受講者のファイル `/var/work/tests/artifacts/4/canary-availability.log` に、形式 `<unix_timestamp> available=N` または `<unix_timestamp> available=api-unreachable` の行が少なくとも 2 つあり、control-plane の upgrade の前と、worker の upgrade の開始後の観察を含んでいる。 |

<details>
<summary>💡 課題 4 のヒント</summary>

問い合わせのループの例です。課題 1-2 を実行している間ずっと、別のターミナル/`screen`/`tmux` で動かしたままにできます：`while true; do if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`。Deployment が一時的にすべての replica を失った場合は、`kubectl get pods -n upgrade-113 -o wide` と、連続する drain が PDB と required の anti-affinity を守っているかを確認してください。
</details>

## 検証

```bash
check_result
```

チェックには `0 Init` と 5 個の必須テストが含まれます。テスト 1-2 は、control-plane と worker ノードそれぞれで、
`kubeadm`/`kubelet`/ローカルの `kubectl` のバージョンと `Ready` ステータス、
および `kubeadm upgrade` の出力を含む文字どおりの evidence ファイルを確認します。テスト 3 は、
ファイルの更新時刻ではなく、checker-owned のクラスターの状態の monitor によって upgrade の順序を確認します。
テスト 4 は、同じ checker-owned の monitor を信頼できる情報源 (source of truth) として、workload `canary` に停止がなかったことを確認します。
テスト 5 は、両方のノードが実際に目的のバージョンになっており、`cordon` の状態のまま
残されていないことの最終確認です。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=113 make delete_cks_task
```
