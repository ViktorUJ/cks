[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 15 - リファレンスソリューション

使用する Istio バージョン: `1.29.1`（istioctl はワーカー PC に事前インストールされています）。

## 目標

`IstioOperator` マニフェストを使用して、**カスタマイズした**設定で Istio をインストールします:
- `default` プロファイルから開始する。
- 2 つの `meshConfig` オプションを設定する:
  - `accessLogFile: /dev/stdout`（Envoy のアクセスログを stdout に出力する）。
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY`（未知のホストへの外向きトラフィックをブロックする）。
- デフォルトの `istio-ingressgateway` に加えて、2 つ目のイングレスゲートウェイコンポーネント `ingressgateway-internal` を追加する。

## ステップ 1. IstioOperator マニフェストを作成する

```bash
cat > custom-istio.yaml <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: custom-istio
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
      - name: ingressgateway-internal
        enabled: true
        label:
          istio: ingressgateway-internal
        k8s:
          service:
            type: ClusterIP
EOF
```

## ステップ 2. カスタムマニフェストで Istio をインストールする

```bash
istioctl install -f custom-istio.yaml -y
```

## ステップ 3. インストールを確認する

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

想定される結果:
- `istiod` が `Running` になっている。
- デプロイメント `istio-ingressgateway` と `ingressgateway-internal` の両方が準備完了している。
- `istio` ConfigMap に `accessLogFile: /dev/stdout` と `outboundTrafficPolicy.mode: REGISTRY_ONLY` が含まれている。

## （任意）ステップ 4. REGISTRY_ONLY の動作を確認する

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

`outboundTrafficPolicy: REGISTRY_ONLY` を使用すると、`ServiceEntry` を介して宣言されていない外部ホストへの呼び出しは拒否されます。このようなトラフィックを許可するには、`ServiceEntry` を追加します（ラボ 05 を参照）。
