[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 103 - 参考解答

> コマンドは、`control-plane` が明示されていない限り worker 上で実行します。static Pod manifests を
> 編集する前に、コピーを保存してください。Kubelet はファイルの変更を自動的に検出し、
> 対応する static Pods を再作成します；Kubernetes API 経由でそれらを削除しないでください。
>
> 試験では、`k` (`alias k=kubectl`) とその bash-completion が SSH ホスト上ですでに設定されています -
> その設定に時間を使わず、そのまま `k` を使ってください (第 33.6 章を参照)。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## 課題 1：kube-bench のレポート

`kube-bench` `0.16.0` はすでに `control-plane` にインストールされています (CIS Benchmark のツールが
ノード上にすでにある実際の試験と同様に) - worker からそこへコピーする必要はありません。Kubernetes
`1.36` はまだ kube-bench の公式 support table に載っていません；このバージョンの組み込み version mapping は
エントリ `"1.34": "cis-1.12"` で終わっており、それより新しいプロファイル (1.35/1.36 向けの
プロファイルも含めて) は `0.16.0` にはまったくないため、最も近い既存のものとして `cis-1.12` を使用します。
これを authoritative な CIS compliance assessment ではなく、approximate な
hardening signal として強制的に実行します。

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

5 つの `== Summary <target> ==` がすべてあることを目で確認してください - 明示的な
`--targets` がないと、その一部 (`etcd`、`policies`) はレポートに含まれません。

## 課題 2：kubelet の hardening

フィールド名を記憶で思い出さないでください - 試験では、すでに取得した kube-bench のレポート
(課題 1) から直接取り出す方が速いです。そこでは各 check に、修正のテキストが書かれた
セクション `== Remediations <target> ==` があり、check 番号で `grep -A1` すれば、すぐに必要なフィールドが得られます：

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

control-plane の kubelet は `/var/lib/kubelet/config.yaml` を読み取ります。YAML には、まさに次の
フィールドが含まれている必要があります (同名のキーを 2 回追加しないでください)：

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

試験では、すべてのコマンドに `sudo` を付けず、一度 root になる (`sudo -i`) 方が
速いです：

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # root シェルを抜ける
exit   # control-plane から抜ける
```

ファイルの静的なテキストではなく、kubelet が実際に適用した有効な設定を、API `configz` 経由で確認します
(YAML のテキスト解析は `webhook.enabled` のような似たフィールドで簡単にだまされますが、`configz` は
kubelet 自身が自分の設定と見なしているものを反映します)：

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## 課題 3：kube-apiserver の profiling を無効にする

課題 2 と同じ手法です - 課題 1 の kube-bench のレポートを信頼できる情報源として使用し、
フラグを記憶で思い出さないでください：

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false
```

パラメータを `kube-apiserver` コンテナの `command` リストに追加します。

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command 配列に、他の引数と同じインデントで次の行を追加します:
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS が Running になるはずです - まだなら、数秒待ってからやり直してください
```

## 課題 4：TLS Secret と Ingress

最小限のアプリケーションと Service を作成し、正確な DNS 名の自己署名証明書を生成してから、
TLS Secret と Ingress を作成します。`ingress-nginx` controller は、この実習ではすでに
インストールされ Ready になっています (lab-owned fixture で、バージョンは bootstrap で固定されています) - Ingress を作成する前に
それを確認しましょう。

リソースの短い名前 (`ns` = namespace、`deploy` = deployment、`svc` = service、
`ing` = ingress、`po` = pod) は、時間的なプレッシャーの下でのタイピングを節約します。

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

`k get ... -o yaml` で止まらず - TLS Ingress が本物の controller を通じて実際に
動作することを確認します。`secure.cks.local` はすでに実際の node IP に解決され
(bootstrap が `/etc/hosts` にエントリを追加しました)、`ingress-nginx-controller` は
すべてのノードで公開されている `NodePort` タイプの Service なので、curl はクラスターへの SSH なしで、
このマシンから直接実行します：

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200、本文に "Server Name: secure-app" が含まれる

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

この HTTP→HTTPS の redirect は、実習が作り出した人為的な要件ではなく、実際の試験の問題です
(mock-exam `tasks/cks/mock/04`、課題 4 を参照)。

## 課題 5：kube-apiserver と etcd の TLS hardening

フラグの正確な名前をドキュメントで探さないでください - すでに実行中の Pod の中から
バイナリ自体に尋ねて (control plane のどのコンポーネントにも `--help` があります)、必要な部分を grep する方が速いです：

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

両方の static Pod manifests の `command` にパラメータを追加します。kube-apiserver では、この課題は
両方のフラグを要求しますが、`VersionTLS13` で実質的な保護を与えるのはまさに `--tls-min-version` です
(Go は TLS 1.3 の cipher suites を自分で選択し、`--tls-cipher-suites` はそれらに影響しません - 「開始前のセルフチェック」の
質問 2 を参照)。それでも `--tls-cipher-suites` は明示的に必要です - これは
defense-in-depth です：最小バージョンを後で 1.2 に緩めたとしても、弱い暗号の組が
勝手に有効になることはありません。etcd (そこでは TLS 1.2 が許可されます) では、`--cipher-suites` は
将来のためではなく、今まさに実際に暗号の組を制限しています。

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command に追加します:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# command に追加します:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS が Running になるはずです - まだなら、数秒待ってからやり直してください
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - 接続に成功しました

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - handshake は失敗するはずです。それが求められている結果です

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

`Protocol version: TLSv1.3` または `Protocol : TLSv1.3` という形式の行が表示されるはずです。また、
`openssl s_client -tls1_2` が handshake エラー/non-zero exit で終了することは、
`TLS 1.2 correctly rejected` として記録されている必要があります。

## 課題 6：kubelet と kubectl の SHA-256 を確認する

基準はローカルファイルから計算しません。公式に公開されている Kubernetes `v1.36.0` のチェックサムを
ダウンロードし、`sha256sum -c` 形式のファイルを作成して、結果を保存します。

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

両方の行が `: OK` で終わる必要があります。バイナリのパスが `/usr/bin` と異なっていても、
`command -v` は `sha256sum -c` に対する正しい入力を生成します。

## 課題 7：Remediation cycle: 具体的な kube-bench の FAIL から PASS へ

課題 1 (レポート全体のスナップショット) とは異なり、ここでは 1 つの具体的な check を
その修正と結びつける必要があります。`kube-bench` は `--check` による個別の実行をサポートしているため、
レポート全体を手動で読み直す必要はありません：

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

ノード上の実際のパーミッションを確認し、`600` に修正します - これは file-only の
変更であり、kubelet はパーミッションの変更では static Pod を再作成せず、
manifest の内容が変わったときにだけ再作成します：

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

同じ check を個別に再実行すると、`PASS` が表示されるはずです：

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

kube-apiserver が正常なままであることを確認します：ファイルのパーミッションの変更は内容を変えないため、
kubelet は static Pod を再作成しないはずです。

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## 課題 8：Remediation cycle: kube-controller-manager

課題 7 と同じ手法を、別のコンポーネントと別の check ID (`1.1.3` -
kube-controller-manager pod specification file のパーミッション) に対して行います：

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## 課題 9：Remediation cycle: kube-controller-manager と kube-scheduler の profiling

課題 7-8 と同じ手法 (kube-bench で具体的な `[FAIL]` を見つけ、修正し、
`[PASS]` を確認する) を、checks `1.3.2` (kube-controller-manager の profiling) と `1.4.1`
(kube-scheduler の profiling) に対して行います。どちらも、セクション `1.x` 全体と同様に、`cis-1.12` では target `master` に
属しているため、課題 7-8 とまったく同じように、明示的な `--targets` は不要です。課題 3 では
kube-apiserver の profiling だけを無効にしました；kubeadm はデフォルトでは、kube-controller-manager/kube-scheduler の
manifest に `--profiling=false` をそもそも追加しません。

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

両方の static Pod manifests を修正します - 課題 3 と同じ手法で、2 つの
別のコンポーネントに対して行うだけです：

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# command 配列に、他の引数と同じインデントで次の行を追加します:
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

ファイルのテキストではなく、実際に実行されている Pod を確認します (kubelet は manifest の変更後、
static Pod を瞬時には再作成しません)。また、同じ check を個別に再実行すると、
`PASS` が表示されるはずです：

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` は両方のコンポーネントで `true` を出力するはずで、上の 2 つの `k get pods` コマンドは
どちらも `Running` を表示するはずです。

## 課題 10：Remediation cycle: worker ノードでの protect-kernel-defaults

課題 7-9 と同じ手法を、今度は実際の worker ノード (control-plane ではない) で、ただし
別のプロファイルに対して行います。固定された `kube-bench 0.16.0`/`cis-1.12` (この実習の他のすべての
課題で使用) には、check protect-kernel-defaults はそもそも含まれていません - CIS はこのバージョンの
プロファイルからそれを削除/番号変更しました；`cis-1.12` の `4.2.6` 自体は
別の check です (`--make-iptables-util-chains`、デフォルトで `PASS`、protect-kernel-defaults とは
関係ありません)。必要な同じ ID `4.2.6` の check は、同じバイナリのより古いプロファイル
`cis-1.24` に存在します - まさにそれを、明示的な `--benchmark cis-1.24` で、この 1 つの課題に
限って使用してください。

control-plane とは異なり、worker ノードには `kube-bench` は事前にインストールされていません - ここで自分で
インストールしてください (実際のインストールであり、control-plane や worker PC からのコピーではありません)：GitHub から同じ
固定されたリリースをダウンロードし、`binary` と `cfg` をデフォルトの `--config-dir`
(`/etc/kube-bench/cfg`) に展開して、毎回のコマンドでこのフラグを明示しなくて済むようにします：

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

cat <<'EOF' > /tmp/install-kube-bench.sh
KUBE_BENCH_VERSION=0.16.0
arch=$(dpkg --print-architecture)
workdir=$(mktemp -d)
asset="kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}"
curl -fsSL -o "$workdir/$asset" "$base/$asset"
# 課題 6 と同じ手法: ファイル自体から計算したチェックサムではなく、独立に公開されているチェックサムと照合します。
curl -fsSL -o "$workdir/checksums.txt" "$base/kube-bench_${KUBE_BENCH_VERSION}_checksums.txt"
(cd "$workdir" && grep -E "[[:space:]]${asset}\$" checksums.txt | sha256sum --check --strict -)
tar -xzf "$workdir/$asset" -C "$workdir"
sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
sudo cp -a "$workdir"/cfg /etc/kube-bench/cfg
sudo install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
rm -rf "$workdir"
EOF
scp /tmp/install-kube-bench.sh "$WORKER_NODE":/tmp/install-kube-bench.sh
ssh "$WORKER_NODE" 'bash /tmp/install-kube-bench.sh'
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` は kubeadm が生成する `KubeletConfiguration` にはそもそも含まれていません -
フィールドは物理的に存在しません (安全でないデフォルトの `false` と同等) ので、置換する既存の行を探さずに
単に追加してください：

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

`/configz` (実際に適用された設定であり、ファイルのテキストではない) と、
check の個別の再実行で確認します：

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
