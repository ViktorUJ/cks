[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 105 - 参考解答：System Hardening OS と Docker

> 作業の進め方：一度 `ssh` でノードに入り、コマンドをそのノード上で直接実行します (`sudo -i` の下で、
> 各コマンドの前に `sudo` を書かなくて済むようにします) - これは各コマンドを個別の `ssh` で送るより
> 速く、試験でもまさにこの進め方をするべきです。control-plane ノードの名前は
> `kubectl get no` で確認します：
>
> ```bash
> kubectl get no
> ssh <ノード名 (出力から)>
> sudo -i
> ```
>
> 確認と成果物：checker は成果物を**作業マシン** (`worker`) の
> `/var/work/tests/artifacts/<番号>/` から読み取るため、ノード上での修正の後は抜けて (`exit`、`exit`)、
> `worker` から短いコマンドで成果物を保存します。そのために、ノード名を一度設定しておきます：
>
> ```bash
> CP=<ノード名 (出力から)>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> 成果物が必要なのは実習の確認のためだけです：試験にはなく、そこではノード上のコマンドと
> 結果の簡単な確認で十分です。コマンドは出力をファイルに保存します (`>`)。内容は
> 別途 `cat <ファイル>` で確認します - 期待される結果は、ブロックの下のコメント `# ...` に示されています。
>
> Docker ホストにも同じように入ります：`ssh docker-host`、続いて `sudo -i`。

## 1. 不要な systemd サービスを無効にする

サービス `cks-lab105-unused.service` は Kubernetes には不要で、攻撃対象領域を増やします。
停止して、自動起動を禁止します。

control-plane で：

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

成果物 (`worker` で)：

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. 不要な TCP/8080 を閉じる

ポート 8080 は、サービス `cks-lab105-port.service` によって意図的に開かれています；これは
control-plane にも kubelet にも不要です。サービスを停止して無効にします - 両方の操作が必須で、
そうしないと、今ポートが閉じていても reboot の後に listener が戻ってきます。

control-plane で：

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # 出力が空 - ポートは閉じている
exit
exit
```

成果物 (`worker` で)：

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# ポートはすでにノード上で確認済み (`ss -ltn | grep 8080` - 空)、結果を記録します:
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. UFW で受信トラフィックを制限する

まず、トポロジーと必要な source を特定します。これはシングルノードの control-plane で、
workload も実行します。Worker には SSH と API アクセスが必要です；Pod CIDR とノード自身には API アクセスが必要です。
ノード間の kubelet/CNI フローはここにはありません。`22`/`6443` を
`Anywhere` に開放しないでください。

`worker` で、必要な値を目で確認します：

```bash
kubectl get no -o wide                                      # ノードの INTERNAL-IP
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # worker の IP
```

それらを preflight に記録します (自分の値に置き換えてください；行 `role=` は必須です)：

```bash
WORKER_IP=<ip-worker>; NODE_IP=<ノードの internal-ip>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

UFW の前の Baseline：TCP/10250 (kubelet HTTPS) が今実際に到達可能であることを確認します -
これがないと、UFW の後の「ブロックされた」は何も証明しません。ポートは別の理由
(security group、routing) で到達不能だったかもしれません。Checker は独自の baseline とも別途照合しますが、あなたの
記録も必要です：

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - ポートは到達可能です (401/403 を含む任意の 1xx-5xx で構いません)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

baseline に到達できない場合 (curl が `000` を返した場合) - まず接続性を修正してください。そうしないと、UFW の後の結果は
説得力のないものになります。

UFW のルールはノード上で設定します。まず recovery と必要な source を許可し、その後で
default を変更します。`WORKER_IP`/`NODE_IP`/`POD_CIDR` の値は `preflight.txt` から取ります
(自分の値に置き換えてください)：

```bash
ssh "$CP"
sudo -i
WORKER_IP=<worker_ip>; NODE_IP=<node_ip>; POD_CIDR=<pod_cidr>
ufw allow from "$WORKER_IP" to any port 22 proto tcp comment 'CKS105 worker SSH recovery'
ufw allow from "$WORKER_IP" to any port 6443 proto tcp comment 'CKS105 worker API'
ufw allow from "$NODE_IP" to any port 6443 proto tcp comment 'CKS105 node API'
ufw allow from "$POD_CIDR" to any port 6443 proto tcp comment 'CKS105 Pod API'
ufw allow in on lo comment 'CKS105 loopback'
ufw default allow outgoing
ufw default deny incoming
ufw --force enable
ufw status verbose
exit
exit
```

成果物 (`worker` で)。`ufw show added` は、実際に追加したルールの正規化された表現です
(元の形式/コマンドの順序とは限りません - UFW は表示時にそれらを正規化します)。確認ではまさにこのリストを
期待される allowlist と比較します - これも保存してください。これは exact な allow-set の最も確実な evidence です。
firewall は `ufw` のみで管理してください -
`/etc/ufw/before*.rules` や `/etc/ufw/after*.rules` を手動で編集しないでください。これらは共通の default ルールを持つ
framework ファイルであり、source を限定したルールの置き場所ではありません；checker は
そのハッシュを checker-owned の bootstrap-baseline と照合し、直接の編集を検出します。

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# API が失われた場合、まだ開いている SSH/console session から実行します:
sudo ufw disable
sudo ufw status verbose
# 限定された (狭い) allow rules を修正し、source IP/CIDR を確認します
sudo ufw --force enable
# ルールが完全に壊れた場合のみ、console/recovery channel 経由で:
sudo ufw --force reset
EOF
```

クラスターが健全であることを確認します (`worker` から)：

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# クラスター内の workload は、引き続き DNS を解決でき、API server に到達できる必要があります
# (UFW が Pod -> CoreDNS と Pod -> API の通信を壊してはなりません):
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # kubernetes Service の Address を返すはずです
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # 000 以外の任意のコード

# 望ましくない worker -> kubelet のフローは、HTTP response を返してはなりません。
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - transport の deny
```

`ufw reload` の後の必須の完全な E2E retest - ruleset が reload を生き残ること、
`ufw enable` の直後にメモリ上でだけ動作しているのではないことを証明します。この手順がないと、
enable の直後に偽の PASS を誤って得てしまうことがあります：

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# workload の同じ 2 つの確認を reload の後にも繰り返します:
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# reload の前と同じ契約: worker は引き続き kubelet に到達しません。
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

declared と effective の比較：`ufw show added` は宣言的なリストで、CLI でルールを追加するときに
ufw 自身が `user.rules` に書き込む `### tuple ###` メタデータから再構築されます。
`ufw reload` の後の実際のカーネルの状態は、`ufw show user-rules` が示すものです。行の数だけでなく
その内容 (source/port/proto) も比較してください：`ufw-user-input` には、loopback (all, lo) と、
正確な source アドレスを持つ 4 つの tcp dpt:22/6443 ルールが表示されるはずで、`ufw6-user-input` には
ちょうど 1 行、v6 の同じ loopback ACCEPT が表示されるはずです (`ufw allow in on lo` は明示的な IP のない
interface ベースのルールなので、ufw は常に v4 と v6 の両方の版を作成します)。そこにあるその他の/追加の行は、
不正な bypass です：

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

出力には `Status: active`、`Default: deny (incoming)`、そして source を限定したルールが
含まれている必要があります - `ufw status verbose` でも、宣言的なリスト `ufw show added` でも同様です。`/readyz`、nodes、calico-node、workload (reload の前後の Pod DNS を含む)、および
`10250` への 2 つの拒否の確認 (`ufw reload` の前と後、同じ
CURL_EXIT/HTTPCODE の契約で) が期待される結果になるまで、元の SSH session を閉じないでください。

## 4. 管理者の kubeconfig を保護する

`/etc/kubernetes/admin.conf` には cluster-admin の credential が含まれています。これは root のみが
読み取れるべきです。

control-plane で：

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

成果物 (`worker` で)：

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. SSH での直接の root login を禁止する

設定を変更し、reload の前に構文を確認して、現在のセッションを切断せずに適用します。

control-plane で：

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

`reload ssh` では現在のセッションは切断されません。ただし、sshd の再起動中は、control-plane への新しい
接続が 1-2 秒間 `Connection refused` を受け取ることがあります - これは
正常で、設定が壊れていることを意味しません (すでに `sshd -t` が確認しています)。単にコマンドを
やり直してください。

connection context なしの `sshd -T` は `Match` ブロックをまったく適用しません - man `sshd(8)` は
test mode で `Match` が適用されるのは `-C` が渡されたときだけだと明記しています。そのため、
worker からの実際の root 接続をシミュレートして `-C` で確認します (アドレスは課題 3 の
`preflight.txt` から取ります)：

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

成果物 (`worker` で、数秒待った後)：

```bash
# WORKER_IP と NODE_IP - 課題 3 と同じ値
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. `docker-host` 上の Docker daemon への安全でないアクセスを塞ぐ

TCP/2375 には TLS も認証もありません：そこへのアクセスは、ホストへの root アクセスとほぼ同じです。
TCP listener を持つ学習用の systemd override を削除し、socket override を通じて unix ソケットの所有者を設定し、
`developer` をグループ `docker` から削除します。

変更は、**両方の** unit の完全な `daemon-reload` + restart で適用します - これは
必須のステップであり、単なる「設定の再読み込み」ではありません：実際の restart がないと、Docker が単に応答しなくなっただけで
確認を誤って「通過」してしまうことがあります (その場合、TCP/2375 が閉じているのは `-H tcp://` が
削除されたからではなく、デーモンがそもそも動いていないからです)。

