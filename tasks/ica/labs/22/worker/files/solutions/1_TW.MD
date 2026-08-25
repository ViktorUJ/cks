[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 22 - 參考解答

已安裝 Istio `1.29.1`。一個「外部」且**僅限 HTTPS** 的後端部署於命名空間
`external`（沒有 sidecar）：nginx 在連接埠 `8443` 終止 TLS，而 Service
`httpsvc` 以明文連接埠 `80` 公開它（`targetPort: 8443`）。一個網格內用戶端
`app-client` 在命名空間 `app` 中執行。

## 目標

讓網格對外部服務**發起 TLS**：應用程式以純 HTTP 與
`httpsvc.external:80` 通訊，而它的 sidecar 在連線到達後端前將連線升級為 TLS。

## 步驟 1. 觀察未發起 TLS 時的失敗

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## 步驟 2. 使用 DestinationRule 設定 TLS 發起

後端使用自簽憑證，因此我們透過
`insecureSkipVerify: true` 跳過上游驗證。在正式環境中，您應改為將
`caCertificates` 設為簽署上游憑證的 CA。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpsvc-tls-origination
  namespace: app
spec:
  host: httpsvc.external.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        insecureSkipVerify: true
EOF
```

## 步驟 3. 驗證

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## 運作方式

- 用戶端向 `httpsvc.external:80` 傳送純**HTTP**。不需要變更應用程式程式碼，也不需在應用程式中管理
  憑證。
- 連接埠 80 上具有 `tls.mode: SIMPLE` 的 `DestinationRule` 指示用戶端 Envoy
  對上游端點（後端的 `targetPort: 8443`）**發起 TLS**。
- 後端收到正確的 TLS 連線並回傳 `200`。
- 在 Istio 中，`SIMPLE` 預設會**驗證**上游憑證。我們的後端使用自簽憑證，因此設定
  `insecureSkipVerify: true`。在正式環境中，您應改為設定 `caCertificates`
  （以及可選的 `subjectAltNames`）來驗證上游，或使用 `MUTUAL` 進行用戶端憑證驗證。

## 為何在網格中發起 TLS

- 應用程式可以保持簡單（純 HTTP），而所有連往外部或舊有服務的 TLS 都由網格一致地處理。
- 結合**出口閘道**（Lab 05），可以在專用節點上集中發起 TLS，使所有外送 TLS 都經由一個經稽核、
  受政策控制的躍點離開叢集。
