[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 107 - 参考解答: Pod Security Admission と immutable root filesystem

> コマンドは作業マシンで実行してください。コンテキスト `cluster1-admin@cluster1` はすでに
> 設定されています。Namespace `psa-restricted-107` と `psa-observe-107` は起動
> スクリプトによって作成されていますが、PSA labels は意図的に付けられていません。

## 1. Enforce restricted と拒否の確認

PSA は、namespace の labels に基づいて Pod Security Standards を適用します。Kubernetes の
将来のアップデートで挙動が変わらないよう、標準のバージョンを固定します：

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

危険なオブジェクトを保存せずに admission を確認します。`hostNetwork` は `restricted` レベルで
禁止されているため、コマンドは `violates PodSecurity` エラーで終了する必要があります：

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

## 2 と 5. Hardened Pod と writable な emptyDir

Pod を最初から最終的な安全な形で作成します。`restricted` レベルは
non-root、seccomp、escalation の禁止、capabilities の drop を要求します。Read-only root filesystem は
コンテナへの書き込みの影響を小さくします；アプリケーションには `emptyDir` 内の `/tmp` だけが
残されます。

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

YAML を読むだけでなく、実際の呼び出しで両方の結果を実証します：コンテナは
`runAsUser: 1000` と read-only root で動作しているため、`/tmp` の外への書き込みはファイルシステムの
エラーで終了する必要があり、マウントされた `emptyDir` への書き込みは成功する必要があります：

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

`restricted-app` がすでに read-only filesystem なしで作成されている場合、Pod のフィールドは変更できません；
削除して作り直してください (すでに課題 6 の後でこれを行う場合は、`spec` に
フィールド `automountServiceAccountToken: false` を追加してください - そうしないと課題 6 の policy が Pod を拒否します)：

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. baseline の Audit と warn

これらのモードはリクエストを禁止しません。`warn` はクライアントに警告を返し、`audit` は
API server の audit event に annotation
`pod-security.kubernetes.io/audit-violations` を追加します。段階的な導入のため、観察用の namespace に
`enforce` は設定しません：

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **バージョンについての但し書き。** `v1.36` は、この学習用インフラの Kubernetes 1.36.0 のために固定されています。
> 2026-09-06 時点で、公式の CKS は `v1.35` を対象としています；これは
> forward-looking な例であり、試験の準備には `*-version=v1.35` を使用してください。

> **audit の証明の限界。** この実習は audit-log の sink を設定しないため、
> `pod-security.kubernetes.io/audit-violations` を `kubectl` コマンドで取り出すことはできません。
> 以下で実際に確認できる結果は、PSA の Warning と成功した admission です；audit の
> annotation は説明されていますが、このインフラでは確認可能な成果物ではありません。

## 4. warn/audit が Pod をブロックしないことを確認する

この Pod は `hostNetwork` のため baseline に違反しますが、namespace に
`enforce` がないため受け入れられます。`kubectl apply` は PSA の警告を出力します；production の workload の
移行時には、それを無視しないでください。

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

## 6. Kyverno/Gatekeeper なしの Native ValidatingAdmissionPolicy

PSA `restricted` は、すでに `allowPrivilegeEscalation: false` と、`ALL` を含む `capabilities.drop` を
要求しています - 課題 2 がまさにそれを示しており、これは Pod Security
Standard の組み込みの部分であって、隙間ではありません。しかし PSS `restricted` は `automountServiceAccountToken` を**確認しません**：
Pod は、マウントされた ServiceAccount token を黙って受け取り、PSA を完全に通過する可能性があります。この
独立した、実際にカバーされていない control には、まさに custom の `ValidatingAdmissionPolicy` が適切です。

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

永続的な Pod を保存せずに、server-side dry-run で 3 つの状態すべてを実証します。フィールドのない Pod は
policy + binding の正確なペアから DENY を受け取る必要があり、`false` は通り、
`true` は同じペアから DENY を受け取る必要があります。最初の Pod は
PSA `restricted` に完全に適合しています (non-root、seccomp、`allowPrivilegeEscalation:
false`、`capabilities.drop: ["ALL"]`) - PSA 自体は受け入れるはずなので、拒否は
`violates PodSecurity` ではなく、新しい policy から来る必要があります：

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

同じ Pod に `automountServiceAccountToken: false` を追加すると、通るはずです：

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

明示的な値 `true` も、同じ policy と binding によって拒否される必要があります：

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

`Binding.matchResources.namespaceSelector` は、policy を `psa-restricted-107` のみに限定します：
他の namespace (たとえば `psa-observe-107`) の Pod はこのルールで確認されず、
余分な Deny も受け取りません。

## 7. Controller-driven な admission denial

まず、単純で hardened でない Deployment - PSA はまだ enforce ではなく、すべて通ります：

```bash
kubectl -n psa-controller-107 create deployment controller-app --image=busybox:1.36 -- sh -c "sleep 3600"
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

enforce を有効にします - 既存の Pod には触れません：

```bash
kubectl label namespace psa-controller-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
kubectl -n psa-controller-107 get pod
# controller-app-xxxx は依然として Running - PSA はすでに存在するオブジェクトには作用しません
```

Pod を削除します - ReplicaSet が代わりの Pod を作成しようとして、拒否を受けます：

```bash
kubectl -n psa-controller-107 delete pod -l app=controller-app
kubectl -n psa-controller-107 get events --sort-by=.lastTimestamp | tail -5
# ... FailedCreate ... violates PodSecurity "restricted:v1.36": ...
kubectl -n psa-controller-107 get deploy controller-app
# controller-app   0/1     1            0           ...   <- READY 0/1, AVAILABLE 0
```

template を修正します - 課題 2 と同じ hardening フィールドを追加します：

```bash
kubectl -n psa-controller-107 edit deployment controller-app
```

`spec.template.spec` で、行 `securityContext: {}` を下のブロックに置き換え、コンテナ `busybox` に
(コンテナ名は `busybox` で、`kubectl create deployment` によって作成されたものです) 独自の `securityContext` を追加します：

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

保存して、rollout を待ちます：

```bash
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

```
deployment "controller-app" successfully rolled out
```

```bash
check_result
```