`docker-host` で：

```bash
ssh docker-host
sudo -i
rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf
install -d -m 0755 /etc/systemd/system/docker.socket.d
printf '[Socket]\nSocketGroup=root\nSocketMode=0660\n' > /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf
gpasswd -d developer docker || true
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service
chown root:root /var/run/docker.sock && chmod 660 /var/run/docker.sock
```

Positive control：restart の後、Docker が実際に動作していること (単に 2375 で listen していないだけではなく、
unix ソケット経由で完全に機能している必要があります)：

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

永続的な設定の確認 - effective な unit に `-H tcp://` が含まれず、socket override が必要な値を
実際に設定していること (一時的にそれらと一致しているだけではなく)：

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

課題の契約はポート 2375 より広いものです：Docker API はどのポートでも TCP で listen してはならず、
`docker.socket` には TCP の `ListenStream` が含まれていてはなりません：

```bash
ss -ltnp | grep dockerd                        # 出力が空 (docker.socket による systemd の TCP ソケットは次の行で検出されます)
systemctl cat docker.socket | grep ListenStream # /run/docker.sock のみ (と空のリセット)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

成果物 (`worker` で)：

```bash
# ポート 2375 はすでに docker-host で確認済み (`ss -ltnp | grep dockerd` - 空)、結果を記録します:
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

