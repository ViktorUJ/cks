[RU version](README_RU.MD)

# Istio Certified Associate (ICA) - Training Materials

<img src="../../docs/images/ICA.png" alt="Istio Certified Associate" width="200">

Complete preparation for the **Istio Certified Associate (ICA)** certification: a
self-study course, hands-on labs, and full mock exams - all in one place.

## What's inside

| Part | Path | What it is |
|------|------|-----------|
| **Course** | [`course/`](course/README.md) | 32-chapter self-study course: from the idea of a service mesh to production operations |
| **Labs** | [`labs/`](labs/) | 31 hands-on labs on real AWS clusters, each tied to a course chapter |
| **Mock exams** | [`mock/`](mock/) | 2 full mock exams that simulate the real ICA experience |

Recommended path: study a course chapter, reinforce it with its lab, then run the mock
exams on the clock.

## The course

The course ([`course/README.md`](course/README.md)) has 32 chapters, written for
engineers who already know Kubernetes (CKA level):

- **Part 1 (chapters 1-24)** - fundamentals and full coverage of the ICA exam domains
  (traffic management, security, observability, advanced scenarios, troubleshooting,
  installation).
- **Part 2 (chapters 25-31)** - real-world best practices: progressive delivery,
  zero-downtime migration, Istio on EKS, multi-cluster, VM workloads, control-plane
  performance, hardening.
- **Exam prep (chapter 32)** - ICA format, tips, and links to the mock exams.

Each chapter ends with a **Practice** section linking to the matching lab.

## The labs

31 hands-on labs (`labs/01` .. `labs/31`), each with an English (`README.MD`) and Russian
(`README_RU.MD`) version. They deploy real clusters in AWS via Terragrunt:

```bash
TASK=01 make run_ica_task      # deploy lab 01
TASK=01 make delete_ica_task   # tear it down
```

Lab topics (and the course chapter that covers the theory):

| Lab | Topic | Chapter |
|-----|-------|---------|
| 01 | Install Istio, Bookinfo, sidecar injection | 2 |
| 02 | Dark launch, header routing, canary | 5, 6 |
| 03 | Fault injection and retries | 8 |
| 04 | mTLS (PeerAuthentication) + AuthorizationPolicy | 13, 14 |
| 05 | Egress: ServiceEntry, egress gateway, REGISTRY_ONLY | 12 |
| 06 | Load balancing + traffic mirroring | 6, 7 |
| 07 | Helm install + canary upgrade (revisions) | 3 |
| 08 | Observability: Prometheus/Jaeger/Kiali | 17 |
| 09 | Ambient mode (sidecarless) | 22 |
| 10 | Resilience: timeout + circuit breaker | 8 |
| 11 | End-user auth: RequestAuthentication + JWT | 15 |
| 12 | Troubleshooting with istioctl | 24 |
| 13 | Edge TLS (SIMPLE) | 9 |
| 14 | Locality-aware failover | 7 |
| 15 | Install & configuration (IstioOperator + MeshConfig) | 2 |
| 16 | Kubernetes Gateway API (Gateway + HTTPRoute) | 11 |
| 17 | Local rate limiting (EnvoyFilter) | 20 |
| 18 | Telemetry API: access logs + tracing | 18 |
| 19 | Custom CA in istiod | 16 |
| 20 | mTLS migration PERMISSIVE to STRICT | 13 |
| 21 | Sidecar scoping | 19 |
| 22 | TLS origination | 12 |
| 23 | WasmPlugin (WebAssembly) | 21 |
| 24 | Ambient: waypoint proxy + L7 authorization | 22 |
| 25 | Progressive delivery with Flagger | 25 |
| 26 | Dynamic CA: cert-manager + istio-csr | 16 |
| 27 | EnvoyFilter + Lua | 21 |
| 28 | TCP routing | 10 |
| 29 | Ingress TLS: MUTUAL and PASSTHROUGH | 9 |
| 30 | StatefulSet and headless services | 23 |
| 31 | Zero-downtime migration: ingress-nginx to Istio | 26 |

## Mock exams

Two full mock exams that mirror the ICA format:

- **Mock 01** ([`mock/01`](mock/01/README.MD)) - 17 tasks on core Istio concepts.
- **Mock 02** ([`mock/02`](mock/02/README.MD)) - 16 tasks on advanced service mesh patterns.

Run them on the clock, without hints, and aim for **70%+**.

## Custom terminal environment

![Terminal Interface](../../docs/images/cockpit.png)

The infrastructure provides a pre-configured terminal with tools and helpers built for
ICA practice.

### Available commands
- **`time_left`** - check remaining lab time
- **`check_result`** - verify task completion (`check_result <task>` for a specific task)
- **`hosts`** - show ingress gateway info (NodePort mappings and IPs)

### Pre-configured tools (with bash completion)
- **`kubectl | k`**, **`istioctl`**, **`helm`**, **`yq`**, **`curl`/`wget`**,
  **`podman`**, **`aws`**

### SSH access
```bash
ssh <kubernetes_nodename>
```

## Quick start

```bash
# check your score (all tasks or a specific one)
check_result
check_result <task_number>

# cluster/ingress info for testing external access
hosts

# time left during a timed run
time_left
```

## Allowed resources during the exam

You may reference the official Istio documentation:
**https://istio.io/latest/docs/** and all subdomains. The mocks mirror this.

## Tips for success

1. **Read task requirements carefully** - exact names, namespaces, and specs matter.
2. **Verify your context** with `kubectl config current-context`.
3. **Test your work** - `curl` from sleep pods to check routing and policies.
4. **Use `istioctl analyze`, `proxy-status`, `proxy-config`** to find misconfigurations.
5. **Review reference solutions** after attempting tasks.

## Common pitfalls

- **VirtualService hosts**: for cross-namespace traffic, include short name and FQDN.
- **Gateway selectors**: must match the actual ingress gateway labels.
- **Sidecar injection**: pods should show `2/2` containers.
- **Context switching**: double-check the cluster before applying resources.

---

**Good luck with your ICA certification!** Practice makes perfect - work through the
course, the labs, and both mocks until you can complete tasks confidently within the time
limits.
