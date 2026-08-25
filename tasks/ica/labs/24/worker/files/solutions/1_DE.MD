[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 24 - Referenzlösung

Istio `1.29.1` ist im **ambient**-Modus (istiod + istio-cni + ztunnel) installiert. Der
Namespace `app` ist für ambient registriert (`istio.io/dataplane-mode: ambient`) und führt
`ping-pong` sowie einen `app-client` aus - beide **ohne** Sidecars. `istioctl` ist auf
dem Worker-PC verfügbar.

## Hintergrund

- **ztunnel** gibt jedem ambient-Workload L4-mTLS und eine Identität, aber es **versteht**
  kein HTTP. Daher funktionieren L4-Richtlinien (Erlauben/Verweigern nach Identität/Port), aber L7-Regeln
  (HTTP-Methoden, Pfade, Header) nicht.
- Zur Durchsetzung einer **L7**-Richtlinie fügen Sie einen **Waypoint-Proxy** hinzu - einen Envoy pro Namespace (oder
  pro Service), durch den ambient-Datenverkehr zur L7-Verarbeitung geroutet wird.

## Ziel

Fügen Sie dem Namespace `app` einen Waypoint und eine L7-`AuthorizationPolicy` hinzu, die nur
`GET`-Anfragen an `ping-pong` erlaubt (alles andere → `403`).

## Schritt 1. Einen Waypoint bereitstellen

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` versieht den Namespace mit dem Label (`istio.io/use-waypoint: waypoint`), sodass Datenverkehr
zu Services in `app` über den Waypoint geroutet wird.

## Schritt 2. Eine L7 AuthorizationPolicy anwenden

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

Eine `ALLOW`-Richtlinie verweigert standardmäßig alles, worauf sie nicht zutrifft, daher wird nur `GET`
zugelassen; andere Methoden erhalten `403`.

## Schritt 3. Überprüfen

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## So funktioniert es

- **Sidecar-loses L4 (ztunnel)** verarbeitet mTLS und Identität für den gesamten Namespace ohne
  Proxy pro Pod. Es ist kostengünstig und im ambient-Modus immer aktiviert.
- **Waypoint (L7)** wird nur dort hinzugefügt, wo Sie Funktionen auf HTTP-Ebene benötigen: L7-Autorisierung,
  Routing, Wiederholungen, Traffic-Splitting. Sie benötigen einen Envoy nur für diese Services.
- Die `AuthorizationPolicy` referenziert mit `targetRefs` das Waypoint-`Gateway`, daher wird sie beim
  L7-Hop durchgesetzt. Dieselbe Richtlinie funktioniert auch, wenn sie an einen Sidecar/Ingress angehängt ist - ambient verschiebt lediglich den
  L7-Durchsetzungspunkt zum Waypoint.
- Dieses geschichtete Modell (ztunnel für L4 überall, Waypoint für L7, wo nötig) ist die zentrale
  Idee von ambient: geringere Basiskosten als Sidecars, L7 nach Bedarf.

## Weiterführend

Labor 09 behandelt die ambient-Grundlagen (ztunnel L4). Labor 04 behandelt dieselbe `AuthorizationPolicy`
im Sidecar-Modell.