すべての手順を終えたら、`check_result` を実行します。

## 7. モジュール `sctp` のロードを禁止する

`sctp` はロードされていますが、このノード上の kubeadm、containerd、Calico のいずれにも必要ありません。
すでにロードされているモジュールのアンロードを試み、その後はいずれにせよ、`blacklist` と
`install` override の両方で再ロードをブロックします。両方のディレクティブは
`modprobe` のレベル (alias resolution と明示的な `modprobe sctp`) で作用し、通常のロード経路を排除します；
カーネルレベルの enforcement の代わりにはなりません (`insmod` は syscall を通じて直接モジュールを挿入し、
`modprobe.d` を読み取りませんし、`modprobe --ignore-install` は、ホスト上の
root アクセスがあれば `install` を迂回できます) - この実習で重要なのは、想定される自動ロードの経路を排除することであり、
すでにノード上で root を持っているユーザーからの防御を実現することではありません。

**`modprobe -r sctp` は、すでに稼働中のクラスターでは失敗することがあります** - これは想定内であり、
受講者の間違いではありません。プロトコルのカーネルモジュール (`sctp` を含む) は、モジュールのロード時に
すでに存在していた各 netns に対して、永続的な per-network-namespace の参照 (pernet の初期化における `try_module_get`) を
受け取ります - このノードではすでに Pod (calico、coredns、kube-system) が動作しているため、`sctp` は
refcount がゼロでなく、`/sys/module/sctp/holders` が空のまま `in use` の状態で残ることがあります (つまり、保持しているのは
他のモジュールではないため、再帰的にアンロードできるものはありません)。これは、これらすべての Pod を停止しなければ修正できず、
それは課題の範囲に含まれません。重要で、実際に確認されるのは、受講者がコントロールできる部分です：
モジュールを**再びロードできない**こと。

