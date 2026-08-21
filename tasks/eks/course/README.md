[Русская версия](README_RU.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# Amazon EKS: a practical self-study guide to production operations

A practical Amazon EKS course tied to the labs in `tasks/eks/labs`. The course is
intended for engineers who have **already completed CKA** (or are confidently
proficient with Kubernetes at the administrator level) and are moving to a managed
cluster in AWS.

There is no separate EKS certification, so this course is built not around an exam
but around real operations: the responsibilities of an engineer when AWS operates
the control plane while nodes, networking, access, cost, and upgrades remain yours.

> **Prerequisites.** Pods, Deployments, Services, Ingress, RBAC, PV/PVC, probes,
> kubectl, and workload troubleshooting are the CKA course foundation and are not
> repeated here. If you do not yet have these topics under your belt, start with the
> [CKA + CKAD course](../../cka/course/README.md).

> **Versions.** The course targets current EKS versions (Kubernetes `1.33` to
> `1.36`). EKS has its own version lifecycle: 14 months of standard support plus
> 12 months of extended support (26 months per minor version), so the upgrade
> chapter focuses on the process rather than a specific version number. Course labs
> deploy the version from each lab's `env.hcl`.

## How the course is organized

Each topic is a numbered folder. It contains localized files. The primary language
is Russian (`ru.md`), from which translations will be made (as in the CKA and Istio
courses). A language switcher appears on the first line of each file after its first
translation.

The course requires **your own AWS account**: almost every topic can be verified
only on a live cluster, and some of them (Spot interruptions, NAT and traffic,
upgrades, and cost) cannot be reproduced in local kind. Labs are deployed through
Terragrunt and removed with one command so that you do not burn money.

Besides chapters and labs, the course has working reference guides. Do not read
them sequentially; use them when needed:

- [Course glossary](GLOSSARY.md) - all chapter terms with links
- [Troubleshooting reference](RUNBOOK.md) - symptom, cause, check: Part 8 summarized
- [Architecture decision records (ADRs)](ADR.md) - decision templates for course branches
- [EKS maturity scorecard](SCORECARD.md) - cluster readiness questionnaire across eight domains
- [Cost model](COST_MODEL.md) - cost items and formulas; supply your own rates

## Contents

### Part 0. AWS fundamentals (optional)

A preparatory section for those arriving with strong Kubernetes skills and limited
AWS experience. If IAM, VPC, and EC2 are familiar tools, proceed directly to Part 1.
This part has no separate labs: it exists so that you can read the remaining chapters
without gaps.

- 0.1. [AWS for the Kubernetes engineer: accounts, Regions, AZs, quotas, tags, billing](00-1-aws/en.md)
- 0.2. [IAM from scratch: policies, roles, trust, STS, and temporary credentials](00-2-iam/en.md)
- 0.3. [VPC from scratch: subnets, routing, IGW and NAT, security groups, VPC endpoints](00-3-vpc/en.md)
- 0.4. [EC2 and pricing models: instance types, AMIs, On-Demand, Spot, Savings Plans](00-4-ec2/en.md)
- 0.5. [Tools: AWS CLI, eksctl, Terraform and Terragrunt, Helm, useful plugins](00-5-tools/en.md)

### Part 1. Cluster architecture and creation

1. [Introduction: what EKS handles and what remains your responsibility](01/en.md)
2. [EKS control plane: public and private endpoints, platform versions, SLA, logs](02/en.md)
3. [Version lifecycle: standard and extended support, upgrade strategy](03/en.md)
4. [Creating a cluster: eksctl, Terraform and Terragrunt, CloudFormation](04/en.md) 🧪
5. [Cluster access: IAM and RBAC, access entries, migration from aws-auth](05/en.md)
6. [Cluster networking: VPC CNI, ENIs and IP addresses, CIDR planning](06/en.md) 🧪
7. [Scaling the address plan: prefix delegation, secondary CIDRs, custom networking](07/en.md)
8. [VPC CNI alternatives: Cilium, networking modes, when to change the CNI](08/en.md) 🧪

### Part 2. Nodes and compute

9. [Compute types: managed node groups, self-managed nodes, Fargate, Auto Mode](09/en.md) 🧪
10. [AMIs and bootstrap: AL2023, Bottlerocket, launch templates, kubelet, and user data](10/en.md) 🧪
11. [Cluster Autoscaler and Karpenter: two approaches to node scaling](11/en.md)
12. [Karpenter: NodePool, EC2NodeClass, disruption, consolidation, drift](12/en.md)
13. [Spot Instances: interruptions, diversification, event handling](13/en.md)
14. [Density and sizing: pods per node, ENI limits, requests and limits in the cloud](14/en.md)
15. [Fargate: profiles, limitations, cost, use cases](15/en.md)

### Part 3. Identity and security

16. [IRSA: OIDC provider, trust policy, ServiceAccount annotations](16/en.md)
17. [EKS Pod Identity: agent, associations, migration from IRSA](17/en.md)
18. [Secrets: KMS encryption, Secrets Manager and SSM through External Secrets and CSI](18/en.md)
19. [Hardening: IMDSv2 and hop limit, Pod Security Admission, private cluster](19/en.md)
20. [Images and supply chain: ECR, scanning, signatures, pull-through cache](20/en.md) 🧪
21. [Audit and detection: control plane logs, CloudTrail, GuardDuty, runtime monitoring](21/en.md)
22. [Policies and multi-tenancy: Kyverno and Gatekeeper, team isolation](22/en.md) 🧪

### Part 4. Data storage

23. [EBS CSI: gp3, StorageClass, expansion, snapshots, AZ affinity](23/en.md)
24. [EFS and FSx: shared storage for workloads across AZs](24/en.md)
25. [S3 in applications: Mountpoint for Amazon S3 CSI and access patterns](25/en.md) 🧪

### Part 5. Networking and traffic

26. [AWS Load Balancer Controller and LoadBalancer Services: NLB](26/en.md)
27. [Ingress through ALB: target-type, annotations, TLS and ACM, WAF](27/en.md)
28. [Gateway API on AWS: ALB Gateway API and VPC Lattice](28/en.md) 🧪
29. [DNS and certificates: external-dns, Route 53, cert-manager](29/en.md)
30. [NetworkPolicy in EKS: VPC CNI network policy and Cilium](30/en.md)
31. [Egress and traffic cost: NAT, VPC endpoints, PrivateLink](31/en.md)
32. [Multi-cluster and multi-account: connectivity, shared resources, patterns](32/en.md)

### Part 6. Observability

33. [Metrics: Container Insights, Managed Prometheus and Grafana, kube-prometheus-stack](33/en.md)
34. [Logs: Fluent Bit, CloudWatch Logs, OpenSearch, cost control](34/en.md)
35. [Application autoscaling: HPA, external metrics, KEDA](35/en.md) 🧪
36. [Tracing and profiling: ADOT and X-Ray](36/en.md)

### Part 7. Operations

37. [EKS add-ons: managed add-ons versus Helm, versions and upgrade order](37/en.md)
38. [Cluster upgrades: in-place version upgrades, blue/green clusters, deprecated APIs](38/en.md)
39. [Cluster version rollback: rollback readiness insights, the 7-day window, rollback order](39/en.md)
40. [Reliability: multi-AZ, PDBs, topology spread, graceful node shutdown](40/en.md) 🧪
41. [Cluster backup with AWS Backup: cluster state, persistent volumes, composite recovery point](41/en.md) 🧪
42. [Recovery and DR: restore to an existing or new cluster, namespace restore, Velero](42/en.md) 🧪
43. [Cost: OpenCost and Kubecost, right-sizing, Savings Plans, Spot mix, traffic](43/en.md)
44. [GitOps and delivery: Argo CD and Flux, fleet management](44/en.md) 🧪

This part has two reference guides: the [cost model](COST_MODEL.md), an assessment
form for chapter 43, and [architecture decision records](ADR.md), ADR templates for
decision branches throughout the course.

### Part 8. Troubleshooting

45. [A node did not join the cluster: IAM, SG, user data, bootstrap, kubelet](45/en.md)
46. [Networking failures: ENI exhausted, SG and NACL, DNS, unhealthy targets in the load balancer](46/en.md) 🧪
47. [Access and IAM: access entries, IRSA and Pod Identity, webhook, kubeconfig](47/en.md) 🧪

The "Diagnostic procedure" sections of these three chapters are consolidated in the
[troubleshooting reference](RUNBOOK.md): symptom, likely cause, and what to check.
It is more convenient to open it on call instead of three chapters.

### Part 9. Final

48. [EKS production checklist and what to read next](48/en.md)

The chapter 48 checklists are available as a scored questionnaire with a technical
debt list in the [EKS maturity scorecard](SCORECARD.md).

## Practice

The course has its own set of labs numbered `101+`, tied to chapters. Labs deploy in
your AWS account through Terragrunt, are checked automatically with `check_result`,
and are removed with one command:

- 🧪 [EKS labs](../../../docs/labs.MD#eks-labs) - lab list and launch commands

The course lab set is currently in progress. The 🧪 icon in the table of contents
means that the chapter already has its own lab; chapters without the icon are
currently theory only.

The repository also has earlier standalone EKS labs ([Karpenter](../labs/02/README.MD),
[autoscaling with KEDA and Prometheus](../labs/03/README.MD)). They are not part
of the course and have their own lifecycle, but their topics overlap with chapters 12
and 35, so you can complete them as additional practice.

## What to read next

- [Amazon EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/) -
  the primary source for versions, add-ons, and limits.
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) -
  official recommendations for networking, security, reliability, and cost.
- [EKS Workshop](https://www.eksworkshop.com/) - free interactive modules from AWS.
- [AWS Backup: EKS backup and restore](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) -
  documentation for backing up cluster state and persistent volumes.
- [From Spot.io to Karpenter](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) -
  our analysis of production node-management migration.
