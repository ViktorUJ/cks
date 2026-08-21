[Русская версия](ADR_RU.md) · [Versión en español](ADR_ES.md) · [Version française](ADR_FR.md) · [Deutsche Version](ADR_DE.md) · [ქართული ვერსია](ADR_GE.md) · [繁體中文版](ADR_TW.md) · [日本語版](ADR_JP.md)

# EKS Course Architecture Decisions (ADR)

[Course contents](README.md) · [Glossary](GLOSSARY.md)

## How to use this

An ADR (Architecture Decision Record) is a short record of one decision: why it was
chosen, which alternatives existed, and what the trade-offs are. The point is not
documentation for its own sake, but to avoid reopening the same argument a year later and
to let a new team member understand the rationale, not just the outcome.

The templates below are already populated with course material: the alternatives, their
benefits, and their costs come from the chapters, not from this document. However, the
**context, status, date, and decision itself are written by the engineer** for their own
project: the course does not know your cluster fleet, compliance requirements, or whether
you have a platform team.

A "rejected alternative" does not mean "bad." In almost every course decision point, both
alternatives are viable, and the rejected one becomes the right choice with different inputs
- that is what the "review conditions" field is for.

## Blank template

```markdown
## ADR-NN. Short decision title

Status: proposed / accepted / rejected / supersedes ADR-NN
Date: YYYY-MM-DD

**Context.** What is the task, what are the constraints, and which questions need to be answered?

**Alternatives considered.**

| Alternative | What it provides | Trade-offs | When it fits |
|---|---|---|---|
|  |  |  |  |

**Consequences of the decision.**

- What we gain:
- What we pay:

**Decision.** What was selected and at what scope (entire fleet, one cluster, pilot).

**Review conditions.** Specific triggers that reopen this record.

**References.** Course chapters and internal project documents.
```

## ADR-01. Compute: EKS Auto Mode versus a self-managed Karpenter stack

Status: _completed by the engineer_
Date: _completed by the engineer_

**Context.** Answer before choosing:

- is there a security requirement for the node image (an attested AMI, custom bootstrap);
- is node access needed for debugging or for node-level agents deployed as a DaemonSet;
- is a non-VPC CNI and control of the Karpenter controller itself needed, not just control of NodePool;
- how critical is cost: is the management surcharge on top of EC2 acceptable;
- is there a team prepared to operate nodes, or is the objective specifically minimal operations.

**Alternatives considered.**

| Alternative | What it provides | Trade-offs | When it fits |
|---|---|---|---|
| EKS Auto Mode | nodes as appliances: Bottlerocket, SELinux enforcing, read-only root, rotation no later than 21 days, built-in Karpenter, IPAM, network policy, EBS CSI, ELB, Pod Identity | a management surcharge on top of EC2 (not covered by Reserved Instance and Savings Plans discounts), no SSH or SSM, default NodePool and NodeClass cannot be changed, no alternative CNI | the goal is minimal node operations, with no image or node-access requirements |
| Self-managed stack: managed node groups or self-managed nodes plus your own Karpenter | custom launch template and AMI, node access, any CNI, full ownership of the Karpenter version and configuration | you operate nodes, add-ons, upgrades, and interruption handling; you pay only for EC2 | a requirement is not met by Auto Mode, or the economics cannot tolerate the surcharge |

**Consequences of the decision.**

- What we gain: one node operating model per cluster and a predictable division of
  responsibility between AWS and the team.
- What we pay: in Auto Mode, containers, cluster and VPC configuration, PVC-backed volumes,
  and load balancers remain your responsibility; custom NodePools do not inherit the default
  pools' restrictions, so instance limits and types must be specified manually or a pool can
  grow without a ceiling.

**Decision.** _complete for your project_

**Review conditions.** A requirement for an attested node image appears; a node-level agent
that cannot run as a sidecar is needed; Cilium is needed as the primary CNI; disruption
budgets begin blocking upgrades beyond the node lifetime; the fleet grows to a scale where
node-replacement bursts and the management surcharge are noticeable on the bill.

**References.** [chapter 9](09/en.md) - compute types, sections 9.6-9.8;
[chapter 10](10/en.md) - launch templates and custom AMIs; [chapter 12](12/en.md) - NodePool and
disruption; [chapter 43](43/en.md) - cost analysis.

## ADR-02. Pod identity: IRSA versus EKS Pod Identity

Status: _completed by the engineer_
Date: _completed by the engineer_

**Context.** Answer before choosing:

- how many clusters exist, and are roles moved between them;
- are there workloads on Fargate or Windows nodes;
- is identity outside EKS (EC2, ECS, Lambda) needed on the same roles;
- is cross-account access needed and in what form;
- what platform version do the existing clusters use.

**Alternatives considered.**

