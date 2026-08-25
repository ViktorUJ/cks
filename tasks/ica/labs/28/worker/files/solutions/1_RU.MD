[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 28 - Эталонное решение

Istio `1.29.1` установлен с фиксированным TCP NodePort `31400` на ingress gateway. Приложение
`tcp-echo` развернуто в пространстве имен `app` в двух версиях:
- **v1** отвечает с префиксом `one`;
- **v2** отвечает с префиксом `two`.

Обе версии прослушивают необработанный TCP-порт `9000` (не HTTP).

## Цель

Направить необработанный сервис **TCP** через ingress gateway, используя `Gateway` с прослушивателем
`TCP` и `VirtualService` с маршрутом `tcp` (со взвешенным распределением между v1 и v2).

## Шаг 1. Gateway с прослушивателем TCP

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: tcp-echo-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 31400
        name: tcp
        protocol: TCP
      hosts:
        - "*"
EOF
```

## Шаг 2. DestinationRule с подмножествами

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tcp-echo
  namespace: app
spec:
  host: tcp-echo
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

## Шаг 3. VirtualService с маршрутом TCP

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tcp-echo
  namespace: app
spec:
  hosts:
    - "*"
  gateways:
    - tcp-echo-gateway
  tcp:
    - match:
        - port: 31400
      route:
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v1
          weight: 80
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v2
          weight: 20
EOF
```

## Шаг 4. Проверка

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

(Если установлен `nc`: `echo hello | nc myapp.local 31400`.)

## Как это работает

- **Маршрутизация TCP** работает на уровне 4: HTTP host/path/header отсутствуют, поэтому ключом
  маршрутизации служит **порт прослушивателя** (`match.port`). Сервер `Gateway` с `protocol: TCP`
  заставляет Envoy открыть обычный прослушиватель TCP; маршрут `VirtualService.tcp` перенаправляет соединение
  в выбранное подмножество backend.
- **Именование портов важно**: порт service/gateway должен называться `tcp` (или `tcp-*`). Istio
  использует префикс имени порта для определения протокола; имя без префикса или `http-*` приведет к тому,
  что Istio будет считать его HTTP, и необработанный протокол перестанет работать.
- **Взвешенное распределение TCP** разделяет *соединения* (а не запросы) между подмножествами - каждое новое TCP
  соединение направляется по весу.
- Функции L7 (retries, header routing, fault injection) **не** применяются к маршрутам TCP -
  только политики уровня соединений (connection pool, timeouts) через `DestinationRule`.

## Связанные протоколы

- **MongoDB/MySQL/Redis** - назовите порт `mongo-*` / `mysql-*` / `redis-*`, чтобы Envoy
  применил правильный анализатор протокола; маршрутизация по-прежнему использует маршруты `tcp`.
- **WebSocket** - несмотря на длительное существование, он работает поверх HTTP `Upgrade`, поэтому используйте обычные
  маршруты `http` и имена портов `http-*`, а не TCP.
