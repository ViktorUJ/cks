[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 108 - 參考解答：Kyverno admission policies

> 所有指令都在工作機上執行。Context 已經設定好；namespace
> `policy-108` 由啟動腳本建立。請先安裝 Kyverno 並等待
> webhook：否則後續基於 CEL 的 policies 不會檢查 admission 請求。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. 安裝 Kyverno

worker 上準備了固定版本的 installer：它會把 Kyverno 的 Helm chart
`3.9.0`(Kyverno `1.19`)安裝到 namespace `kyverno`。執行之前可以先查看它。

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

等到 `kyverno` 中至少有一個 Deployment 的 `AVAILABLE > 0`。

> **Migration note**。舊的 `kyverno.io/v1` `Policy`/`ClusterPolicy` 範例只在維護
> 既有叢集時才有用。在 Kyverno `1.19` 中它們已被 deprecated,
> 並計畫在 `1.20` 中移除。本實驗中的新 policy 使用
> `policies.kyverno.io/v1`。

## 2. 禁止 `latest` 標籤

建立 `Deny` 模式的 `ValidatingPolicy`。規則會檢查全部三個 container 清單 -
`containers`、`initContainers` 與 `ephemeralContainers`：否則被禁止的 image 很容易
透過 init 或 ephemeral container 夾帶進去，而 Pod 本身仍然會通過 admission。

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

任務允許「兩種」image reference 形式 - non-latest tag 或 digest。請
明確檢查 digest 形式能通過(而不只是帶版本的 tag 能通過)- 否則很容易
寫出一個不小心拒絕「所有」digest reference 的 policy:

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
# 預期:成功(沒有任何 admission 錯誤)
```

確認標籤的處理考慮到 registry 埠中的冒號：`registry.example:5000/app`
不包含 image tag，必須被當作 implicit latest 而被拒絕。Digest 在其他 container 清單中
也必須被接受 - 例如在 `initContainers` 中，以及透過
`kubectl debug --image=...` 用於 `ephemeralContainers`。

## 3. 要求 `runAsNonRoot`

這個 policy 要求 Pod-level `securityContext` 中的值正是 `true`；隱含的
值與 `false` 都不會通過。此外還禁止 Pod 層級的 `runAsUser: 0`,
以及在全部三個 container 清單中 container-level 的 overrides `runAsNonRoot: false` / `runAsUser: 0`，否則 container-level 的 securityContext 就能夠覆寫
Pod-level `runAsNonRoot: true`，並啟動 root 行程。

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

## 4. 只允許已核准的 registry

允許 `registry.k8s.io` 與專門的組織路徑 `ghcr.io/cks-lab`。CEL
合併全部三個 container 清單，並對每個 image 套用同一個 allowlist。

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

不建立 Pod、不 pull image 的檢查。`docker.io` 只是「一個」具體的
untrusted 值；請確認 policy 確實是 ALLOWLIST(禁止兩個允許的 registry 之外的「任何」
registry)，而不只是逐字字串的 `docker.io` denylist -
否則 unqualified image、另一個第三方 registry 或寫法相似的 host 很容易
繞過。

Positive controls 必須在 `containers`、`initContainers` 與 `ephemeralContainers` 中涵蓋兩個允許的 prefix(`registry.k8s.io/` 與
`ghcr.io/cks-lab/`)；不要
讓其中一個 registry 只限於一般的 container。

Negative controls(這些 manifest 中的每一個都必須被拒絕)：

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

四個都必須被拒絕。下面第一個 Pod 是主 container 違反規則，
第二個 - 只有 `initContainers` 違反；兩者都必須被拒絕：

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

兩個指令都必須以 admission policy 錯誤結束。若要明確嘗試透過
`ephemeralContainers` 繞過，請建立一個允許的 Pod，然後先用
`docker.io/library/busybox:1.36` 執行 `kubectl debug`(預期 denial)，再用
`registry.k8s.io/e2e-test-images/busybox:1.36-1`(預期成功)。保護 subresource update 的
正是 `matchConstraints` 中的
`pods/ephemeralcontainers`。

## 5. 選擇性：mutation label

這個 `MutatingPolicy` 不拒絕 Pod，而是透過 CEL
`ApplyConfiguration` 加入 label - 但只有在 label 還沒有設定時才會加入。任務要求的正是
defaulting 語意(「如果它不存在」)：已經帶有這個 label、但值「不同」的 Pod
(例如來自其他擁有者/工具)，其 label 值不應被強制覆寫。

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
# 預期:kyverno

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
# 預期:external(mutation「不會」覆寫已經設定的值)
```

執行 `check_result`。任務 5 會顯示在檢查中，但它是選擇性的：缺少
mutation policy 不會影響任務 1-4、6 與 7 的計分。

## 6. ImagePolicyWebhook：外部 backend

與任務 1-5 不同，這裡 image 的決定是由外部 HTTPS-backend 透過
`ImageReview` API 做出的，而不是 Kyverno 內部的 CEL 運算式。上游關於
ImagePolicyWebhook 的文件明確要求 backend 連線使用 TLS("It is
required that the backend communicate over TLS")，因此我們使用自簽
憑證，而不是 HTTP。

Backend 已經在工作機上準備好了：

```bash
cat /opt/image-policy-backend/server.py
```

建立 namespace 以及帶有 backend 程式碼的 ConfigMap:

```bash
kubectl create namespace image-policy --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap image-policy-backend-src -n image-policy \
  --from-file=server.py=/opt/image-policy-backend/server.py \
  --dry-run=client -o yaml | kubectl apply -f -
```

在 Deployment「之前」建立 Service - 需要 `ClusterIP` 才能在憑證中放入正確的 SAN:

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

簽發在 SAN 中帶有這個 `ClusterIP` 的自簽憑證，並把它儲存到 Secret:

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

部署 Deployment，同時掛載程式碼與憑證：

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

把 CA 憑證(這裡是 self-signed，所以伺服器憑證本身就是它自己的
CA)複製到 `control-plane`，讓 kube-apiserver 在連線到 backend 時能夠驗證憑證鏈，然後登入節點：

```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
scp "$workdir/tls.crt" "$CP":/tmp/image-policy-ca.crt
rm -rf "$workdir"
echo "$BACKEND_IP"     # 在節點上會用到
ssh "$CP"
sudo -i
```

在 `control-plane` 上建立 admission config 與給 backend 的 kubeconfig。路徑位於 **control-plane
本身**的磁碟上：

```bash
# 在 control-plane 上(root)
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

BACKEND_IP=10.111.15.20     # 填入 "echo $BACKEND_IP" 輸出的 ClusterIP
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

**在 `control-plane` 上**編輯 static manifest(你已經在 root 工作階段中)。不要整個取代
既有的 `--enable-admission-plugins` - 請把 `ImagePolicyWebhook` 接在目前的
值之後(通常那裡已經有 `NodeRestriction`)，加入 `--admission-control-config-file` 與
`--runtime-config`，並把新的目錄以 hostPath 掛載：

```bash
# 在 control-plane 上(root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# control-plane 上 /etc/kubernetes/manifests/kube-apiserver.yaml 的片段
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook   # 接在既有清單之後
    - --admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml
    - --runtime-config=imagepolicy.k8s.io/v1alpha1=true               # 如果 runtime-config 已經設定過,就補寫在後面
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

儲存之後離開節點；kubelet 會自己接手 static Pod 的變更：

```bash
exit   # 離開 root
exit   # 離開 control-plane
```

等待 API 恢復：

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -q '^ok$'; do sleep 5; done
```

檢查這兩種情況：

```bash
kubectl run webhook-latest-must-fail --image=nginx:latest
# Error from server (Forbidden): pods "webhook-latest-must-fail" is forbidden:
# image policy webhook backend denied one or more images: Images using latest tag are not allowed

kubectl run webhook-pinned-ok --image=nginx:1.27.3
kubectl get pod webhook-pinned-ok
# STATUS: Running
```

`ImagePolicyWebhook` 使用來自 `/opt/image-policy-backend/server.py` 的 backend:
在 `default` 與其餘 namespace(`policy-108` 除外)中，它禁止 explicit/implicit
latest;`policy-108` 則完全由任務 2–4 的三個 Kyverno policy 控制。
這是實驗用的機制隔離，而不是通用的 production pattern。
使用者 annotation `alpha.image-policy.k8s.io/break-glass` 「不會」給予許可：
在 ImageReview 中傳遞 annotations 並不是身分驗證。

`defaultAllow: false` 表示 fail-closed：如果 backend 無法連線，新的 Pod/image
會被禁止，而不是被允許。請明確檢查這一點 - 但「不要」把
`image-policy-backend` 縮減到 0 個 replica:`ImagePolicyWebhook` 是 cluster-wide 的 admission
plugin，在我們的設定中沒有依 namespace 的例外，因此它也會檢查 backend 自己的 Pod。
如果暫時移除所有 replica，然後試圖把它們恢復回來，建立「新的」backend Pod
「本身」就會經過同一個(此刻無法連線的)ImagePolicyWebhook，並在 `defaultAllow: false` 正確運作時被拒絕 -
就會形成 deadlock,`kubectl rollout status` 無法脫離。因此請改為
把 Service 與 backend 斷開，把 `selector` 改成不存在的值 - 這不會
建立也不會刪除任何 Pod，只是暫時移除 `Endpoints`:

```bash
kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.selector}'
# 記下這個值,以便稍後恢復

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# 當 ENDPOINTS 變空時按 Ctrl+C

kubectl run webhook-should-fail-closed --image="nginx:fail-closed-check-$(date +%s%N)"
# 預期:Forbidden - backend 無法連線,defaultAllow:false 禁止 admission
# (使用「尚未見過」的標籤,而不只是以秒為單位的日期,以免撞上
# backend 對上一次嘗試中同一個標籤的 TTL 快取回應)

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# 當 ENDPOINTS 再次出現時按 Ctrl+C - 這和探測之前是同一個 Pod,不需要任何
# 重建/重新建立
```

這和[課程的第 26 章](../../../../../course/26/tw.md)中為
production 設定的 ImagePolicyWebhook 所描述的，是同樣原則性的 fail-closed 決策。

## 7. Gatekeeper：在 ConstraintTemplate 中補寫 Rego blocklist

Gatekeeper 以及起始的(不完整的)`ConstraintTemplate`/`Constraint` 已經由
叢集的 bootstrap 部署在單獨的 namespace `gatekeeper-108` 中 - 這是本實驗中單獨的、第三個
admission engine(在 Kyverno 與 ImagePolicyWebhook 之後)，檢查的正是
OPA/Rego 技能。`gatekeeper-108` 與 Kyverno 的任務 1-5(`policy-108`)是刻意隔離的：
否則同一個測試 Pod 可能同時被 Kyverno 與
Gatekeeper 拒絕，denial 的來源就會不明確。查看目前的 Rego:

```bash
kubectl get constrainttemplate k8sblockedregistries -o yaml
```

`spec.targets[].rego` 透過獨立的事實宣告被封鎖的 registry:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
```

其中沒有 `very-bad-registry.test` - 需要補寫的正是這一行。`Constraint
deny-bad-registries` 已經完全正確,而且完全不使用 `spec.parameters` -
不需要編輯它；修正「正是」在 `ConstraintTemplate` 內的 Rego 中，
而不是在 Constraint 中。編輯 template(例如 `kubectl edit
constrainttemplate k8sblockedregistries`,或 `get -o yaml` → 修改 → `apply -f -`),
加入新的一行，但不要刪除既有的：

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
blocked_registry("very-bad-registry.test")
```

用 server-side dry-run 檢查全部三種結果，不建立持久的 Pod：新的
registry 必須被 denied，舊的(已經被封鎖的)- 仍然是 denied(沒有
迴歸)，受信任的 - 通過：

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
# 預期:Error from server ... admission webhook "validation.gatekeeper.sh" denied
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
# 預期:同樣是 Error from server ... - 舊的規則不應該遺失

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
# 預期:成功(沒有任何 admission 錯誤)
```

確認拒絕確實來自 Gatekeeper(`validation.gatekeeper.sh`)，而
不是來自任務 2-4 中的某個 Kyverno `ValidatingPolicy` - 錯誤訊息明確
指出 webhook 與你的 Constraint 的名稱。不要透過 `Constraint.spec.parameters` 來解決這個任務 -
在這個版本的 policy 中，Constraint 完全不使用它們。

執行 `check_result`。