| Alternative | What it provides | Trade-offs | When it fits |
|---|---|---|---|
| IRSA | OIDC federation through STS, works outside EKS, direct cross-account access, supports Fargate and Windows nodes | an IAM OIDC provider per cluster, the trust policy must be rewritten per cluster, session tags are manual | Fargate, Windows, identity outside EKS, federation-based cross-account access |
| EKS Pod Identity | one trust policy for `pods.eks.amazonaws.com` across all clusters, association through the EKS API without annotations, session tags and ABAC out of the box | Amazon EC2 Linux nodes only; no Fargate, Windows, Outposts, or EKS Anywhere; requires the add-on agent and a minimum platform version | new clusters on EC2 nodes, a cluster fleet with reusable roles |

**Consequences of the decision.**

- What we gain: a single way to grant permissions to pods and one clear source of truth for
  where a role is bound to a ServiceAccount.
- What we pay: a mixed fleet requires maintaining both models; if both are configured on the
  same ServiceAccount, IRSA wins because web identity comes earlier in the SDK chain than the
  container provider, and the Pod Identity association is silently ignored.

**Decision.** _complete for your project_

**Review conditions.** Fargate profiles or Windows nodes are added to the fleet; a requirement
for ABAC based on session tags appears; Pod Identity restrictions are reduced in the
documentation; the same role is needed for workloads inside and outside EKS.

**References.** [chapter 16](16/en.md) - IRSA and the OIDC provider; [chapter 17](17/en.md) - Pod
Identity, comparison, and migration order.

## ADR-03. Networking: VPC CNI versus Cilium (chaining or full replacement)

Status: _completed by the engineer_
Date: _completed by the engineer_

**Context.** Answer before choosing:

- are L7 policies (HTTP, gRPC, Kafka) or policies by DNS name required, and who will write them;
- is Hubble-level observability of traffic between pods required;
- do real pod addresses in the VPC, security groups for pods, and pod-level Flow Logs matter;
- cannot IPv4 scarcity be resolved by other means;
- is the team prepared to own CNI upgrades and its compatibility with the cluster version.

**Alternatives considered.**

| Alternative | What it provides | Trade-offs | When it fits |
|---|---|---|---|
| VPC CNI with built-in NetworkPolicy | managed add-on, AWS support, standard upgrades, standard L3/L4 `NetworkPolicy` and administrative `ClusterNetworkPolicy`, real VPC addresses | no L7 rules, no FQDN-based policies, no Cilium CRDs or Hubble | L3/L4 isolation is needed and the VPC address model is suitable |
| Cilium in CNI chaining mode | `CiliumNetworkPolicy`, L7 and DNS policies, Hubble, while IPAM and VPC integrations remain with VPC CNI | self-managed Cilium installation and maintenance, a second CRD model, team training | L7 or DNS policies or Hubble are needed, while the address model is suitable |
| Cilium as a full replacement (ENI IPAM or cluster-pool) | custom IPAM, optional overlay and relief from IPv4 scarcity, ClusterMesh, replacement of kube-proxy with eBPF | you own upgrades and compatibility, AWS support is reduced; with an overlay, real pod addresses, security groups for pods, and pod addresses in Flow Logs are lost | an overlay or multicluster networking is needed, or requirements cannot be met by the ENI model |

**Consequences of the decision.**

- What we gain: an explicit boundary between what AWS support covers and what the platform
  team owns.
- What we pay: a CNI cannot be changed by flipping a flag; it is assigned to a pod when that
  pod is created, so the transition is blue/green through a new node pool or a new cluster;
  incident diagnosis moves into the CNI's tooling; also account for a policy-free window at
  pod startup (`NETWORK_POLICY_ENFORCING_MODE` in `standard` mode results in default allow).

**Decision.** _complete for your project_

**Review conditions.** A requirement for L7 or DNS-name policies appears; a map of traffic
between pods is needed; IPv4 scarcity can no longer be addressed with the measures in chapter
7; a shared Pod Network for multiple clusters is needed; iptables kube-proxy becomes a
bottleneck.

**References.** [chapter 8](08/en.md) - alternative CNIs, transition cost, and migration;
[chapter 6](06/en.md) - pod addressing through ENIs; [chapter 7](07/en.md) - address scarcity;
[chapter 30](30/en.md) - network policies in production.

## ADR-04. Node autoscaling: Cluster Autoscaler versus Karpenter

Status: _completed by the engineer_
Date: _completed by the engineer_

**Context.** Answer before choosing:

- is the cluster on Auto Mode or a self-managed stack (in Auto Mode, the question is settled because Karpenter is already included);
- how heterogeneous are the workloads and how many node groups will need to be maintained;
- is a fast response to traffic spikes required;
- is unification with clusters in other clouds using one tool required;
- is CA already installed, well-tuned, and actually causing a problem.

**Alternatives considered.**

