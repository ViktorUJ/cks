[RU version](README_RU.md)

# Istio: a hands-on self-study course

A practical course on the Istio service mesh, tied to the hands-on labs
(`tasks/ica/labs`). Written for engineers who already passed CKA. Part 1 covers the ICA
exam, Part 2 covers best practices for real-world operations.

Structure: every topic is a numbered folder. Inside are localized files (`ru.md` is the
main one for now; English translations are added later).

## Contents

### Part 1. Fundamentals and ICA preparation

1. [Introduction to service mesh and Istio architecture](01/en.md)
2. [Installing and configuring Istio](02/en.md)
3. [Upgrading Istio: Helm, revisions, canary and in-place](03/en.md)
4. [Data plane: Envoy and sidecar injection](04/en.md)
5. [Traffic management: Gateway, VirtualService, DestinationRule](05/en.md)
6. [Release strategies: canary, header-routing, traffic mirroring](06/en.md)
7. [Load balancing and locality-aware failover](07/en.md)
8. [Resilience: fault injection, timeouts, retries, circuit breaking](08/en.md)
9. [Edge TLS: ingress in SIMPLE, MUTUAL, PASSTHROUGH modes](09/en.md)
10. [Routing TCP, gRPC and WebSocket traffic](10/en.md)
11. [Kubernetes Gateway API](11/en.md)
12. [Egress: ServiceEntry, egress gateway, TLS origination](12/en.md)
13. [mTLS and PeerAuthentication: the Zero Trust model](13/en.md)
14. [AuthorizationPolicy: service-to-service authorization](14/en.md)
15. [End-user authentication: RequestAuthentication and JWT](15/en.md)
16. [Certificate management: custom CA, cert-manager and istio-csr](16/en.md)
17. [Observability: Prometheus, Grafana, Jaeger, Kiali](17/en.md)
18. [Telemetry API: access logs and distributed tracing](18/en.md)
19. [Sidecar scoping and proxy config optimization](19/en.md)
20. [Rate limiting: local request limiting](20/en.md)
21. [Extending the data plane: EnvoyFilter, Lua and WasmPlugin](21/en.md)
22. [Ambient mode: ztunnel and waypoint proxy](22/en.md)
23. [StatefulSets and headless services in the mesh](23/en.md)
24. [Troubleshooting Istio](24/en.md)

### Part 2. Best practices for real-world use

25. [Progressive delivery with Flagger](25/en.md)
26. [Zero-downtime production migration: ingress-nginx to Istio](26/en.md)
27. [Istio on EKS: production install](27/en.md)
28. [Multi-cluster mesh](28/en.md)
29. [Non-Kubernetes workloads: VMs in the mesh](29/en.md)
30. [Control-plane performance and operations](30/en.md)
31. [Hardening and the mesh threat model](31/en.md)

### Exam preparation

32. [The ICA exam: format and preparation](32/en.md)
