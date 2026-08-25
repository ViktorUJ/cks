[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 08 - საცნობარო გადაწყვეტა

## ნაბიჯი 1. sidecar-ის ინექციის ჩართვა

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## ნაბიჯი 2. აპლიკაციისა და Gateway/VirtualService-ის განთავსება

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/08/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
```

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.local"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - main-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 8080
```

```bash
kubectl apply -f gateway.yaml
```

## ნაბიჯი 3. დაკვირვებადობის დანამატების ინსტალაცია

```bash
REL=release-1.29
kubectl apply -f https://raw.githubusercontent.com/istio/istio/$REL/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/$REL/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/$REL/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/$REL/samples/addons/kiali.yaml

kubectl rollout status deployment/prometheus -n istio-system
kubectl rollout status deployment/kiali -n istio-system
```

## ნაბიჯი 4. ტრასირების სემპლინგის 100%-ზე დაყენება

```yaml
# telemetry.yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: zipkin
    randomSamplingPercentage: 100.0
```

```bash
kubectl apply -f telemetry.yaml
```

## ნაბიჯი 5. ტრაფიკის გენერირება

```bash
for i in $(seq 50); do curl -s -o /dev/null http://myapp.local:32080; done
```

## ნაბიჯი 6. მეტრიკები (Prometheus)

```bash
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s 'http://prometheus.istio-system:9090/api/v1/query?query=istio_requests_total{destination_service_name="ping-pong"}' | jq '.data.result | length'
```

ბრაუზერი (არასავალდებულო): `kubectl -n istio-system port-forward svc/prometheus 9090:9090`

## ნაბიჯი 7. ტრასირება (Jaeger)

```bash
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s 'http://tracing.istio-system/jaeger/api/services' | jq .
```

ბრაუზერი (არასავალდებულო): `kubectl -n istio-system port-forward svc/tracing 8080:80`, შემდეგ გახსენით `/jaeger`

## ნაბიჯი 8. სერვისების გრაფი (Kiali)

```bash
kubectl -n istio-system port-forward svc/kiali 20001:20001
# open http://localhost:20001 -> Graph -> namespace "default"
```

## შემოწმება

```bash
kubectl get pods -n istio-system | grep -E 'prometheus|grafana|jaeger|kiali'
```
