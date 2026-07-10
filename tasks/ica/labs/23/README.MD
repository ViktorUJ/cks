[RU version](README_RU.MD) · [Versión en español](README_ES.MD)

# Lab 23 - WasmPlugin: extend the data plane with WebAssembly

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

## What WebAssembly is (for those new to it)

In short: **WebAssembly (Wasm)** is a format for small compiled programs that can run
safely inside another program. Wasm was originally created for browsers (to run C++/Rust
code alongside JavaScript), but today it is used everywhere, including inside network
proxies.

Step by step, here is what is going on:

- **What the data plane and Envoy are.** In Istio, an **Envoy** proxy runs next to each
  pod (the "sidecar"). All of the pod's network traffic - inbound and outbound - goes
  through it. Together these proxies form the *data plane*. Envoy is what actually
  enforces the rules: mTLS, routing, limits, authorization.
- **The problem.** Envoy can do a lot out of the box, but it cannot anticipate
  everything. Historically, to add custom logic you had to rebuild Envoy in C++ and swap
  the proxy image - slow, risky, and it breaks on upgrades.
- **The Wasm plugin idea.** Instead of rebuilding, you write a small module in a
  convenient language (**Rust, C++, Go/TinyGo, AssemblyScript**), compile it to `.wasm`,
  and hand it to Envoy. Envoy loads that module **at runtime, with no restart and no
  rebuild**, and starts running requests through it.
- **The sandbox.** A Wasm module runs in an isolated environment: it has no direct access
  to Envoy's memory or the host and talks to the proxy only through a strictly defined
  interface. Even if the module crashes, it will not take down the proxy. This makes
  running custom code inside proxies relatively safe.
