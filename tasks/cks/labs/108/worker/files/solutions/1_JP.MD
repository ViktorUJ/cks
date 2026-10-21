[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 108 - 参考解答：Kyverno admission policies

> すべてのコマンドは作業マシンで実行します。コンテキストはすでに設定済みです；namespace
> `policy-108` は起動スクリプトによって作成されています。まず Kyverno をインストールして
> webhook を待ってください：そうしないと、後続の CEL ベースの policies は admission リクエストを確認しません。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Kyverno をインストールする

worker には固定された installer が用意されています：これは Kyverno の Helm chart
`3.9.0` (Kyverno `1.19`) を namespace `kyverno` にインストールします。実行する前に中身を確認できます。

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

`kyverno` 内の少なくとも 1 つの Deployment が `AVAILABLE > 0` になるまで待ちます。

> **Migration note.** 古い `kyverno.io/v1` の `Policy`/`ClusterPolicy` の例は、既存のクラスターを
> 保守する場合にのみ役立ちます。Kyverno `1.19` ではこれらは deprecated であり、
> `1.20` で削除が予定されています。この実習の新しい policy は
> `policies.kyverno.io/v1` を使用します。

## 2. タグ `latest` を禁止する

`Deny` モードの `ValidatingPolicy` を作成します。ルールは 3 つのコンテナリストすべて -
`containers`、`initContainers`、`ephemeralContainers` を確認します：そうでないと、禁止された image を
init または ephemeral コンテナ経由で簡単にすり抜けさせることができ、Pod 自体は admission を通ってしまいます。

```yaml
# deny-latest-tag.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: deny-latest-tag
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must use an explicit non-latest tag or a digest.
    expression: >-
      variables.images.all(image,
        image.contains('@') ||
        (image.matches('^(?:.*/)?[^/:]+:[^/]+$') && !image.endsWith(':latest')))
```

```bash
kubectl apply -f deny-latest-tag.yaml
```

課題は image reference の 2 つの形式 - latest 以外のタグ、または digest - を許可しています。
digest の形式が通ることを (versioned tag が通ることだけでなく) 明示的に確認してください - そうでないと、
すべての digest references を誤って拒否する policy を書いてしまいやすいです：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: digest-pinned-ok
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56
EOF
# 期待される結果: 成功 (admission エラーなし)
```

タグの処理が registry のポートのコロンを考慮していることを確認してください：`registry.example:5000/app`
には image tag がなく、implicit latest として拒否されなければなりません。Digest は
他のコンテナリストでも受け入れられる必要があります - たとえば `initContainers` や、
`ephemeralContainers` 用の `kubectl debug --image=...` を通じて。

## 3. `runAsNonRoot` を要求する

policy は、Pod-level の `securityContext` で値がまさに `true` であることを要求します；暗黙の
値と `false` は通りません。さらに、Pod レベルの `runAsUser: 0` と、3 つすべての
container lists の container-level の overrides `runAsNonRoot: false` / `runAsUser: 0` が禁止されます。そうでなければ、container-level の securityContext が
Pod-level の `runAsNonRoot: true` を上書きして、root プロセスを起動できてしまいます。

```yaml
# require-run-as-non-root.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  validations:
  - message: Pod and every container must have an effective non-root security context.
    expression: >-
      has(object.spec.securityContext) &&
      object.spec.securityContext.?runAsNonRoot.orValue(false) &&
      object.spec.securityContext.?runAsUser.orValue(1) != 0 &&
      object.spec.containers.all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?initContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?ephemeralContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0))
```

```bash
kubectl apply -f require-run-as-non-root.yaml
```

## 4. 承認された registry のみを許可する

許可されるのは `registry.k8s.io` と、専用の組織パス `ghcr.io/cks-lab` です。CEL は
3 つの container lists をすべて結合し、各 image に 1 つの allowlist を適用します。

```yaml
# allow-approved-registries.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: allow-approved-registries
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must come from registry.k8s.io or ghcr.io/cks-lab.
    expression: >-
      variables.images.all(image,
        image.startsWith('registry.k8s.io/') ||
        image.startsWith('ghcr.io/cks-lab/'))
