[RU version](ru.md)

# Chapter 30. Control plane performance and operations

> **What's next.** We have gone from the basics to multi-cluster and VMs. This chapter closes the
> operations block: how the control plane works, what its performance depends on, what to monitor,
> how to tune it, and how to keep the mesh healthy in production. Two more chapters lie ahead -
> hardening and the threat model (chapter 31) and preparing for the ICA exam (chapter 32).

## 30.1. How the control plane works and what affects its performance

Recall from chapter 4: istiod (the control plane) does not process traffic itself. Its job is to
watch the cluster's state (services, pods, your configs) and **distribute the up-to-date
configuration** to all Envoys over xDS. It is exactly this work that loads the control plane.

```mermaid
flowchart LR
    E["a change<br>(pod / config)"] --> D["debounce / batching"]
    D --> C["istiod recomputes"]
    C --> P["push over xDS to all proxies"]
    style E fill:#673ab7,color:#fff
    style D fill:#f4b400,color:#000
    style C fill:#326ce5,color:#fff
    style P fill:#0f9d58,color:#fff
```

istiod's performance is affected by:

- **The number of services and pods** - the more there are, the more configuration to compute and
  send.
- **The rate of change (churn)** - every new pod, every service or rule change triggers a recompute
  and a push.
- **The number of connected proxies** - the config has to be delivered to each one.
- **The size of the configuration per proxy** - if every sidecar knows about the whole mesh (chapter
  19), the volume grows quadratically.

## 30.2. Monitoring the control plane

istiod needs to be monitored separately from the applications. Go by its "golden signals":

- **Config propagation latency** - `pilot_proxy_convergence_time`. The main signal: how long it
  takes for a change to reach the proxies. A rise is the first sign that the control plane is not
  keeping up.
- **Pushes and errors** - `pilot_xds_pushes` (how many distributions) and counters of rejected
  configs/xDS errors. A spike in errors means config or connectivity problems.
- **Connected proxies** - how many Envoys are connected to istiod.
- **Saturation** - istiod's CPU and memory. If it hits its limits, all config propagation suffers.

These metrics are the basis of control plane alerts (chapter 17). Running proxies keep working even
when istiod is unavailable (on the last configuration received), but new changes will not arrive - so
istiod's health is critical.

**Check your work.** Basic PromQL queries for istiod's golden signals:

```promql
# p99 of config convergence time (sec) - the main signal
histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le))

# the rate of xDS pushes by type (cds/eds/lds/rds)
sum(rate(pilot_xds_pushes[5m])) by (type)

# rejected configurations - should be 0
sum(rate(pilot_total_xds_rejects[5m]))

# how many proxies are connected to istiod
pilot_xds
```

A rise in the p99 of convergence or a non-zero `pilot_total_xds_rejects` is a signal to investigate:
istiod overload, a broken config or connectivity problems.

## 30.3. Performance tuning

The main levers (many of which we have already mentioned):

- **discovery selectors** (chapter 19) - istiod watches only the needed namespaces, ignoring the
  rest. The biggest win if part of the cluster is not in the mesh.
- **Sidecar scope** (chapter 19) - each proxy gets the config only of the services it needs, not the
  whole mesh. Sharply reduces the configuration volume and the load on istiod.
- **Event batching and debounce** - istiod does not push the config on every little change but groups
  changes over a short interval (debounce) and throttles the push rate. These parameters (for
  example, `PILOT_DEBOUNCE_AFTER`, `PILOT_PUSH_THROTTLE`) are tuned to the load: more batching - fewer
  pushes, but a slightly higher propagation latency.
- **istiod resources and HA** (chapter 27) - several replicas + an HPA, enough CPU/memory.
- **Reducing churn** - fewer unnecessary changes (for example, not touching configs without need) =
  fewer recomputes.

The batching parameters are set as istiod environment variables - in the `IstioOperator` via
`components.pilot.k8s.env`:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
        - name: PILOT_DEBOUNCE_AFTER      # wait for quiet before recomputing
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX        # but no longer than this
          value: "10s"
        - name: PILOT_PUSH_THROTTLE       # max concurrent pushes
          value: "100"
```

More debounce - fewer recomputes and pushes during a spike of changes, but a slightly higher
propagation latency (watch `pilot_proxy_convergence_time`, section 30.2). The defaults suit most;
touch them deliberately, for a concrete problem.

## 30.4. Deployment policies: OPA Gatekeeper

In a large mesh it is important that teams do not deploy unsafe or breaking configurations. Here
**OPA Gatekeeper** helps - an admission controller that checks resources on creation (like the
webhook from chapter 4) and rejects those that do not conform to the rules.

Typical policies for Istio:

- require an injection label (or `istio.io/rev`) on application namespaces;
- forbid a `PeerAuthentication` with `mode: DISABLE` (so that no one accidentally turns off mTLS);
- require that a Service's ports be named correctly (chapter 10);
- forbid overly broad `AuthorizationPolicy` or `EnvoyFilter` without review.

Gatekeeper turns the best practices from this course into **automatically enforced rules**: not "we
agreed to do it this way", but "otherwise it just will not deploy".

Example: forbid a `PeerAuthentication` with `mode: DISABLE`. The policy is described by two resources
- a `ConstraintTemplate` (what to check, in Rego) and a `Constraint` (what to apply it to):

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: denymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: DenyMtlsDisable
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package denymtlsdisable
      violation[{"msg": msg}] {
        input.review.object.spec.mtls.mode == "DISABLE"
        msg := "PeerAuthentication mode DISABLE is forbidden by policy"
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
    - apiGroups: ["security.istio.io"]
      kinds: ["PeerAuthentication"]
```

