[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 127 - 參考解決方案(CEL 上的 ValidatingAdmissionPolicy)

所有命令都透過 SSH 在工作機上執行。kubectl 已經在集群上配置好了(kubeconfig 是在機器
啟動時透過 `aws eks update-kubeconfig` 組裝的)。

## 任務 1. Namespace `eks-127`

```bash
kubectl create namespace eks-127
```

## 任務 2. Audit 模式下的 CEL 政策讓帶有 `:latest` 的 pod 通過

我們創建一個 `validationActions: ["Audit"]` 的 `ValidatingAdmissionPolicy` 和
`ValidatingAdmissionPolicyBinding`。這個政策只透過 `namespaceSelector`(標籤
`kubernetes.io/metadata.name`,k8s 會自動把它加到 namespace 上)應用於 namespace
`eks-127`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-latest-tag
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: ":latest 標籤是 forbidden 的,請指定具體的映像版本"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Audit"]
EOF
```

確認兩個對象都已到位:

```bash
kubectl get validatingadmissionpolicy disallow-latest-tag
kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding
```

現在在 `Audit` 模式下創建一個帶有 `:latest` 映像的 pod - 它應該被創建,因為 `Audit` 只
會把違規寫入 audit 日誌,而不會阻擋請求:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: latest-audit-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get pod latest-audit-pod -n eks-127
```

儘管違反了規則,pod 仍被創建 - 這正是 `Audit` 的意義所在:試驗政策而不冒破壞現有負載
的風險。

## 任務 3. 切換到 Deny - 帶有 `:latest` 的 pod 被拒絕

我們更新 Binding,只改動 `validationActions`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Deny"]
EOF
```

我們嘗試再創建一個帶有 `:latest` 的 pod - 現在 apiserver 應該拒絕這個請求:

```bash
mkdir -p /var/work/tests/artifacts/3
cat <<'EOF' | kubectl apply -f - 2> /var/work/tests/artifacts/3/denied.txt
apiVersion: v1
kind: Pod
metadata:
  name: latest-deny-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

cat /var/work/tests/artifacts/3/denied.txt
```

檔案 `denied.txt` 中應該包含來自 apiserver 的、帶有政策文字的錯誤訊息(`latest` 和
`forbidden` 這兩個詞)。Pod `latest-deny-pod` 這時不會被創建 - `kubectl get pod
latest-deny-pod -n eks-127` 會回傳 `NotFound`。

## 任務 4. 帶有明確標籤的合法 pod 即使在 Deny 下也能通過

這個政策只檢查 `:latest`,所以帶有具體映像版本的 pod 能順利通過。標籤 `53833ea` 是
`viktoruj/ping_pong` 中一個真實的 commit 標籤,它確實存在,並且已經為 amd64 和 arm64
建置好了。使用一個真實存在的標籤很重要:准入只看映像的字串,所以帶有虛構標籤的 pod
同樣會被創建,但會停留在 `ErrImagePull` 中 - 政策在形式上「沒有阻擋」,但這個說法將無
從驗證:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tagged-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF

kubectl get pod tagged-pod -n eks-127
```

## 任務 5. 第二個 CEL 政策:強制要求 `resources.requests`

再創建一個直接處於 `Deny` 模式的 `ValidatingAdmissionPolicy` - 我們要求每個容器都設定
了 `resources.requests`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resources-requests
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.requests))"
      message: "每個容器都必須設定 resources.requests"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resources-requests-binding
spec:
  policyName: require-resources-requests
  validationActions: ["Deny"]
EOF
```

沒有 `requests` 的 pod 被拒絕:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-requests-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF
```

這個命令會回傳一個准入錯誤,`kubectl get pod no-requests-pod -n eks-127` 會顯示
`NotFound`。設定了 `requests` 的 pod 能正常通過:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: requests-ok-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl get pod requests-ok-pod -n eks-127
```

## 任務 6. `failurePolicy: Fail` 以及它與外部 webhook 的差異

我們在第一個政策上明確設定 `failurePolicy: Fail`(這是預設值,但我們明確地固定下
來):

```bash
kubectl patch validatingadmissionpolicy disallow-latest-tag --type merge \
  -p '{"spec":{"failurePolicy":"Fail"}}'

kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}'
```

`failurePolicy` 對 CEL 表達式計算的錯誤做出反應(例如,存取物件上在舊版 API 中不存在
的欄位),而不是對外部服務不可達做出反應。內建的 `ValidatingAdmissionPolicy` 根本沒有
外部 webhook - CEL 是直接在 apiserver 內部計算的,所以它沒有 Kyverno 和 Gatekeeper 特
有的「webhook 沒有回應,准入卡住了」的風險(在那裡,規則由 webhook 背後的獨立服務執
行,如果它不可達,`failurePolicy: Fail` 就會讓請求排隊或被阻擋)。

我們把這段說明保存到產物中:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/failurepolicy.txt <<'EOF'
ValidatingAdmissionPolicy 上的 failurePolicy 只對 CEL 表達式計算的錯誤做出反應
(例如存取物件上缺失的欄位),而不是對外部服務不可達做出反應。

內建的 ValidatingAdmissionPolicy 根本沒有外部 webhook:CEL 表達式是直接在 apiserver
內部計算的,沒有任何對外的網路呼叫。因此這裡不存在 Kyverno 和 Gatekeeper 特有的
「webhook 沒有回應」的風險,在它們那裡,規則由 webhook 背後的獨立服務
執行,而 apiserver 要等待它的回應。
EOF
cat /var/work/tests/artifacts/6/failurepolicy.txt
```

## 快速檢查

```bash
check_result
```

用於查看政策狀態的常用命令:

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingadmissionpolicy disallow-latest-tag -o yaml
```