```

```bash
kubectl apply -f allow-approved-registries.yaml
```

Pod を作成せず、image pull もしない確認です。`docker.io` は 1 つの具体的な
untrusted の値にすぎません；policy が本当に allowlist (許可された 2 つ以外の任意の
registry を禁止する) であり、単に文字列として `docker.io` を禁止する denylist ではないことを確認してください -
そうでないと、unqualified な image、別のサードパーティの registry、綴りの似た host が
簡単にすり抜けます。

Positive controls は、`containers`、`initContainers`、`ephemeralContainers` で、許可された 2 つの prefix (`registry.k8s.io/` と
`ghcr.io/cks-lab/`) の両方をカバーする必要があります；どちらかの registry を通常のコンテナだけに
限定しないでください：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-unqualified-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-quay-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: quay.io/prometheus/busybox:v0.24.0
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-lookalike-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io.evil.example/pause:3.10
EOF
```

4 つすべてが拒否される必要があります。以下の最初の Pod はメインのコンテナでルールに違反し、
2 つ目は `initContainers` のみで違反します；両方とも拒否される必要があります：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry-main
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-init-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: docker.io/library/busybox:1.36
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

どちらのコマンドも admission policy のエラーで終了する必要があります。`ephemeralContainers` を通じた
明示的な回避の試みについては、許可された Pod を作成してから、まず
`docker.io/library/busybox:1.36` で `kubectl debug` を実行し (denial が期待されます)、次に
`registry.k8s.io/e2e-test-images/busybox:1.36-1` で実行します (成功が期待されます)。subresource の
update を保護するのは、まさに `matchConstraints` の `pods/ephemeralcontainers` です。

## 5. オプション：mutation label

この `MutatingPolicy` は Pod を拒否せず、CEL の
`ApplyConfiguration` を通じて label を追加します - ただし label がまだ設定されていない場合のみです。課題が求めているのは、まさに
defaulting のセマンティクス (「存在しない場合」) です：すでにこの label を異なる
値で (たとえば別の所有者/ツールによって) 持っている Pod は、強制的に上書きされてはなりません。

```yaml
# add-kyverno-managed-label.yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-kyverno-managed-label
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE]
      resources: [pods]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  mutations:
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        has(object.metadata.labels) &&
        'security.cks.io/managed-by' in object.metadata.labels
        ? Object{}
        : Object{
            metadata: Object.metadata{
              labels: {"security.cks.io/managed-by": "kyverno"}
            }
          }
```

```bash
kubectl apply -f add-kyverno-managed-label.yaml
kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# 期待される結果: kyverno

kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check-existing-label
  namespace: policy-108
  labels:
    security.cks.io/managed-by: external
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# 期待される結果: external (mutation はすでに設定された値を上書きしません)
```

`check_result` を実行します。課題 5 はチェックに表示されますが、オプションです：mutation policy がなくても、
課題 1-4、6、7 の合格には影響しません。

## 6. ImagePolicyWebhook: 外部 backend

