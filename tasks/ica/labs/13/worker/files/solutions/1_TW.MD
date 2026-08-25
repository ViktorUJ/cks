[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 13 - 參考解答（使用 TLS 保護邊緣流量）

## 步驟 1. 啟用 sidecar 注入並部署應用程式

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/13/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/ping-pong -n default
```

## 步驟 2. 建立 TLS 憑證並將其儲存為 Secret

憑證 Secret 必須位於 ingress gateway 的命名空間（`istio-system`）中。

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout myapp.key -out myapp.crt \
  -subj "/CN=myapp.local/O=demo" \
  -addext "subjectAltName=DNS:myapp.local"

kubectl create -n istio-system secret tls myapp-cert \
  --cert=myapp.crt --key=myapp.key
```

## 步驟 3. HTTPS Gateway（TLS 終止，模式 SIMPLE）

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: myapp-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: myapp-cert   # references the Secret in istio-system
    hosts:
    - "myapp.local"
```

## 步驟 4. VirtualService

```yaml
# vs.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - myapp-gateway
  http:
  - route:
    - destination:
        host: ping-pong
        port:
          number: 8080
```

```bash
kubectl apply -f gateway.yaml
kubectl apply -f vs.yaml
```

## 驗證

```bash
# HTTPS terminated at the edge (-k because the cert is self-signed)
curl -sk https://myapp.local:32443/ | grep 'Server Name'

# inspect the served certificate
curl -skv https://myapp.local:32443/ 2>&1 | grep -E 'subject:|issuer:'
```

## （選用）邊緣的雙向 TLS（MUTUAL）

要求用戶端出示由受信任 CA 簽署的憑證：

```bash
# add the CA cert to the same secret (generic) and switch the gateway to MUTUAL
kubectl create -n istio-system secret generic myapp-cert-mtls \
  --from-file=tls.crt=myapp.crt --from-file=tls.key=myapp.key --from-file=ca.crt=ca.crt
```

```yaml
    tls:
      mode: MUTUAL
      credentialName: myapp-cert-mtls
```

接著，用戶端必須傳送 `--cert client.crt --key client.key`。