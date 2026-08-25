[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 21 - 参照解答

Istio `1.29.1` がインストールされています。2 つの namespace がデプロイされています:
- `app` には `ping-pong` があります（sidecar 注入済み）。
- `other` には `backend` があります（sidecar 注入済み）。

デフォルトでは、すべての sidecar が mesh 内の**すべて**の service 向けの Envoy 設定を受け取るため、
`app` proxy は `backend.other` と通信しない場合でも、その cluster を保持します。

## 目的

`Sidecar` resource を使用して `app` namespace の proxies をスコープし、自身の namespace と
`istio-system` の設定だけを受け取るようにします。

## 手順 1. デフォルトの（スコープなし）設定を確認する

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## 手順 2. egress をスコープする Sidecar resource を適用する

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

- `./*` - **local** namespace（`app`）内のすべての service。
- `istio-system/*` - control-plane namespace（telemetry などに必要）。

`workloadSelector` を持たない `default` という名前の `Sidecar` は、その namespace 内のすべての
workloads に適用されます。

## 手順 3. 設定が縮小されたことを検証する

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## 仕組みと重要な理由

- **`Sidecar`** resource は、istiod が proxy にプッシュする設定のスコープを制御します。
  `egress.hosts` は、proxy が認識する services を許可リスト化します。
- デフォルトで mesh は「full mesh」です。すべての proxy はすべての service を認識します。大規模な
  cluster（数千の services）では、Envoy の設定が巨大化し、pod ごとのメモリ使用量が増え、
  変更のたびに istiod の CPU 負荷が高くなります。
- `Sidecar` resources による proxy のスコープ設定は、Istio をスケールさせる標準的な方法です:
  設定を小さくし、プッシュを高速化し、istiod の負荷を下げ、egress 境界をより厳格にします。
- `Sidecar` 内の `outboundTrafficPolicy` は、namespace ごとに `REGISTRY_ONLY` を追加設定して、
  宣言されていない egress をブロックできます。

> 注記: スコープ設定は*設定配布*に関するものであり、認可ではありません。実際に calls を禁止するには、
> `AuthorizationPolicy`（ラボ 04）または `outboundTrafficPolicy: REGISTRY_ONLY` を使用してください。
