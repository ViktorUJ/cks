[Русская версия](SCORECARD_RU.md) · [Versión en español](SCORECARD_ES.md) · [Version française](SCORECARD_FR.md) · [Deutsche Version](SCORECARD_DE.md) · [ქართული ვერსია](SCORECARD_GE.md) · [繁體中文版](SCORECARD_TW.md) · [日本語版](SCORECARD_JP.md)

# EKS Maturity Matrix: Readiness Questionnaire

[Course contents](README.md) · [Chapter 48](48/en.md) · [Glossary](GLOSSARY.md)

This is a working companion to chapter 48: it uses the same readiness domains, but as a questionnaire
that the team completes and turns into a technical-debt list. It contains no new material.

## How to complete it

- Work through all eight domains in order, without skipping any: each domain is a separate operational
  axis, and strength in one does not compensate for weakness in another.
- Answer every item honestly: yes or no. “Partially”, “almost”, and “configured but not tested” count
  as no.
- Complete it as a team, not as one person: the network, security, and cost owners see different gaps,
  and “it seems ready” is exposed precisely where opinions intersect.
- The point is not the score. The score only shows the level; the questionnaire result is a list of
  unresolved items, with owners and due dates.
- Mark every unresolved item as a known risk with a task. Do not quietly skip it just to make the
  form look green.
- Repeat it quarterly and after major changes: versions age, workloads grow, and what was “done”
  yesterday can be a gap today.
- Keep the form in the repository next to the IaC, so its changes are visible in pull requests.

## Level scale

The questionnaire has 51 items in total. One completed item equals one point.

| Level | Points | What it means | What to do next |
|---|---|---|---|
| Level 1. Unstable and manual | 0-20 | The cluster works while nothing breaks: much was done with clicks, and recovery and security boundaries have not been tested | Complete the blocking items and the entire “must have” column before enabling production traffic |
| Level 2. Managed | 21-33 | The foundation exists: the cluster is defined as code, and access and compute are intentional, but validation and observability depend on individual people | Finish security and operations: audit, retention, alerts, upgrade plan |
| Level 3. Repeatable and observable | 34-44 | Practices are established and repeatable: upgrade, backup, and restore have been completed, and an incident can be localized using a runbook | Complete the “important in the first weeks” priority items and assign ownership for every domain |
| Level 4. Autonomous resilience | 45-51 | Readiness does not degrade between releases: DR has been validated in exercises, cost and traffic are under control, and GitOps is the source of truth | Maintain the level: complete the questionnaire quarterly, run game days, and finish “nice to have” items |

If any blocking item is unresolved, the level cannot be higher than Level 2, regardless of the total
score. The rule is explained in “Scoring and what to do with the result”.

## 1. Cluster and control plane

The foundation. If the version is out of support or subnets are configured in one AZ, nothing else matters.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | Kubernetes version is within standard support | An unsupported version is a risk that configuration cannot mitigate | [38](38/en.md) |
| [ ] | A version upgrade plan exists, rather than reacting one month before support ends | An upgrade under a deadline is performed without a rollback window | [38](38/en.md) |
| [ ] | Endpoint access is deliberate: public or private, with source ranges suited to the need | API access mode defines the cluster attack surface | [02](02/en.md) |
| [ ] | Cluster subnets span three AZs, and the IP plan accommodates pod growth | One AZ is a single point of failure; IP exhaustion stops pod scheduling | [06](06/en.md) |
| [ ] | The cluster was created from code (Terraform or eksctl), not by clicking in the console | A manual cluster cannot be recreated during DR or reviewed in a pull request | [04](04/en.md) |
| [ ] | Resources are tagged with team, environment, and cost allocation | Without tags, cost and ownership cannot be allocated across teams | [43](43/en.md) |

## 2. Compute

Nodes are entirely the engineer’s responsibility: resilience and the bill are decided here.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | The node strategy is a deliberate choice: Auto Mode, Karpenter, or managed node groups | Leaving the default means unclear consequences for cost and resilience | [09](09/en.md) |
| [ ] | A Spot mix is used for fault-tolerant workloads | Spot saves money where the workload can tolerate interruption | [13](13/en.md) |
| [ ] | Instance types in the Spot pool are diversified | Spot without diversification is not savings; it is the risk of losing capacity all at once | [13](13/en.md) |
| [ ] | Requests are set based on actual usage (right-sizing), not by guesswork | Overstated requests pay for empty capacity; understated ones break the workload | [14](14/en.md) |
| [ ] | Karpenter disruption and consolidation are configured, and drift is not ignored | Without consolidation, the node fleet sprawls; drift accumulates divergence from code | [12](12/en.md) |
| [ ] | Pod density per node is aligned with ENI and IP limits | Excessive density leaves pods in `Pending` for no obvious reason | [14](14/en.md) |

