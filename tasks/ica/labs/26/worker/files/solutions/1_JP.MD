[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 26 - 参照ソリューション

プラットフォームはすでに動的な証明書発行用に構成されています:
- **cert-manager** がインストールされています。
- 自己署名ルート CA と、`istio-system` 内の `istio-ca` という名前の CA `Issuer` が存在します。
- **istio-csr** (`cert-manager-istio-csr`) は `cert-manager` 内で稼働し、`istio-ca` Issuer を
  バックエンドとする Istio CA gRPC API を提供します。
- **Istio** は組み込み CA が**無効化**された状態でインストールされており (`ENABLE_CA_SERVER=false`)、
  `global.caAddress` は istio-csr を指しているため、istiod はすべての署名を cert-manager に委任します。

`istioctl` はワーカー PC で利用できます。

## 目標

ワークロードをデプロイし、その ID 証明書 (`SVID`) が istiod の自己署名 CA ではなく、
istio-csr を介して **cert-manager** により発行されることを確認します。

## ステップ 1. アプリをデプロイする

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## ステップ 2. cert-manager による証明書発行を確認する

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## ステップ 3. ワークロード証明書が cert-manager から発行されたことを検証する

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

発行者には `cert-manager` / `istio-ca` が含まれています。ワークロード SVID は cert-manager
CA によって署名され、SPIFFE ID も維持されています。

## 仕組み

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

- istiod は証明書に署名しなくなります (`ENABLE_CA_SERVER=false`)。エージェントを
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443` に向けます。
- **istio-csr** は Istio CA gRPC API を実装します。ワークロード CSR ごとに cert-manager
  `CertificateRequest` を作成し、cert-manager が構成済みの `Issuer` で署名します。
- 署名鍵は cert-manager の `Issuer` 内にあります (ここでは自己署名 CA secret ですが、
  **Vault**、**ACME** CA、または企業 PKI を使用することもできます)。istiod 内にはありません。

## 静的な `cacerts` より優れている理由 (ラボ 19)

| | ラボ 19 (`cacerts` secret) | このラボ (cert-manager + istio-csr) |
|---|---|---|
| 署名鍵の場所 | 中間鍵が istiod に存在 | cert-manager `Issuer` (Vault/PKI) に保持される |
| CA ローテーション | 手動 (secret を再作成して再起動) | cert-manager により自動化 |
| バックエンド | 静的 PEM のみ | Vault、ACME、企業 PKI など |
| 監査可能性 | なし | すべての証明書が `CertificateRequest` オブジェクト |

どちらもメッシュを自分で制御する CA にチェーンさせます。istio-csr は、本番環境に適した
自動化可能な進化形です。