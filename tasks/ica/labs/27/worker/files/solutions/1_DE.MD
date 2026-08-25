[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 27 - Referenzlösung

Istio `1.29.1` ist installiert (Ingress-Gateway auf NodePort `32080`). Die App `ping-pong`
ist im Namespace `app` bereitgestellt und unter `http://myapp.local:32080/` erreichbar.

## Ziel

Hänge einen `EnvoyFilter` mit einem **inline Lua**-HTTP-Filter an das Ingress-Gateway an, der:
- einen Response-Header `x-lua-lab: hello-from-lua` hinzufügt;
- jede Anfrage mit `x-block: yes` mit einem `403` ablehnt.

## Schritt 1. Ausgangszustand

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## Schritt 2. Den Lua-EnvoyFilter anwenden

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

## Schritt 3. Prüfen

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

## Funktionsweise

- **`EnvoyFilter`** patcht die rohe Envoy-Konfiguration, die Istio erzeugt. Hier fügt er den
  integrierten **Lua**-HTTP-Filter (`envoy.filters.http.lua`) in die Filterkette des
  Ingress-Gateways ein, direkt vor dem Router.
- Das Lua-Skript implementiert zwei Lifecycle-Callbacks:
  - `envoy_on_request(request_handle)` - wird für jede Anfrage ausgeführt; kann Header lesen/ändern,
    den Body lesen oder mit `request_handle:respond(...)` frühzeitig antworten.
  - `envoy_on_response(response_handle)` - wird für jede Response ausgeführt; hier fügt es einen Header hinzu.
- `context: GATEWAY` begrenzt den Patch auf das Ingress-Gateway. Verwende `SIDECAR_INBOUND` /
  `SIDECAR_OUTBOUND`, um stattdessen Workload-Sidecars anzusprechen.

## Lua vs. Wasm vs. integrierte CRDs

- **Inline Lua** - die schnellste Möglichkeit, kleine benutzerdefinierte Logik hinzuzufügen: kein Image,
  kein Build, das Skript wird in YAML bearbeitet. Ideal für Header-Anpassungen, einfaches Request-Gating und schnelle Experimente.
- **Wasm** (Lab 23) - für umfangreichere/wiederverwendbare Logik in einer echten Sprache (Rust/Go), versioniert
  und als OCI-Image verteilt, in einer Sandbox ausgeführt.
- **Integrierte CRDs** (`AuthorizationPolicy`, `Telemetry`, ...) - bevorzuge diese immer zuerst;
  greife nur zu Lua/Wasm, wenn sie nicht ausdrücken können, was du benötigst.

> `EnvoyFilter` ist eine Low-Level-, versionssensitive API - Istio warnt davor, dass sich seine Konfiguration
> zwischen Releases ändern kann. Halte solche Patches minimal und teste sie bei Upgrades.
