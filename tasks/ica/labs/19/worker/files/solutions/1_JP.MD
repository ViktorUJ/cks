[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 19 - リファレンスソリューション

クラスターは起動していますが、Istio は**インストールされていません**。`istioctl 1.29.1` と `openssl` は
ワーカー PC で利用できます。

## 目標

istiod に自己署名 CA を使用させる代わりに、**独自の**認証局を
組み込みます。
1. ルート CA と中間 CA を生成する。
2. それらを `cacerts` シークレットとして istio-system にロードする。
3. Istio をインストールする。istiod は中間 CA を使用してすべてのワークロード証明書に署名する。
4. ワークロード証明書がカスタムルートに連鎖することを確認する。

## ステップ 1. ルート CA と中間 CA を生成する

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

## ステップ 2. `cacerts` シークレットを作成する

```bash
kubectl create namespace istio-system
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem \
  --from-file=ca-key.pem \
  --from-file=root-cert.pem \
  --from-file=cert-chain.pem
```

## ステップ 3. Istio をインストールする

```bash
istioctl install --set profile=default -y
```

istiod は起動時に `cacerts` シークレットを検出し、自己署名 CA を生成する代わりに中間 CA を使用して
ワークロード証明書を発行します。

## ステップ 4. アプリをデプロイする

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/19/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## ステップ 5. 信頼チェーンを検証する

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

## 仕組み

- Istiod はメッシュ CA です。すべてのサイドカーが mTLS に使用する SPIFFE ID 証明書（`SVID`）に署名します。デフォルトでは、初回起動時に CA を自己署名します。
- **`cacerts`** シークレット（`ca-cert.pem`、`ca-key.pem`、`root-cert.pem`、
  `cert-chain.pem`）により、独自の中間 CA を提供できます。istiod はその後、*独自の* PKI から
  ワークロード証明書を発行するため、メッシュ全体が制御下にあるルートに連鎖します。これはエンタープライズ PKI や共有マルチクラスター信頼ルートとの統合に不可欠です。
- istiod はワークロード証明書を引き続き**ローテーション**します（短期間有効な SVID）。提供するのは署名 CA のみです。

## 本番環境での発展: cert-manager + istio-csr による動的発行

静的な `cacerts` シークレットを組み込む場合、中間鍵はクラスター内に存在し、手動でローテーションする必要があります。本番環境では、チームはしばしば **cert-manager + istio-csr** を使用します。
istiod は署名を `istio-csr` に委任し、`istio-csr` は cert-manager の
`Issuer`（Vault、ACME CA、または企業 PKI によって支えられる）から証明書を要求します。これにより署名鍵を istiod の外部に保持し、CA の自動ローテーションが可能になります。