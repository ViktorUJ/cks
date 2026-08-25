[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 17 - Referenzlösung

Istio `1.29.1` ist installiert (ingress gateway auf NodePort `32080`). Die Anwendung `ping-pong`
ist im Namespace `app` bereitgestellt und über das ingress gateway unter
`http://myapp.local:32080/` erreichbar.

## Ziel

Wenden Sie mithilfe eines `EnvoyFilter` eine **lokale Ratenbegrenzung** auf das ingress gateway an:
Lassen Sie höchstens 5 Anfragen pro Minute zu und lehnen Sie die übrigen mit HTTP `429` ab.

## Schritt 1. Ausgangszustand

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Schritt 2. Lokale Ratenbegrenzung anwenden (EnvoyFilter)

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

## Schritt 3. Überprüfen

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## Funktionsweise

- **`token_bucket`** - `max_tokens: 5`, `tokens_per_fill: 5`, `fill_interval: 60s`:
  Der Bucket enthält 5 Tokens und wird alle 60 Sekunden auf 5 aufgefüllt. Jede Anfrage
  verbraucht ein Token; wenn der Bucket leer ist, werden Anfragen mit `429` abgelehnt.
- **`filter_enabled` / `filter_enforced`** - der Prozentsatz der Anfragen, für die der Filter
  aktiv ist und tatsächlich durchgesetzt wird (hier beide `100%`).
- **context: GATEWAY** - der Filter wird in den Listener des ingress gateway eingefügt,
  daher gilt die Begrenzung für den gesamten eingehenden Datenverkehr am Rand.

## Lokale vs. globale Ratenbegrenzung

- **Lokale Ratenbegrenzung** (dieses Lab) - jede Envoy-Instanz führt ihren eigenen Token-Bucket.
  Einfach, keine zusätzlichen Komponenten, aber die effektive Begrenzung vervielfacht sich mit der
  Anzahl der Gateway-Replikate.
- **Globale Ratenbegrenzung** - Envoy ruft einen externen Ratenbegrenzungsdienst auf (gestützt durch Redis),
  sodass die Begrenzung von allen Replikaten gemeinsam genutzt wird. Sie verwendet den
  Filter `envoy.filters.http.ratelimit` sowie eine `ConfigMap` mit Deskriptoren und einen
  bereitgestellten ratelimit-Service. Verwenden Sie sie, wenn Sie eine clusterweite, exakte Quote benötigen.
