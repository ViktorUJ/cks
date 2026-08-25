[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 20 - リファレンスソリューション

Istio `1.29.1` がインストールされています。3 つのワークロードがデプロイされています:
- 名前空間 `app` の `ping-pong` (サイドカーが注入され、アプリを提供);
- 名前空間 `app` の `mesh-client` (サイドカーが注入され、mTLS で通信);
- 名前空間 `legacy` の `legacy-client` (**サイドカーなし**、プレーンテキストのみ)。

`PeerAuthentication` がない場合、mTLS のデフォルトは **PERMISSIVE** です: メッシュクライアント
(mTLS) とレガシークライアント (プレーンテキスト) の両方がアプリに到達できます。

## 目標

`app` 名前空間を **STRICT** mTLS に移行し、メッシュ内クライアントを壊すことなく、
mTLS トラフィックのみを受け入れるようにします。

## ステップ 1. PERMISSIVE のベースラインを確認する

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

## ステップ 2. (推奨) PERMISSIVE で意図を明示する

安全な移行では、最初に PERMISSIVE を明示的に固定し、プレーンテキストトラフィックが残っていないことを
(メトリクスで) 確認してから STRICT に切り替えます:

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

## ステップ 3. 名前空間を STRICT に切り替える

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

## ステップ 4. 検証する

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

## 仕組み

- **PeerAuthentication** は、*サーバー側* サイドカーが受信接続を受け入れる方法を
  制御します:
  - `PERMISSIVE` (メッシュのデフォルト) - mTLS とプレーンテキストの両方を受け入れます。これにより、
    ダウンタイムなしの移行が可能になります: レガシーのプレーンテキストクライアントを稼働させたまま、
    ワークロードを段階的にメッシュへ参加させることができます。
  - `STRICT` - mTLS のみを受け入れます。プレーンテキスト接続はリセットされます。
- スコープ階層: `istio-system` (ルート) の `PeerAuthentication` はメッシュ全体に適用されます。
  名前空間内のものはその名前空間で上書きし、`selector` を持つものはワークロードごとに上書きします。
- **安全な移行手順**: PERMISSIVE を維持し、
  `istio_requests_total{connection_security_policy="none"}` メトリクスがゼロになるまで監視し
  (プレーンテキストが残っていない状態)、その後 STRICT に切り替えます。

## 関連

Lab 04 では、`AuthorizationPolicy` (誰が誰を呼び出せるか) と組み合わせた STRICT の最終状態を扱います。
この Lab は移行そのものと PERMISSIVE の役割に焦点を当てています。