[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 23 - Referenzlösung

Istio `1.29.1` ist installiert (Ingress-Gateway auf NodePort `32080`). Die App `ping-pong`
ist im Namespace `app` bereitgestellt und unter `http://myapp.local:32080/` verfügbar.

## Ziel

Erweitere die Envoy-Datenebene mit einem **WebAssembly**-Modul: Lade die Community-
`basic_auth`-Wasm-Erweiterung auf dem Ingress-Gateway, sodass Anfragen HTTP Basic Auth benötigen.

> Istio `1.29` verwendet die `WasmPlugin`-API (`extensions.istio.io/v1alpha1`). In `1.30+`
> wird diese durch die `TrafficExtension`-API ersetzt.

## Schritt 1. Ausgangszustand (keine Authentifizierung erforderlich)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Schritt 2. Das WasmPlugin anwenden

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

Der Istio-Agent auf dem Ingress-Gateway lädt das OCI-Wasm-Image herunter, speichert es lokal im Cache
und fügt es als HTTP-Filter ein. Warte einige Sekunden.

## Schritt 3. Überprüfen

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Funktionsweise

- **WebAssembly (Wasm)** ermöglicht es dir, benutzerdefinierte Logik zu Envoy hinzuzufügen, ohne den Proxy neu zu bauen,
  und sie zur Laufzeit dynamisch zu laden.
- **`url: oci://...`** - das Modul wird als OCI-Artefakt ausgeliefert; der Istio-Agent lädt es herunter und
  speichert es im Cache. Du kannst auch `file://` (im Image enthalten) oder `http(s)://` verwenden.
- **`phase: AUTHN`** platziert den Filter früh in der Kette (vor Routing/Authz).
- **`selector`** begrenzt das Plugin anhand von Labels auf Workloads (hier das Ingress-Gateway). Ein
  WasmPlugin in `istio-system` mit einem Gateway-Selektor betrifft nur das Gateway.
- **`pluginConfig`** wird an das Modul übergeben. Das Modul `basic_auth` liest
  `basic_auth_rules` (Pfadpräfix, Methoden und akzeptierte Anmeldedaten).

## Wann Wasm verwendet werden sollte

- Benutzerdefinierte Authentifizierung, Header-Anreicherung, Anfragevalidierung oder Protokolllogik, die Istios
  integrierte CRDs (`AuthorizationPolicy`, `EnvoyFilter`) nicht ausdrücken können.
- Bevorzuge zuerst integrierte APIs; verwende Wasm, wenn du tatsächlich benutzerdefinierten Code in der Datenebene benötigst.
  Beachte die betrieblichen Kosten: Modulverteilung, Versionierung und den Laufzeitabruf
  (`failStrategy` steuert das Verhalten, wenn der Download fehlschlägt).