課題 1-5 とは異なり、ここでは image の判断を、Kyverno 内の CEL 式ではなく、
API `ImageReview` を通じた外部の HTTPS-backend が行います。Upstream のドキュメントは
ImagePolicyWebhook が、backend との接続に TLS を使用することを明示的に要求しているため ("It is
required that the backend communicate over TLS")、HTTP ではなく自己署名の
証明書を使用します。

Backend はすでに作業マシンに用意されています：

```bash
cat /opt/image-policy-backend/server.py
```

namespace と、backend のコードを持つ ConfigMap を作成します：

```bash
kubectl create namespace image-policy --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap image-policy-backend-src -n image-policy \
  --from-file=server.py=/opt/image-policy-backend/server.py \
  --dry-run=client -o yaml | kubectl apply -f -
```

Deployment の**前に** Service を作成します - 証明書の正しい SAN のために `ClusterIP` が必要です：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  selector:
    app: image-policy-backend
  ports:
  - port: 8443
    targetPort: 8443
EOF

BACKEND_IP=$(kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.clusterIP}')
echo "$BACKEND_IP"
```

この `ClusterIP` を SAN に含む自己署名証明書を発行し、Secret に保存します：

```bash
workdir=$(mktemp -d)
openssl req -x509 -nodes -newkey rsa:2048 -days 3 \
  -keyout "$workdir/tls.key" -out "$workdir/tls.crt" \
  -subj "/CN=image-policy-backend" \
  -addext "subjectAltName=IP:${BACKEND_IP}"

kubectl create secret tls image-policy-backend-tls -n image-policy \
  --cert="$workdir/tls.crt" --key="$workdir/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
```

コードと証明書の両方をマウントして Deployment をデプロイします：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-policy-backend
  template:
    metadata:
      labels:
        app: image-policy-backend
    spec:
      containers:
      - name: backend
        image: python:3.12-slim
        command: ["python3", "/opt/image-policy/server.py"]
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: src
          mountPath: /opt/image-policy
        - name: tls
          mountPath: /opt/image-policy/tls
          readOnly: true
      volumes:
      - name: src
        configMap:
          name: image-policy-backend-src
      - name: tls
        secret:
          secretName: image-policy-backend-tls
EOF

kubectl rollout status deployment/image-policy-backend -n image-policy --timeout=90s
```

kube-apiserver が backend への接続時に証明書チェーンを検証できるよう、CA 証明書 (ここは自己署名なので、サーバー証明書自体が
自分自身の CA です) を `control-plane` にコピーし、ノードに入ります：

```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
scp "$workdir/tls.crt" "$CP":/tmp/image-policy-ca.crt
rm -rf "$workdir"
echo "$BACKEND_IP"     # ノード上で必要になります
ssh "$CP"
sudo -i
```

`control-plane` で、backend 用の admission config と kubeconfig を作成します。パスは **control-plane 自身の**ディスク上です：

```bash
# control-plane で (root)
mkdir /etc/kubernetes/image-policy
mv /tmp/image-policy-ca.crt /etc/kubernetes/image-policy/ca.crt

cat > /etc/kubernetes/image-policy/admission-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/image-policy/kubeconfig
      allowTTL: 30
      denyTTL: 30
      retryBackoff: 500
      defaultAllow: false
EOF

BACKEND_IP=10.111.15.20     # "echo $BACKEND_IP" が出力した ClusterIP を入力します
cat > /etc/kubernetes/image-policy/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: image-policy-backend
  cluster:
    certificate-authority: /etc/kubernetes/image-policy/ca.crt
    server: https://${BACKEND_IP}:8443/imagepolicy
users:
- name: kube-apiserver
contexts:
- name: image-policy
  context:
    cluster: image-policy-backend
    user: kube-apiserver
current-context: image-policy
EOF
```

static manifest を **`control-plane` 上で**編集します (すでに root セッションにいます)。既存の
`--enable-admission-plugins` を丸ごと置き換えないでください - 現在の値 (通常はすでに `NodeRestriction` が
あります) に `ImagePolicyWebhook` を追記し、`--admission-control-config-file` と
`--runtime-config` を追加し、新しいディレクトリを hostPath としてマウントします：

```bash
# control-plane で (root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# control-plane 上の /etc/kubernetes/manifests/kube-apiserver.yaml の抜粋
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook   # 既存のリストに追記します
    - --admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml
    - --runtime-config=imagepolicy.k8s.io/v1alpha1=true               # runtime-config がすでに設定されていた場合は追記します
    volumeMounts:
    - name: image-policy
      mountPath: /etc/kubernetes/image-policy
      readOnly: true
  volumes:
  - name: image-policy
    hostPath:
      path: /etc/kubernetes/image-policy
      type: DirectoryOrCreate
```

保存した後、ノードから抜けます；kubelet が static Pod の変更を自分で検出します：

```bash
exit   # root から
exit   # control-plane から
```

API が復旧するまで待ちます：

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -q '^ok$'; do sleep 5; done
```

両方のケースを確認します：

```bash
kubectl run webhook-latest-must-fail --image=nginx:latest
# Error from server (Forbidden): pods "webhook-latest-must-fail" is forbidden:
# image policy webhook backend denied one or more images: Images using latest tag are not allowed

kubectl run webhook-pinned-ok --image=nginx:1.27.3
kubectl get pod webhook-pinned-ok
# STATUS: Running
```

`ImagePolicyWebhook` は `/opt/image-policy-backend/server.py` の backend を使用します：
`default` とその他の namespace (`policy-108` を除く) では、explicit/implicit の
latest を禁止します；`policy-108` は、課題 2-4 の 3 つの Kyverno-policy が完全に制御します。
これは仕組みを分離するための実習上の措置であり、一般的な production パターンではありません。
ユーザー定義のアノテーション `alpha.image-policy.k8s.io/break-glass` は許可を**与えません**：
ImageReview の forwarding annotations は認証の確認ではありません。

`defaultAllow: false` は fail-closed を意味します：backend が利用できない場合、新しい Pod/image は
許可されず、禁止されます。これを明示的に確認してください - ただし `image-policy-backend` を 0 レプリカに
スケールしては**いけません**：`ImagePolicyWebhook` はこの構成では namespace による除外のない cluster-wide の
admission plugin であるため、backend 自身の Pod も確認します。レプリカを一時的にすべて取り除いてから
戻そうとすると、新しい backend Pod の作成自体が、同じ (その時点で
利用できない) ImagePolicyWebhook を通ることになり、正しい `defaultAllow: false` のもとで拒否されます -
`kubectl rollout status` が終わらないデッドロックになります。代わりに、
`selector` を存在しない値に変更して Service を backend から切り離してください - これは Pod を 1 つも
作成も削除もせず、一時的に `Endpoints` を取り除くだけです：

```bash
kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.selector}'
# 後で復元できるよう、この値を保存しておきます

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# ENDPOINTS が空になったら Ctrl+C