- **The proxy-wasm ABI.** The "Envoy ↔ Wasm module" interaction is standardized by the
  **proxy-wasm** protocol (a set of hook functions: "a request arrived", "a header
  arrived", "a body chunk arrived", etc.). Thanks to this shared standard the same module
  works across Envoy/Istio versions and even in other proxies that support proxy-wasm.
- **How the module reaches the proxy.** The module is packaged as an **OCI image** (like
  a regular Docker image) and pushed to a registry. In the `WasmPlugin` you set
  `url: oci://...`, and the Istio agent downloads the module, caches it on the node, and
  attaches it to Envoy as an HTTP filter.

An analogy: it is like a "browser plugin/extension", except the plugin is installed into
a network proxy instead of a browser, and it processes network requests between services
instead of web pages. In this lab that "plugin" is the ready-made `basic_auth` module,
which requires a username/password (HTTP Basic auth) at the mesh edge.

## Ready-made modules and how to build your own

**Ready-made Wasm modules (no code needed).** Often the functionality you need already
exists - you just point the `WasmPlugin` at an image:

- **istio-ecosystem/wasm-extensions** - the official Istio community examples
  (`basic_auth` and others), published under `ghcr.io/istio-ecosystem/wasm-extensions/...`
  (this is exactly what we use in the lab).
- **Vendor/product modules** (for example coraza-WAF as Wasm, OPA, various auth/rate-limit
  filters) distributed as OCI images.
- **WebAssembly Hub / OCI registries** - modules are packaged as regular OCI images, so
  they can live in any registry (ghcr, Docker Hub, ECR, a private Harbor).

The rule is simple: if the module exists as an OCI image, you just write `url: oci://...`
and write no code.

**If you need your own module - the short path.** Custom logic is written in a language
that compiles to Wasm, using a proxy-wasm SDK:

1. **Pick a language and SDK.** Popular choices: **Rust**
   (`proxy-wasm/proxy-wasm-rust-sdk`), **Go/TinyGo** (`proxy-wasm-go-sdk`), C++, or
   AssemblyScript. Production often uses Rust (fast, compact `.wasm`).
2. **Implement the hooks.** In the SDK you implement request-lifecycle callbacks such as
   `on_http_request_headers` (request headers arrived), `on_http_response_headers`, etc.
   Inside goes your logic: inspect a header, add/modify it, or reject the request.
3. **Compile to Wasm.** For Rust, for example:
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # result: target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **Package as an OCI image and push it.** Istio expects the Wasm inside an OCI artifact.
   Build it with tools like `buildah`/`docker` or `func-e`/`wasme`, then
   `docker push <registry>/my-plugin:1.0`.
5. **Wire it up via WasmPlugin.** Set `url: oci://<registry>/my-plugin:1.0` and, if
   needed, a `pluginConfig` with your parameters - exactly as in this lab.

A minimal Rust example (adds a response header):

```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

proxy_wasm::main! {{
    proxy_wasm::set_http_context(|_, _| -> Box<dyn HttpContext> { Box::new(MyPlugin) });
}}

struct MyPlugin;
impl Context for MyPlugin {}
impl HttpContext for MyPlugin {
    fn on_http_response_headers(&mut self, _n: usize, _eos: bool) -> Action {
        self.set_http_response_header("x-my-plugin", Some("hello"));
        Action::Continue
    }
}
```

For real development, see the guides in the `istio-ecosystem/wasm-extensions` repository
(how to write, test, and build OCI images).

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
- **`url: oci://...`** - the module ships as an OCI artifact; the Istio agent pulls and
  caches it. `file://` (baked into the image) and `http(s)://` are also supported.
- **`phase: AUTHN`** places the filter early in the chain (before routing/authz).
- **`selector`** scopes the plugin to workloads by labels (here the ingress gateway).
- **`pluginConfig`** is passed to the module; `basic_auth` reads `basic_auth_rules` (path
  prefix, methods, and accepted credentials).

## When this is useful (real-world scenarios)

- **Custom authentication/authorization**: Basic auth, API-key checks, HMAC request
  signing, integration with a non-standard IdP - things `RequestAuthentication` /
  `AuthorizationPolicy` cannot express.
- **Request/response manipulation**: enrich headers from an external source, compute
  signatures, rewrite bodies (mask PII), normalize paths.
- **Protocol and edge business logic**: rate limiting keyed on a custom value, feature
  flags, A/B based on complex rules, decoding a proprietary protocol.
- **Compliance and security**: audit logging in a specific format, WAF-like checks,
  blocking by custom signatures.
- **Move logic out of the app**: implement cross-cutting logic (auth, logging, headers)
  once in the mesh instead of in every service in every language.

## Advantages over the alternatives

| Approach | Pros | Cons / when worse than Wasm |
|---|---|---|
| **Built-in CRDs** (`AuthorizationPolicy`, `RequestAuthentication`, `Telemetry`, `EnvoyFilter` local ratelimit) | Simple, declarative, supported by Istio | Limited to predefined capabilities; arbitrary logic is not expressible |
| **`EnvoyFilter` + Lua** (see lua-scripts) | No rebuild, inline script | Lua only; heavy tasks are slower; no strong typing/tests; logic scattered across YAML |
| **`EnvoyFilter` with a native C++ filter** | Maximum performance | Requires rebuilding Envoy and a custom proxy image; breaks with upgrades; high barrier |
| **Logic inside the app** | Full control | Duplicated across every service and language; hard to keep consistent and updated |
| **External service (ext_authz / callout)** | Any language, deployed separately | Extra network hop and latency on every request; one more component to operate |
| **WasmPlugin (this lab)** | Your own code in any language that compiles to Wasm (C++, Rust, Go/TinyGo, AssemblyScript); loaded **at runtime with no Envoy rebuild and no restart**; runs **in-process** (no network hop like ext_authz); Wasm sandbox for isolation and safety; portable across Envoy/Istio versions thanks to the stable proxy-wasm ABI; versioning and delivery via an OCI registry | API is Alpha; runtime fetch/caching overhead; you must maintain, test, and version your own code; harder to debug than declarative CRDs |

**In short:** Wasm wins when you need *arbitrary* logic in the data plane while still
caring about low latency (in-process, no extra hop like ext_authz), safety (sandbox), and
the ability to roll out/update the filter dynamically without rebuilding the proxy.

**Practical selection order:** start with built-in CRDs → if not enough, `EnvoyFilter`
(including Lua for simple cases) → an external `ext_authz` when the logic is easier to
keep as a separate service and latency is not critical → **Wasm** when you need your own
fast in-process code inside the proxy itself. Mind the operational cost of Wasm: module
distribution, versioning, and the runtime fetch (`failStrategy` controls behaviour on a
failed download - fail-open or fail-close).

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
