[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 13 - Эталонное решение (Защита периферийного трафика с помощью TLS)

## Шаг 1. Включите инъекцию sidecar и разверните приложение

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/13/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/ping-pong -n default
```

## Шаг 2. Создайте TLS-сертификат и сохраните его как Secret

Secret с учетными данными должен находиться в пространстве имен ingress gateway (`istio-system`).

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout myapp.key -out myapp.crt \
  -subj "/CN=myapp.local/O=demo" \
  -addext "subjectAltName=DNS:myapp.local"

kubectl create -n istio-system secret tls myapp-cert \
  --cert=myapp.crt --key=myapp.key
```

## Шаг 3. HTTPS Gateway (терминация TLS, режим SIMPLE)

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

## Шаг 4. VirtualService

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

## Проверка

```bash
# HTTPS terminated at the edge (-k because the cert is self-signed)
curl -sk https://myapp.local:32443/ | grep 'Server Name'

# inspect the served certificate
curl -skv https://myapp.local:32443/ 2>&1 | grep -E 'subject:|issuer:'
```

## (необязательно) Взаимный TLS на периферии (MUTUAL)

Потребуйте от клиентов предоставить сертификат, подписанный доверенным CA:

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

Затем клиенты должны передавать `--cert client.crt --key client.key`.
