[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 13 - Solución de referencia (Protección del tráfico perimetral con TLS)

## Paso 1. Habilitar la inyección de sidecar y desplegar la aplicación

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/13/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/ping-pong -n default
```

## Paso 2. Crear un certificado TLS y almacenarlo como un Secret

El Secret de credenciales debe estar en el espacio de nombres de la puerta de enlace de entrada (`istio-system`).

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout myapp.key -out myapp.crt \
  -subj "/CN=myapp.local/O=demo" \
  -addext "subjectAltName=DNS:myapp.local"

kubectl create -n istio-system secret tls myapp-cert \
  --cert=myapp.crt --key=myapp.key
```

## Paso 3. Gateway HTTPS (terminación TLS, modo SIMPLE)

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: myapp-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: myapp-cert   # references the Secret in istio-system
    hosts:
    - "myapp.local"
```

## Paso 4. VirtualService

```yaml
# vs.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - myapp-gateway
  http:
  - route:
    - destination:
        host: ping-pong
        port:
          number: 8080
```

```bash
kubectl apply -f gateway.yaml
kubectl apply -f vs.yaml
```

## Verificar

```bash
# HTTPS terminated at the edge (-k because the cert is self-signed)
curl -sk https://myapp.local:32443/ | grep 'Server Name'

# inspect the served certificate
curl -skv https://myapp.local:32443/ 2>&1 | grep -E 'subject:|issuer:'
```

## (opcional) TLS mutuo en el perímetro (MUTUAL)

Exija a los clientes que presenten un certificado firmado por una CA de confianza:

```bash
# add the CA cert to the same secret (generic) and switch the gateway to MUTUAL
kubectl create -n istio-system secret generic myapp-cert-mtls \
  --from-file=tls.crt=myapp.crt --from-file=tls.key=myapp.key --from-file=ca.crt=ca.crt
```

```yaml
    tls:
      mode: MUTUAL
      credentialName: myapp-cert-mtls
```

Después, los clientes deben enviar `--cert client.crt --key client.key`.