## 3. Identity and security

The broadest domain and the most common source of quiet gaps. Check it item by item.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | Pods access AWS through IRSA or Pod Identity, without static keys | A long-lived key in a pod leaks with the image or log | [16](16/en.md) |
| [ ] | **Blocking.** Cluster access is not limited to the cluster creator; access entries are configured | A cluster accessible to one person is lost with that person | [05](05/en.md) |
| [ ] | Secrets come from Secrets Manager or SSM (External Secrets, CSI), not manifests | A secret in a manifest ends up in git and every copy of the repository | [18](18/en.md) |
| [ ] | Nodes and pods are hardened: IMDSv2, hop limit, Pod Security Admission | Accessing node metadata from a pod turns the pod into node privileges | [19](19/en.md) |
| [ ] | Images are scanned in ECR, and base images come from trusted sources | A vulnerable base image is pulled into every service at once | [20](20/en.md) |
| [ ] | Control plane audit is enabled: api, audit, authenticator are logged | Enable auditing before the incident; afterward, the logs will not exist | [21](21/en.md) |
| [ ] | Kyverno or Gatekeeper policies block dangerous manifest patterns | Human review misses what a policy always catches | [22](22/en.md) |

## 4. Storage

A small but tricky domain: EBS defaults and untested volume backups fail unexpectedly.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | The default StorageClass is gp3, not the legacy gp2 | gp2 often remains the default through inertia and loses on both performance and cost | [23](23/en.md) |
| [ ] | `volumeBindingMode: WaitForFirstConsumer` is configured | Otherwise, the volume is created in the wrong AZ and the pod remains `Pending` forever | [23](23/en.md) |
| [ ] | Persistent volumes are included in backups | A volume without a backup is data that exists in only one copy | [41](41/en.md) |
| [ ] | Volume snapshots have been validated by restore, not merely by creation | An untested snapshot is equivalent to no snapshot | [41](41/en.md) |
| [ ] | EBS AZ affinity is accounted for when migrating and scheduling workloads | Migrating manifests “as is” fails specifically on volumes | [23](23/en.md) |
| [ ] | Shared storage is selected deliberately: EFS or FSx where ReadWriteMany is needed | EBS does not provide ReadWriteMany, so workarounds must be addressed during design | [24](24/en.md) |

## 5. Network and traffic

Errors in this domain are visible from outside: an unreachable service, open egress, or traffic across every AZ.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | Load balancers are created through AWS Load Balancer Controller: NLB | Manual load balancers drift from the cluster state | [26](26/en.md) |
| [ ] | Ingress uses an ALB with a deliberate target type | The target type determines the traffic path and drain behavior | [27](27/en.md) |
| [ ] | TLS certificates use ACM, and HTTPS terminates at the load balancer | Manual certificates expire at the most inconvenient moment | [27](27/en.md) |
| [ ] | **Blocking.** NetworkPolicy uses default-deny, and traffic between pods is explicitly allowed | Without default-deny, a compromised pod can see all its neighbors | [30](30/en.md) |
| [ ] | DNS records are managed by external-dns, not manually in Route 53 | A manual record survives service deletion and points to nothing | [29](29/en.md) |
| [ ] | VPC endpoints are used for AWS services, NAT is per AZ, and egress traffic is under control | Egress through one NAT is both a point of failure and a cost item | [31](31/en.md) |

## 6. Observability

Without this domain, incidents are debugged blind. Data must not only flow, but also be retained for the
necessary duration and generate alerts.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | metrics-server is running | Without it, neither `kubectl top` nor HPA responds | [33](33/en.md) |
| [ ] | A metrics backend exists: Prometheus or Container Insights | Metrics need history, not just “right now” | [33](33/en.md) |
| [ ] | Logs are exported from nodes and pods | Logs left on a node disappear with the node | [34](34/en.md) |
| [ ] | Log retention is set deliberately | Retention without a plan means missing logs during investigation or unnecessary storage | [34](34/en.md) |
| [ ] | Alerts are configured for key symptoms, not only dashboards | A dashboard nobody watches does not replace an alert | [33](33/en.md) |
| [ ] | Tracing (ADOT or X-Ray) exists where the call chain matters | In microservices, the cause of a failure is not in the service where its symptom is visible | [36](36/en.md) |

## 7. Operations

