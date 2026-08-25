[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 22 - リファレンスソリューション

Istio `1.29.1` がインストールされています。"external" の **HTTPS 専用** バックエンドが
namespace `external` にデプロイされています（sidecar なし）。nginx はポート `8443` で TLS を終端し、Service
`httpsvc` はこれを平文ポート `80`（`targetPort: 8443`）で公開しています。インメッシュのクライアント
`app-client` は namespace `app` で実行されています。

## 目標

メッシュから外部サービスへの **TLS オリジネーション**を実現します。アプリは
`httpsvc.external:80` に平文 HTTP で接続し、その sidecar がバックエンドに到達する前に
接続を TLS にアップグレードします。

## ステップ 1. オリジネーションなしでの失敗を確認する

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## ステップ 2. DestinationRule で TLS オリジネーションを設定する

バックエンドは自己署名証明書を使用しているため、`insecureSkipVerify: true` を使って
upstream の検証をスキップします。本番環境では、代わりに upstream に署名した CA を
`caCertificates` に設定します。

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

## ステップ 3. 検証する

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## 仕組み

- クライアントは `httpsvc.external:80` に平文の **HTTP** を送信します。アプリコードの変更や、アプリ内で管理する証明書は不要です。
- ポート 80 上の `tls.mode: SIMPLE` を含む `DestinationRule` は、クライアント側の Envoy に
  upstream endpoint（バックエンドの `targetPort: 8443`）への **TLS オリジネーション**を指示します。
- バックエンドは適切な TLS 接続を受け取り、`200` を返します。
- Istio では、`SIMPLE` はデフォルトで upstream 証明書を **検証**します。このバックエンドは
  自己署名証明書を使用しているため、`insecureSkipVerify: true` を設定しています。本番環境では、代わりに
  `caCertificates`（および任意で `subjectAltNames`）を設定して upstream を検証するか、クライアント証明書認証には
  `MUTUAL` を使用します。

## メッシュで TLS オリジネーションを行う理由

- アプリケーションはシンプルなまま（平文 HTTP）に保ちつつ、外部サービスやレガシーサービスへのすべての TLS を
  メッシュが一貫して処理できます。
- **egress gateway**（Lab 05）と組み合わせると、オリジネーションを専用ノードに集約できるため、すべての outbound TLS が
  1 つの監査済みかつポリシー制御された hop を介してクラスターを出るようにできます。
