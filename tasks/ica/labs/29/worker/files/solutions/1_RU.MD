[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 29 - Эталонное решение

Установлен Istio `1.29.1` (HTTPS ingress gateway на NodePort `32443`). PKI
создана заранее:
- сертификат сервера gateway для `myapp.local` + клиентский CA → секрет `myapp-credential`
  (`istio-system`);
- набор клиентских сертификатов → секрет `client-certs` (`app`);
- TLS-сертификат для `passthrough.local` → секрет `backend-tls` (`backend`).

Рабочие нагрузки: `ping-pong` (namespace `app`, с injected sidecar) и TLS-only `secure-backend`
(namespace `backend`, самостоятельно завершает TLS, отвечает `secure-ok`).

## Цель

Настройте ingress gateway с двумя режимами TLS на порту 443, выбираемыми по SNI:
- **MUTUAL** для `myapp.local` - завершить TLS и требовать клиентский сертификат (mTLS на
  границе);
- **PASSTHROUGH** для `passthrough.local` - перенаправить зашифрованный поток на backend,
  который завершает TLS.

## Шаг 1. Gateway с серверами MUTUAL + PASSTHROUGH

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

## Шаг 2. Направьте хост MUTUAL (HTTP после завершения TLS)

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

## Шаг 3. Направьте хост PASSTHROUGH (TLS, по SNI)

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

## Шаг 4. Проверка

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

## Краткий обзор режимов TLS

| Режим | Кто завершает TLS | Клиентский сертификат | Типичное применение |
|---|---|---|---|
| `SIMPLE` (Lab 13) | gateway | нет | стандартный HTTPS ingress |
| `MUTUAL` | gateway | **обязателен** (проверяется по `ca.crt`) | mTLS на границе, B2B/partner APIs |
| `PASSTHROUGH` | backend | н/д на gateway | сквозное шифрование, gateway не может/не должен видеть plaintext |
| `ISTIO_MUTUAL` | gateway (Istio certs) | управляется Istio | внутренний gateway traffic mesh |

## Как это работает

- Один `Gateway` может размещать **несколько серверов на одном порту**; Istio выбирает
  сервер по TLS **SNI** (`myapp.local` или `passthrough.local`).
- **MUTUAL**: gateway представляет свой серверный сертификат и запрашивает клиентский сертификат, проверяя
  его по `ca.crt` внутри `myapp-credential`. После завершения TLS маршрутизация выполняется обычным
  L7 (`http` route).
- **PASSTHROUGH**: gateway не расшифровывает трафик; он маршрутизирует по SNI на L4, используя
  соответствие `VirtualService.tls` + `sniHosts`, и пересылает необработанный TLS на backend, который
  владеет сертификатом и завершает TLS.
