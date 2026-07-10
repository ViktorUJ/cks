[RU version](ru.md) · [Versión en español](es.md)

# Chapter 11. The Kubernetes Gateway API

> **What's next.** In chapters 5-10 we managed traffic through Istio resources: Gateway and
> VirtualService. But Kubernetes has grown a common standard for the same thing - the
> Kubernetes Gateway API. Istio fully supports it and considers it the future of ingress. In
> this chapter we look at what it is, compare it with the Istio resources and, most
> importantly, work out what to use and when.

## 11.1. Why a separate standard was needed

The `Gateway` and `VirtualService` resources from `networking.istio.io` work great, but they
have one drawback: it is an **Istio-specific** API. If tomorrow you decide to switch mesh or
ingress controller, all the manifests will have to be rewritten for another product. Every
solution (Istio, nginx, Traefik, cloud gateways) had its own set of resources.

The Kubernetes community solved this problem with a single standard - the **Kubernetes Gateway
API** (`gateway.networking.k8s.io`). It is a vendor-neutral API for managing inbound traffic,
implemented by many products, Istio among them. You write it once against the standard - and
it works on any compatible implementation.

Let us warn about the naming confusion right away. There are two different resources with the
word `Gateway`:

- `Gateway` from `networking.istio.io` - the Istio resource (we have used it since chapter 5).
- `Gateway` from `gateway.networking.k8s.io` - the resource of the Kubernetes Gateway API
  standard.

These are different APIs with different structures. From here on, by "Gateway API" we mean
exactly the second, standard one.

## 11.2. Roles and resources of the Gateway API

In the Gateway API responsibility is split across several resources, each for its own role:

| Resource | Responsible for | Istio counterpart |
|----------|-----------------|-------------------|
| `GatewayClass` | the implementation type (who handles the traffic) | set at install time |
| `Gateway` | what to listen on: ports, protocols, TLS | Istio `Gateway` |
| `HTTPRoute` | HTTP routing rules | Istio `VirtualService` |

Besides `HTTPRoute` there are other routes for different protocols: `TCPRoute`, `TLSRoute`,
`GRPCRoute`. The idea is the same as in Istio: "what we listen on" (Gateway) separate from
"where we route" (Route).

## 11.3. Installing the Gateway API CRDs

An important practical point people often trip over: the Gateway API resources are **CRDs
that may not be in the cluster by default**. Istio implements the standard, but the
definitions themselves (`GatewayClass`, `Gateway`, `HTTPRoute`…) must be installed by either
the community or Istio. If the CRDs are not installed, your manifests simply will not apply.

Check for their presence:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

If the CRDs are missing, install them from the official standard release (the `standard`
channel contains the stable resources, `experimental` also adds `TCPRoute`/`TLSRoute` and
more):

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio installs a `GatewayClass` named `istio` automatically at install time (istiod watches
the CRDs and creates the class). Check the class is in place:

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway and HTTPRoute by example

Let us bring up a gateway on port 80 and route all traffic to the `reviews` service.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # this implementation is provided by Istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # which Gateway the route is bound to
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # directly the Kubernetes Service name
      port: 8080
