[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 32 - Referenzlösung

Istio `1.29.1` (Standardprofil) ist installiert. Der Namespace `app` (mit
aktiviertem istio-injection) führt das Image `viktoruj/ping_pong` aus, das gRPC
verwendet (`PingPong.Echo` gibt den Hostnamen des bedienenden Pod zurück):

- **grpc-server** - der gRPC Echo/Health-Server, **3 Replikate** (gRPC auf Port
  `8079`);
- **grpc-client** - dasselbe Image, das zum Erzeugen von gRPC-Last verwendet
  wird (`/app -grpc-client ...`).

Der **Service** `grpc-server` wird mit einem **falsch benannten** Port (`tcp`)
erstellt. Daher behandelt Istio Port `8079` als reines L4 TCP: Die einzelne
langlebige HTTP/2-gRPC-Verbindung wird an einen Pod gebunden, sodass der Client
nur **einen** unterschiedlichen Server sieht und kein Load Balancing pro Anfrage
stattfindet.

## Ziel

1. Istio soll den gRPC-Port erkennen, damit es ein Load Balancing **pro
   Anfrage** (HTTP/2) über alle Backend-Pods hinweg ausführt.
2. Einen `VirtualService` für `grpc-server` mit gRPC-**Wiederholungsversuchen**
   und einem **Timeout** hinzufügen.

## Schritt 1. Benennung des Service-Ports korrigieren

gRPC ist HTTP/2, kein reines TCP. Istio erkennt das Protokoll anhand des
**Namenspräfixes** des Ports (`grpc`, `http2`, ...) oder des expliziten Feldes
`appProtocol`. Benennen Sie den Port in `grpc` um (und/oder setzen Sie
`appProtocol: grpc`):

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

Entsprechendes vollständiges Manifest:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

Sobald Istio einen HTTP/2-(gRPC)-Cluster erkennt, verteilt Envoy **jede
Anfrage** innerhalb der gemeinsamen Verbindung auf alle Endpoints. Es ist keine
zusätzliche Konfiguration erforderlich.

## Schritt 2. VirtualService mit gRPC-Wiederholungsversuchen + Timeout

gRPC basiert auf HTTP und wird daher über den Block `http` konfiguriert (nicht
über `tcp`): Wiederholungsversuche, Timeouts, Header-Routing und Load Balancing
pro Anfrage finden alle Anwendung.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` verwendet gRPC-fähige Bedingungen: `unavailable`, `cancelled`,
  `deadline-exceeded` werden gRPC-Statuscodes zugeordnet; `refused-stream` und
  `connect-failure` decken Transportprobleme ab.
- `timeout` begrenzt die gesamte Anfrage; `perTryTimeout` begrenzt jeden
  Versuch.

## Schritt 3. (optional) Die Load-Balancing-Richtlinie festlegen

Load Balancing pro Anfrage ist standardmäßig aktiv, sobald der Port gRPC ist.
Um die Richtlinie explizit festzulegen:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## Schritt 4. Überprüfen

Erzeugen Sie gRPC-Last vom Client aus und bestätigen Sie, dass Anfragen **alle
drei** Backend-Pods erreichen (Load Balancing pro Anfrage):

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

Erwartetes Ende:

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` beweist, dass die Anfragen pro Anfrage verteilt werden.
Vor der Korrektur (Port mit dem Namen `tcp`) meldet derselbe Befehl `distinct
servers: 1`.

## Warum das funktioniert

- **gRPC ist HTTP/2, nicht TCP.** Bei einer L4/TCP-Sicht führt Envoy Load
  Balancing für *Verbindungen* durch: Ein gRPC-Client behält eine einzelne
  langlebige Verbindung bei, sodass jeder Aufruf bei einem Pod verbleibt. Die
  Deklaration des Ports als `grpc` veranlasst Envoy, HTTP/2 zu analysieren und
  **jede Anfrage** (jeden Stream) auf die Endpoints zu verteilen.
- **Die Portbenennung ist der Schalter.** Der Port muss `grpc` / `grpc-*` (oder
  `http2`) heißen oder `appProtocol: grpc` enthalten. Ein neutraler Name
  (`tcp`, unbenannt) deaktiviert jede L7-Funktion: kein Load Balancing pro
  Anfrage, keine Wiederholungsversuche, keine Timeouts, keine gRPC-Metriken.
- **L7-Funktionen gelten für gRPC.** Da es HTTP ist, erhält gRPC `http`-
  Wiederholungsversuche (mit gRPC-fähigem `retryOn`), `timeout`/
  `perTryTimeout`, Header-Routing, Fault Injection und umfassende Telemetrie,
  genau wie reines HTTP.
