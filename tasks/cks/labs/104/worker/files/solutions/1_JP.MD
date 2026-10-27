[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 104 - 参考解答：RBAC、ServiceAccount token、匿名 API

> 手順に特に記載がない限り、コマンドは作業マシンから実行します。Namespace
> `security-104` はすでに存在します。
>
> 試験では、`k` (`alias k=kubectl`) とその bash-completion が SSH ホスト上ですでに設定されています -
> その設定に時間を使わず、そのまま `k` を使ってください (第 33.6 章を参照)。

## 1. `auditor` による Pod のみへの最小限のアクセス

試験で、典型的な RBAC オブジェクトの完全な YAML を手書きするのは時間の無駄です：
`kubectl create` は ServiceAccount/Role/RoleBinding をそれぞれ 1 つのコマンドで生成します：

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # no になるはず
```

## 2. ServiceAccount の projected token

TokenRequest volume は短命の token を発行します；通常の automount は無効にします。
`audience: kubernetes.default.svc` はハードコードしません：kubeadm では、これが API server に受け入れられる
値であるとは限りません。`audience` を省略すると、kubelet は API server の
デフォルトの identifier を使用します。別の audience を指定してよいのは、control-plane で
`--api-audiences` (または `--service-account-issuer` のデフォルト) を確認した後だけです。
`expirationSeconds` は `600`-`3600` (両端を含む) の範囲である必要があります - Kubernetes API は、
`serviceAccountToken` の projected source に対して `600` 秒未満のあらゆる値を、
manifest に何が書かれていても invalid として拒否します。

`projected.sources[].serviceAccountToken` の正確な構文を試験で記憶から
思い出す必要はありません - `kubernetes.io/docs` の Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/) に、
**"serviceAccountToken projected volumes"** という見出しで載っています (この volume を持つ Pod の
用意された例があります - ゼロから書かず、そこから構造を取ってください)。`kubectl run` はフラグでは
そのような volume を追加できません - `--dry-run=client -o yaml` で Pod の骨組みを生成し、
ドキュメントの例からコピーした必要なフィールドだけを `vim` で追記します：

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# Pod の spec に追加します (containers/image/command は kubectl run がすでに生成済み):
spec:
  serviceAccountName: api-client              # 追加
  automountServiceAccountToken: false         # 追加
  containers:
  - name: token-client
    volumeMounts:                             # 追加
    - name: api-token                         # 追加
      mountPath: /var/run/secrets/tokens       # 追加
      readOnly: true                          # 追加
    ...
  volumes:                                    # 追加
  - name: api-token                           # 追加
    projected:                                # 追加
      sources:                                # 追加
      - serviceAccountToken:                  # 追加
          path: api-token                     # 追加
          expirationSeconds: 3600             # 追加
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# ファイルがあります - manifest がドキュメントの例と一致していれば、kubelet が発行したということです

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

ファイルの存在だけでなく、マウントされた projected token が期待される ServiceAccount として
実際に認証されることも、`TokenReview` に送信して確認します：

```bash
TOKEN=$(k exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)

k create -o jsonpath='{.status.authenticated}{" "}{.status.user.username}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $TOKEN
EOF
# true system:serviceaccount:security-104:api-client
```

この実習では、この確認は必須です：ファイルが存在するだけでは、projected token が有効で
期待される ServiceAccount として認証されることの証明にはなりません。`TokenReview` は
`authenticated: true` と username
`system:serviceaccount:security-104:api-client` を返す必要があります。

試験では、課題の条件が要求しない限り、`TokenReview` を別途実行する必要はありません：
そこでは、正しい projected token volume を素早く作成し、その課題に必要な方法で
結果を確認すれば十分です。ここでの `TokenReview` は学習用の verification チェックであり、
同時にこの実習の受け入れ基準にも対応しています。

## 3. API token を持たない Pod

ServiceAccount と Pod の両方で automount を無効にします：これは、テンプレートや ServiceAccount への
後の変更から守ってくれます。

`kubectl create serviceaccount` には `automountServiceAccountToken` 用のフラグがありません - 作成して
すぐにパッチを当てます：

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# Pod の spec に追加します:
spec:
  serviceAccountName: no-token-sa       # 追加
  automountServiceAccountToken: false   # 追加
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# YAML の spec のレベルだけでなく、runtime のレベルで確認します:
# コンテナ内に token ファイルが実際にないこと。
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - ファイルはなく、exec 自体は成功しました
```

`type: kubernetes.io/service-account-token` の legacy `Secret` を別途マウントすることもしないでください -
automount が無効でも、そのような Secret は `volumes[].secret` を通じて手動でマウントできてしまい、
その場合 Pod は automount フィールドの上では形式的に「token なし」ですが、実際には
コンテナ内に有効な API token を持つことになります。

## 4. wildcard 権限の削除

binding (subject はアクセスを受け取らなくなる) と、ClusterRole 自体 (危険な
テンプレートが再利用のために残らなくなる) の両方を削除します：

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # no になるはず
```

## 5. anonymous-auth の無効化

単純な `--anonymous-auth=false` はここでは適していません：kubeadm `release-1.36` は
kube-apiserver の static Pod を、`/livez` と `/readyz` への HTTPS liveness/readiness/startup probes とともに
生成し、kubelet の HTTP probes は client credentials を渡しません - anonymous access を
完全に無効にすると、これらのリクエストは `401` を受け取り、kubelet は kube-apiserver を
異常と見なし始めます (その結果、安定して動作する API server に依存する課題 9 も壊れます)。
代わりに、anonymous access を 3 つの health の path のみに制限する `anonymous.conditions` を持つ
`AuthenticationConfiguration` を使用します。試験では、すべてのコマンドに `sudo` を付けず、
一度 root になる (`sudo -i`) 方が速いです：

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

static manifest を修正します：`--anonymous-auth=true` を完全に削除し (`--authentication-config` と
並べて残してはいけません - 両方が指定されると kube-apiserver は起動を拒否します)、
`--authentication-config` を追加し、さらに新しい設定ファイル用の `hostPath` volume/volumeMount も追加します -
kube-apiserver は `authentication-config.yaml` をノードのファイルシステムから読み取るため、
ファイルはホスト上にあるだけでなく、volumeMount を通じて container 内から見える必要があります：

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command 配列で:
# - 行 "- --anonymous-auth=true" を削除します
# - 他の引数と同じインデントで次の行を追加します:
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# コンテナの volumeMounts に (隣接する要素と同じインデントで):
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# Pod の volumes に (隣接する要素と同じインデントで):
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` は static Pod の即時の再構築を強制します - 試験では、
kubelet がファイルの変更に自分で気づくのを待つより速いです (通常は数秒ですが、
瞬時であるとは限りません)：

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS が Running になるはずです - まだなら、数秒待ってからやり直してください
```

3 つの挙動をすべて確認します：`/version` は匿名リクエストを拒否し、`/livez`/`/readyz`
は受け付けます：

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access は閉じている
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - health probe は動作する
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - health probe は動作する
```

`/readyz` への認証済みリクエスト (すでに設定済みの kubectl context 経由) は、
まったく同じように動作し続けます - `AuthenticationConfiguration.anonymous.conditions` は、
anonymous リクエストに対して特定の path へのアクセスを広げるだけで、すでに認証された
クライアントのアクセスを狭めることはありません：

```bash
k get --raw=/readyz # ok
```

制限的な authorization のない authentication は無意味です - static Pod の
`--authorization-mode` がまだ `Node,RBAC` で、`AlwaysAllow` を含まないことを確認してください
(kubeadm はデフォルトでそう設定しますが、何かがフラグを変えていないか確認する価値があります)：

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

別途、subjects が匿名ユーザーまたはグループを指している ClusterRoleBinding を監査します -
クラスターには、そのような lab-owned の紐づけが 1 つ意図的に残されています：

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` は標準の kubeadm の紐づけです：これも
`system:unauthenticated` を対象としていますが、その ClusterRole が許可するのは、通常の
Kubernetes リソースではなく non-resource URL `/livez`、`/readyz`、`/healthz`、`/version`、`/version/` に対する
read-only の `GET` のみです - これは default Kubernetes RBAC であり、bootstrap に必要な部分なので、
触れないでください。これは、同じ課題の `anonymous.conditions` とは別のものです：そのリストは、
authentication の段階で、どの path でリクエストが anonymous identity を受け取るかを
制限します (そこにあるのは `/livez`/`/readyz`/`/healthz` のみ) - `/version` が匿名で
`401` を返すのは、まさにそこに anonymous identity が割り当てられないからであり、
`system:public-info-viewer` の権限がそこで足りないからではありません。`lab104-unintended-anonymous-access` は
意図的な lab-owned の発見事項です：その ClusterRole `lab104-anonymous-debug-access` は、
クラスター全体で `pods`/`secrets`/`configmaps` に対する本格的な RBAC `get`/`list` を与えており、つまり
任意の匿名リクエストがそれらを読み取れます。課題 4/7 と同様に、両方のオブジェクトを削除します：

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

取り消しは、まさに認証されていない identity (`system:anonymous` + グループ `system:unauthenticated`、
それ以外は何もなし) として行う negative control で、`SubjectAccessReview` を通じて確認します -
これは admin コンテキストが作成するため、グループのリストを
人為的に拡張する必要はありません：

```bash
for R in pods secrets configmaps; do
  for NS in $(k get ns -o jsonpath='{.items[*].metadata.name}'); do
    ALLOWED=$(k create -o jsonpath='{.status.allowed}' -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: system:anonymous
  groups: ["system:unauthenticated"]
  resourceAttributes:
    namespace: $NS
    resource: $R
    verb: get
EOF
    )
    printf '%-12s %-24s %s\n' "$R" "$NS" "$ALLOWED"
  done
done
# すべての行で false が期待されます
```

`can-i --as=system:anonymous` に `--as-group=system:authenticated` を追加しないでください：実際の
認証されていないリクエストはそのグループに含まれず、チェックは本物の
anonymous identity を反映しなくなります。namespace ごとに個別に確認するのは、
RoleBinding はそれ自身の namespace でのみ有効だからです：cluster-wide な紐づけがないことは、
ローカルな紐づけがないことの証明にはならず、受け入れ基準は、どの namespace でもアクセスがないことを要求しています。

最後に `check_result` を実行します。

## 6. env 経由の Secret の `/proc/1/environ` への漏洩：volume への移行

`app-vulnerable` は `envFrom` を通じて `db-creds` を受け取るため、値はコンテナの PID 1 プロセスの
environment に入ります。この Pod への `kubectl exec` 権限を持つ人なら誰でも、Kubernetes API にアクセスすることなく、
また `get secrets` の RBAC なしに、`/proc` から直接 secret を読み取れます：

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

値のない単なる単語 `DB_PASSWORD` ではなく、プロセスの環境にある行 `DB_PASSWORD=<実際の値>` を
そのまま保存します - checker が Secret `db-creds` の実際の値と自分で照合するため、
値を自分で別途計算して比較する必要はありません。

同じ名前で Pod を再作成します：`envFrom` を削除し、同じ Secret を volume
`db-creds-vol` として `/etc/secrets` に、read-only かつ `defaultMode: 0400` (`kubectl get pod -o json` が
表示するとおり decimal で `256`) でマウントします。`0400` はコンテナ内のファイルの所有者に対してのみの
read-only です；アプリケーションのプロセス自体もこの UID で起動する必要があり、そうでなければ
ファイルを読み取れません。

Pod のほとんどのフィールド (`volumes` を含む) は変更不可であるため、Pod は削除して、同じ名前で作り直す必要があります。ここでも、
YAML 全体を書くより、`--dry-run` で骨組みを生成して `vim` で volume を追記する方が簡単です：

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# Pod の spec に追加します:
spec:
  automountServiceAccountToken: false     # 追加
  containers:
  - name: app-vulnerable
    volumeMounts:                         # 追加
    - name: db-creds-vol                  # 追加
      mountPath: /etc/secrets             # 追加
      readOnly: true                      # 追加
    ...
  volumes:                                # 追加
  - name: db-creds-vol                    # 追加
    secret:                               # 追加
      secretName: db-creds                # 追加
      defaultMode: 0400                   # 追加
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

「environment に secret がない」だけでなく、最終的な 3 つの性質を確認します：ファイルの
パーミッションがちょうど `400` であること (どこかに部分文字列 `400` が含まれているだけではなく)、そして、より重要なことに、
アプリケーションが secret の値を実際に読み取れること - そうでなければ hardening が
気づかないうちにアプリケーション自体の機能を壊しているかもしれません：

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# 何も見つかりません - 想定どおりです

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - まさにこの値であり、どこかに "400" を含む任意のテキストではありません。フラグ -L は
# 必須です：secret volume は symlink のチェーン ("..data") 経由でマウントされるため、-L がないと
# stat は実際のファイルではなく symlink 自体のモード (Linux では常に 777) を表示します。

# Positive control: アプリケーションのプロセスが secret の値を実際に読み取れる必要があります。
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# 修正前の env-leak-before.txt にあった値と一致するはずです
```

`defaultMode: 0400` は、同じ Pod 上の他の UID による読み取り (たとえば、必要な UID を持たない
隣の sidecar-container) からは守りますが、etcd の encryption at rest の代わりにはならず、
想定された UID で起動したプロセスがファイル自体を読み取ることも妨げません - mount はまさにそれを許可します。
また、`db-creds` が同時に 2 つ目の方法でマウントされていないこと
(たとえば `projected` volume 経由でも) を確認してください - この Secret をマウントする volume は
ちょうど 1 つだけ残るはずです。

最後に `check_result` を実行します。

## 7. 隠れた RBAC privilege escalation 経路の監査と取り消し

`build-agent-hidden-privesc` には wildcard `*` は含まれませんが、`impersonate`/`bind`/`escalate`/
CSR-approval は危険な verbs の別のカテゴリです：これらは見えるリソースのリストを広げず、
**他者の名前で行動する**か、**自分自身に追加の権限を付与する**ことを可能にします。この fixture のバージョンでは、
ClusterRole に `clusterroles`/`clusterrolebindings` に対する基本的な
`create`/`update` も含まれています - それがなければ `bind`/`escalate` は
不完全な escalation primitives になります (RBAC は、ロールの権限をすでに持っているか、
または Role/Binding を実際に作成/更新しようとする**状況で**明示的に
`escalate`/`bind` を持っていることのどちらかを要求します)。
危険な verbs のいずれかを許可する ClusterRole を持つ、すべての ClusterRoleBinding を見つけます。ClusterRole
(クラスターには標準の `system:*` を含めて何十もあります) からではなく、
ClusterRoleBinding から始めます - `kubectl get clusterrolebinding` は、デフォルトですでに列
`ROLE` (形式 `ClusterRole/<名前>`) を表示し、`-o wide` は `USERS`/`GROUPS`/
`SERVICEACCOUNTS` も追加します - custom-columns も YAML も不要です：

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

各候補について、`jq`/YAML に対する `grep` なしで、その ClusterRole を人間が読める形で確認します -
`kubectl describe` は verbs を表形式で自分で出力するため、`impersonate`/`bind`/
`escalate` と、`certificatesigningrequests/approval` に対する別のルールがすぐに見えます：

```bash
k describe clusterrole build-agent-hidden-privesc
# PolicyRule 表の Verbs に impersonate / bind / escalate / update
# (certificatesigningrequests/approval に対して) が表示されます - このロールが危険であることが目で確認できます
```

ClusterRoleBinding の名前 (ClusterRole の名前ではありません - 一致しない場合があり、この実習では
たまたま一致しています) を artifact に保存します：

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` が最終的なファイルに含まれている必要があります (ClusterRoleBinding の名前として、
ClusterRole ではなく)。まさにこの ClusterRoleBinding を (そして、テンプレートが再利用のために残らないよう、
ClusterRole も) 削除し、Kubernetes の core コンポーネントに必要な
`impersonate`/CSR アクセスを与える `system:*` の bindings には触れません：

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

宣言された危険な権限のうち一部だけでなく、すべての取り消しを確認します。2 つの注意点：
この fixture は `impersonate` を 3 つのリソースタイプ (`users`/`groups`/`serviceaccounts`) すべてに対して
与えています - `users` だけを確認しても、残りの 2 つが取り消されたことの証明にはなりません；また、`kubectl auth
can-i` の `TYPE/NAME` は resourceName であり subresource ではありません (`kubectl auth can-i --help` は
まさに例 "jobs.batch/bar" を示しています - 文字どおり `bar` という名前のオブジェクトの確認です)。そのため、
`certificatesigningrequests/approval` には、スラッシュではなく
別のフラグ `--subresource=approval` が必要です：

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

最後に `check_result` を実行します。

## 8. Namespace レベルの baseline: automount なしの `default` SA

課題 3 では、特定の Pod とその専用の SA で個別に automount を無効にしました。ここで必要なのは
体系的な baseline です：namespace の `default` SA を、その中に Pod を**作成する前に**修正し、
開発者が manifest で明示的なフィールドを忘れたとしても、新しい workload がデフォルトで
token を受け取らないようにします。

ServiceAccount `default` は、Namespace が現れた後に別の controller によって非同期に作成されます -
`kubectl wait` は、condition だけでなく、オブジェクトが現れること自体 (`--for=create`) も待てるため、
手動の retry も自作のループも不要です：

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

`serviceAccountName` も `automountServiceAccountToken` も指定**しない** Pod を作成します -
これは、開発者が単に SA のことを考えない、現実で最もよくあるケースです。フィールド
`automountServiceAccountToken` は Pod の spec に存在してはいけません - 明示的に `false` を指定すると、
namespace レベルの baseline が実際に機能していることではなく、Pod 自体の個別の設定
(課題 3 のような) を実証するだけになってしまいます。

ここでは `--dry-run` すら不要です - Pod に SA/automount に関するフィールドを一切追加しないので、
フラグなしの `kubectl run` が、必要なものをそのまま直接作成します：

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# 空の出力 - フィールドは spec に存在せず、false に設定されているわけでもありません

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - ファイルはなく、exec 自体も成功しました (存在しないファイルに対する単純な
# "cat" とは異なります。その exit code も cat では非ゼロになりますが、理由が別です -
# test ! -e は必要なチェックをまさに行い、その成功自体を個別に
# 要求する必要があります。単に「任意のエラー = ファイルなし」ではありません)
```

SA の値は、Pod が自分でそれを上書きしない場合にのみ有効です。同じ namespace に
API アクセスを持つ Pod が必要になった場合は、本当にアクセスが必要であることを確認した上で、
その特定の manifest に `automountServiceAccountToken: true` を明示的に追加してください - namespace 全体の baseline である
`default` SA を `true` に戻さないでください。また、`volumes[].secret` を通じて
`type: kubernetes.io/service-account-token` の古い (legacy の) `Secret` を手動でマウントしないでください -
それは automount の設定に関係なく、Pod に有効な API token を与えてしまいます。

最後に `check_result` を実行します。

## 9. 統合課題：危険な RBAC の変更の検出 → audit log → containment

課題 1-8 では、`build-agent` 自身が利用できる特定の権限昇格経路 (wildcard、impersonate/bind/escalate、
automount) を塞ぎました。ここで必要なのは別の防御レイヤーです -
単なる RBAC の現在のスナップショットだけでなく、**管理者によって付与された危険な RBAC grant**
(誤って、compromise された automation によって、あるいは悪意を持って) の検出です。
control-plane に接続し、最小限の audit backend を準備します：

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

RBAC のルールが先頭にあります - より具体的なルールは一般的な
catch-all より前に置く必要があり、そうでないと `Metadata` がイベントを先に捕捉します。policy 全体のレベルの `omitStages: [RequestReceived]`
は、リクエストの処理前の余分なレコードを取り除きます - それには
`requestObject`/`responseStatus` がなく、checker はそのようなレコードをどのみち除外します (`stage ==
"ResponseComplete"`)。また、クラスターの他のすべてのリクエストに対する catch-all の `Metadata` ルールがあると、
このステージは audit.log の量を無駄に 2 倍にしてしまいます。

static manifest を修正します：`--audit-policy-file`/`--audit-log-path` と、policy およびログのディレクトリ用の hostPath
volume/volumeMount を追加します - 課題 5 の `authentication-config.yaml` と同じ手法です：

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# command 配列に、他の引数と同じインデントで次の行を追加します:
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# コンテナの volumeMounts に (隣接する要素と同じインデントで):
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# Pod の volumes に (隣接する要素と同じインデントで):
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` は static Pod の即時の再構築を強制します - 課題 5 と同様に、
kubelet がファイルの変更に自分で気づくのを待つより速い方法です：

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS が Running になるはずです - まだなら、数秒待ってからやり直してください
```

作業マシンに戻り (管理者 `cluster1-admin` として)、危険な紐づけを作成します -
これは `build-agent` による escalation の試み**ではなく** (課題 7 の後、
`build-agent` にはそのための実際の経路はもうありません)、管理者の行為をモデル化したもので、
audit log は、それを実際に誰が行い、誰に権限が付与されたのかについての
再現可能な evidence として捕捉する必要があります：

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

まず、audit ルールが実際に機能し、イベントがログに入ったことを目で確認します -
試験で通常必要なのは、用意された artifact ではなく、まさにこの確認です：

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` はログの各レコードを人間が読める形 (1 行に 1 フィールド) で出力し、`grep -A 30`
は、名前が見つかった行とその後の 30 行を表示します - これで、`stage`、`user.username` (実際の開始者)、
`requestObject.roleRef`、`requestObject.subjects` を、特別な jq の構文なしで目で見るのに十分です。

実際の試験にはこれで十分ですが、この実習ではさらにイベントの artifact ファイルが必要です -
ルールが機能していることを知るだけでは checker に足りないからではなく (checker は
SSH 経由で control-plane の `audit.log` を独立して自分で読み取ります)、別のスキルを確認するためです：
実際のレコードを、自分の言葉で言い換えるのではなく、forensic evidence として
抽出して保存すること (checker は、あなたのファイルの `auditID` を、ログ内の実際のレコードの `auditID` と照合します)。
`/var/work/tests/artifacts/9/` は control-plane ではなく**作業マシン**上のパスなので、
作業マシンから `ssh control-plane "..."` を通じて、通常の部分文字列に対する同じ grep の組み合わせで保存します
(イベント名 + `ResponseComplete` で、同じ request の途中の
`ResponseStarted` レコードに当たらないようにします)：

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

イベントを、audit log に実際にある**そのままの全体** (`auditID` を含む) で保存します -
書き直したり JSON を手動で組み立てたりしないでください。そうしないと、検証時に artifact が
ログ内の実際のレコードと一致しません。

Containment：紐づけを削除し、オブジェクトが単に読み取れなくなったのではなく、アクセスが実際に取り消されたことを確認します。
`can-i` は `-n`/`-A` なしでは、クラスター全体ではなく、kubeconfig コンテキストの現在の namespace のみを確認します -
`security-104` の namespaced な RoleBinding (すでに削除された cluster-wide な ClusterRoleBinding とは異なり) では、
これが結果を変えるため、namespace を明示します：

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

課題 7 との違い：あちらでは、RBAC オブジェクトの静的解析によって、workload 自身 (`build-agent`) に属する
**すでに存在する**隠れた経路を見つけて取り消しました。ここでの
source of truth は **時間軸上のイベント** (audit log) で、誰が
(フィールド `user.username` - リクエストの実際の開始者で、この場合は管理者であり、
`build-agent` ではありません) 危険な権限を、誰に対して付与したのかを証明します - これは、
使用後にオブジェクト自体がすでに削除されているかもしれない実際のインシデントで必要となるものであり、`build-agent` は
イベントの中では、リクエストの作成者ではなく、権限の受け取り手としてのみ登場します。

最後に `check_result` を実行します。

## 10. Secret のデコード、作成、マウント

`legacy-config` はすでに存在します。推測せずに、API 経由で両方の値を読み取ります：

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

同じキー名と同じ値で新しい generic Secret を作成します -
`--from-literal` は値を自分で base64 にエンコードするため、手動で行う必要はありません：

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

それを read-only の volume として Pod にマウントします - ここでも dry-run + `vim` での個別の修正です：

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# Pod の spec に追加します:
spec:
  automountServiceAccountToken: false      # 追加
  containers:
  - name: secret-workflow
    volumeMounts:                          # 追加
    - name: rehydrated-config-vol          # 追加
      mountPath: /etc/rehydrated           # 追加
      readOnly: true                       # 追加
    ...
  volumes:                                 # 追加
  - name: rehydrated-config-vol            # 追加
    secret:                                # 追加
      secretName: rehydrated-config        # 追加
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# 上の $SERVICE_USER / $SERVICE_TOKEN と一致するはずです
```

最後に `check_result` を実行します。

## 11. 既存の Role の修復と、別の namespace の SA への紐づけ

`rbac-a` の既存の Role `pod-role` は `get`、`list`、`delete` を許可しています - 余分な
`delete` を削除し、必要な `watch` を追加します：

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` は `rbac-b` にすでに存在します。まさに `rbac-b` の中に、新しい Role+RoleBinding を作成します -
RoleBinding は別の namespace の subject をサポートしますが、権限自体は
RoleBinding 自身の namespace でのみ有効です：

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

`dev` を実際に使用する Pod を `rbac-a` に作成します：

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

最後に `check_result` を実行します。

## 12. CSR + namespaced RBAC による Client certificate ユーザー

private key と `CN=john` の CSR を生成します - 証明書ベースのユーザーの RBAC は
`kind: User` を通じて紐づけます (`ServiceAccount` ではありません)。`User` には専用の API
オブジェクトがなく、その identity は、クライアント証明書の CN が
binding の `name` と一致しているかどうかで完全に決まります。

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

課題 7 で CSR の承認にすでに使用したのと同じ signer を使って、Kubernetes `CertificateSigningRequest` として送信します
(`kubernetes.io/kube-apiserver-client` は、API server へのリクエストを
認証する client-auth 証明書のための、まさに正しい signer です)：

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

`status.certificate` フィールドが空でないことだけでなく、証明書がこのクラスターによって
実際に署名されたことを確認します：

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC：`development` の Role と、`kind: User, name: john` への RoleBinding - `kubectl create rolebinding` の `--user=john` は
自分で `kind: User` を設定するため、YAML を書く必要はありません：

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` が実証するのは RBAC のロジックだけです (実際の証明書が発行されたかどうかに関係なく、
admin なら誰でも使える impersonation です)。別途、**発行された**証明書が、本物の TLS client-auth の
リクエストで API server に実際に受け入れられることを実証します：

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

同じ証明ですが、`curl` ではなくおなじみの `kubectl` を通じて行います - すでに発行された証明書から John 用の
別の kubeconfig を組み立てます (`set-credentials` には `--token` ではなく `--client-certificate`/
`--client-key` を使います。ここでの identity は ServiceAccount token ではなく、まさに client-cert だからです)：

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# 動作します - RBAC が通します

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - 上の curl での確認と同じ 403 です

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - この kubeconfig が、たまたま必要なレスポンスコードを返しているのではなく、
# 実際にまさに john として認証されていることを確認します
```

最後に `check_result` を実行します。