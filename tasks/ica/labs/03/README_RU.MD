## Шаг 1. Включение sidecar-инъекции

Добавляем label на namespace `default` для автоматической инъекции sidecar-прокси Envoy:

```bash
kubectl label namespace default istio-injection=enabled
```


``` 
k apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-136/tasks/ica/labs/03/k8s-1/scripts/1.yaml
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
  - main-gateway   # Наш Ingress Gateway
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
  - "ping-pong"
  gateways:
  - mesh
  http:
  - fault:
      abort:
        httpStatus: 503
        percentage:
          value: 50.0 # Ломаем ровно половину запросов
    route:
    - destination:
        host: ping-pong
        # Обратите внимание: никаких subset! Трафик идет просто на сервис.
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

``` 
curl http://myapp.local:32080
```