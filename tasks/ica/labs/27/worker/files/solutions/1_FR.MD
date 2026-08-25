[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 27 - Solution de référence

Istio `1.29.1` est installé (passerelle d'entrée sur NodePort `32080`). L'application `ping-pong`
est déployée dans l'espace de noms `app` et exposée à l'adresse `http://myapp.local:32080/`.

## Objectif

Attachez un `EnvoyFilter` avec un filtre HTTP **Lua intégré** à la passerelle d'entrée qui :
- ajoute un en-tête de réponse `x-lua-lab: hello-from-lua` ;
- rejette toute requête contenant `x-block: yes` avec un code `403`.

## Étape 1. Référence

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## Étape 2. Appliquer le Lua EnvoyFilter

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: lua-edge
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
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.lua
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
            inlineCode: |
              function envoy_on_request(request_handle)
                if request_handle:headers():get("x-block") == "yes" then
                  request_handle:respond(
                    {[":status"] = "403"},
                    "blocked by lua\n")
                end
              end
              function envoy_on_response(response_handle)
                response_handle:headers():add("x-lua-lab", "hello-from-lua")
              end
EOF
```

## Étape 3. Vérifier

```bash
# response header added by Lua
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab
# x-lua-lab: hello-from-lua

# request blocked by Lua
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/
# 403

# normal request still works
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# 200
```

## Fonctionnement

- **`EnvoyFilter`** modifie la configuration Envoy brute générée par Istio. Ici, il insère le
  filtre HTTP **Lua** intégré (`envoy.filters.http.lua`) dans la passerelle d'entrée,
  juste avant le routeur.
- Le script Lua implémente deux rappels de cycle de vie :
  - `envoy_on_request(request_handle)` - s'exécute pour chaque requête ; peut lire ou modifier les en-têtes, lire
    le corps, ou interrompre le traitement avec `request_handle:respond(...)`.
  - `envoy_on_response(response_handle)` - s'exécute pour chaque réponse ; il ajoute ici un en-tête.
- `context: GATEWAY` limite le correctif à la passerelle d'entrée. Utilisez `SIDECAR_INBOUND` /
  `SIDECAR_OUTBOUND` pour cibler plutôt les sidecars de charge de travail.

## Lua vs Wasm vs CRD intégrées

- **Lua intégré** - la manière la plus rapide d'ajouter une petite logique personnalisée : pas d'image, pas de compilation, modifiez le
  script dans YAML. Idéal pour les ajustements d'en-têtes, le filtrage simple des requêtes et les expérimentations rapides.
- **Wasm** (Lab 23) - pour une logique plus lourde ou réutilisable dans un véritable langage (Rust/Go), versionnée
  et distribuée sous forme d'image OCI, exécutée dans un bac à sable.
- **CRD intégrées** (`AuthorizationPolicy`, `Telemetry`, ...) - privilégiez-les toujours en premier ;
  utilisez Lua/Wasm seulement lorsqu'elles ne peuvent pas exprimer ce dont vous avez besoin.

> `EnvoyFilter` est une API bas niveau sensible aux versions - Istio prévient que sa configuration peut
> changer d'une version à l'autre. Gardez ces correctifs minimaux et testez-les lors des mises à niveau.
