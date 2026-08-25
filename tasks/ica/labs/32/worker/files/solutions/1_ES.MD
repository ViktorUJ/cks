[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 32 - Solución de referencia

Istio `1.29.1` (perfil predeterminado) está instalado. El espacio de nombres `app` (con istio-injection
habilitado) ejecuta la imagen `viktoruj/ping_pong`, que usa gRPC
(`PingPong.Echo` devuelve el hostname del pod que atiende):

- **grpc-server** - el servidor gRPC Echo/Health, **3 réplicas** (gRPC en el puerto
  `8079`);
- **grpc-client** - la misma imagen, usada para generar carga gRPC
  (`/app -grpc-client ...`).

El **Service** `grpc-server` se crea con un puerto **mal nombrado** (`tcp`).
Por ello, Istio trata el puerto `8079` como TCP L4 sin procesar: la única conexión
HTTP/2 gRPC de larga duración queda fijada a un pod, por lo que el cliente ve solo
**un** servidor distinto y no se produce balanceo por solicitud.

## Objetivo

1. Hacer que Istio reconozca el puerto gRPC para que haga balanceo de carga **por solicitud**
   (HTTP/2) entre todos los pods backend.
2. Añadir un `VirtualService` para `grpc-server` con **reintentos** gRPC y un
   **timeout**.

## Paso 1. Corregir el nombre del puerto del Service

gRPC es HTTP/2, no TCP sin procesar. Istio detecta el protocolo a partir del **prefijo
 del nombre** del puerto (`grpc`, `http2`, ...) o del campo explícito `appProtocol`. Renombra el
puerto a `grpc` (y/o establece `appProtocol: grpc`):

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

Manifiesto completo equivalente:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

En cuanto Istio ve un clúster HTTP/2 (gRPC), Envoy balancea **cada solicitud**
dentro de la conexión compartida entre todos los endpoints, sin configuración adicional.

## Paso 2. VirtualService con reintentos gRPC + timeout

gRPC se ejecuta sobre HTTP, por lo que se configura mediante el bloque `http` (no `tcp`):
se aplican reintentos, timeouts, enrutamiento por encabezados y balanceo por solicitud.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` usa condiciones compatibles con gRPC: `unavailable`, `cancelled`,
  `deadline-exceeded` se asignan a códigos de estado gRPC; `refused-stream` y
  `connect-failure` cubren problemas de transporte.
- `timeout` limita toda la solicitud; `perTryTimeout` limita cada intento.

## Paso 3. (opcional) Fijar la política de balanceo de carga

El balanceo por solicitud está activo de forma predeterminada una vez que el puerto es gRPC. Para hacer
explícita la política:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## Paso 4. Verificar

Genera carga gRPC desde el cliente y confirma que las solicitudes alcanzan **los tres** pods
backend (balanceo por solicitud):

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

Resultado esperado al final:

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` demuestra que las solicitudes se balancean por solicitud. Antes de la
corrección (puerto llamado `tcp`), el mismo comando informa `distinct servers: 1`.

## Por qué funciona

- **gRPC es HTTP/2, no TCP.** Con una vista L4/TCP, Envoy balancea las
  *conexiones*: un cliente gRPC mantiene una única conexión de larga duración, por lo que cada
  llamada queda en un pod. Declarar el puerto como `grpc` hace que Envoy analice HTTP/2
y balancee **cada solicitud** (stream) entre endpoints.
- **El nombre del puerto es el interruptor.** El puerto debe llamarse `grpc` / `grpc-*` (o
  `http2`), o incluir `appProtocol: grpc`. Un nombre neutro (`tcp`, sin nombre) elimina
  toda función L7: sin LB por solicitud, sin reintentos, sin timeouts ni métricas gRPC.
- **Las funciones L7 se aplican a gRPC.** Como es HTTP, gRPC obtiene reintentos `http`
  (con `retryOn` compatible con gRPC), `timeout`/`perTryTimeout`, enrutamiento por encabezados,
  inyección de fallos y telemetría enriquecida, exactamente como HTTP simple.