```

```mermaid
flowchart LR
    C["Client"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>routing rules"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

Key fields:

- **`gatewayClassName: istio`** - says that this Gateway is implemented by Istio. This is the
  counterpart of how in an Istio Gateway we bound to the ingress gateway via `selector`.
- **`parentRefs`** in the HTTPRoute links the route to a specific Gateway. In Istio this role
  was played by the `gateways` field in the VirtualService.
- **`backendRefs`** points directly at a Kubernetes Service and port. There are no subsets or
  DestinationRule in the base Gateway API - versions and policies are described differently.

One more convenience: when you create a `Gateway` with `gatewayClassName: istio`, Istio can
automatically deploy a dedicated Envoy deployment for that gateway. You do not need to install
an ingress gateway in advance - it appears for the specific Gateway.

## 11.5. TLS: HTTPS on the Gateway API

Edge TLS from chapter 9 is described with its own fields in the Gateway API. An HTTPS listener
is declared with `protocol: HTTPS` and a `tls` block, where the mode and the reference to the
certificate Secret live:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # the gateway terminates TLS (like SIMPLE in Istio)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # the same tls Secret as in chapter 9
    allowedRoutes:
      namespaces:
        from: All                    # which namespaces may attach routes (see 11.7)
```

The mapping to the modes from chapter 9:

- **`mode: Terminate`** - the gateway decrypts TLS (like `SIMPLE`/`MUTUAL` in Istio). Client
  certificate verification (the `MUTUAL` analogue) is configured via
  `frontendValidation`/`BackendTLSPolicy` and depends on the standard's version.
- **`mode: Passthrough`** - the gateway does not decrypt, traffic goes through by SNI (like
  `PASSTHROUGH`); for it you use a `TLSRoute`, not an `HTTPRoute`.

The certificate is stored in an ordinary Kubernetes `Secret` of type `tls` - it can likewise
be issued by cert-manager (chapter 9), the route now just references it via `certificateRefs`
rather than `credentialName`.

## 11.6. Canary and filters in HTTPRoute

Weighted traffic splitting (the canary from chapter 6) in the Gateway API is a **standard**
capability, not an extension: `backendRefs` has a `weight` field.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # 90% of traffic to v1
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% to v2
      port: 8080
      weight: 10
```

Note: there are no subsets/DestinationRule in the Gateway API, so different versions are
**different Kubernetes Services** (`reviews-v1`, `reviews-v2`), not a subset of one service.

HTTPRoute can modify requests through **filters** (`filters`) - the counterpart of part of the
VirtualService capabilities:

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # add/remove headers
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # traffic mirroring (chapter 6)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

Useful filter types: `RequestHeaderModifier`/`ResponseHeaderModifier` (headers),
`RequestRedirect` (redirects, including HTTP→HTTPS), `URLRewrite` (rewriting the path/host),
`RequestMirror` (mirroring). But **fault injection** is not in the standard - that remains
exclusive to the Istio API (chapter 8).

## 11.7. Cross-namespace routes: allowedRoutes and ReferenceGrant

A strong side of the Gateway API is explicit, safe separation of rights between namespaces.
There are two mechanisms here.

**`allowedRoutes` on a listener** - the Gateway itself decides which namespaces are allowed to
attach routes to it (`from: Same` - only its own, `All` - any, `Selector` - by namespace
labels):

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # only routes from namespaces with this label
```

**`ReferenceGrant`** - when a resource in one namespace references a resource in **another**
(for example, an HTTPRoute in `apps` wants to send traffic to a Service in `data`), this is
forbidden by default. Permission is granted by a `ReferenceGrant` in the **target** namespace:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # the namespace where the target Service lives
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # who references
  to:
  - group: ""
    kind: Service              # what we allow to be referenced
```

This protects against a foreign route "hijacking" traffic to a service in your namespace
without your consent - the Istio API has no such built-in mechanism.

## 11.8. Comparison with the Istio API

| | Istio API | Kubernetes Gateway API |
|---|-----------|------------------------|
| Ingress resources | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| Route binding | the `gateways` field in VirtualService | `parentRefs` in the Route |
| Implementation choice | `selector` on the ingress gateway | `gatewayClassName` |
| Versions/subsets | `DestinationRule` (subsets) | different Services + `weight` in `backendRefs` |
| Weighted canary | `VirtualService` weight | `backendRefs.weight` (built-in) |
| Mirroring | `VirtualService` mirror | `RequestMirror` filter (built-in) |
| Fault injection | yes | no (Istio only) |
| Backend policies | `DestinationRule` (LB, circuit breaking) | no (Istio only) |
| Rights separation by namespace | no built-in | `allowedRoutes` + `ReferenceGrant` |
| Standard | Istio-specific | common, vendor-neutral |
| Portability | Istio only | any compatible ingress/mesh |

The main takeaway from the table: the Gateway API wins on standardization, portability and
separation of rights between teams, while the Istio API wins on the breadth of capabilities at
the recipient (`DestinationRule`: balancing, circuit breaking, subsets) and on fault
injection. Mirroring and weighted canary exist in both APIs.

## 11.9. What to use and when (best practices)

Practical recommendations for what to choose in real projects.

**Take the Kubernetes Gateway API when:**

- you are starting a new project and want to be on the current standard;
- portability matters: you do not want to be tied to Istio at the manifest level;
- you need a clear division of responsibility between teams (the platform team owns the
  `Gateway`, product teams own their `HTTPRoute`s);
- the standard routing capabilities are enough (by path, headers, weights);
- you work with **ambient mode**: waypoint proxies (chapter 22) are configured precisely
  through the Gateway API.

**Stay on the Istio API (VirtualService/DestinationRule) when:**

- you need features the standard lacks: **fault injection** (chapter 8), `DestinationRule`
  policies (fine-grained balancing, circuit breaking, outlier detection, subsets), route
  delegation;
- you already have many working manifests on the Istio API and no reason to rewrite them.

(Mirroring and weighted canary exist in both APIs, so there is no need to migrate or stay for
their sake.)

### The classic Kubernetes Ingress resource (legacy)

There is a third way in as well - the plain Kubernetes `Ingress` (`networking.k8s.io/v1`), the
one used with nginx-ingress, Traefik and cloud controllers. Istio can act as an ingress
controller for it: the Istio ingress gateway reads `Ingress` resources if they specify the
`istio` class.

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reviews-ingress
  namespace: app
spec:
  ingressClassName: istio          # served by the Istio ingress gateway
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /reviews
        pathType: Prefix
        backend:
          service:
            name: reviews
            port:
              number: 8080
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-cert          # a tls Secret, as in chapter 9
```

Why this is **legacy** and why it should not be chosen for new traffic:

- The `Ingress` standard itself has a very poor set of capabilities: host, path, TLS - and
  that's it. No weights, no mirroring, no redirects, no header-based splits.
- Everything on top of that is implemented via **non-standard annotations** of the controller
  (like nginx, chapter 26). Annotations are incompatible between controllers, and Istio
  supports only a small subset of them - most of the familiar `nginx.ingress.kubernetes.io/*`
  do not work.
- The direction of the industry and of Istio itself is toward the Gateway API, which was
  created as the "next-generation `Ingress`".

The practical takeaway: the classic `Ingress` in Istio is kept only for compatibility with old
manifests during migration (chapter 26). For new ingress take the Kubernetes Gateway API or,
if you need Istio features, the Istio `Gateway` + `VirtualService`.

**General rules:**

- Do not describe the same route both through a VirtualService and an HTTPRoute at once - that
  is confusion and conflicts. For a single service pick one.
- The Istio API is not going away and is fully supported, so migration can be gradual: new
  services on the Gateway API, old ones stay as they are.
- The industry's direction of travel is toward the Gateway API, so it is worth knowing and
  mastering even if today most of your traffic is on the Istio API.

## 11.10. Chapter summary

- The Kubernetes Gateway API (`gateway.networking.k8s.io`) is a vendor-neutral standard for
  managing inbound traffic; Istio implements it.
- Do not confuse the Istio `Gateway` and the `Gateway` from the Gateway API - they are
  different resources.
- The roles in the Gateway API: `GatewayClass` (the implementation), `Gateway` (what to listen
  on), `HTTPRoute` and other Routes (where to route).
- Route-to-gateway binding is via `parentRefs`, the implementation choice via
  `gatewayClassName: istio`.
- The Gateway API CRDs may not be there by default - they are installed separately (the
  `standard` channel), while Istio creates the `GatewayClass istio` itself.
- TLS: an HTTPS listener with `tls.mode: Terminate`/`Passthrough` and a reference to a Secret
  via `certificateRefs` (the counterpart of `credentialName`); the certificates are likewise
  issued by cert-manager.
- Weighted canary (`backendRefs.weight`, but versions are different Services) and mirroring
  (the `RequestMirror` filter) are built in; fault injection and `DestinationRule` policies
  are Istio API only.
- Separation of rights between namespaces: `allowedRoutes` on a listener and `ReferenceGrant`
  for cross-namespace references - there is no built-in analogue in the Istio API.
- Best practice: the Gateway API for new ingress, standard scenarios and ambient; the Istio
  API when you need fault injection or DestinationRule policies; do not mix both for one route.
- Istio also serves the classic Kubernetes `Ingress` (`ingressClassName: istio`), but that is
  legacy: capabilities are poor, the advanced stuff goes through non-standard annotations (a
  small subset). It is kept for compatibility during migration and not chosen for new traffic.

## 11.11. Self-check questions

1. What problem does the Kubernetes Gateway API solve compared with the Istio API?
2. How do the two resources named `Gateway` differ?
3. Which Gateway API resources correspond to the Istio Gateway and VirtualService?
4. What do `gatewayClassName` and `parentRefs` handle?
5. In which cases is it better to stay on the Istio VirtualService/DestinationRule? Which
   features does the Gateway API lack?
6. Why should you not describe one route in both APIs at once?
7. How do you configure HTTPS and weighted canary in the Gateway API? How does the canary
   differ from Istio (what about subsets)?
8. What are `allowedRoutes` and `ReferenceGrant` for? What security problem do they solve?
9. What should you check if Gateway API manifests do not apply in the cluster?
10. Can Istio serve the classic Kubernetes `Ingress`, and why is it considered legacy? When is
    it still used?

## Practice

Set up ingress through the Kubernetes Gateway API (Gateway + HTTPRoute):

🧪 Lab 16: [tasks/ica/labs/16](../../labs/16/README.MD)

---
[Contents](../README.md) · [Chapter 10](../10/en.md) · [Chapter 12](../12/en.md)
