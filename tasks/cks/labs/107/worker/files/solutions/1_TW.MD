[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 107 - 參考解答：Pod Security Admission 與 read-only root filesystem

> 請在工作機上執行指令。Context `cluster1-admin@cluster1` 已經
> 設定好。Namespace `psa-restricted-107`、`psa-observe-107` 與 `psa-controller-107` 由啟動
> 腳本建立，但刻意沒有 PSA labels。

## 1. Enforce restricted 並檢查拒絕

PSA 依據 namespace 的 labels 套用 Pod Security Standards。我們固定
標準的版本，讓行為不會隨著未來 Kubernetes 的升級而改變：

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

檢查 admission，但不保存危險的物件。`hostNetwork` 被 `restricted` 等級禁止，
因此指令必須以錯誤 `violates PodSecurity` 結束：

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-by-restricted
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
YAML
```

## 2 與 5. Hardened Pod 與可寫的 emptyDir

直接以最終的安全形式建立 Pod。等級 `restricted` 要求
non-root、seccomp、禁止 escalation 以及捨棄 capabilities。Read-only root filesystem
減少寫入容器所造成的後果；應用程式只保留 `/tmp`，位於
`emptyDir` 中。

```yaml
# restricted-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-app
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir:
      medium: Memory
```

```bash
kubectl apply -f restricted-app.yaml
kubectl get pod restricted-app -n psa-restricted-107
```

用即時呼叫證明兩種結果，而不只是閱讀 YAML：容器以
`runAsUser: 1000` 搭配 read-only root 執行，因此寫入 `/tmp` 之外必須以
檔案系統錯誤結束，而寫入已掛載的 `emptyDir` - 必須成功：

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

如果 `restricted-app` 已經在沒有 read-only filesystem 的情況下建立，Pod 的這個欄位無法修改；
請刪除並重新建立它(如果你是在完成任務 6 之後才這樣做，請在 `spec` 中加入
欄位 `automountServiceAccountToken: false` - 否則任務 6 的 policy 會拒絕這個 Pod):

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. baseline 的 Audit 與 warn

這些模式不會禁止請求。`warn` 向用戶端回傳警告，而 `audit`
會在 API server 的 audit event 中加入 annotation
`pod-security.kubernetes.io/audit-violations`。為了分階段導入，不要在觀察用的 namespace 中設定
`enforce`:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **版本說明**。在這個學習用基礎架構中，`v1.36` 是為 Kubernetes 1.36.0 固定的。
> 截至 2026-09-06，官方 CKS 以 `v1.35` 為準；這是
> forward-looking 的範例，準備考試時請使用 `*-version=v1.35`。

> **audit 證明的邊界**。本實驗沒有設定 audit-log sink，因此
> `pod-security.kubernetes.io/audit-violations` 無法透過 `kubectl` 指令取得。
> 下面真正可驗證的結果是 PSA Warning 與成功的 admission;audit
> annotation 已有說明，但不是這個基礎架構中可驗證的 artifact。

## 4. 確認 warn/audit 不會阻擋 Pod

這個 Pod 因為 `hostNetwork` 而違反 baseline，但仍被接受，因為 namespace
沒有 `enforce`。`kubectl apply` 會輸出 PSA 的警告；在遷移 production workload 時
不要忽略它。

```yaml
# baseline-audit-sample.yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-audit-sample
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f baseline-audit-sample.yaml
kubectl get pod baseline-audit-sample -n psa-observe-107
kubectl get namespace psa-restricted-107 --show-labels
kubectl get namespace psa-observe-107 --show-labels
```

## 6. 不使用 Kyverno/Gatekeeper 的 Native ValidatingAdmissionPolicy

PSA `restricted` 已經要求 `allowPrivilegeEscalation: false` 以及包含 `ALL` 的 `capabilities.drop` -
任務 2 展示的正是這一點，這是 Pod Security
Standard 的內建部分，而不是缺口。但 PSS `restricted` **不檢查** `automountServiceAccountToken`:
Pod 可以悄悄取得被掛載的 ServiceAccount token，並完整通過 PSA。對於
這個獨立的、真正未被涵蓋的 control，適合使用自訂的 `ValidatingAdmissionPolicy`。

```yaml
# require-no-automount-token.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-no-automount-token
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >-
      has(object.spec.automountServiceAccountToken) &&
      object.spec.automountServiceAccountToken == false
    message: "spec.automountServiceAccountToken must be explicitly set to false"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-no-automount-token-binding
spec:
  policyName: require-no-automount-token
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: psa-restricted-107
```

```bash
kubectl apply -f require-no-automount-token.yaml
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

透過 server-side dry-run 證明全部三種狀態，不保存持久的 Pod。沒有該
欄位的 Pod 必須從 policy + binding 這個確切的組合得到 DENY,`false` 必須通過，而
`true` 必須從同一個組合得到 DENY。第一個 Pod
完全符合 PSA `restricted`(non-root、seccomp、`allowPrivilegeEscalation:
false`、`capabilities.drop: ["ALL"]`)- PSA 本身會接受它，因此拒絕必須
來自新的 policy，而不是 `violates PodSecurity`:

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-unsafe-check
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

同一個 Pod 加上 `automountServiceAccountToken: false` 必須通過：

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-safe-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
```

明確的值 `true` 同樣必須被同一個 policy 與 binding 拒絕：

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-explicit-true-check
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

`Binding.matchResources.namespaceSelector` 把 policy 只限制在 `psa-restricted-107`:
其他 namespace(例如 `psa-observe-107`)中的 Pod 不會被這條規則檢查，也不會
得到多餘的 Deny。

## 7. Controller-driven admission denial

首先建立簡單的、沒有 hardening 的 Deployment - PSA 目前還不是 enforce，一切都會通過：

```bash
kubectl -n psa-controller-107 create deployment controller-app --image=busybox:1.36 -- sh -c "sleep 3600"
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

啟用 enforce - 既有的 Pod 不會被動到：

```bash
kubectl label namespace psa-controller-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
kubectl -n psa-controller-107 get pod
# controller-app-xxxx 仍然是 Running - PSA 不作用於已經存在的物件
```

刪除 Pod - ReplicaSet 嘗試建立替代的 Pod 並被拒絕：

```bash
kubectl -n psa-controller-107 delete pod -l app=controller-app
kubectl -n psa-controller-107 get events --sort-by=.lastTimestamp | tail -5
# ... FailedCreate ... violates PodSecurity "restricted:v1.36": ...
kubectl -n psa-controller-107 get deploy controller-app
# controller-app   0/1     1            0           ...   <- READY 0/1, AVAILABLE 0
```

修正 template - 加入與任務 2 相同的 hardening 欄位：

```bash
kubectl -n psa-controller-107 edit deployment controller-app
```

在 `spec.template.spec` 中，把 `securityContext: {}` 這一行換成下面的區塊，並在容器 `busybox`
(容器名稱為 `busybox`，由 `kubectl create deployment` 建立)中加入它自己的 `securityContext`:

```yaml
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: busybox
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

儲存並等待 rollout:

```bash
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

```
deployment "controller-app" successfully rolled out
```

```bash
check_result
```
