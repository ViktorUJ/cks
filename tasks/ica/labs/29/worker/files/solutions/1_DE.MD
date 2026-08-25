[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 29 - Referenzlösung

Istio `1.29.1` ist installiert (Ingress-Gateway HTTPS auf NodePort `32443`). Eine PKI ist
vorab erstellt:
- Gateway-Serverzertifikat für `myapp.local` + eine Client-CA → secret `myapp-credential`
  (`istio-system`);
- ein Client-Zertifikatsbündel → secret `client-certs` (`app`);
- ein TLS-Zertifikat für `passthrough.local` → secret `backend-tls` (`backend`).

Arbeitslasten: `ping-pong` (Namespace `app`, injiziert) und ein reines TLS-Backend `secure-backend`
(Namespace `backend`, terminiert TLS selbst, antwortet `secure-ok`).

## Ziel

Konfiguriere das Ingress-Gateway mit zwei TLS-Modi auf Port 443, ausgewählt per SNI:
- **MUTUAL** für `myapp.local` - TLS terminieren und ein Client-Zertifikat verlangen (mTLS am
  Rand);
- **PASSTHROUGH** für `passthrough.local` - den verschlüsselten Stream an das Backend
  weiterleiten, das TLS terminiert.

## Schritt 1. Gateway mit MUTUAL- + PASSTHROUGH-Servern

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-mutual
        protocol: HTTPS
      tls:
        mode: MUTUAL
        credentialName: myapp-credential
      hosts:
        - "myapp.local"
    - port:
        number: 443
        name: https-passthrough
        protocol: HTTPS
      tls:
        mode: PASSTHROUGH
      hosts:
        - "passthrough.local"
EOF
```

## Schritt 2. Den MUTUAL-Host routen (HTTP nach der Terminierung)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
  namespace: app
spec:
  hosts:
    - "myapp.local"
  gateways:
    - edge-gateway
  http:
    - route:
        - destination:
            host: ping-pong
            port:
              number: 8080
EOF
```

## Schritt 3. Den PASSTHROUGH-Host routen (TLS, per SNI)

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: app
spec:
  hosts:
    - "passthrough.local"
  gateways:
    - edge-gateway
  tls:
    - match:
        - sniHosts:
            - "passthrough.local"
      route:
        - destination:
            host: secure-backend.backend.svc.cluster.local
            port:
              number: 443
EOF
```

## Schritt 4. Verifizieren

```bash
# MUTUAL - without a client cert the handshake is rejected
curl -sk -o /dev/null -w "%{http_code}\n" https://myapp.local:32443/        # not 200

# MUTUAL - with the client cert it succeeds
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.crt}' | base64 -d > /tmp/c.crt
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.key}' | base64 -d > /tmp/c.key
curl -sk --cert /tmp/c.crt --key /tmp/c.key https://myapp.local:32443/      # 200

# PASSTHROUGH - TLS terminates at the backend
curl -sk https://passthrough.local:32443/                                   # secure-ok
```

## TLS-Modi auf einen Blick

| Modus | Wer terminiert TLS | Client-Zertifikat | Typischer Einsatz |
|---|---|---|---|
| `SIMPLE` (Labor 13) | Gateway | nein | Standard-HTTPS-Ingress |
| `MUTUAL` | Gateway | **erforderlich** (gegen `ca.crt` verifiziert) | mTLS am Rand, B2B-/Partner-APIs |
| `PASSTHROUGH` | das Backend | n/v am Gateway | Ende-zu-Ende-Verschlüsselung, Gateway kann/sollte Klartext nicht sehen |
| `ISTIO_MUTUAL` | Gateway (Istio-Zertifikate) | von Istio verwaltet | Mesh-interner Gateway-Verkehr |

## Funktionsweise

- Ein einzelnes `Gateway` kann **mehrere Server auf demselben Port** hosten; Istio wählt den
  Server anhand des TLS-**SNI** (`myapp.local` gegenüber `passthrough.local`) aus.
- **MUTUAL**: Das Gateway präsentiert sein Serverzertifikat und fordert ein Client-Zertifikat
  an, das gegen die `ca.crt` in `myapp-credential` validiert wird. Nach der Terminierung ist
  das Routing normales L7-(`http`-)Routing.
- **PASSTHROUGH**: Das Gateway entschlüsselt nicht; es routet per SNI auf L4 mithilfe eines
  `VirtualService.tls`- + `sniHosts`-Matches und leitet das rohe TLS an das Backend weiter,
  das das Zertifikat besitzt und TLS terminiert.
