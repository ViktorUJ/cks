[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 105 - System Hardening OS と Docker daemon のセキュリティ

## 目的

この CKS 実習では、2 台の Linux ホストの攻撃対象領域を減らします。Kubernetes の
control-plane では、不要なサービスを無効にし、開いているポートを閉じ、firewall を設定し、
kubeconfig を保護し、SSH での直接の root login を禁止する必要があります。別の `docker-host` では、
Docker daemon の 3 つの危険な設定を解消する必要があります：TLS なしの TCP API、グループ `docker` 経由の
`docker.sock` へのアクセス、そしてユーザー `developer` のこのソケットへのアクセスです。

この学習環境は意図的に安全でない状態で作られています。初期設定を production に
持ち込まないでください：TLS なしの TCP/2375 の Docker API は、ポートに接続できる人なら誰にでも
リモートの root アクセスを与えてしまいます。

## 開始前のセルフチェック

<details>
<summary>1. `systemctl disable` は `systemctl stop` と何が違うか、そして課題 1 でなぜ両方が必要なのか?</summary>

`stop` は、すでに起動しているプロセスを今すぐ停止しますが、次回のシステム起動時の自動起動には影響しません。`disable` は、サービスを自動起動から外します (unit ファイルはもう target に紐づいていません) が、すでに動作しているプロセスは停止しません。攻撃対象領域を完全に塞ぐには両方が必要です - そうしないと、サービスが今も動き続けるか、reboot の後にまた起動してしまいます。
</details>

<details>
<summary>2. TLS なしの TCP Docker API (`-H tcp://0.0.0.0:2375`) が、リモートの root アクセスと等価なのはなぜか?</summary>

Docker daemon は root 権限で動作し、その API には、TLS client certificates がなければ built-in の authentication がありません。このポートにネットワーク経由で接続できる人は誰でも、`--privileged` とマウントしたホストのファイルシステムを持つ任意の container を起動でき、SSH やその他のあらゆるアクセス制御の仕組みを迂回して、ホストの完全な制御を得られます。
</details>

<details>
<summary>3. ファイルシステム上ですでに root だけがアクセスできるとしても、kubeconfig の `chmod 600` が重要なのはなぜか?</summary>

`/etc/kubernetes/admin.conf` には `cluster-admin` 権限を持つ client certificate が含まれています - ファイルのモードが広すぎる場合 (たとえば `644`、全員が読み取り可能)、このノード上の任意のユーザーが、sudo がなくても credential を読み取り、ノード上で権限昇格をする必要すらなく、リモートからクラスターへの完全な管理アクセスを得られます。
</details>

<details>
<summary>4. secret がディスクに書き込まれたことがなくても、プロセスの core dump から secret が漏れる可能性があるのはなぜか?</summary>

Core dump は crash した時点のプロセスのメモリイメージで、平文のまま保持されている復号済みの変数の値、private key、token を**含む可能性があります**。これがプロセスのメモリ全体であるとは限りません：マッピングの集合は `/proc/<pid>/coredump_filter` に依存し、個別の領域は、たとえば `MADV_DONTDUMP` などで除外されることがあります。そのため、アプリケーションが secret をファイルに明示的に書き込むことがなくても、crash dump は、含まれているマッピング内にあった secret を、読み取り可能なファイルとしてディスクに保存する可能性があります。
</details>

## コースとの関連

- [第 14 章。ホスト OS の footprint の最小化と runtime デーモンのセキュリティ](../../course/14/jp.md)
- [第 15 章。ホスト上の Least-privilege と外部アクセスの最小化](../../course/15/jp.md)
- [CKA: systemd、サービス、Linux](../../../cka/course/00-5-linux/jp.md)
- [CKA: コンテナと runtime](../../../cka/course/00-4-containers/jp.md)

## インフラ

環境は Terragrunt により AWS `eu-central-1` に展開されます：

| コンポーネント | 用途 |
|---|---|
| `vpc` | 2 つのパブリックサブネットを持つ VPC `10.10.0.0/16` |
| `ssh-keys` | 内部接続用の SSH キー |
| `k8s-1` | シングルノードの kubeadm クラスター Kubernetes `1.36.0`、containerd、Calico；これが対象の control-plane |
| `docker-host` | Docker を備え、意図的に安全でない構成になっている別の Ubuntu 22.04 |
| `worker` | `kubectl`、SSH 設定、`check_result` を備えた作業マシン |

`worker` は、Kubernetes の node name で control-plane に、また名前 `docker-host` で別の
ホストに SSH アクセスできます。Docker は Kubernetes クラスターの runtime ではありません：課題 6 の
設定は `docker-host` に分離されています。

## デプロイ

```bash
TASK=105 make run_cks_task
```

`worker` に接続し (kubectl のコンテキストはすでに設定済みです)、control-plane
ノードの名前を確認してから、各ホストに入ります：

```bash
kubectl get no
ssh <ノード名 (出力から)>
ssh docker-host
```

便利なコマンド：

```bash
time_left
check_result
```

確認用の成果物は `/var/work/tests/artifacts/<番号>/` に保存してください。この実習のための
Kubernetes manifest を作成する必要はありません。

## 課題

---
| **1** | **不要なサービスを無効にする** |
| :---: | :--- |
| やること | control-plane で `cks-lab105-unused.service` を無効にして停止します。このサービスは Kubernetes の動作には不要で、reboot 後に起動してはなりません。 |
| 受け入れ基準 | `systemctl is-enabled cks-lab105-unused.service` が `disabled` を返し、`systemctl is-active` が `inactive` を返す；`/var/work/tests/artifacts/1/service.txt` に行 `disabled inactive` がある。 |

<details>
<summary>💡 課題 1 のヒント</summary>

コマンドの順序：`sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - 両方のステップが必要で、どちらか一方がもう一方の代わりになることはありません (上のセルフチェックの質問 1 を参照)。成果物には、まさに "disabled inactive" という行 (この順序で、スペース区切り) が含まれている必要があります - 保存する前に形式を確認してください。
</details>

---
| **2** | **不要な開いているポートを閉じる** |
| :---: | :--- |
| やること | control-plane で、`cks-lab105-port.service` が作成した TCP/8080 の listener を解消します。サービスを無効にして停止します (両方の操作が必須です - セルフチェックの質問 1 を参照)；これは control-plane にも kubelet にも不要です。 |
| 受け入れ基準 | `ss -ltn` に TCP/8080 が表示されない；`systemctl is-enabled cks-lab105-port.service` が `disabled` を返し、`systemctl is-active` が `inactive` を返す；`/var/work/tests/artifacts/2/service.txt` に行 `disabled inactive` が含まれる；`/var/work/tests/artifacts/2/port-8080.txt` に `tcp/8080: closed` が含まれる。 |

<details>
<summary>💡 課題 2 のヒント</summary>

まず、どのプロセスがポートを保持しているか (`sudo ss -ltnp | grep 8080`) を調べ、それが本当に `cks-lab105-port.service` であり、他の何かではないことを確認してください。この課題では、ポートを firewall (課題 3) で閉じるだけでは不十分です - テストは、listener が外部からブロックされているだけでなく、listener 自体が存在しないことを確認します。
</details>

---
| **3** | **firewall で受信トラフィックを制限する** |
| :---: | :--- |
| やること | • UFW を有効にする前に、ノードの役割、worker の source IP、node の InternalIP、`spec.podCIDR` を記録します。<br/>• **firewall の前の必須の baseline:** worker から TCP/10250 (kubelet HTTPS endpoint) の baseline プローブを記録します - ポートへのネットワーク到達性を示す実際の `CURL_EXIT`/`HTTPCODE` を持つ `curl` (401/403 を含む任意の 1xx-5xx は到達性とみなされます - kubelet API が実際に応答したためです)。このステップがないと、post-hardening の「ブロックされた」を、UFW の前からポートをブロックしていた無関係な障害 (security group、routing) と区別できません。あなたの記録とは別に、checker は、これを独自の bootstrap-baseline と独立して照合します。それは、実習の提供の前に、保護されたディレクトリ `/var/lib/cks-lab105-checker` (`0711 root:root`、デフォルトで全員が書き込み可能な `/var/work/tests` とは別) に記録されたものです。<br/>• トポロジー：シングルノードの control-plane + workload node。必要なルールはちょうど 5 つです：loopback、worker からの SSH recovery、worker から、ノード自身から、Pod CIDR からの API `6443/tcp`。etcd/scheduler/controller-manager はローカルのフローを使用し、このトポロジーにはノード間の CNI/kubelet フローはありません。<br/>• firewall はコマンド `ufw` (allow/deny/reject/limit/route、その後 enable/reload) のみで管理します。`/etc/ufw/before*.rules`、`after*.rules`、`user.rules`、`user6.rules` を手動で編集しないでください：framework ファイル (before/after) は bootstrap-baseline とハッシュで照合され、`user.rules`/`user6.rules` (ufw があなたのルールを書き込む場所) は、ファイルだけでなく、カーネルの実際の状態 (`ufw show user-rules`) を通じて確認されます。<br/>• `ufw default deny incoming` の前に、source を限定した allow ルールを追加します。広い `ALLOW Anywhere` を使わず、これら 5 つ (loopback + source を限定した 4 つ) 以外のルールは、deny/reject/route を含め一切追加しないでください。<br/>• UFW を有効にし、`/var/work/tests/artifacts/3/` に保存します：`ufw status`、`ufw show added` (追加されたルールの正規化された表現 - 必ずしも元の形式/コマンドの順序ではありません)、preflight (TCP/10250 の baseline を含む)、recovery コマンド。<br/>• **`ufw reload` の後の必須の retest:** `sudo ufw reload` を実行し、同じ確認をすべて繰り返します (readyz、node Ready、calico-node Ready、Pod DNS、Pod→API、worker→kubelet:10250 deny、effective な UFW ルール数)。enable の直後にはメモリ上でのみ機能し、reload を生き残らないルールは、正しい解決策とはみなされません。 |
| 受け入れ基準 | • **TCP/10250 の baseline:** checker-owned の bootstrap-baseline (実習の提供の前に `/var/lib/cks-lab105-checker` に記録され、ディレクトリは `/var/work/tests` の外の `0711 root:root`、ファイルは `0444 root:root`) が、TCP/10250 の初期の到達性を確認する；UFW の前のあなた自身の baseline プローブが保存されており、実際のネットワーク到達性 (`CURL_EXIT=0`、HTTP `1xx-5xx`) を示している。baseline の時点でポートがすでに到達不能な場合、課題の結果は PASS ではなく `inconclusive` となる。<br/>• **UFW とルールの正確な集合：** UFW が active で、default-deny である；`ufw show added` にちょうど 5 行が含まれる：loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`。任意のアクション (`allow`/`deny`/`reject`/`limit`/`route`) の余分なルールが 1 つもなく、5 つのうち欠けているものもない。<br/>• **Framework ファイル：** `/etc/ufw/before*.rules`/`after*.rules` のハッシュが、checker-owned の bootstrap-baseline と異ならない (ルールは `ufw` を通じてのみ追加され、framework ファイルは手動で編集されない)。<br/>• **カーネルの実際の状態：** `sudo ufw show user-rules` (`iptables -L` による実際の `ufw-user-*` chains) が、期待される 5 つのルールと意味的に一致する - 数だけでなく、各ルールの source/interface/protocol/port が、`enable` の後と `reload` の後の両方で確認される。`ufw6-user-input` は、ちょうど 1 行のまま残る - loopback ACCEPT の v6 版 (`ufw allow in on lo` は、明示的な IP のない interface ベースのルールであるため、v4 と v6 の両方のルールを同時に作成する；「完全に空」ではない)。これは、tuple metadata なしの `user.rules`/`user6.rules` の直接の編集 (`ufw show added` にも `before/after` のハッシュにも反映されない) や、行数を変えないまま、すでに宣言されたルールを拡大すること (たとえば、`node_ip`→`6443/tcp` が、こっそり `node_ip`→`any` に置き換えられる) を検出する。<br/>• **クラスターの健全性：** `/readyz=ok`；期待されるノードとすべての `calico-node` Pod が `Ready` のままである；`health-probe` が Ready のままで、DNS を解決し、Kubernetes Service に到達する。<br/>• **kubelet のブロック：** UFW の後、worker は kubelet `10250` に到達しない (`HTTPCODE=000`、transport の deny) - 実証された baseline に対するリグレッションとして。<br/>• **reload 後の Retest:** **明示的な `sudo ufw reload` の後も、同じ確認がすべて再び通る**：readyz/node/calico-node/DNS/Pod→API が健全なままで、worker→kubelet:10250 が reload の前と同じ deny の契約でブロックされたままであり、カーネル内の実際のルール数が再び宣言的なものと一致する。<br/>• **成果物：** 成果物に recovery のコマンド (`ufw disable`、確認、修正、再有効化) が含まれている。 |

<details>
<summary>💡 課題 3 のヒント</summary>

ここで最も危険な間違いは、worker の IP からの SSH の allow ルールを追加する前に `ufw enable` (default-deny) を有効にすることです。順序は次のとおりでなければなりません：まず必要なすべての `ufw allow from <IP> to any port <port>`、その後でのみ `ufw --force enable`。firewall での作業中は、現在の SSH セッションを開いたままにしてください - アクセスを失うと、recovery 用の 2 つ目のセッションは接続できません (下の警告を参照)。UFW を有効にする前の TCP/10250 の baseline プローブを忘れないでください - それがないと、post-hardening の「ブロックされた」は何も証明しません：ポートはもっと前から、まったく別の理由 (たとえば AWS security group) で到達不能だったかもしれず、その場合 UFW はまったく無関係です；さらに、checker には、実習の提供の前に別の保護されたディレクトリに記録された独自の baseline があるため、この記録を後から偽造することはできません。allow-set は厳密に `sudo ufw show added` で確認してください (`ufw status` だけでなく) - そこにはちょうど 5 行があり、余分な行 (広い `ALLOW Anywhere` や追加のポートなど。これは新しい allow だけでなく `allow`、`deny`、`reject`、`limit`、`route` の任意のアクションに当てはまります) も、不足している行もあってはなりません。firewall はコマンド `ufw` のみで管理してください - `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules` を手動で編集しないでください：framework ファイルはハッシュで照合され、`user.rules`/`user6.rules` の実際の状態は、checker が `ufw-user-*` chains の実際の iptables ルール (`sudo ufw show user-rules`) を通じて直接確認するため、正しい `### tuple ###` コメントのない `user.rules` の編集であっても、`ufw reload` の後に検出されます。そして、最後に `sudo ufw reload` を実行して、すべての確認を繰り返すのを忘れないでください - `enable` の直後にしか機能せず、`reload` を生き残らないルールは、認められません。
</details>

> **まず Recovery。** 完全な確認が終わるまで、現在の SSH セッションを開いたままにしてください。API が
> 消えた場合は、そこから `sudo ufw disable` を実行し、allow ルールを修正してから、
> firewall を再度有効にします。SSH がすでに失われている場合は、プロバイダーの console/recovery channel を使用してください；
> 広い `allow from any` で状況を「治そう」としないでください。
>
> **適用範囲の限界。** この UFW の allowlist は、シングルノードの fixture のみを想定しています。
> multi-node クラスターにそのまま持ち込んではいけません：default-deny の前に、
> kubelet とノード間のフロー、CNI overlay、BGP/VXLAN/WireGuard、LoadBalancer/NodePort、および
> 具体的なトポロジーに対する provider の firewall/security groups を洗い出す必要があります。
>
> **Lab-specific exception: Calico node 上の UFW。** Calico の公式要件ドキュメントは、
> Calico のノードでは firewalld やその他の iptables manager を無効にすることを明確に推奨しています。
> Calico 自身が設定するルールと競合する可能性があるためです。UFW も同様の iptables/nftables manager です。
> この実習が control-plane で UFW を意図的に残しているのは、host firewall hardening の練習 (CKS の試験範囲の独立したスキル) のためであり、
> production で Calico と host firewall を両立させる推奨の方法としてではありません -
> そのために Calico は独自の `HostEndpoint`/`GlobalNetworkPolicy` を提供しています。まさにこのため、課題は
> 制御された baseline → `ufw enable` → retest の手順を明示的に求め、`calico-node` と Kubernetes の
> 接続性全体が正常なままであることを確認させます (`ADVERSARIAL_ACCEPTANCE_STANDARD.md` を参照)。

---
| **4** | **kubeconfig のパーミッションを修正する** |
| :---: | :--- |
| やること | control-plane で、cluster-admin の credential を含む `/etc/kubernetes/admin.conf` を保護します：所有者とグループは `root:root`、モードは `600` である必要があります。 |
| 受け入れ基準 | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` が `root root 600` を返す；同じ値が `/var/work/tests/artifacts/4/admin-conf.txt` に保存されている。 |

<details>
<summary>💡 課題 4 のヒント</summary>

1 つのコマンドですべて解決します：`sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`。直後に自己確認してください - あなた自身が `KUBECONFIG=/etc/kubernetes/admin.conf` を通じてこのファイルをユーザー `ubuntu` として使っている場合、読み取りアクセスは失われますが、それは想定どおりです - 日常の作業には別の kubeconfig を使用してください。
</details>

---
| **5** | **SSH での root login を禁止する** |
| :---: | :--- |
| やること | control-plane で `/etc/ssh/sshd_config` に `PermitRootLogin no` を設定し、`sshd -t` で構文を確認して、SSH を安全に再読み込みします。connection context なしの単なる `sshd -T` ではなく、コマンド `sshd -T -C "user=root,addr=<あなたの IP>,laddr=<ノードの IP>,lport=22"` で、root の接続に対する effective な値を確認してください。 |
| 受け入れ基準 | root の connection context に対する `permitrootlogin` の effective な値が `no` である；`/var/work/tests/artifacts/5/sshd.txt` に `PermitRootLogin no` が含まれている。 |

<details>
<summary>💡 課題 5 のヒント</summary>

`sshd -T` は effective な設定を表示しますが、connection context (`-C`) がないと、`Match` ブロック (`Match User`/`Match Address`/`Match Group` など) はまったく適用されません - `sshd(8)` の man ページは、`Match` ルールがテストモードで適用されるのは "only when the connection parameters are supplied via one or more `-C` options" の場合だけだと明記しています。そのため、`-C` なしの `sshd -T` は、設定のメインブロックの `permitrootlogin no` を表示することがありますが、より具体的な `Match` ブロック (たとえば `Match Address <管理者の IP>` や `Match User root`) が、実際の接続に対して root login を許可している可能性があります。`sshd -T -C "user=root,addr=<IP>,laddr=<ノードの IP>,lport=22"` で確認してください - これは実際の root の着信接続をシミュレートし、最終的な値を表示する前に `sshd` にすべての該当する `Match` ブロックを適用させます。`systemctl reload sshd` の前に、必ず現在の SSH セッションを開いたままにし、変更前にすでに認証されていたセッションではなく、新しいセッションから確認してください。
</details>

---
| **6** | **`docker-host` 上の Docker daemon への安全でないアクセスを塞ぐ** |
| :---: | :--- |
| やること | • 別の `docker-host` で、Docker API の TCP/2375 での公開をやめます：学習用の systemd override から `-H tcp://...` を削除し、unix-socket 経由のアクセスだけを維持します。<br/>• `/var/run/docker.sock` を `root:root` でモード `660` に設定します；restart 後も維持されるよう、`docker.socket` の override でこれを設定します。<br/>• `developer` をグループ `docker` から削除します。<br/>• 修正後は、必ず `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` を実行します - これは、設定がデーモンの再起動を生き残ることの証明であり、期待される状態に一時的に一致しているだけではないことを示します。<br/>• restart 後、Docker が単に停止しているのではなく、実際に動作していること (`sudo docker version`) を確認します。 |
| 受け入れ基準 | • **restart 後に Docker が動作する：** `daemon-reload` + restart の後、`docker.service` と `docker.socket` が `active` 状態で、`sudo docker version`/`sudo docker info` が成功する (positive control - Docker が実際に動作しており、単に「停止しているので 2375 が閉じている」のではない)。<br/>• **TCP API がない：** TCP/2375 に listener がない。restart 後、Docker API はどのポートにも TCP listener を持たない：effective な `docker.service` に TCP の `-H/--host` がなく、`docker.socket` に TCP の `ListenStream` がない；唯一の API endpoint は Unix socket `/var/run/docker.sock` である。<br/>• **ソケット：** `stat -c '%U %G %a' /var/run/docker.sock` が `root root 660` を返す；永続的な `docker.service`/`docker.socket` の override (`systemctl cat` 経由) に `-H tcp://` が含まれず、`SocketGroup=root`/`SocketMode=0660` が設定されている。<br/>• **ユーザー `developer`:** グループ `docker` に属さず、`sudo -u developer docker ps` がアクセスエラーで終了する。<br/>• **成果物：** `/var/work/tests/artifacts/6/docker-tcp.txt`、`/var/work/tests/artifacts/6/docker-socket.txt`、`/var/work/tests/artifacts/6/developer-access.txt` を作成し、それぞれ行 `tcp/2375: closed`、`root root 660`、`developer docker ps: denied` を含める。 |

<details>
<summary>💡 課題 6 のヒント</summary>

グループ `docker` のメンバーシップは、事実上 root と同等です - `docker.sock` にアクセスできる任意のプロセスは、`--privileged` の container を通じてホストのファイルシステムをマウントできます。`developer` がグループから削除されたことを確認するには、`groups developer` だけでは不十分です - グループのメンバーシップの変更は**新しい** login セッションに適用されるため、すでに開いている `developer` のセッションではなく、新しいコマンドで `sudo -u developer docker ps` を通じて確認してください。最初の確認が成功した時点で止まらないでください - 両方の unit (`docker.socket`、`docker.service`) の `daemon-reload` と `restart` を実行し、確認をもう一度繰り返してください：この手順がないと、単に Docker を一時的に停止しただけで課題を通ってしまうことがあります (その場合、2375 が閉じているのは `-H tcp://` が削除されたからではなく、デーモンがそもそも動いていないからです) - さらに、restart の後に `sudo docker version` が動作することも確認してください。これは、Docker が単に「停止している」のではなく、実際に機能していることの証明になります。
</details>

---
| **7** | **未使用のカーネルモジュールのロードを禁止する (`modprobe` blacklist)** |
| :---: | :--- |
| やること | • control-plane では、モジュール `sctp` がロードされていますが、この実習では kubeadm、containerd、Calico のいずれにも必要ではありません。アンロードを試みます (`sudo modprobe -r sctp`)。<br/>• **すでに稼働中のクラスターではアンロードが失敗することがあり、それはエラーではありません：** プロトコルのカーネルモジュールは、ロード時に存在していた各 netns に対して、永続的な per-network-namespace の参照を受け取ります。そしてこのノードではすでに Pod (calico、coredns など) が動作しています；それらを停止することは課題の範囲に含まれません。<br/>• `/etc/modprobe.d/60-cks-sctp.conf` で、ディレクティブ `blacklist sctp` と `install sctp /bin/true` により、再ロードを禁止します。<br/>• 脅威モデルの制約：両方のディレクティブは `modprobe` のレベル (alias resolution と dependency loading) で作用します - これはカーネルの絶対的な防御ではありません。`insmod` はカーネルの syscall を通じて直接モジュールを挿入し、`modprobe.d` を読み取りませんし、`modprobe --ignore-install` は、適切な host-level のアクセスがあれば `install` の override を迂回できます。ノードの root 所有者にとってはこれは想定内です：目的は通常のロード経路 (`modprobe sctp`、protocol へのアクセス時の alias による自動ロード) を排除することであり、すでにノード上で root を持っているユーザーから守ることではありません。<br/>• `modprobe --show-config` が effective な override を表示すること、および直接の `modprobe sctp` がモジュールの状態を変えないことを確認します。 |
| 受け入れ基準 | • **ファイル：** `/etc/modprobe.d/60-cks-sctp.conf` に `blacklist sctp` と `install sctp /bin/true` の両方の行が含まれている。<br/>• **Effective な設定：** `modprobe --show-config \| grep sctp` が `install sctp /bin/true` を表示する。<br/>• **モジュールの状態：** 直接の `modprobe sctp` の再実行が、モジュールの状態を変えない (ロードされていたならロードされたまま、ロードされていなかったならロードされないまま)。<br/>• **成果物：** `/var/work/tests/artifacts/7/sctp.txt` に、行 `lsmod: absent` または `lsmod: present` (どちらか - 実際の現在の状態) と、行 `install sctp /bin/true` が含まれている。 |

<details>
<summary>💡 課題 7 のヒント</summary>

`blacklist sctp` だけではすべてをブロックできません - alias resolution による**自動ロード**は防ぎますが、直接の `modprobe sctp` は `install` の override がなければ動作します。両方の行が必要です：自動ロード用の `blacklist` と、明示的な `modprobe sctp` の呼び出し用の `install sctp /bin/true` (ロードコマンドを no-op に置き換えます)。すでにロードされているモジュールをアンロードするには `sudo modprobe -r sctp` を試してください。ただし、`/sys/module/sctp/holders` が空のまま `FATAL: Module sctp is in use` が出た場合は - 稼働中のクラスターでは想定内であり (すでに動作している Pod による per-netns の固定)、課題の通過を妨げません；設定は、確認の対象でもある**今後の**ロードを引き続き防ぎます。
</details>

---
| **8** | **kubelet 用の `protectKernelDefaults` と安全な sysctl** |
| :---: | :--- |
| やること | • control-plane では現在 `kernel.unprivileged_bpf_disabled = 0` です - 非特権プロセスが eBPF プログラムをロードでき、カーネルの攻撃対象領域が広がります。これを修正してください。<br/>• `vm.overcommit_memory = 1` を追加します (メモリ逼迫時の kubelet/containerd の安定性のための典型的な推奨事項)。<br/>• 両方のパラメータを `/etc/sysctl.d/99-kubernetes.conf` に設定し、その後 `sudo sysctl --system` を適用します。<br/>• `/var/lib/kubelet/config.yaml` で `protectKernelDefaults: true` を有効にし、kubelet を再起動します。<br/>• **順序が重要です：** `true` の場合、kubelet は起動時に、現在の kernel/cgroup パラメータが期待されるデフォルトと一致しているかを確認し、一致しない場合は**起動しません** - そのため、sysctl は kubelet の再起動の**前に**適用されている必要があり、後ではいけません。 |
| 受け入れ基準 | • **Live の値：** `sysctl kernel.unprivileged_bpf_disabled` が `1` を返す；`sysctl vm.overcommit_memory` が `1` を返す。<br/>• **永続的な設定：** `/etc/sysctl.d/99-kubernetes.conf` に、両方のパラメータが有効な行 (`kernel.unprivileged_bpf_disabled = 1`、`vm.overcommit_memory = 1`) として含まれている；コメント、`= 1 # comment`、一時的な `sysctl -w` はカウントされない。<br/>• **kubelet:** kubelet の実効設定 (`/api/v1/nodes/<node>/proxy/configz`) に `protectKernelDefaults: true` が含まれている。<br/>• **再起動後の状態：** `systemctl is-active kubelet` が `active` を返し、ノードが `Ready` のままである。 |

<details>
<summary>💡 課題 8 のヒント</summary>

ここでは順序が重要であり、課題の説明でも意図的に強調されています：まず `sysctl --system` (値を適用)、その後でのみ `protectKernelDefaults: true` を有効にして kubelet を再起動します。逆の順序で行うと、kubelet は起動時に kernel パラメータが期待と合っていないことを検出して起動を拒否し - ノードは NotReady のままになり、kubelet のログ (`journalctl -u kubelet`) を読まなければ原因が分かりません。確認は、`config.yaml` のテキストではなく、`kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"` による kubelet に実際に有効な設定を基準にします - ファイル内の行がコメントアウトされていたり誤字があっても、`grep` はそれを見つけてしまう可能性がありますが、kubelet は古いデフォルト値で動作し続けています。ファイルを修正した後は、必ず kubelet を再起動し、まさに `configz` で確認してください。
</details>

---
| **9** | **余分な SUID バイナリを見つけて無効化する** |
| :---: | :--- |
| やること | • control-plane で `find / -xdev -perm -4000 -type f 2>/dev/null` を実行し、結果の中から `/usr/local/bin/cks-lab105-suid-tool` を見つけます - これは SUID ビットを持つように特別に作られた学習用のバイナリで、このノード上の Kubernetes のどのコンポーネントにも必要ありません。<br/>• 見つかった SUID ファイルの完全なリストを、修正**前に** `/var/work/tests/artifacts/9/suid-before.txt` に保存します。<br/>• バイナリから SUID ビットを外します (`chmod u-s`)。<br/>• 修正**後**の `cks-lab105-suid-tool` のモードを `/var/work/tests/artifacts/9/suid-after.txt` に保存します。<br/>• システムの SUID バイナリ (`passwd`、`sudo`、`mount` など) には触れないでください：それらを削除すると OS の通常の動作が壊れ、課題の範囲に含まれません。 |
| 受け入れ基準 | • **修正前：** `suid-before.txt` の見つかった SUID ファイルの中に、パス `/usr/local/bin/cks-lab105-suid-tool` が含まれている。<br/>• **修正後：** `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` が `755` を返す (SUID ビット `4` なし)；`suid-after.txt` に `755` が含まれている。<br/>• **システムのバイナリ：** 標準の SUID バイナリ (たとえば `/usr/bin/sudo` や `/usr/bin/passwd`) が、SUID ビットを持ったまま手つかずである。 |

<details>
<summary>💡 課題 9 のヒント</summary>

`chmod u-s` は、他のパーミッションには触れずに SUID ビットだけを外します (`chmod 755` は他のすべてのパーミッションビットも上書きします - この場合結果は一致しますが、一般的な習慣としては `u-s` の方が安全です)。必要に迫られない限り、`-xdev` なしで `find / -perm -4000` を実行しないでください - それがないと、コマンドはマウントされたネットワーク/仮想ファイルシステムをスキャンし、非常に長くかかったりハングしたりすることがあります。確認では、システムの SUID バイナリの現在の集合を、実習の開始前に記録された baseline と比較します - 他のシステムの SUID バイナリを (`sudo`/`passwd` だけでなく) 触ることは禁止されており、誤って (あるいは意図的に) 他の何かから外してしまった場合は、`sudo` に SUID を戻すだけでは助けになりません。`/var/lib/containerd` 内のパス (overlayfs 経由の container image のレイヤー) は、baseline にも確認にもカウントされません - これらはホストのファイルではなく、イメージの pull/extract によって、あなたとは無関係に自然に変化するからです。
</details>

---
| **10** | **core dump を無効にし、SUID プロセスをメモリダンプから保護する** |
| :---: | :--- |
| やること | • プロセスの core dump には、crash した時点でメモリ上にあった復号済みの secret、private key、token が含まれる可能性があります。<br/>• control-plane の `/etc/security/limits.conf` に、行 `* hard core 0` と `* soft core 0` を追加します (core dump のサイズ制限)。<br/>• SUID/privileged プロセスのダンプを禁止します：`/etc/sysctl.d/99-kubernetes.conf` に `fs.suid_dumpable = 0` (課題 8 と同じファイル - 競合する別のファイルを作成しないでください)。<br/>• **Ubuntu ではこれでは不十分です：** crash dump はデフォルトでは、直接ファイルに渡されるのではなく、userspace の pipe handler (Apport) を指す `kernel.core_pattern` を通じて渡されます。`RLIMIT_CORE` は、まさに pipe ハンドラに対してカーネルに無視されるため、Apport は `ulimit -c` に関係なく `/var/lib/apport/coredump/` で crash を捕捉します (`man 5 core` を参照："RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program")。<br/>• そのため、同じ `/etc/sysctl.d/99-kubernetes.conf` に追加で `kernel.core_pattern = \|/bin/false` を設定します - これは pipe-handler を確実に機能しないものに置き換え、カーネルはファイルにも Apport 経由でも dump を作成しなくなります。`sudo sysctl --system` を適用します。<br/>• 確認します：`sysctl fs.suid_dumpable` が `0` を返し、`cat /proc/sys/kernel/core_pattern` が `\|/bin/false` を返すこと。<br/>• 確認します：新しい login-shell (`bash -l` または `sudo su - ubuntu -c 'ulimit -c'` - まさに `sudo` 付きで。通常の `su` を自分自身に対して使うと、やはりパスワードを要求されます) で `ulimit -c` が `0` になること。<br/>• 確認します：テストプロセスの実際の crash (`SIGSEGV`) の後に、`/var/lib/apport/coredump/` にも他のどこにも、新しい core dump が現れないこと。 |
| 受け入れ基準 | • **Live の値：** `sysctl -n fs.suid_dumpable` が `0` を返す；`cat /proc/sys/kernel/core_pattern` が `\|/bin/false` を返す。<br/>• **永続的な sysctl:** `/etc/sysctl.d/99-kubernetes.conf` に、有効な (コメントアウトされていない) 行 `fs.suid_dumpable = 0` と `kernel.core_pattern = \|/bin/false` が含まれている。<br/>• **制限:** `/etc/security/limits.conf` に、`* hard core 0` と `* soft core 0` の両方の行が含まれている；新しい login-shell が `ulimit -c` を `0` と表示する。<br/>• **Crash probe:** テストプロセスの controlled crash が、新しい retained な core dump を作成しない。<br/>• **成果物：** `/var/work/tests/artifacts/10/coredump.txt` に、controlled crash probe の結果を含むすべての確認が含まれている。 |

<details>
<summary>💡 課題 10 のヒント</summary>

あなたの現在の SSH セッションの `ulimit -c` は、`limits.conf` を編集した後も変わりません - PAM の limits は、新しいセッション/login-shell が作成されるときにのみ適用されます。`sudo su - ubuntu -c 'ulimit -c'` (新しい login；`sudo` は必須です - root から呼び出されない限り、`su` は自分自身に対してでも常にパスワードを要求します) で確認するか、新しい SSH セッションを開いてください。ファイルを編集したのと同じ shell で `ulimit -c` を確認しないでください。両方の値が必要です：`hard` は絶対的な上限、`soft` は有効なデフォルト値です；`soft` だけを設定すると、プロセスは自分で制限を `hard` まで引き上げられます。この課題の核心となる罠：`ulimit -c 0` と `fs.suid_dumpable=0` は、Ubuntu ではそれだけでは core dump を無効に**しません** - `man 5 core` は、`kernel.core_pattern` が pipe ハンドラ (`|program`) を指している場合に `RLIMIT_CORE` がカーネルに無視されると明記しており、Ubuntu はデフォルトで crash をまさにそのようなハンドラ (Apport) に向けるため、それは `ulimit` に関係なく dump を捕捉します。唯一の確実な方法は、プロセスの limits だけでなく、`kernel.core_pattern` 自体を (たとえば `|/bin/false` に) 上書きすることです。
</details>

## 追加：kernel と containerd/CRI の hardening

これは課題 7-9 に加えた、短い node-local の演習であり、fixture の自動的な基準には含まれません。
特定のカーネルモジュールに限定されない、より広い CRI の文脈を示します。

この実習では、Kubernetes は Docker ではなく **containerd** を使用します。そのため、同じ原則を
CRI にも適用する必要があります：`/run/containerd/containerd.sock` と
`/etc/containerd/config.toml` のパーミッションを確認し、通常のユーザーをソケットへのアクセスを与える
グループに追加せず、この endpoint に対する `ctr`/`crictl` を、特権を持つ管理者にのみ
許可してください。稼働中の CRI ソケットの所有者やモードを、よく考えずに変更しないでください：誤った
設定は kubelet と workload を停止させます。

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# 非特権ユーザーに対してアクセス拒否が期待されます
```

## 検証

`worker` で次を実行します：

```bash
check_result
```

チェックには `0 Init` と 10 個の独立したテストが含まれます。両方のホストの状態を SSH 経由で確認し、
必須の成果物も確認します。`sshd_config` または systemd unit を修正した後は、
`systemctl reload/restart` が完了するのを待ってから、再度確認を実行してください。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)。

## 削除

```bash
TASK=105 make delete_cks_task
```
