# Lab 23 — WasmPlugin: extend the data plane with WebAssembly

## Overview

Sometimes Istio's built-in CRDs (`AuthorizationPolicy`, `EnvoyFilter`) are not enough and
you need custom logic right in the data plane. **WebAssembly (Wasm)** makes this possible:
you write (or reuse) a module and Envoy loads it dynamically at runtime, without
rebuilding the proxy.

In this lab you load the community **`basic_auth`** module on the ingress gateway so
requests require HTTP Basic authentication.

> Istio `1.29` uses the `WasmPlugin` API (`extensions.istio.io/v1alpha1`). In `1.30+` it
> is being replaced by the `TrafficExtension` API.

Istio is already installed (ingress gateway on NodePort `32080`), the `ping-pong` app is
deployed in namespace `app` and exposed at `http://myapp.local:32080/`.

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"missing/invalid creds"| R["401 Unauthorized"]
    GW -->|"valid creds"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## Task

1. Confirm the app is reachable without a plugin (`200`).
2. Apply a `WasmPlugin` that loads the `basic_auth` module from an OCI registry on the
   ingress gateway (`selector: istio=ingressgateway`) and requires Basic auth.
3. Confirm that without credentials the request returns `401`, and with valid credentials
   `200`.

## Step 1. Baseline (no auth)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Step 2. Apply the WasmPlugin

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

The Istio agent on the ingress gateway downloads the OCI Wasm image, caches it locally,
and injects it as an HTTP filter. Give it a few seconds.

## Step 3. Verify

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## How it works

- **WebAssembly (Wasm)** lets you add custom logic to Envoy without rebuilding the proxy
  and load it dynamically at runtime.
- **`url: oci://...`** — the module ships as an OCI artifact; the Istio agent pulls and
  caches it. `file://` (baked into the image) and `http(s)://` are also supported.
- **`phase: AUTHN`** places the filter early in the chain (before routing/authz).
- **`selector`** scopes the plugin to workloads by labels (here the ingress gateway).
- **`pluginConfig`** is passed to the module; `basic_auth` reads `basic_auth_rules` (path
  prefix, methods, and accepted credentials).

## When to reach for Wasm

- Custom auth, header enrichment/validation, or protocol logic that Istio's built-in CRDs
  cannot express.
- Prefer built-in APIs first; use Wasm when you genuinely need custom code in the data
  plane. Mind the operational cost: module distribution, versioning, and the runtime
  fetch (`failStrategy` controls behaviour if the download fails).

## Check the result

Run on the worker PC:

```bash
check_result
```

## Summary

You extended the data plane with a custom Wasm module pulled from an OCI registry and
added Basic auth at the mesh edge without changing the application. Working with
`WasmPlugin` is a senior skill for cases where Istio's built-in capabilities fall short.

## Infrastructure

| Component | Type | Count | Role |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | capacity for the app |
| worker PC | `t3.small` | 1 | workstation: `kubectl`, `curl`, `check_result` |

Region: `eu-central-1` (AZ `eu-central-1a` / `eu-central-1b`).
