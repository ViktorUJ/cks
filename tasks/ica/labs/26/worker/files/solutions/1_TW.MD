[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 26 - 參考解答

平台已完成動態簽發憑證的設定：
- 已安裝 **cert-manager**；
- 在 `istio-system` 中存在自我簽署的根 CA，以及名為 `istio-ca` 的 CA `Issuer`；
- **istio-csr** (`cert-manager-istio-csr`) 在 `cert-manager` 中執行，並提供由 `istio-ca` Issuer 支援的 Istio CA
  gRPC API；
- **Istio** 安裝時已**停用**其內建 CA (`ENABLE_CA_SERVER=false`)，且
  `global.caAddress` 指向 istio-csr，因此 istiod 會將所有簽署工作委派給 cert-manager。

工作電腦上可使用 `istioctl`。

## 目標

部署一個工作負載，並確認其身分憑證 (`SVID`) 由
**cert-manager** 經由 istio-csr 簽發，而非由 istiod 的自我簽署 CA 簽發。

## 步驟 1. 部署應用程式

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## 步驟 2. 觀察 cert-manager 簽發憑證

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## 步驟 3. 驗證工作負載憑證來自 cert-manager

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

簽發者包含 `cert-manager` / `istio-ca`，工作負載 SVID 由您的
cert-manager CA 簽署，且 SPIFFE 身分保持完整。

## 運作方式

```
sidecar (istio-agent)
    │  CSR over gRPC
    ▼
istio-csr (cert-manager-istio-csr)      # implements the Istio CA API
    │  creates CertificateRequest
    ▼
cert-manager  ──uses──►  Issuer "istio-ca"  ──►  signs the cert
    │
    ▼
sidecar receives its SVID (rotated automatically)
```

- istiod 不再簽署憑證 (`ENABLE_CA_SERVER=false`)；它會將代理程式指向
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443`。
- **istio-csr** 實作 Istio CA gRPC API。它會為每個工作負載 CSR 建立一個
  cert-manager `CertificateRequest`，並由 cert-manager 使用已設定的
  `Issuer` 簽署。
- 簽署金鑰位於 cert-manager 的 `Issuer` 中（此處是自我簽署的 CA secret，但也可以是
  **Vault**、**ACME** CA 或企業 PKI），而非位於 istiod 中。

## 為何這優於靜態 `cacerts`（實驗 19）

| | 實驗 19（`cacerts` secret） | 此實驗（cert-manager + istio-csr） |
|---|---|---|
| 簽署金鑰位置 | 中繼金鑰位於 istiod | 保留在 cert-manager `Issuer` 中（Vault/PKI） |
| CA 輪替 | 手動（重新建立 secret + 重新啟動） | 由 cert-manager 自動處理 |
| 後端 | 僅限靜態 PEM | Vault、ACME、企業 PKI 等 |
| 可稽核性 | 無 | 每張憑證都是一個 `CertificateRequest` 物件 |

兩者都讓網格鏈結至您掌控的 CA；istio-csr 是適合生產環境且可自動化的演進方案。
