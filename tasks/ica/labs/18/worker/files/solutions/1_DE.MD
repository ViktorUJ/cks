[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 18 - Referenzlösung

Istio `1.29.1` ist installiert (Ingress-Gateway auf NodePort `32080`), wobei das verteilte
Tracing mit dem Erweiterungsanbieter `zipkin` (`zipkin.istio-system:9411`) verbunden ist. Das
**Jaeger**-Addon ist als Tracing-Backend bereitgestellt. Die Anwendung `ping-pong` ist im
Namespace `app` bereitgestellt und unter `http://myapp.local:32080/` verfügbar. Die
Zugriffsprotokollierung ist standardmäßig **deaktiviert**, und es existiert noch keine
`Telemetry`-Ressource.

## Ziel

Verwende die **Telemetry API**, um:
- die Envoy-Zugriffsprotokollierung für den Namespace `app` zu aktivieren (integrierter Anbieter `envoy`);
- Tracing über den Anbieter `zipkin` mit 100 % Sampling zu aktivieren, damit Traces tatsächlich
  in Jaeger erfasst werden.

## Schritt 1. Bestätige, dass Zugriffsprotokolle AUS sind

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## Schritt 2. Konfiguriere Protokolle + Traces über Telemetry

```bash
cat > telemetry.yaml <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: app-telemetry
  namespace: app
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100.0
EOF

kubectl apply -f telemetry.yaml
```

## Schritt 3. Erzeuge Datenverkehr

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## Schritt 4. Überprüfe die Erfassung

Zugriffsprotokolle (in der Sidecar-Standardausgabe):

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

Traces (in Jaeger, aus dem Cluster heraus abgefragt):

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

Du kannst auch die Jaeger-UI per Port-Forward verfügbar machen:

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## Wohin Protokolle und Traces gehen

| Signal | Anbieter | Ziel |
|---|---|---|
| Zugriffsprotokolle | `envoy` (integriert) | Sidecar-Standardausgabe → `kubectl logs -c istio-proxy` |
| Traces | Erweiterungsanbieter `zipkin` | Jaeger (`zipkin.istio-system:9411`) → Jaeger-UI |

## So funktioniert es

- Die **Telemetry API** (`telemetry.istio.io`) konfiguriert deklarativ Protokolle, Metriken
  und Traces und unterstützt eine Bereichshierarchie: mesh-weit (Root-Namespace) → Namespace →
  Workload (`selector`).
- **`accessLogging.providers.name: envoy`** schreibt Zugriffsprotokolle in die
  Sidecar-Standardausgabe.
- **`tracing.providers.name: zipkin`** verweist auf den Erweiterungsanbieter `zipkin`, der in
  `meshConfig.extensionProviders` deklariert ist und Spans an Jaeger weiterleitet.
  Ohne eine Anbieterreferenz hätte die Sampling-Richtlinie keinen Ort, an den sie Spans senden könnte.
- **`randomSamplingPercentage: 100`** zeichnet jede Anfrage auf (verwende in der Produktion einen
  niedrigen Wert, um den Overhead zu begrenzen).