The domain that separates “the cluster works today” from “the cluster survives an upgrade and failure”.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | A cluster and add-on upgrade plan exists, and deprecated APIs have been removed | A deprecated API stops an upgrade at the worst possible moment | [37](37/en.md) |
| [ ] | Rollback readiness is clear: the rollback window and sequence are known | Rollback is designed in advance, not during a failed upgrade | [39](39/en.md) |
| [ ] | PDB and topology spread protect availability during drain and upgrades | Without them, a node upgrade removes all replicas of a service at once | [40](40/en.md) |
| [ ] | PDBs do not block drain permanently (`maxUnavailable: 0` is a red flag) | Such a PDB stops the upgrade and appears as a stuck drain | [40](40/en.md) |
| [ ] | AWS Backup is configured for cluster state and persistent volumes | Backing up volumes alone does not restore the cluster itself | [41](41/en.md) |
| [ ] | **Blocking.** DR restore has been actually tested in a game day | A configured but never tested restore is hope, not backup | [42](42/en.md) |
| [ ] | Cost is visible by team and namespace (OpenCost or Kubecost) | Invisible cost cannot be optimized and has no owner | [43](43/en.md) |
| [ ] | GitOps is the source of truth for manifests (Argo CD or Flux) | A cluster that drifts from git means nobody knows the state | [44](44/en.md) |

## 8. Incident readiness

The final domain: when everything breaks, architecture matters less than the speed of localization.

| Done | Item | Why it matters | Chapter |
|---|---|---|---|
| [ ] | A runbook exists for a node that did not join the cluster | Causes differ (IAM, SG, user data, kubelet); the diagnostic order saves hours | [45](45/en.md) |
| [ ] | A runbook exists for network failures: ENI, SG and NACL, DNS, unhealthy targets | A network failure looks the same even when causes differ | [46](46/en.md) |
| [ ] | A runbook exists for access: 401 versus 403, IRSA and Pod Identity, kubeconfig | An access failure blocks both work and incident investigation | [47](47/en.md) |
| [ ] | SSM access to nodes works without bare SSH, and the node can be accessed | It is too late to configure node access after the node has already failed | [45](45/en.md) |
| [ ] | Control plane logging is enabled, and authenticator and API logs are written | Without these logs, the cause of an access failure cannot be reconstructed | [21](21/en.md) |
| [ ] | Control plane logs are available for investigation and are not deleted too early | Logs are needed during investigation, not during configuration | [34](34/en.md) |

## Scoring and what to do with the result

Calculate it as follows:

- One completed item equals one point, up to 51. Domains are equally important: network is no more
  important than storage, and a high score in one domain does not close a gap in another.
- Three items are marked as **blocking**: DR restore has not been tested, only one person has cluster
  access, and the network has no default-deny NetworkPolicy.
- If at least one blocking item is unresolved, the level cannot exceed Level 2 regardless of the
  total score. A blocking item is not “minus one point”; it is a stop for production traffic.

Then turn unresolved items into a prioritized technical-debt list:

| Priority | What belongs there | What to do |
|---|---|---|
| Must have before production | supported version, access not limited to one person, control plane audit and logs, default-deny NetworkPolicy, secrets not in manifests, tested restore, PDBs do not block upgrades | complete before enabling production traffic: the first incident or breach costs more than delaying launch |
| Important in the first weeks | right-sizing requests, Spot mix, log retention, alerts, upgrade plan, VPC endpoints | create tasks with owners and due dates immediately after launch |
| Nice to have | microservice tracing, detailed cost allocation, mature GitOps for a fleet of clusters | improve iteratively in production without blocking launch |

Document the technical-debt list as explicit tasks with an owner and due date. The phrase “sometime
later” means the item is unresolved and will be in the same place during the next review.

What to do with the result next:

- Assign ownership for domains: network, security, and cost each have an owner responsible for
  ensuring their items are complete and have not degraded.
- Complete the form before every production rollout: a new cluster or major new service does not go
  live until the “must have” priority is fully and explicitly complete.
- Tie the result to game days and upgrades: return DR restore and upgrade-plan validation to the form
  as a confirmed or failed item, not as a promise.
- Compare it with the previous review: the interesting measure is not the score total, but which items
  were completed, which returned to unresolved, and why.

## Limitations of this questionnaire

- It does not replace an architecture review: readiness axes are visible, but design decisions are not.
- It evaluates whether a practice exists, not its quality: enabled auditing and useful auditing receive
  the same point; the difference is visible only during incident investigation.
- It does not cover the application layer: service code and data schemas remain outside the form.
- The score is not comparable between clusters with different purposes: a non-production cluster may
  not need some items, and a low score there does not mean anything bad.
