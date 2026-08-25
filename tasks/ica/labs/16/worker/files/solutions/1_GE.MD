[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 16 - ეტალონური გადაწყვეტა

Istio `1.29.1` უკვე დაყენებულია (ნაგულისხმევი პროფილით) და Kubernetes Gateway API-ის
CRD-ები (`v1.2.1`) ხელმისაწვდომია. აპლიკაცია (`ping-pong-v1` / `ping-pong-v2`) განთავსებულია
namespace `app`-ში.

## ნაბიჯი 1. განათავსეთ აპლიკაცია

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

თითოეული pod უნდა იყოს `2/2` (აპლიკაცია + istio-proxy sidecar).

## ნაბიჯი 2. შექმენით Gateway (Kubernetes Gateway API)

Gateway ანოტირებულია ისე, რომ Istio-მ მისთვის **NodePort** Service შექმნას (ამ სატესტო
გარემოში ღრუბლოვანი load balancer არ არის).

```bash
cat > gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: app
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

kubectl apply -f gateway.yaml
```

Istio ავტომატურად ქმნის Deployment-სა და Service-ს სახელით `web-gateway-istio`
namespace `app`-ში:

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## ნაბიჯი 3. შექმენით HTTPRoute

`x-version: canary` header-ის მქონე მოთხოვნები მიმართეთ **v2**-ისკენ, დანარჩენი კი **v1**-ისკენ.

```bash
cat > httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ping-pong-route
  namespace: app
spec:
  parentRefs:
    - name: web-gateway
  rules:
    - matches:
        - headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: ping-pong-v2
          port: 8080
    - backendRefs:
        - name: ping-pong-v1
          port: 8080
EOF

kubectl apply -f httproute.yaml
```

## ნაბიჯი 4. შეამოწმეთ მარშრუტიზაცია

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

მოსალოდნელი შედეგი: ნაგულისხმევი მოთხოვნა აბრუნებს `Ping-Pong-V1 (Stable)`-ს, ხოლო
`x-version: canary` header-ის მქონე მოთხოვნა აბრუნებს `Ping-Pong-V2 (Canary)`-ს.

## Istio API და Gateway API

| ცნება | Istio API | Kubernetes Gateway API |
|---|---|---|
| შესვლის წერტილი | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| მარშრუტიზაციის წესები | `VirtualService` | `HTTPRoute` |
| Backend | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Gateway pod | საერთო `istio-ingressgateway` | ავტომატურად შექმნილი თითოეული `Gateway`-სთვის |
| პორტაბელურობა | სპეციფიკურია Istio-სთვის | მომწოდებლისგან დამოუკიდებელი, პორტაბელური mesh-ებსა და ingress-ებს შორის |
