[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗室 33 - 參考解答

Istio `1.29.1`（預設設定檔、全叢集探索、無 Sidecar 範圍）與 OPA
Gatekeeper 已預先安裝。存在三個命名空間：

- `app`（已注入，`mesh=enabled`）- `frontend`；
- `shop`（已注入，`mesh=enabled`）- `catalog` + 無 sidecar 的 `probe`；
- `legacy`（未注入，無 `mesh` 標籤）- `legacy-app`。

工作節點電腦上可使用 `istioctl`。

## 目標

1. 啟用**探索選擇器**，讓 istiod 僅追蹤 `mesh=enabled` 命名空間
   （排除 `legacy`）。
2. 在 `app` 中新增 **Sidecar** 輸出範圍，讓其 Proxy 僅知悉 `app` + `istio-system`
   （排除 `shop`）。
3. 觀察 istiod 的**黃金訊號**。
4. 使用 **OPA Gatekeeper** 強制執行部署政策。

## 步驟 1. 探索選擇器

以符合 `mesh=enabled` 的 `meshConfig.discoverySelectors` 重新套用安裝
（`istio-system`、`app`、`shop` 皆有此標籤；`legacy` 沒有）：

```bash
cat <<EOF > /tmp/iop.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    discoverySelectors:
      - matchLabels:
          mesh: enabled
EOF
istioctl install -f /tmp/iop.yaml -y
```

確認 `legacy` 已從網格中消失（從尚無 Sidecar 範圍的 Proxy 執行）：

```bash
istioctl proxy-config clusters deploy/catalog.shop | grep legacy-app || echo "legacy dropped"
```

## 步驟 2. app 中的 Sidecar 輸出範圍

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

`./*` = Proxy 自身的命名空間（`app`），再加上用於控制平面與
閘道的 `istio-system/*`。其他所有內容（包括 `shop`）均會從 `app` Proxy 中移除：

```bash
istioctl proxy-config clusters deploy/frontend.app | grep catalog.shop || echo "shop dropped from app"
```

## 步驟 3. istiod 黃金訊號

```bash
# convergence time + push count (the key control-plane signals)
kubectl exec -n shop deploy/probe -c probe -- \
  curl -s http://istiod.istio-system:15014/metrics \
  | grep -E 'pilot_proxy_convergence_time|pilot_xds_pushes'

# how many proxies are connected / config sync state
istioctl proxy-status
```

`pilot_proxy_convergence_time` 是主要訊號：一項變更到達 Proxy 所需的時間。
`pilot_xds_pushes` 計算推送次數。收斂時間上升或出現推送錯誤，表示
控制平面承受壓力；步驟 1-2 的範圍控制機制正是用來降低此壓力。

## 步驟 4. OPA Gatekeeper 部署政策

要求每個命名空間宣告注入標籤（本章節的經典部署衛生政策）。
建立範本與限制：

```bash
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("namespace is missing required labels: %v", [missing])
        }
EOF

kubectl apply -f - <<'EOF'
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: ns-must-have-injection
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Namespace"]
  parameters:
    labels: ["istio-injection"]
EOF
```

確認政策已強制執行（應會遭到**拒絕**）：

```bash
kubectl create ns test-no-label
# Error ... admission webhook "validation.gatekeeper.sh" denied the request:
# namespace is missing required labels: {"istio-injection"}
```

## 運作原理

- **探索選擇器**限制 istiod 完全監看的命名空間。缺少選擇器標籤的命名空間
  對控制平面不可見，其服務絕不會成為任何 Proxy 上的叢集/端點，藉此縮減設定大小與
  推送工作量。當叢集的一部分不在網格中時，效益最大。
- **Sidecar 輸出範圍**會依命名空間限制 Proxy 所獲知的服務。使用 `./*` + `istio-system/*` 時，
  `app` Proxy 不再攜帶 `shop`（或網格其餘部分）的設定。這會縮減每個 Proxy 的設定，
  並降低 istiod 的推送擴散範圍。
- **黃金訊號**（`pilot_proxy_convergence_time`、`pilot_xds_pushes`、已連線的 Proxy、
  istiod CPU/記憶體）讓您得以觀察控制平面是否跟得上；範圍控制機制是降低收斂時間的
  主要工具。
- **OPA Gatekeeper** 將最佳實務轉化為准入規則：不合規資源會在建立時遭到拒絕，
  而非僅受到勸阻。