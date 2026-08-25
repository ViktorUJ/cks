[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 15 - 參考解答

使用的 Istio 版本：`1.29.1`（worker PC 上已預先安裝 istioctl）。

## 目標

使用 `IstioOperator` manifest 以**自訂**設定安裝 Istio：
- 從 `default` profile 開始；
- 設定兩個 `meshConfig` 選項：
  - `accessLogFile: /dev/stdout`（Envoy 存取日誌輸出至 stdout），
  - `outboundTrafficPolicy.mode: REGISTRY_ONLY`（封鎖連至未知主機的 egress）；
- 除了預設的 `istio-ingressgateway` 外，再新增第二個 ingress gateway 元件 `ingressgateway-internal`。

## 步驟 1. 撰寫 IstioOperator manifest

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

## 步驟 2. 使用自訂 manifest 安裝 Istio

```bash
istioctl install -f custom-istio.yaml -y
```

## 步驟 3. 驗證安裝

```bash
# control plane
kubectl get pods -n istio-system

# both ingress gateways
kubectl get deploy -n istio-system | grep -E 'ingressgateway'

# meshConfig landed in the istio configmap
kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' | grep -E 'accessLogFile|outboundTrafficPolicy|REGISTRY_ONLY'
```

預期結果：
- `istiod` 為 `Running`；
- `istio-ingressgateway` 與 `ingressgateway-internal` deployments 均已就緒；
- `istio` configmap 包含 `accessLogFile: /dev/stdout` 及 `outboundTrafficPolicy.mode: REGISTRY_ONLY`。

## （選用）步驟 4. 實際查看 REGISTRY_ONLY 的效果

```bash
kubectl create namespace demo
kubectl label namespace demo istio-injection=enabled
kubectl -n demo run curl --image=curlimages/curl -it --rm --restart=Never -- \
  sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://httpbin.org/get'
# -> 502 : egress is blocked because the host is not in the mesh registry
```

使用 `outboundTrafficPolicy: REGISTRY_ONLY` 時，對未透過 `ServiceEntry` 宣告的外部主機進行呼叫會被拒絕。若要允許此類流量，請新增 `ServiceEntry`（請參閱 Lab 05）。
