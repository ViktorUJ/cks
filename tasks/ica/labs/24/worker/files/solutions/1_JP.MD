[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 24 - 参照解答

Istio `1.29.1` は **ambient** モード（istiod + istio-cni + ztunnel）でインストールされています。名前空間
`app` は ambient に参加しており（`istio.io/dataplane-mode: ambient`）、`ping-pong` と
`app-client` を実行しています。どちらも **sidecar なし**です。`istioctl` は
ワーカー PC で利用できます。

## 背景

- **ztunnel** は各 ambient workload に L4 mTLS と identity を提供しますが、HTTP は**理解しません**。
  したがって、L4 policy（identity/port による allow/deny）は機能しますが、L7 rule
  （HTTP method、path、header）は機能しません。
- **L7** policy を適用するには、**waypoint proxy** を追加します。これは名前空間ごと（または
  service ごと）の Envoy であり、ambient traffic は L7 処理のためにそこを経由してルーティングされます。

## 目標

`app` 名前空間に waypoint を追加し、`ping-pong` への `GET` request のみを許可する L7
`AuthorizationPolicy` を追加します（それ以外はすべて → `403`）。

## ステップ 1. waypoint をプロビジョニングする

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` は名前空間にラベル（`istio.io/use-waypoint: waypoint`）を付与するため、
`app` 内の service への traffic は waypoint を経由してルーティングされます。

## ステップ 2. L7 AuthorizationPolicy を適用する

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

`ALLOW` policy は一致しないすべてをデフォルトで deny するため、`GET` のみが許可されます。
他の method は `403` になります。

## ステップ 3. 検証する

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## 仕組み

- **Sidecar なしの L4（ztunnel）** は、pod ごとの proxy なしで名前空間全体の mTLS と identity を処理します。
  これは低コストで、ambient では常に有効です。
- **Waypoint（L7）** は、HTTP レベルの機能が必要な箇所にのみ追加されます。L7 authorization、
  routing、retry、traffic splitting が該当します。Envoy のコストが発生するのは、それらの service に対してのみです。
- `AuthorizationPolicy` の `targetRefs` は waypoint `Gateway` を指定するため、policy は
  L7 hop で適用されます。sidecar/ingress に同じ policy をアタッチしても機能します。ambient は単に
  L7 enforcement point を waypoint に移動するだけです。
- この layered model（すべての場所の L4 には ztunnel、必要な箇所の L7 には waypoint）は、ambient の重要な
  考え方です。sidecar より低いベースラインコストで、必要に応じて L7 を利用できます。

## 関連項目

ラボ 09 では ambient の基本（ztunnel L4）を扱います。ラボ 04 では同じ `AuthorizationPolicy` を
sidecar model で扱います。