| Alternative | What it provides | Trade-offs | When it fits |
|---|---|---|---|
| Cluster Autoscaler | works on top of an Auto Scaling group, one approach across many providers, familiar operations without new CRDs | acts at the group rather than pod level; the type set is fixed by the launch template; slower due to the ASG layer; removes empty nodes but does not consolidate | simple, predictable clusters; multicloud standardization; a working installation |
| Karpenter | calls EC2 directly, selects an instance type for specific pods, active consolidation, instance-type diversification for spot | custom `NodePool` and `EC2NodeClass` CRDs, ownership of the controller version and configuration, AWS-first | new EKS clusters, heterogeneous workloads, a need for speed and dense packing |

**Consequences of the decision.**

- What we gain: one mechanism responsible for creating and removing nodes, and one place to
  define fleet limits.
- What we pay: operating both at once is acceptable only on different sets of nodes and only
  as a temporary migration mode; otherwise they compete over scale-down decisions; migration
  proceeds through new nodes, not by moving pods on a live node.

**Decision.** _complete for your project_

**Review conditions.** The node-group sprawl grows and becomes unmanageable; idle capacity due
to poor packing becomes noticeable on the bill; response to traffic spikes no longer meets
the SLO; the cluster moves to Auto Mode; clusters in other clouds appear with a requirement
for a single tool.

**References.** [chapter 11](11/en.md) - approach comparison and selection checklist;
[chapter 12](12/en.md) - NodePool, consolidation, and disruption budgets;
[chapter 13](13/en.md) - spot; [chapter 9](09/en.md) - the relationship with Auto Mode.

## ADR-05. GitOps for a cluster fleet: hub-and-spoke versus decentralization

Status: _completed by the engineer_
Date: _completed by the engineer_

**Context.** Answer before choosing:

- how many clusters are in the fleet now and how many are expected;
- is cluster autonomy required if the hub or connectivity to it is lost;
- is a single overview dashboard for the whole fleet needed;
- who updates the agents, and is the team prepared for their versions to diverge;
- what is the cost of reconciliation traffic across cluster boundaries.

**Alternatives considered.**

| Alternative | What it provides | Trade-offs | When it fits |
|---|---|---|---|
| Hub-and-spoke | one Argo CD or Flux instance on the hub; no agent needs to be installed in every cluster; an ApplicationSet with cluster and git generators through a matrix deploys an add-on set to the whole fleet; a unified view | the hub is a failure domain: workloads on spokes continue running, but commit application, self-healing, and rollbacks stop across the fleet; reconciliation over the network adds latency, egress charges, and connectivity sensitivity | a small or medium fleet where operational simplicity and a unified view are valued |
| Hub sharding | clusters are distributed among application-controller replicas; the replica count is duplicated in `ARGOCD_CONTROLLER_REPLICAS` | one failure domain remains; hash-based distribution is uneven, round-robin is more balanced | the fleet has outgrown one controller, but cluster autonomy is not required |
| Decentralization | the hub deploys only the foundation and a local agent; after that, each cluster pulls from Git itself and remains autonomous if the hub is lost | there are as many agents as clusters, and they must be upgraded and configured; there is no unified dashboard; agent versions diverge | a large fleet or a strict autonomy requirement |
| argocd-agent | one central Argo CD instance sees the `Application` resources of all clusters, while the agent on the spoke side pulls synchronization | an `argoproj-labs` project, incubating rather than part of Argo CD core; the topology remains hub-and-spoke | the team is prepared to use an incubating project for reverse flow |

**Consequences of the decision.**

- What we gain: a clear answer to the question, "what happens to delivery if the hub is unavailable?"
- What we pay: the boundary between IaC and GitOps remains mandatory in every topology -
  infrastructure (VPC, cluster, node groups, IAM) goes through Terraform, while add-ons and
  workloads go through GitOps; mixing them results either in recreating a cluster to change a
  Deployment, or in a chicken-and-egg problem with an agent that lives in the same cluster.

**Decision.** _complete for your project_

**Review conditions.** The fleet grows enough that one controller cannot cope; a requirement
to continue reconciliation when the hub is lost appears; reconciliation egress charges become
noticeable; argocd-agent graduates from incubation.

**References.** [chapter 44](44/en.md) - fleet topologies, section 44.6;
[chapter 32](32/en.md) - cluster fleets; [chapter 4](04/en.md) - IaC and Terraform;
[chapter 31](31/en.md) - traffic cost; [chapter 38](38/en.md) - blue/green migration.

## What is deliberately not decided here

The course does not consider some decision points architectural: their technical merits are
roughly equal, and the company context decides. The choice between Argo CD and Flux is a
question of what the team already knows how to use and which interface it needs, not a
property of the tools. The choice between self-managed Prometheus and a managed service is a
question of who is on call and what storage costs, not the architecture of metrics
collection. The same applies to the image registry, secrets tool, and account layout: these
are organizational boundaries. A consolidated list of what to check before production is in
[chapter 48](48/en.md).
