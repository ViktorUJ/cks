[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 28 - Referenzlösung

Istio `1.29.1` ist mit einem festen TCP-NodePort `31400` am Ingress-Gateway installiert. Die
App `tcp-echo` wird im Namespace `app` in zwei Versionen bereitgestellt:
- **v1** antwortet mit dem Präfix `one`;
- **v2** antwortet mit dem Präfix `two`.

Beide lauschen auf dem reinen TCP-Port `9000` (nicht HTTP).

## Ziel

Leite einen reinen **TCP**-Dienst über das Ingress-Gateway weiter, indem du ein `Gateway` mit
einem `TCP`-Listener und einen `VirtualService` mit einer `tcp`-Route verwendest (gewichtete
Verteilung zwischen v1 und v2).

## Schritt 1. Gateway mit einem TCP-Listener

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: tcp-echo-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 31400
        name: tcp
        protocol: TCP
      hosts:
        - "*"
EOF
```

## Schritt 2. DestinationRule mit Subsets

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tcp-echo
  namespace: app
spec:
  host: tcp-echo
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

## Schritt 3. VirtualService mit einer TCP-Route

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tcp-echo
  namespace: app
spec:
  hosts:
    - "*"
  gateways:
    - tcp-echo-gateway
  tcp:
    - match:
        - port: 31400
      route:
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v1
          weight: 80
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v2
          weight: 20
EOF
```

## Schritt 4. Überprüfen

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

(Falls `nc` installiert ist: `echo hello | nc myapp.local 31400`.)

## Funktionsweise

- **TCP-Routing** arbeitet auf Layer 4: Es gibt keinen HTTP-Host/Pfad/Header, daher basiert
  das Routing auf dem **Listener-Port** (`match.port`). Ein `Gateway`-Server mit
  `protocol: TCP` veranlasst Envoy, einen reinen TCP-Listener zu öffnen; die
  `VirtualService.tcp`-Route leitet die Verbindung an das gewählte Backend-Subset weiter.
- **Portbenennung ist wichtig**: Der Dienst-/Gateway-Port muss `tcp` (oder `tcp-*`) heißen. Istio
  verwendet das Präfix des Portnamens zur Erkennung des Protokolls; ein Name ohne Präfix oder
  mit `http-*` würde Istio veranlassen, ihn als HTTP zu behandeln, und das reine Protokoll
  würde nicht funktionieren.
- Gewichtetes TCP teilt *Verbindungen* (nicht Requests) auf die Subsets auf - jede neue
  TCP-Verbindung wird gemäß der Gewichtung geroutet.
- L7-Funktionen (Retries, Header-Routing, Fehlerinjektion) gelten **nicht** für TCP-Routen -
  nur Richtlinien auf Verbindungsebene (Connection Pool, Timeouts) über `DestinationRule`.

## Verwandte Protokolle

- **MongoDB/MySQL/Redis** - benenne den Port `mongo-*` / `mysql-*` / `redis-*`, damit Envoy
  den richtigen Protokollparser anwendet; das Routing verwendet weiterhin `tcp`-Routen.
- **WebSocket** - obwohl es langlebig ist, läuft es über HTTP `Upgrade`, verwende daher normale
  `http`-Routen und `http-*`-Portnamen, nicht TCP.