control-plane で：

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # 空でも空でなくても構いません - どちらも許容されます
modprobe --show-config | grep sctp      # install sctp /bin/true と blacklist sctp
exit
exit
```

成果物 (`worker` で)：現在の状態 (`absent` または `present`) と、effective な
modprobe config の override：

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (または lsmod: present - どちらも許容されます、上を参照)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` と安全な sysctl

まず sysctl を修正します - `protectKernelDefaults: true` は、カーネルの現在の値が kubelet の期待と一致しない場合、kubelet を**起動時に失敗させる**ため、
sysctl は kubelet の再起動より前に適用されている必要があります。

control-plane で：

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

次に、kubelet の設定で `protectKernelDefaults` を有効にして、サービスを再起動します：

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

ノードは `Ready` のままである必要があります (`worker` から)：

```bash
kubectl get no
```

このステップの後に kubelet が起動しない場合は、まさに順序を確認してください：kubelet が起動時にそれらを
確認する前に、sysctl が (ファイルに書き込まれただけでなく) 適用されている
(`sysctl --system`) 必要があります。

## 9. 余分な SUID バイナリを見つけて無効化する

`find` は、システムの SUID バイナリ (`sudo`、`passwd`、`mount` - これらには触れません) と、
このノード上のどの Kubernetes コンポーネントにも必要のない学習用の
`/usr/local/bin/cks-lab105-suid-tool` の両方を表示します。

`/var/lib/containerd` は出力から除外されています：その overlayfs の snapshot パスは
container image のレイヤーの内容であり、ホストにインストールされたバイナリではなく、実習中のイメージの
pull/extract のたびに、受講者の操作とは無関係に変化します。

成果物 `suid-before.txt` は修正の**前に**保存する必要があります (`worker` で)：

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

学習用のファイルからのみ SUID ビットを外し (control-plane で)、システムの
SUID バイナリが影響を受けていないことを確認します - `sudo`/`passwd` は SUID ビットを持ったままでなければならず、
そうでなければ OS の基本的な機能が壊れます：

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

成果物 `suid-after.txt` (`worker` で)：

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

すべての手順を終えたら、`check_result` を実行します。

## 10. core dump を無効にし、SUID プロセスを保護する

Core dump には、crash した時点のプロセスのメモリにあった secret や鍵が含まれる可能性があります - 通常のプロセスにも
SUID プロセスにも禁止する必要があります。`fs.suid_dumpable` は、課題 8 ですでに作成した同じ
ファイル `/etc/sysctl.d/99-kubernetes.conf` に追加します - 競合する別の設定は作成しません。

Ubuntu では、`ulimit -c 0` と `fs.suid_dumpable=0` では core dump がないことは**保証されません**：
`man 5 core` は、`kernel.core_pattern` が dump を pipe (`|program`) 経由で userspace ハンドラに
送る場合、`RLIMIT_CORE` がカーネルに無視されることを明記しています。
Ubuntu はデフォルトでまさにそのように設定されています - crash は Apport が捕捉し、プロセスの `ulimit -c` に
関係なく `/var/lib/apport/coredump/` に保存します。唯一の確実な
方法は、`kernel.core_pattern` 自体を、確実に機能しないハンドラに上書きすることです。

プロセスの limits のレベルでも core dump のサイズを制限します - これは
`suid_dumpable`/`core_pattern` とは別の仕組みです (古典的なファイルベースの書き込みが
いつか復活した場合の、通常の crash に対する soft limit)。

control-plane で：

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` は、すでに開いている shell ではなく、PAM を通じて新しい login セッションに適用されます -
まさに新しいセッションで確認します：

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

成果物 `coredump.txt` (`worker` で)。controlled crash probe を含みます：実際の `SIGSEGV` の後に、Apport のディレクトリ
(`/var/lib/apport/coredump`、`/var/crash`) に新しい retained な core dump が現れないことを
確認します：

```bash
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo su - ubuntu -c 'ulimit -c'" \
  > /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  >> /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" '
before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
sh -c "kill -SEGV \$\$" || true
sleep 2
after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
if [ "$after_count" -le "$before_count" ]; then
  echo "crash-probe: no new retained core dump"
else
  echo "crash-probe: NEW core dump appeared after SIGSEGV"
fi
' >> /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

すべての手順を終えたら、`check_result` を実行します。
