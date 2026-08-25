[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 34 - 參考解答

Istio `1.29.1`（預設設定檔、PERMISSIVE mTLS、`ALLOW_ANY` egress、無 authz）及 OPA
Gatekeeper 已預先安裝。命名空間 `app`（已注入）包含 `frontend`，以及兩個 curl
用戶端 `good`（SA `good`）與 `bad`（SA `bad`），還有 SA `mesh-editor`；命名空間
`legacy`（未注入）包含一個無 sidecar 的 `legacy` curl 用戶端。`istioctl` 位於工作人員
PC 上。

## 目標（縱深防禦）

1. 網格全域的 **STRICT mTLS**。
2. **預設拒絕**授權，加上對 `good` 的目標式允許。
3. **Egress 控制**：`REGISTRY_ONLY`。
4. **Istio CRD 的 RBAC**：允許 Istio 設定，但禁止 `EnvoyFilter`。
5. **OPA Gatekeeper**：拒絕 `mode: DISABLE` 的 `PeerAuthentication`。
6. **Sidecar 繞過韌性**：將 NetworkPolicy 作為獨立的 L3/L4 層。

## 步驟 1. STRICT mTLS（網格全域）

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

現在，無 sidecar 的 `legacy` 用戶端（明文）無法再連線至 `frontend`：

```bash
kubectl exec -n legacy deploy/legacy -c curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 http://frontend.app.svc.cluster.local:8080/
# connection reset / 000
```

## 步驟 2. 預設拒絕 + 目標式允許

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

## 步驟 3. Egress 控制：REGISTRY_ONLY

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

（若要允許特定外部主機，您會新增 `ServiceEntry`，請參閱 lab 05。）

## 步驟 4. Istio CRD 的 RBAC（禁止 EnvoyFilter）

`EnvoyFilter` 是最危險的 Istio CRD，因為它會注入原始 Envoy 設定。將 Istio
設定管理權授予 `mesh-editor`，但**排除** `envoyfilters`：

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

## 步驟 5. OPA Gatekeeper：禁止停用 mTLS

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

## 步驟 6. NetworkPolicy（sidecar 繞過韌性）

mTLS/authz 位於 sidecar 中；若流量繞過 sidecar，便不會套用它們。
NetworkPolicy 由 CNI（Calico）在核心中強制執行，是獨立的 L3/L4 層：

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

只有 `app` 中的 Pod 可以透過 `8080` 連線至 `frontend`；`legacy` 在到達 sidecar 之前
即被丟棄。連接埠 `15021` 保持開放，讓 Istio sidecar 的 kubelet readiness probe
持續通過（否則該 Pod 會變為 NotReady）。

## 為何可行（威脅模型）

- **STRICT mTLS**：只接受經雙向驗證的網格流量；明文及非網格
  用戶端會被拒絕。加密加上服務身分。
- **預設拒絕 authz**：最小權限，除非明確的 ALLOW
  相符，否則不允許任何操作，從而限制已遭入侵工作負載的影響範圍。
- **REGISTRY_ONLY egress**：已遭入侵的 Pod 無法將資料外洩至任意外部
  主機；只有已宣告的目的地可連線。
- **CRD 上的 RBAC**：限制 `EnvoyFilter`（以及一般的 Istio 設定）可防止
  權限過高的使用者重新設定資料平面。
- **OPA Gatekeeper**：使「絕不停用 mTLS」成為嚴格的准入規則，而非慣例。
- **NetworkPolicy**：獨立的核心層級控制，即使 sidecar 被
  繞過仍會生效，這就是縱深防禦。
