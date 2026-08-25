[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 19 - 參考解答

叢集已啟動，但尚未安裝 Istio。工作電腦上可使用 `istioctl 1.29.1` 和 `openssl`。

## 目標

不要讓 istiod 使用其自我簽署的 CA，而是接入您**自己的**憑證授權單位：
1. 產生根 CA 和中繼 CA；
2. 將它們以 `cacerts` Secret 載入 istio-system；
3. 安裝 Istio，istiod 會使用中繼 CA 簽署所有工作負載憑證；
4. 確認工作負載憑證可鏈結至您的自訂根憑證。

## 步驟 1. 產生根 CA 和中繼 CA

```bash
mkdir -p ~/ca && cd ~/ca

# Root CA
openssl genrsa -out root-key.pem 4096
openssl req -x509 -new -nodes -key root-key.pem -sha256 -days 3650 \
  -subj "/O=CKS-Lab/CN=CKS-Lab Root CA" -out root-cert.pem

# Intermediate CA, signed by the root
openssl genrsa -out ca-key.pem 4096
openssl req -new -key ca-key.pem -subj "/O=CKS-Lab/CN=CKS-Lab Intermediate CA" -out ca.csr

cat > ext.cnf <<'EOF'
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,digitalSignature,keyCertSign,cRLSign
subjectAltName=DNS:istiod.istio-system.svc
EOF

openssl x509 -req -in ca.csr -CA root-cert.pem -CAkey root-key.pem -CAcreateserial \
  -days 1825 -sha256 -extfile ext.cnf -out ca-cert.pem

# Istio expects the chain = intermediate + root
cat ca-cert.pem root-cert.pem > cert-chain.pem
```

## 步驟 2. 建立 `cacerts` Secret

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## 步驟 3. 安裝 Istio

```bash
istioctl install --set profile=default -y
```

istiod 會在啟動時偵測 `cacerts` Secret，並使用中繼 CA 簽發工作負載憑證，而不是產生自我簽署的 CA。

## 步驟 4. 部署應用程式

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## 步驟 5. 驗證信任鏈

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# The root of trust the sidecar validates against - should be our custom root
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="ROOTCA") | .secret.validationContext.trustedCa.inlineBytes' \
  | base64 -d | openssl x509 -noout -subject -issuer
# subject/issuer -> O=CKS-Lab, CN=CKS-Lab Root CA

# The workload certificate itself, signed by our intermediate
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer
# issuer -> O=CKS-Lab, CN=CKS-Lab Intermediate CA
```

## 運作方式

- Istiod 是服務網格 CA：它會簽署每個 sidecar 用於 mTLS 的 SPIFFE 身分憑證（`SVID`）。預設情況下，它會在首次啟動時自我簽署一個 CA。
- **`cacerts`** Secret（`ca-cert.pem`、`ca-key.pem`、`root-cert.pem`、`cert-chain.pem`）可讓您提供自己的中繼 CA。之後 istiod 會從*您的* PKI 簽發工作負載憑證，因此整個服務網格會鏈結至您所控制的根憑證，這對與企業 PKI 或共用的多叢集信任根整合至關重要。
- istiod 仍會自動**輪替**工作負載憑證（短效 SVID）；您只需提供簽署 CA。

## 生產環境演進：使用 cert-manager + istio-csr 的動態簽發

接入靜態 `cacerts` Secret 意味著中繼金鑰存在叢集中，且您必須手動輪替。在生產環境中，團隊通常會使用 **cert-manager + istio-csr**：istiod 會將簽署委派給 `istio-csr`，後者會向 cert-manager `Issuer` 請求憑證（其後端可為 Vault、ACME CA 或企業 PKI）。這可讓簽署金鑰留在 istiod 之外，並啟用自動 CA 輪替。