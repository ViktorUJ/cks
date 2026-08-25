[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 22 - Referenzlösung

Istio `1.29.1` ist installiert. Ein „externes“, **ausschließlich HTTPS-basiertes** Backend ist im
Namespace `external` bereitgestellt (kein Sidecar): nginx terminiert TLS auf Port `8443` und der Service
`httpsvc` stellt es auf dem Klartextport `80` bereit (`targetPort: 8443`). Ein Client innerhalb des Meshs
`app-client` läuft im Namespace `app`.

## Ziel

Das Mesh soll TLS **initiieren** zur externen Anwendung: Die App spricht unverschlüsseltes HTTP mit
`httpsvc.external:80`, und ihr Sidecar rüstet die Verbindung auf TLS hoch, bevor sie das
Backend erreicht.

## Schritt 1. Den Fehler ohne TLS-Initiierung beobachten

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> 400 : plaintext hit the TLS-only port
```

## Schritt 2. TLS-Initiierung mit einer DestinationRule konfigurieren

Das Backend verwendet ein selbstsigniertes Zertifikat, daher überspringen wir die Prüfung des Upstreams mit
`insecureSkipVerify: true`. In der Produktion würdest du stattdessen `caCertificates` auf die CA setzen, die
den Upstream signiert hat.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: httpsvc-tls-origination
  namespace: app
spec:
  host: httpsvc.external.svc.cluster.local
  trafficPolicy:
    portLevelSettings:
    - port:
        number: 80
      tls:
        mode: SIMPLE
        insecureSkipVerify: true
EOF
```

## Schritt 3. Überprüfen

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -w "\nHTTP %{http_code}\n" http://httpsvc.external.svc.cluster.local/
# -> secure-ok
#    HTTP 200
```

## Funktionsweise

- Der Client sendet unverschlüsseltes **HTTP** an `httpsvc.external:80`. Keine Änderungen am Anwendungscode,
  keine Zertifikate, die in der App verwaltet werden müssen.
- Die `DestinationRule` mit `tls.mode: SIMPLE` auf Port 80 weist den clientseitigen Envoy an,
  TLS **zum Upstream zu initiieren** (dem `targetPort: 8443` des Backends).
- Das Backend erhält eine korrekte TLS-Verbindung und gibt `200` zurück.
- In Istio **prüft** `SIMPLE` standardmäßig das Upstream-Zertifikat. Unser Backend verwendet ein
  selbstsigniertes Zertifikat, daher setzen wir `insecureSkipVerify: true`. In der Produktion würdest du stattdessen
  `caCertificates` (und optional `subjectAltNames`) setzen, um den Upstream zu prüfen, oder `MUTUAL` für
  Clientzertifikat-Authentifizierung verwenden.

## Warum TLS im Mesh initiieren

- Anwendungen können einfach bleiben (unverschlüsseltes HTTP), während sämtliches TLS zu externen/älteren Anwendungen
  einheitlich vom Mesh verarbeitet wird.
- In Kombination mit einem **Egress-Gateway** (Lab 05) kann die Initiierung auf einem dedizierten
  Knoten zentralisiert werden, sodass sämtliches ausgehendes TLS den Cluster über einen überprüften, richtlinien-
  gesteuerten Hop verlässt.
