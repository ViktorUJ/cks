# ping_pong_front

<p align="center">
    <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>

A lightweight **HTTP reverse proxy** written in Go designed to **emulate frontend service behavior** in Kubernetes/Istio environments. Its primary use case is testing **Istio retry policies** and **traffic management scenarios** — specifically situations where a backend service becomes unavailable and Istio must perform retries on behalf of the frontend.

The service forwards incoming requests to a configurable backend server — preserving all **headers, query parameters, and request body** — and returns the backend's response enriched with **proxy metadata**: backend status code and response time. Because it transparently propagates backend error codes (5xx, timeouts), Istio can observe real failure conditions and trigger retry logic exactly as it would with a real frontend service.

## Table of Contents
- [How It Works](#how-it-works)
- [Istio Use Cases](#istio-use-cases)
- [Usage Scenarios](#usage-scenarios)
- [Run](#run)
  - [Docker](#run-docker-container)
  - [Kubernetes](#run-in-kubernetes)
  - [Compilation from Source Code](#compilation-from-source-code)
- [Configuration](#configuration)
- [Response Format](#response-format)
- [API](#api)

---

## How It Works

```
Client  →  ping_pong_front  →  Backend (BACKEND_URL)
                ↑
        copies all headers,
        query params, body
        measures response time
        returns backend body +
        proxy info block
```

Every request received by `ping_pong_front` is forwarded to `BACKEND_URL` with:
- all original headers (including custom ones)
- original HTTP method
- original path and query string
- original request body
- added `X-Forwarded-For` header with the client IP

The response to the client includes:
- all headers from the backend
- `X-Backend-Status-Code` header
- `X-Backend-Response-Time` header
- a proxy info block prepended to the backend body

---

## Istio Use Cases

`ping_pong_front` acts as a real frontend that calls a backend through the Istio service mesh. This makes it ideal for testing Istio traffic management features without writing custom application code.

### Testing Istio retries on backend failure

Deploy `ping_pong_front` as the frontend and `ping_pong` as the backend. Configure Istio `VirtualService` with retry policy, then simulate backend failures (stop pods, inject faults) and observe that Istio retries the requests transparently:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: backend
spec:
  hosts:
    - backend-svc
  http:
    - retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure
      route:
        - destination:
            host: backend-svc
```

Because `ping_pong_front` propagates the real backend status code (`X-Backend-Status-Code`) and response time (`X-Backend-Response-Time`), you can clearly see in the response whether Istio retried and which attempt succeeded.

### Typical test scenarios

| Scenario | How to simulate |
|---|---|
| Backend pod crash | `kubectl delete pod <backend-pod>` |
| Backend overloaded (503) | Set `MAX_RESPONSE_WORKER=1` on `ping_pong` backend |
| Backend slow response / timeout | Set `RESPONSE_DELAY=6000` on backend, `BACKEND_TIMEOUT=5s` on front |
| Istio fault injection | Add `HTTPFaultInjection` to backend `VirtualService` |

---

## Usage Scenarios

### Basic proxy to a backend service

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080
```

### Custom listen port and backend timeout

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080 \
  --env SRV_PORT=9000 \
  --env BACKEND_TIMEOUT=10s
```

### Use together with ping_pong as backend

```bash
# start backend
kubectl run backend --image viktoruj/ping_pong --env SRV_PORT=8081

# start proxy in front
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://backend:8081 \
  --env SRV_PORT=8080
```

### Disable stdout logging

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080 \
  --env ENABLE_OUTPUT=false
```

---

## Run

### Run Docker container

```bash
docker run -d -p 8080:8080 \
  -e BACKEND_URL=http://my-backend:8081 \
  viktoruj/ping_pong_front
```

### Run in Kubernetes

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080
```

### Compilation from Source Code

```bash
cd docker/ping_pong_front/app
go mod tidy
go run app.go
# or build binary
go build -o ping_pong_front app.go
```

Run with env vars:

```bash
BACKEND_URL=http://localhost:8081 SRV_PORT=8080 go run app.go
```

---

## Configuration

| ENV VAR           | Default                  | Description                                                                 |
|-------------------|--------------------------|-----------------------------------------------------------------------------|
| `BACKEND_URL`     | `http://localhost:8081`  | Target backend URL. All requests are forwarded here.                        |
| `SRV_PORT`        | `8080`                   | Port the proxy listens on.                                                  |
| `BACKEND_TIMEOUT` | `5s`                     | Timeout for backend requests. Accepts Go duration format: `5s`, `500ms`, `1m30s`. |
| `ENABLE_OUTPUT`   | `true`                   | Log requests to stdout.                                                     |

---

## Response Format

Each response contains a proxy info block followed by the full backend response body:

```
--- Proxy Info ---
Backend URL      : http://my-backend:8081/some/path?q=1
Backend Status   : 200
Backend Response Time: 42.3ms
--- Backend Response ---
<full backend response body>
```

Response headers also include:

| Header                    | Description                          |
|---------------------------|--------------------------------------|
| `X-Backend-Status-Code`   | HTTP status code returned by backend |
| `X-Backend-Response-Time` | Time taken by backend to respond     |

### Example

```bash
curl -v http://localhost:8080/test?foo=bar -H "X-My-Header: hello"
```

```
< HTTP/1.1 200 OK
< X-Backend-Status-Code: 200
< X-Backend-Response-Time: 3.812ms

--- Proxy Info ---
Backend URL      : http://localhost:8081/test?foo=bar
Backend Status   : 200
Backend Response Time: 3.812ms
--- Backend Response ---
Server Name: ping_pong_server
URL: http://localhost:8081/test?foo=bar
...
```

---

## API

| Path       | Description                        |
|------------|------------------------------------|
| `/healthz` | Health check, returns `ok`         |
| `/`        | Proxy — forwards request to backend |

### Health check

```bash
curl http://localhost:8080/healthz
# ok
```
