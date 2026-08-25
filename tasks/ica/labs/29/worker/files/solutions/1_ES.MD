[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 29 - Solución de referencia

Istio `1.29.1` está instalado (HTTPS del gateway de entrada en NodePort `32443`). Una PKI está
precreada:
- certificado de servidor del gateway para `myapp.local` + una CA de cliente → secret `myapp-credential`
  (`istio-system`);
- un paquete de certificados de cliente → secret `client-certs` (`app`);
- un certificado TLS para `passthrough.local` → secret `backend-tls` (`backend`).

Cargas de trabajo: `ping-pong` (namespace `app`, inyectado) y un `secure-backend` solo TLS
(namespace `backend`, termina TLS por sí mismo, responde `secure-ok`).

## Objetivo

Configura el gateway de entrada con dos modos TLS en el puerto 443, seleccionados por SNI:
- **MUTUAL** para `myapp.local` - terminar TLS y requerir un certificado de cliente (mTLS en
  el borde);
- **PASSTHROUGH** para `passthrough.local` - reenviar el flujo cifrado al backend, que termina
  TLS.

## Paso 1. Gateway con servidores MUTUAL + PASSTHROUGH

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

## Paso 2. Enrutar el host MUTUAL (HTTP después de la terminación)

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

## Paso 3. Enrutar el host PASSTHROUGH (TLS, mediante SNI)

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

## Paso 4. Verificar

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

## Modos TLS de un vistazo

| Modo | Quién termina TLS | Certificado de cliente | Uso típico |
|---|---|---|---|
| `SIMPLE` (Lab 13) | gateway | no | entrada HTTPS estándar |
| `MUTUAL` | gateway | **obligatorio** (verificado contra `ca.crt`) | mTLS en el borde, API B2B/de socios |
| `PASSTHROUGH` | el backend | no aplicable en el gateway | cifrado de extremo a extremo, el gateway no puede/no debe ver texto sin cifrar |
| `ISTIO_MUTUAL` | gateway (certificados de Istio) | gestionado por Istio | tráfico de gateway interno de la malla |

## Cómo funciona

- Un único `Gateway` puede alojar **varios servidores en el mismo puerto**; Istio selecciona el
  servidor mediante el **SNI** TLS (`myapp.local` frente a `passthrough.local`).
- **MUTUAL**: el gateway presenta su certificado de servidor y solicita un certificado de cliente,
  validándolo contra el `ca.crt` dentro de `myapp-credential`. Después de la terminación, el
  enrutamiento es L7 normal (ruta `http`).
- **PASSTHROUGH**: el gateway no descifra; enruta mediante SNI en L4 usando una coincidencia de
  `VirtualService.tls` + `sniHosts` y reenvía el TLS sin procesar al backend, que posee el
  certificado y termina TLS.
