[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 20 - 參考解答

已安裝 Istio `1.29.1`。已部署三個工作負載：
- `ping-pong` 位於命名空間 `app`（已注入 sidecar，提供應用程式服務）；
- `mesh-client` 位於命名空間 `app`（已注入 sidecar，透過 mTLS 通訊）；
- `legacy-client` 位於命名空間 `legacy`（**未**使用 sidecar，僅支援純文字）。

在沒有 `PeerAuthentication` 時，mTLS 預設為 **PERMISSIVE**：mesh 用戶端
(mTLS) 和舊版用戶端（純文字）都能連線至應用程式。

## 目標

將 `app` 命名空間遷移至 **STRICT** mTLS，使其僅接受 mTLS 流量，同時不影響
mesh 內的用戶端。

## 步驟 1. 觀察 PERMISSIVE 基準狀態

```bash
# in-mesh client -> app : works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : ALSO works under PERMISSIVE
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200
```

## 步驟 2. （建議）使用 PERMISSIVE 明確表達意圖

安全的遷移會先明確固定為 PERMISSIVE，然後在您透過指標確認
不再有純文字流量後，再切換至 STRICT：

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

## 步驟 3. 將命名空間切換至 STRICT

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## 步驟 4. 驗證

```bash
# in-mesh client -> app : still works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : now rejected (connection reset)
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/
# -> 000 (curl exit 56: reset by peer)
```

## 運作方式

- **PeerAuthentication** 控制 *伺服器端* sidecar 如何接受傳入的
  連線：
  - `PERMISSIVE`（mesh 預設值）- 同時接受 mTLS 和純文字。這使得
    零停機遷移成為可能：您可以逐步讓工作負載加入 mesh，
    同時讓舊版純文字用戶端持續運作。
  - `STRICT` - 僅接受 mTLS；純文字連線會被重設。
- 範圍層級：位於 `istio-system`（根）的 `PeerAuthentication` 會套用至整個 mesh；
  位於命名空間中的一個會在該處覆寫它；具有 `selector` 的一個會針對每個工作負載覆寫它。
- **安全遷移方法**：維持 PERMISSIVE，監看
  `istio_requests_total{connection_security_policy="none"}` 指標，直到其降至
  零（不再有純文字流量），然後切換至 STRICT。

## 相關內容

實驗 04 涵蓋與 `AuthorizationPolicy`（誰可以呼叫誰）結合的 STRICT 最終狀態。本實驗著重於遷移本身以及 PERMISSIVE 的角色。