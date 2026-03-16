## Шаг 1. Включение sidecar-инъекции

Добавляем label на namespace `default` для автоматической инъекции sidecar-прокси Envoy:

```bash
kubectl label namespace default istio-injection=enabled
```



```
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
spec:
  hosts:
  - "myapp.local"       # Внешний домен
  gateways:
  - ping-pong-gateway   # Наш Ingress Gateway
  http:
  - route:
    - destination:
        host: frontend  # Весь внешний трафик идет во Фронтенд

```

``` 
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
spec:
  hosts:
  - "ping-pong"  # Реагируем на внутрикластерное DNS-имя
  gateways:
  - mesh         # МАГИЧЕСКОЕ СЛОВО: правило только для внутреннего трафика!
  http:
  # Дефолтная маршрутизация 90% на v1, 10% на v2
  - route:
    - destination:
        host: ping-pong
        subset: v1
      weight: 100
```

``` 
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway # Нейтральное имя
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
```