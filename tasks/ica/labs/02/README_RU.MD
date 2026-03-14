# Dark Launch (Теневой запуск)
Разработчики выкатили абсолютно новую, экспериментальную версию приложения — v3. Она еще сырая, и обычные пользователи ни в коем случае не должны ее увидеть (они должны оставаться на стабильной v1). Однако вам нужно пустить туда QA-инженеров, чтобы они проверили логику работы на реальном "боевом" кластере. Тестировщики будут идентифицироваться с помощью специального HTTP-заголовка: x-user: tester.

Цель:
С нуля настроить правила Istio (DestinationRule и VirtualService) таким образом, чтобы Envoy-прокси перехватывал трафик, читал HTTP-заголовки и выполнял маршрутизацию на основе их содержимого.
Создан Gateway  http://myapp.local:32080

Добавляем label на namespace `default` для автоматической инъекции sidecar-прокси Envoy:

```bash
kubectl label namespace default istio-injection=enabled
```

установим приложение в 3- версиях . Создан общий Kubernetes Service с именем ping-pong.

````
k apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-134/tasks/ica/labs/02/k8s-1/scripts/1.yaml
````

проверяем что поды поднялись с Envoy-прокси:

```
# k get pods

NAME                            READY   STATUS    RESTARTS   AGE
ping-pong-v1-77cfd77f88-jk6wq   2/2     Running   0          29m
ping-pong-v2-685bbbd94f-brptj   2/2     Running   0          29m
ping-pong-v3-8448447987-bn6s8   2/2     Running   0          29m

```
создаем DestinationRule:
```
# vim  dl-destination-rule.yaml

apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ping-pong-dr
spec:
  host: ping-pong # Указываем на общий K8s Service
  subsets:
  - name: v1
    labels:
      version: v1 # Ищет поды с лейблом version=v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3

```
``` 
k apply -f dl-destination-rule.yaml
```

создаем VirtualService с правилами маршрутизации:

```
# vim vs-virtual-service.yaml

apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
spec:
  hosts:
  - "*"
  gateways:
  - ping-pong-gateway  # для внешнего трафика 
  - mesh #  нужно чтобы наши правила работали внутри кластера
  http:
  # ПРАВИЛО №1: Срабатывает ТОЛЬКО если есть заголовок x-user: tester
  - match:
    - headers:
        x-user:
          exact: tester
    route:
    - destination:
        host: ping-pong
        subset: v3

  # ПРАВИЛО №2: Дефолтное правило для всех остальных (Канарейка 90/10)
  - route:
    - destination:
        host: ping-pong
        subset: v1
      weight: 90
    - destination:
        host: ping-pong
        subset: v2
      weight: 10

```
``` 
k apply -f vs-virtual-service.yaml
```
создаем gateway для доступа извне:

```
# vim gateway.yaml

apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: ping-pong-gateway
spec:
  selector:
    istio: ingressgateway # Говорим применить эти настройки к нашему Ingress-шлюзу
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*" # Принимаем запросы на любые домены (включая myapp.local и IP-адреса)

```
test
```
for i in {1..10}; do curl -s  http://myapp.local:32080 | grep 'Server Name:' ; done

```
```
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V2 (Canary)
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V2 (Canary)
Server Name: Ping-Pong-V1 (Stable)
Server Name: Ping-Pong-V1 (Stable)

```

теперь добавим заголовок x-user: tester и проверим, что мы всегда попадаем на v3:

```
#  curl -s -H "x-user: tester" http://myapp.local:32080/ | grep 'Server Name:'

Server Name: Ping-Pong-V3 (Experimental)

```
