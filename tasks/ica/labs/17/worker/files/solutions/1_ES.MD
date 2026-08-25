[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 17 - Solución de referencia

Istio `1.29.1` está instalado (ingress gateway en NodePort `32080`). La aplicación `ping-pong`
está desplegada en el namespace `app` y expuesta a través del ingress gateway en
`http://myapp.local:32080/`.

## Objetivo

Aplicar un **límite de tasa local** en el ingress gateway mediante un `EnvoyFilter`: permitir como
máximo 5 solicitudes por minuto y rechazar el resto con HTTP `429`.

## Paso 1. Estado inicial

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Paso 2. Aplicar el límite de tasa local (EnvoyFilter)

```bash
cat > ratelimit.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingress-local-rate-limit
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            value:
              stat_prefix: http_local_rate_limiter
              token_bucket:
                max_tokens: 5
                tokens_per_fill: 5
                fill_interval: 60s
              filter_enabled:
                runtime_key: local_rate_limit_enabled
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              filter_enforced:
                runtime_key: local_rate_limit_enforced
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              response_headers_to_add:
                - append_action: OVERWRITE_IF_EXISTS_OR_ADD
                  header:
                    key: x-local-rate-limit
                    value: "true"
EOF

kubectl apply -f ratelimit.yaml
```

## Paso 3. Verificar

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## Cómo funciona

- **`token_bucket`** - `max_tokens: 5`, `tokens_per_fill: 5`, `fill_interval: 60s`:
  el bucket contiene 5 tokens y se rellena hasta 5 cada 60 segundos. Cada solicitud
  consume un token; cuando el bucket está vacío, las solicitudes se rechazan con `429`.
- **`filter_enabled` / `filter_enforced`** - el porcentaje de solicitudes en las que el filtro
  está activo y se aplica realmente (ambos al `100%` aquí).
- **context: GATEWAY** - el filtro se inserta en el listener del ingress gateway, por lo que el
  límite se aplica a todo el tráfico entrante en el borde.

## Limitación de tasa local frente a global

- **Límite de tasa local** (este lab) - cada instancia de Envoy mantiene su propio token bucket.
  Es sencillo y no requiere componentes adicionales, pero el límite efectivo se multiplica por el
  número de réplicas del gateway.
- **Límite de tasa global** - Envoy llama a un servicio externo de límite de tasa (respaldado por
  Redis), por lo que el límite se comparte entre todas las réplicas. Usa el filtro
  `envoy.filters.http.ratelimit` más un `ConfigMap` con descriptores y un servicio ratelimit
  desplegado. Úsalo cuando necesites una cuota exacta para todo el clúster.
