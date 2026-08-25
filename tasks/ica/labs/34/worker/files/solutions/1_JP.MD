[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 34 - 参照解答

Istio `1.29.1`（デフォルトプロファイル、PERMISSIVE mTLS、`ALLOW_ANY` egress、authz なし）と OPA
Gatekeeper は事前にインストールされています。名前空間 `app`（インジェクション済み）には `frontend`、2 つの curl
クライアント `good`（SA `good`）と `bad`（SA `bad`）、および SA `mesh-editor` があります。名前空間
`legacy`（インジェクションなし）には、サイドカーなしの `legacy` curl クライアントがあります。`istioctl` は
worker PC 上にあります。

## 目標（多層防御）

1. メッシュ全体で **STRICT mTLS**。
2. **デフォルト拒否**の認可と、`good` のみを対象とした許可。
3. **Egress 制御**: `REGISTRY_ONLY`。
4. **Istio CRD の RBAC**: Istio 設定は許可するが、`EnvoyFilter` は禁止。
5. **OPA Gatekeeper**: `PeerAuthentication` の `mode: DISABLE` を拒否。
6. **サイドカー迂回への耐性**: 独立した L3/L4 レイヤーとしての NetworkPolicy。

## ステップ 1. STRICT mTLS（メッシュ全体）

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system      # root namespace -> mesh-wide
spec:
  mtls:
    mode: STRICT
EOF
```

これで、サイドカーなしの `legacy` クライアント（平文）は `frontend` に到達できなくなります。

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## ステップ 2. デフォルト拒否 + 対象を絞った許可

```bash
# default-deny for the whole app namespace (empty spec)
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: app
spec: {}
EOF

# allow only the "good" identity to call frontend
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-good
  namespace: app
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/app/sa/good"]
EOF
```

```bash
kubectl exec -n app deploy/good -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 200
kubectl exec -n app deploy/bad  -c curl -- curl -s -o /dev/null -w '%{http_code}\n' http://frontend.app.svc.cluster.local:8080/   # 403
```

## ステップ 3. Egress 制御: REGISTRY_ONLY

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
EOF
istioctl install -f /tmp/iop.yaml -y

# external host that is not in the registry is now blocked
kubectl exec -n app deploy/good -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://www.example.com/   # 502 (blocked)
```

（特定の外部ホストを許可するには、`ServiceEntry` を追加します。lab 05 を参照してください。）

## ステップ 4. Istio CRD の RBAC（EnvoyFilter を禁止）

`EnvoyFilter` は最も危険な Istio CRD であり、生の Envoy 設定を注入します。`mesh-editor` に Istio
設定管理を許可しますが、`envoyfilters` は**除外**します。

```bash
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mesh-editor
  namespace: app
rules:
  - apiGroups: ["networking.istio.io"]
    resources: ["virtualservices","destinationrules","gateways","serviceentries","sidecars","workloadentries"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  - apiGroups: ["security.istio.io"]
    resources: ["authorizationpolicies","requestauthentications"]
    verbs: ["get","list","watch","create","update","patch","delete"]
  # envoyfilters intentionally NOT granted
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mesh-editor
  namespace: app
roleRef:
  kind: Role
  name: mesh-editor
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: mesh-editor
    namespace: app
EOF
```

```bash
kubectl auth can-i create virtualservices.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app   # yes
kubectl auth can-i create envoyfilters.networking.istio.io     --as=system:serviceaccount:app:mesh-editor -n app   # no
```

## ステップ 5. OPA Gatekeeper: mTLS の無効化を禁止

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdenymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: K8sDenyMtlsDisable
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdenymtlsdisable
        violation[{"msg": msg}] {
          input.review.object.spec.mtls.mode == "DISABLE"
          msg := "PeerAuthentication with mode: DISABLE is not allowed"
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
      - apiGroups: ["security.istio.io"]
        kinds: ["PeerAuthentication"]
EOF
```

```bash
# should be DENIED
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: try-disable
  namespace: app
spec:
  mtls:
    mode: DISABLE
EOF
```

## ステップ 6. NetworkPolicy（サイドカー迂回への耐性）

mTLS/authz はサイドカー内で動作するため、トラフィックがサイドカーを迂回すると適用されません。
NetworkPolicy は CNI（Calico）によってカーネルで強制される、独立した L3/L4 レイヤーです。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-app
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
  ingress:
    # app port 8080 only from pods in the app namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: app
      ports:
        - port: 8080
          protocol: TCP
    # istio sidecar health (15021) / metrics (15090) from anywhere (kubelet, prometheus)
    - ports:
        - port: 15021
          protocol: TCP
        - port: 15090
          protocol: TCP
EOF
```

`app` 内の Pod のみが `8080` で `frontend` に到達できます。`legacy` はサイドカーに到達する前に
ドロップされます。Istio サイドカーの kubelet readiness probe が成功し続けるように、ポート `15021` は
開いたままにします（そうしないと Pod は NotReady になります）。

## これが機能する理由（脅威モデル）

- **STRICT mTLS** - 相互認証されたメッシュトラフィックのみが受け入れられ、平文および
  非メッシュクライアントは拒否されます。暗号化 + サービスアイデンティティ。
- **デフォルト拒否 authz** - 最小権限: 明示的な ALLOW に一致しない限り何も許可されないため、
  侵害されたワークロードによる影響範囲を限定します。
- **REGISTRY_ONLY egress** - 侵害された Pod は任意の外部ホストへデータを持ち出すことができず、
  宣言済みの宛先のみに到達可能です。
- **CRD の RBAC** - `EnvoyFilter`（および Istio 設定全般）を制限することで、過剰な権限を持つ
  ユーザーがデータプレーンを再プログラムすることを防ぎます。
- **OPA Gatekeeper** - 「mTLS を決して無効化しない」を慣習ではなく、強制的な admission ルールにします。
- **NetworkPolicy** - サイドカーが迂回されても維持される独立したカーネルレベルの制御です。
  多層防御。
