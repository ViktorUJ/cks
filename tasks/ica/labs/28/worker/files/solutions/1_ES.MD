[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 28 - Solución de referencia

Istio `1.29.1` está instalado con un TCP NodePort fijo `31400` en el gateway de entrada. La
aplicación `tcp-echo` se despliega en el espacio de nombres `app` en dos versiones:
- **v1** responde con el prefijo `one`;
- **v2** responde con el prefijo `two`.

Ambas escuchan en el puerto TCP sin procesar `9000` (no HTTP).

## Objetivo

Enrutar un servicio **TCP** sin procesar a través del gateway de entrada usando un `Gateway` con un
listener `TCP` y un `VirtualService` con una ruta `tcp` (ponderada entre v1 y v2).

## Paso 1. Gateway con un listener TCP

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

## Paso 2. DestinationRule con subconjuntos

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

## Paso 3. VirtualService con una ruta TCP

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

## Paso 4. Verificar

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

(Si `nc` está instalado: `echo hello | nc myapp.local 31400`.)

## Cómo funciona

- El **enrutamiento TCP** opera en la Capa 4: no hay host/ruta/cabecera HTTP, por lo que el enrutamiento se basa
  en el **puerto del listener** (`match.port`). Un servidor `Gateway` con `protocol: TCP` hace que
  Envoy abra un listener TCP simple; la ruta `VirtualService.tcp` reenvía la conexión
  al subconjunto de backend elegido.
- **El nombre del puerto importa**: el puerto de servicio/gateway debe llamarse `tcp` (o `tcp-*`). Istio
  usa el prefijo del nombre de puerto para detectar el protocolo; un nombre sin prefijo o `http-*`
  haría que Istio lo tratara como HTTP y el protocolo sin procesar fallaría.
- **TCP ponderado** divide las *conexiones* (no las solicitudes) entre subconjuntos - cada nueva conexión TCP
  se enruta según el peso.
- Las funcionalidades L7 (reintentos, enrutamiento por cabecera, inyección de fallos) **no** se aplican a las rutas TCP -
  solo las políticas a nivel de conexión (grupo de conexiones, tiempos de espera) mediante `DestinationRule`.

## Protocolos relacionados

- **MongoDB/MySQL/Redis** - nombre el puerto `mongo-*` / `mysql-*` / `redis-*` para que Envoy
  aplique el analizador de protocolo correcto; el enrutamiento sigue usando rutas `tcp`.
- **WebSocket** - aunque es de larga duración, se ejecuta sobre HTTP `Upgrade`, así que use rutas
  `http` normales y nombres de puerto `http-*`, no TCP.
