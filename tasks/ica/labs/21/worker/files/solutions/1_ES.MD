[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 21 - Solución de referencia

Istio `1.29.1` está instalado. Se implementan dos espacios de nombres:
- `app` con `ping-pong` (sidecar inyectado);
- `other` con `backend` (sidecar inyectado).

De forma predeterminada, cada sidecar recibe la configuración de Envoy para **todos** los servicios de la malla, por lo que el
proxy de `app` también incluye un cluster para `backend.other` aunque nunca se comunica con él.

## Objetivo

Limitar los proxies del espacio de nombres `app` con un recurso `Sidecar` para que solo reciban configuración
para su propio espacio de nombres e `istio-system`.

## Paso 1. Observar la configuración predeterminada (sin limitar)

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## Paso 2. Aplicar un recurso Sidecar para limitar el egress

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

- `./*` - cada servicio en el espacio de nombres **local** (`app`);
- `istio-system/*` - el espacio de nombres del plano de control (necesario para telemetría, etc.).

Un `Sidecar` llamado `default` sin `workloadSelector` se aplica a todas las cargas de trabajo del
espacio de nombres.

## Paso 3. Verificar que la configuración se redujo

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## Cómo funciona y por qué importa

- El recurso **`Sidecar`** controla el alcance de la configuración que istiod envía a un
  proxy. `egress.hosts` incluye en una lista de permitidos los servicios que el proxy conoce.
- De forma predeterminada, la malla es "full mesh": cada proxy conoce cada servicio. En un clúster
  grande (miles de servicios), eso implica configuraciones Envoy enormes, alto consumo de memoria por pod
y una carga elevada de CPU de istiod en cada cambio.
- Limitar los proxies con recursos `Sidecar` es la forma estándar de hacer que Istio escale:
  configuraciones más pequeñas, envíos más rápidos, menor carga de istiod y límites de egress más estrictos.
- `outboundTrafficPolicy` dentro de `Sidecar` puede además establecer `REGISTRY_ONLY` por
  espacio de nombres para bloquear el egress no declarado.

> Nota: limitar se refiere a la *distribución de configuración*, no a la autorización. Para prohibir realmente
> llamadas, use `AuthorizationPolicy` (Laboratorio 04) u `outboundTrafficPolicy: REGISTRY_ONLY`.