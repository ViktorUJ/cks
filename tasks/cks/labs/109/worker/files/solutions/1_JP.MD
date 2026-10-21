[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 109 - 参考解答：Secret の encryption at rest

> 試験と同じように作業します：`kubectl` のコマンドは作業マシンで実行し、ノードに対する操作
> (etcd、control-plane のファイルと manifest) は control-plane 自体で行います：
> `ssh control-plane` で入り、コマンドを実行して抜けます (`exit`)。これは**学習用のシングルノード
> クラスターだけ**の話です；production では、ユーザーに etcd への直接アクセスを与えません。

## ドキュメントで例を見つける場所

以下のコマンドはすべて Kubernetes の公式ドキュメントから取ったものです - 試験では、暗記するのではなく、
同じようにそこで見つける必要があります：

| 必要なもの | ページとセクション |
| :--- | :--- |
| etcd の raw レコードを読み取り、プレフィックス `k8s:enc:aescbc:v1:` を確認する (コマンド `ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/secret1 \| hexdump -C`) | [Encrypting Confidential Data at Rest - Verify that newly written data is encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#verifying-that-data-is-encrypted) |
| `aescbc` と `identity` を持つ `EncryptionConfiguration` の例 | [Encrypting Confidential Data at Rest - Write an encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#write-an-encryption-configuration-file) |
| フラグ `--encryption-provider-config` と、static Pod kube-apiserver へのファイルのマウント | [Encrypting Confidential Data at Rest - Use the new encryption configuration file](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#use-the-new-encryption-configuration-file) |
| すべての Secret を書き直す (`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`) | [Encrypting Confidential Data at Rest - Ensure all relevant data are encrypted](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#ensure-all-secrets-are-encrypted) |
| 鍵のローテーション (手順 1-7) と古い鍵の削除 | [Encrypting Confidential Data at Rest - Rotate a decryption key](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#rotating-a-decryption-key) |
| etcd の証明書のパスを覚えていない場合の探し方：「`trusted-ca-file`、`cert-file`、`key-file` は etcd の Pod の description から取得できます」(`kubectl -n kube-system describe pod etcd-<node>` または `/etc/kubernetes/manifests/etcd.yaml`) | [Operating etcd clusters for Kubernetes - Snapshot using etcdctl options](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| Role/RoleBinding と ServiceAccount (`automountServiceAccountToken`) | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) |

kubeadm クラスターの証明書のパス：`/etc/kubernetes/pki/etcd/ca.crt`、
`/etc/kubernetes/pki/etcd/server.crt`、`/etc/kubernetes/pki/etcd/server.key`；デフォルトの endpoint は
`https://127.0.0.1:2379` なので、control-plane ではフラグ `--endpoints` は不要です。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
export NS=encryption-109
kubectl config use-context "$CTX"
```

## 1. 暗号化を有効にする前の plaintext の証明を記録する

API の `Secret.data` は base64 でエンコードされているのであって、暗号化されているのではありません。Bootstrap は、EncryptionConfiguration が現れる前に安全な
canary を作成しました。まず、ドキュメントのコマンドで etcd の raw レコードを確認し、
次に文字列の証明を control-plane 上のファイル (`/tmp/plaintext-proof.txt`) として保存し、
それを作業マシンの `/var/work/109/plaintext-proof.txt` にコピーします (ディレクトリは bootstrap が作成済みです)：確認は作業マシン上のファイルを読み取ります。

control-plane に入り、そこで実行します (このコマンドは、etcd のキー
`/registry/secrets/<namespace>/<name>` 以外はすべてドキュメントにあるものです)：

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane で: etcd の raw レコード、hexdump -C の出力が plaintext を示します
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C

# 証明を保存する (値だけ、strings 経由) - これも control-plane 上で
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings > /tmp/plaintext-proof.txt
cat /tmp/plaintext-proof.txt
# cks-109-legacy-plaintext
exit   # root から
exit   # control-plane から
```

```bash
# 作業マシンで: 証明をコピーする
scp control-plane:/tmp/plaintext-proof.txt /var/work/109/plaintext-proof.txt
cat /var/work/109/plaintext-proof.txt
```

この段階では、ファイルに `k8s:enc:` はありません。これは設定の**前の**状態の証明です；
re-encryption の後は、再度の出力は ciphertext になり、marker は消えるはずです。

## 2. EncryptionConfiguration を作成する

`aescbc` は、CKS の学習用の手順のためだけに選ばれています。Kubernetes は AES-CBC を、
padding-oracle 攻撃のリスクのため弱いものとみなし、production のデフォルトとしては推奨していません。外部の key
manager には KMS v2 を使用してください；ローカルの provider は、最新の threat model と
ローテーションの手順を踏まえた上でのみ選択してください。

32 バイトの AES-256 鍵を生成し、base64 でエンコードして、control-plane に設定を作成します。
`aescbc` が最初にあります：新しい Secret はそれで書き込まれます。`identity` を最後に置くことで、API
server は移行が完了するまでの間だけ、古い plaintext のレコードを読み取れます。ファイルの例は、ドキュメントのページ
(解答の冒頭のリンク) にあります。

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane で (root)
mkdir -m 700 /etc/kubernetes/enc
key=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/encryption-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: cks-109-aescbc
        secret: ${key}
  - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/encryption-config.yaml
ls -ld /etc/kubernetes/enc; ls -l /etc/kubernetes/enc
exit   # root から
exit   # control-plane から
```

本物の鍵を Git、チケット、ターミナルの log、Terraform state に置いてはいけません。
鍵を失うと、snapshot にある encrypted Secret は読み取れなくなります。

## 3. 設定を static kube-apiserver に接続する

まず manifest を `/etc/kubernetes/manifests/` ディレクトリの**外**に保存します：kubelet は、このディレクトリの
隠しファイルでないすべてのファイル (`*.bak` を含む) を static Pod として読み取ります。ディレクトリ内にある元の manifest の
コピーは、同じ名前を持つ 2 つ目の static Pod になります；kubelet がまさにそれ
(`--encryption-provider-config` のない古い設定) を起動し続ける可能性があり、メインのファイルの修正は黙って
効果を持たず、API server は見かけ上 healthy なまま、暗号化は無効のままになります。
control-plane で、必ず既存の static-Pod の manifest を開き、**既存の** `command`、`volumeMounts`、
`volumes` に次の要素を追加します；ファイル全体をテンプレートで置き換えないでください。

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane で (root)
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# container name: kube-apiserver
command:
- kube-apiserver
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
volumeMounts:
- name: encryption-config
  mountPath: /etc/kubernetes/enc
  readOnly: true

# spec.volumes
volumes:
- name: encryption-config
  hostPath:
    path: /etc/kubernetes/enc
    type: Directory
```

Kubelet が変更を検出して static Pod を再起動します。続行する前に API
server を待ってください。そうしないと、YAML やパスのエラーで control-plane が利用できないままになる可能性があります。

```bash
# まだ control-plane 上で: フラグが稼働中の manifest に入ったことを確認してから、抜ける
grep -n -- '--encryption-provider-config\|encryption-config' /etc/kubernetes/manifests/kube-apiserver.yaml
exit   # root から
exit   # control-plane から
```

```bash
# 作業マシンで: API server の再起動には 1 分ほどかかります；コマンドが
# "readyz check passed" を返すまで繰り返します (それまでは "connection refused" になります)
kubectl get --raw='/readyz?verbose'
```

## 4. 古い Secret を書き直して ciphertext を確認する

設定は、すでに保存されているレコードを変更しません。まず provider を有効にした後で Secret を作成し、
次に既存のすべての Secret を API 経由で書き直します。production では、その前に
保護された snapshot を作成し、retry を伴う制御された手順を使用します。

```bash
kubectl -n "$NS" create secret generic encrypted-secret \
  --from-literal=token='cks-109-fresh-ciphertext'
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

kubectl -n "$NS" get secret legacy-secret -o jsonpath='{.data.token}' | base64 -d; echo
kubectl -n "$NS" get secret encrypted-secret -o jsonpath='{.data.token}' | base64 -d; echo
# cks-109-legacy-plaintext
# cks-109-fresh-ciphertext
```

raw レコードは、課題 1 と同様に control-plane で読み取ります：

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane で (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret | hexdump -C
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/encrypted-secret | hexdump -C
# 両方のレコードが k8s:enc:aescbc:v1:... で始まります
exit   # root から
exit   # control-plane から
```

API は認可されたクライアントに plaintext を返します - これは正常であり、encryption at rest の
証明にはなりません。ここでの証明は、raw etcd に、古いレコードと新しいレコードの両方で `k8s:enc:aescbc:v1:` が含まれ、
legacy marker がもう含まれないことです。

これで migration fallback はもう不要です。`identity` を削除し、CRI 経由で static kube-apiserver を強制的に
再起動して、健全性と読み取りをもう一度確認します。これは、snapshot を取り、
影響を受けるすべてのリソースタイプの ciphertext を確認した後にのみ行ってください。

```bash
ssh control-plane
sudo -i
```

```bash
# control-plane で (root): identity を取り除いて static kube-apiserver を再起動する
vim /etc/kubernetes/enc/encryption-config.yaml   # 行 "- identity: {}" を削除する
crictl stop $(crictl ps --name kube-apiserver -q)
exit   # root から
exit   # control-plane から
```

```bash
# 作業マシンで
until kubectl get --raw=/readyz 2>/dev/null | grep -qx ok; do sleep 2; done
kubectl -n "$NS" get secret legacy-secret encrypted-secret
```

この実習の最終状態：暗号化を行う provider (`aescbc`) が最初で唯一のものであり、`identity` は
削除されています。一時的な fallback を、永続的な「保険」として残してはいけません。

## 5. API アクセスを制限し、token の automount を無効にする

encryption at rest は RBAC の代わりにはなりません：Secret の `get` を持つ subject は、API 経由で plaintext を見られます。
ちょうど 1 つの Secret だけにアクセスできる ServiceAccount と、マウントされた
service-account token のない診断用の Pod を作成します。

```yaml
# rbac-109.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-reader
  namespace: encryption-109
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader-109
  namespace: encryption-109
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["encrypted-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-reader-109
  namespace: encryption-109
subjects:
- kind: ServiceAccount
  name: secret-reader
  namespace: encryption-109
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader-109
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader-109
  namespace: encryption-109
spec:
  serviceAccountName: secret-reader
  automountServiceAccountToken: false
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
```

```bash
kubectl apply -f rbac-109.yaml
kubectl wait -n "$NS" --for=condition=Ready pod/secret-reader-109 --timeout=120s
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/encrypted-secret -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader list secrets -n "$NS"
kubectl auth can-i --as=system:serviceaccount:$NS:secret-reader get secret/legacy-secret -n "$NS"
# yes
# no
# no

check_result
```

`automountServiceAccountToken: false` は Pod が利用できる credential の surface を減らしますが、
アプリケーションが他の credentials を手に入れた場合の、ServiceAccount 自体の RBAC は
制限しません。

## 追加：KMS v2 の概要と鍵ローテーションの完全な手順

### KMS v2: config にローカルの鍵を持たない envelope encryption

上の `aescbc` は学習用の手順のためだけのものです。production では、KMS v2 は
サポートされている KMS-plugin を、`EncryptionConfiguration` のローカルの Unix socket を通じて接続します。
KMS v2 では、API server は、暗号化された seed/DEK を API server のレベルで使用し、
個々のレコードの暗号化鍵を導出します。Plugin は外部の KEK を通じて seed を保護します；
これが、per-resource の KMS v1 との違いです。Etcd にはリソースの ciphertext と
復号に必要なメタデータが保存されます。KEK は外部の KMS にあり、etcd や Git にはありません。設定の
スキーマは Kubernetes と plugin のバージョンに依存しますが、原理的には provider `kms`、
安定した key の名前、socket の endpoint が必要です。他のクラスターの例の endpoint をコピーしないでください：
KMS v2 の形式と health/ACL の要件は、使用している Kubernetes のバージョンのドキュメントで確認してください。

### aescbc key のローテーションの完全な lifecycle

課題 4 の `identity -> aescbc` の移行は migration であり、すでに
暗号化されたデータに対する鍵のローテーションではありません。ローテーションの前に、暗号化された etcd snapshot を作成し、
古い鍵を rollback のために保存してください。新しい鍵を**最初に**追加し、古い鍵は一時的に
2 番目に残します：providers は順番に読み取られ、新しいレコードは最初の鍵で書き込まれます。

```yaml
- aescbc:
    keys:
    - name: cks-109-aescbc-2026-rotation
      secret: <base64-32-byte-new-key>
    - name: cks-109-aescbc
      secret: <base64-32-byte-old-key>
```

API server の再起動後、リソースを書き直し、一般的な `k8s:enc` のプレフィックスだけでなく、raw
ciphertext 内の新しい key の名前を確認します：

```bash
# 作業マシンで
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
ssh control-plane
sudo -i
```

```bash
# control-plane で (root)
ETCDCTL_API=3 etcdctl \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/encryption-109/legacy-secret --print-value-only \
  | strings | grep -F 'k8s:enc:aescbc:v1:cks-109-aescbc-2026-rotation:'
exit   # root から
exit   # control-plane から
```

すべての Secret の migration が確認でき、backup が取られ、API がデータを読み取れ、`/readyz` が
`ok` を返したら、古い key をリストから削除し、API server を再起動して、
確認をやり直します。古い key をそれより早く削除しないでください：新しい provider で書き直されていないレコードは
読み取れなくなります。KMS v2 でも順序は同じです：まず新しい primary の KEK/plugin、次に
re-encryption、確認、そして migration の後にのみ古い KEK を運用から外します。
