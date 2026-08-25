[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 17 - Solution de référence

Istio `1.29.1` est installé (passerelle d'entrée sur NodePort `32080`). L'application `ping-pong`
est déployée dans l'espace de noms `app` et exposée via la passerelle d'entrée à l'adresse
`http://myapp.local:32080/`.

## Objectif

Appliquez une **limite de débit locale** sur la passerelle d'entrée à l'aide d'un `EnvoyFilter` : autorisez au
maximum 5 requêtes par minute, rejetez les autres avec HTTP `429`.

## Étape 1. Référence

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Étape 2. Appliquer la limite de débit locale (EnvoyFilter)

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

## Étape 3. Vérifier

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## Fonctionnement

- **`token_bucket`** - `max_tokens: 5`, `tokens_per_fill: 5`, `fill_interval: 60s` :
  le compartiment contient 5 jetons et est rempli de nouveau à 5 toutes les 60 secondes. Chaque requête
  consomme un jeton ; lorsque le compartiment est vide, les requêtes sont rejetées avec `429`.
- **`filter_enabled` / `filter_enforced`** - le pourcentage de requêtes pour lesquelles le filtre est
  actif et réellement appliqué (tous deux à `100%` ici).
- **context: GATEWAY** - le filtre est inséré dans l'écouteur de la passerelle d'entrée,
  donc la limite s'applique à tout le trafic entrant à la périphérie.

## Limitation de débit locale ou globale

- **Limite de débit locale** (ce lab) - chaque instance Envoy conserve son propre compartiment de jetons.
  Simple, sans composants supplémentaires, mais la limite effective est multipliée par le nombre de
  répliques de passerelle.
- **Limite de débit globale** - Envoy appelle un service externe de limitation de débit (s'appuyant sur Redis)
  afin que la limite soit partagée entre toutes les répliques. Elle utilise le filtre
  `envoy.filters.http.ratelimit` ainsi qu'un `ConfigMap` avec des descripteurs et un
  service ratelimit déployé. Utilisez-la lorsque vous avez besoin d'un quota précis à l'échelle du cluster.