Now any `PeerAuthentication` with mTLS turned off will be rejected at admission - no one accidentally
"punches a hole" in the mesh. An alternative to Gatekeeper with a simpler YAML syntax (no Rego) is
**Kyverno**; the choice between them is usually about the tool adopted in your team.

## 30.5. Operations on EKS/AWS

A couple of EKS-specific points that affect the control plane.

- **Monitoring istiod via managed services.** istiod's golden signals are conveniently written into
  **Amazon Managed Prometheus (AMP)** and viewed in **Grafana (AMG)**, with the metrics collected by
  the **ADOT** agent (chapter 17). istiod can in this case live on **Fargate** (chapter 27) - it is
  stateless.
- **Karpenter and spot nodes increase churn.** Node autoscaling (Karpenter) and spot with its
  interruptions mean frequent appearance/disappearance of nodes and pods. For the control plane this
  is a **rise in churn**: every recreated pod is an endpoints event and new xDS pushes. What helps:
  a not-too-aggressive **consolidation** in Karpenter, a `disruption budget` on the node pool, PDBs
  on the applications - so that nodes are not "reassembled" constantly. Plus the same scope (chapter
  19), so that a spike of changes in one part of the cluster is not distributed to all proxies.
- **The cost of observability.** Istio's metrics are high-cardinality; on a large EKS cluster the
  bill for AMP/storage grows fast - manage this via the Telemetry API (chapter 18): disable
  unneeded dimensions, sample traces sensibly.

## 30.6. Operating at scale: a checklist

Let us gather the operational practices scattered across the course:

- **Monitor the control plane** separately (istiod's golden signals), not just the applications.
- **Optimize the scope** (discovery selectors + Sidecar) on large clusters - the main performance
  lever.
- **Upgrade via revisions/canary** (chapter 3), not in-place on live production.
- **Lay down the PKI and a common CA in advance** (chapters 16, 28), plan root rotation.
- **Keep uniform versions** of Istio across a multi-cluster's clusters (chapter 28).
- **Automate policies** via Gatekeeper - best practices as mandatory rules.
- **Observability across the whole mesh** with alerts (chapters 17-18), sensible sampling.
- **Rehearse upgrades and rollbacks** before you need them in battle.
- **Do not over-complicate prematurely** - introduce ambient, multi-cluster, VMs for a concrete need,
  not "because you can".

## 30.7. Chapter summary

- The control plane (istiod) does not carry traffic, but it computes and distributes the
  configuration to all proxies; that is its load.
- Performance depends on the number of services/pods, the rate of change, the number of proxies, and
  the config size per proxy.
- Monitor istiod's golden signals: config propagation time (`pilot_proxy_convergence_time`), pushes
  and errors, the number of proxies, CPU/memory.
- Tuning: **discovery selectors** and **Sidecar scope** (chapter 19), push batching/throttle
  (`PILOT_DEBOUNCE_AFTER`/`PILOT_PUSH_THROTTLE` via the `IstioOperator`), istiod resources and HA,
  reducing churn.
- **OPA Gatekeeper** (or Kyverno) turns best practices into mandatory admission rules
  (`ConstraintTemplate` + `Constraint`), for example forbidding mTLS `DISABLE`.
- On EKS: monitor istiod via AMP/AMG/ADOT, istiod on Fargate; **Karpenter/spot** increase churn -
  restrain consolidation and keep the scope narrow; watch the cost of high-cardinality metrics.
- Operating at scale: control plane monitoring, scope optimization, upgrades via revisions, PKI in
  advance, uniform versions, policy automation, end-to-end observability, rehearsing rollbacks,
  rejecting unnecessary complexity.

## 30.8. Self-check questions

1. What loads the control plane if it does not process user traffic?
2. What factors affect istiod's performance?
3. Name the control plane's golden signals and what a rise in `pilot_proxy_convergence_time` means.
4. What performance-tuning levers do you know? How do you set istiod's batching parameters?
5. What does OPA Gatekeeper give in the context of operating Istio? What resources does a policy
   consist of and what can it be replaced with?
6. With which PromQL queries would you check the control plane's health?
7. How do Karpenter and spot nodes affect istiod's load and what do you do about it?

## Practice

Practice operations and performance hands-on: discovery selectors and Sidecar scope, monitoring
istiod's golden signals, deployment policies via OPA Gatekeeper.

🧪 Lab 33: [tasks/ica/labs/33](../../labs/33/README.MD)

---
[Contents](../README.md) · [Chapter 29](../29/en.md) · [Chapter 31](../31/en.md)