kubectl run webhook-should-fail-closed --image="nginx:fail-closed-check-$(date +%s%N)"
# 期待される結果: Forbidden - backend が利用できず、defaultAllow:false が admission を禁止します
# (単なる秒単位の日付ではなく、まだ見たことのないタグを使うのは、前回の試行の同じタグに対する
# backend の応答の TTL キャッシュに当たらないようにするためです)

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# ENDPOINTS が再び現れたら Ctrl+C - プローブの前と同じ Pod であり、再構築/再作成は
# 不要でした
```

これは、production 構成の ImagePolicyWebhook について[コースの第 26 章](../../../../../course/26/jp.md)で説明されているのと
同じ、原理的な fail-closed の判断です。

## 7. Gatekeeper: ConstraintTemplate に Rego の blocklist を書き足す

Gatekeeper と初期の (不完全な) `ConstraintTemplate`/`Constraint` は、クラスターの
bootstrap によって別の namespace `gatekeeper-108` にすでにデプロイされています - これはこの実習における独立した、3 つ目の
admission engine (Kyverno と ImagePolicyWebhook の次) で、まさに
OPA/Rego のスキルを確認します。`gatekeeper-108` は、Kyverno の課題 1-5 (`policy-108`) から意図的に
分離されています：そうでないと、同じテスト Pod が Kyverno と
Gatekeeper の両方に同時に拒否される可能性があり、denial の原因が曖昧になります。現在の Rego を確認します：

```bash
kubectl get constrainttemplate k8sblockedregistries -o yaml
```

`spec.targets[].rego` は、ブロックされた registry を個別のファクトとして宣言しています：

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
```

`very-bad-registry.test` はその中にありません - まさにこの行を書き足す必要があります。`Constraint
deny-bad-registries` はすでに完全に正しく、`spec.parameters` をまったく使用していません -
編集する必要はありません；修正はまさに `ConstraintTemplate` 内の Rego にあり、Constraint にはありません。template を編集し (たとえば `kubectl edit
constrainttemplate k8sblockedregistries`、または `get -o yaml` → 修正 → `apply -f -`)、
既存の行を削除せずに新しい行を追加します：

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
blocked_registry("very-bad-registry.test")
```

永続的な Pod を作成せずに、server-side dry-run で 3 つの結果すべてを確認します：新しい
registry は denied になり、古い (すでにブロックされている) ものは denied のまま (リグレッションなし)、
信頼されたものは通る必要があります：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-new-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
# 期待される結果: Error from server ... admission webhook "validation.gatekeeper.sh" denied
# the request: [deny-bad-registries] image registry very-bad-registry.test is blocked
# by k8sblockedregistries

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-old-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
# 期待される結果: こちらも Error from server ... - 古いルールが失われていてはなりません

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-trusted-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# 期待される結果: 成功 (admission エラーなし)
```

拒否が実際に Gatekeeper (`validation.gatekeeper.sh`) から来たものであり、課題 2-4 の Kyverno
`ValidatingPolicy` のいずれかからではないことを確認してください - エラーメッセージが
webhook と Constraint の名前を明示しています。課題を `Constraint.spec.parameters` で解決しないでください。
この policy のバージョンでは、Constraint はそれらをまったく使用しません。

`check_result` を実行します。
