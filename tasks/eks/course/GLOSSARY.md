[Русская версия](GLOSSARY_RU.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# EKS Course Glossary

[Course contents](README.md)

A single alphabetical reference to course terms. Terms remain in English where AWS or Kubernetes use English; descriptions are in English. The "Chapters" column identifies where each term is covered, with links to the relevant chapters. Search this page with Ctrl+F.

| Term | Description | Chapters |
|--------|----------|-------|
| **ABAC / RBAC** | Tag-based access through `aws:PrincipalTag`, versus access granted by roles and policies with specific actions and resources. | [0.2](00-2-iam/en.md) |
| **Access entry** | A cluster access configuration record that maps an IAM principal to `username` and `kubernetesGroups`; `STANDARD` is for people and services, while `EC2_LINUX`, `EC2_WINDOWS`, `FARGATE_LINUX`, `HYBRID_LINUX`, and `EC2` are for nodes. | [01](01/en.md), [05](05/en.md), [47](47/en.md) |
| **access entry of type `EC2_LINUX`** | An entry that authorizes a node-role ARN in the cluster. | [45](45/en.md) |
| **access point** | An EFS subdirectory entry point with its own permissions and POSIX identity; the basis for dynamic provisioning and directory isolation. | [24](24/en.md) |
| **Access policy** | An AWS-managed Kubernetes-level permissions policy associated with an access entry; it contains verbs and resources rather than IAM permissions and cannot be edited. | [05](05/en.md), [47](47/en.md) |
| **Access scope** | The scope of an access policy: `cluster` or `namespace` with a list. | [05](05/en.md) |
| **ACM (AWS Certificate Manager)** | Certificates that live on the load balancer; the private key cannot be exported and renewal is automatic. | [27](27/en.md), [29](29/en.md) |
| **actions / conditions** | Annotations for custom actions (redirect, fixed-response, weighted forward) and additional routing conditions (headers, method, query, source IP). | [27](27/en.md) |
| **Admission webhook** | An external handler that the API server calls before writing an object to etcd; mutating changes the object, while validating only accepts or rejects it. | [22](22/en.md) |
| **ADOT** | AWS Distro for OpenTelemetry: AWS's OTel distribution (SDKs, agents, Collector). | [36](36/en.md) |
| **ALIAS** | A Route 53 record for an AWS resource (for example, ELB); it works at a domain apex, where CNAME is prohibited, and is not billed as a separate query. | [29](29/en.md) |
| **Allocatable** | Resources left for pods after `kube-reserved`, `system-reserved`, and the eviction threshold; this is what the scheduler considers. | [14](14/en.md) |
| **`allowVolumeExpansion`** | A StorageClass flag that allows volume expansion by growing the PVC. | [23](23/en.md) |
| **Amazon EKS** | Managed Kubernetes in AWS: AWS operates the control plane, while you operate the nodes and supporting infrastructure. | [01](01/en.md) |
| **Amazon Managed Grafana (AMG)** | Managed Grafana; it connects AMP as a data source, with user access through IAM Identity Center. | [33](33/en.md) |
| **Amazon Managed Service for Prometheus (AMP)** | A managed Prometheus-compatible backend; workspace, remote-write, PromQL, and retention are managed by AWS. | [33](33/en.md) |
| **amazon-cloudwatch-observability** | An EKS managed add-on that installs the CloudWatch agent and enables Container Insights with enhanced observability. | [33](33/en.md) |
| **AMI (Amazon Machine Image)** | An instance disk template containing the kernel, filesystem, and software; nodes use an EKS-optimized image with aligned `kubelet`, `containerd`, and bootstrap logic. | [0.4](00-4-ec2/en.md), [10](10/en.md) |
| **API Priority and Fairness** | A Kubernetes mechanism that distributes concurrent-request capacity among request types; a client receives `429` when capacity is exhausted. | [02](02/en.md) |
| **app-of-apps** | A parent `Application` that deploys a set of child applications. | [44](44/en.md) |
| **Application** | An Argo CD CRD that binds a Git source to a target cluster and namespace. | [44](44/en.md) |
| **Application Load Balancer (ALB)** | An L7 (HTTP/HTTPS) load balancer with host and path routing, TLS termination, WAF, and authentication; in EKS, LBC creates it from Ingress. | [27](27/en.md) |
| **ApplicationSet** | An Argo CD controller that generates `Application` resources from a template; the cluster generator creates one for every connected cluster, the git generator creates them from directories or files in Git, and the matrix generator combines two generators (cluster + git). | [44](44/en.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`, the address of a resource. | [0.1](00-1-aws/en.md) |
| **`AssumeRoleWithWebIdentity`** | An STS operation that exchanges a web identity token for temporary IAM role credentials. | [16](16/en.md) |
| **auditID** | A unique request identifier in the audit log; it is the same for every stage of one operation. There is no common ID with CloudTrail, so correlate sources by principal, IP, and time. | [21](21/en.md) |
| **`authenticationMode`** | Cluster authentication mode: `CONFIG_MAP`, `API_AND_CONFIG_MAP`, or `API`; transitions are only toward `API`. | [04](04/en.md), [05](05/en.md), [47](47/en.md) |
| **`authenticationSource`** | The source of volume credentials: `driver` (the driver's shared role) or `pod` (the pod service account's role). | [25](25/en.md) |
| **Availability Zone (AZ)** | An isolated group of data centers in a Region and the primary failure domain for replica placement. | [0.1](00-1-aws/en.md), [40](40/en.md) |
| **AWS Backup** | Central AWS backup service for EKS, EBS, EFS, S3, and other resources under common plans and vaults. | [41](41/en.md) |
| **aws cli v2** | The primary CLI for AWS; configuration is in `~/.aws/config`, and access is selected with `--profile` or `AWS_PROFILE`. | [0.5](00-5-tools/en.md) |
| **AWS Control Tower** | A ready-made AWS landing zone with controls (preventive, detective, proactive), drift detection, and account factory. | [0.1](00-1-aws/en.md) |
| **`aws eks get-token`** | An `exec` plugin in kubeconfig that creates a presigned STS token for cluster access. | [47](47/en.md) |
| **AWS Gateway API Controller** | The `aws-application-networking-k8s` controller with GatewayClass `amazon-vpc-lattice`; it translates Gateway API resources into VPC Lattice objects. | [28](28/en.md) |
| **AWS Load Balancer Controller (Gateway API)** | An implementation with `controllerName` `gateway.k8s.aws/alb` (ALB, L7) and `gateway.k8s.aws/nlb` (NLB, L4). | [28](28/en.md) |
| **AWS Load Balancer Controller (LBC)** | An in-cluster controller that creates NLBs for LoadBalancer Services and ALBs for Ingress; it is installed with Helm and requires IAM roles. | [26](26/en.md) |
| **AWS Organizations** | Multi-account management with an OU hierarchy, shared policies (SCPs), and consolidated billing. | [0.1](00-1-aws/en.md), [32](32/en.md) |
| **AWS PrivateLink** | A mechanism for private access to AWS services and services in other accounts through an interface endpoint. | [31](31/en.md) |
| **AWS RAM (Resource Access Manager)** | A service for sharing resources (subnets, Transit Gateway, VPC Lattice service networks, Route 53 Resolver rules) with other accounts and the organization. | [0.1](00-1-aws/en.md), [32](32/en.md) |
| **`aws sts get-caller-identity`** | The “who am I” command: account, ARN, and userId. | [0.5](00-5-tools/en.md) |
| **AWS X-Ray** | A managed trace backend with storage, service map, latency breakdown, and trace search. | [36](36/en.md) |
| **`aws-auth` ConfigMap** | A legacy mapping mechanism through an object in `kube-system` with `mapRoles` and `mapUsers` fields. | [05](05/en.md), [45](45/en.md), [47](47/en.md) |
| **aws-for-fluent-bit** | An AWS-built Fluent Bit image with built-in output plugins for AWS services. | [34](34/en.md) |
| **`aws-vault`** | Stores credentials in a keychain and runs commands in a temporary session. | [0.5](00-5-tools/en.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | Disables node SNAT for pod egress (`true`) so the external side sees the pod's real address; Internet egress then goes only through the NAT gateway. | [07](07/en.md) |
| **`AWSTraceHeader`** | An SQS system message attribute for the X-Ray trace header; a way to carry context across an asynchronous boundary where headers do not exist. | [36](36/en.md) |
| **backend-protocol-version** | The target group's application protocol: `HTTP1`, `HTTP2`, or `GRPC`; required for ALB to proxy gRPC and HTTP/2 to pods rather than HTTP/1.1. | [27](27/en.md) |
| **backup plan** | A backup plan: schedule, retention, lifecycle (transition to cold storage), and resource assignment. | [41](41/en.md) |
| **backup vault** | Storage for recovery points with a KMS key and access policy; Vault Lock is enabled on it. | [41](41/en.md) |
| **BackupStorageLocation (BSL)** | The location for Velero backups (an S3 bucket). | [42](42/en.md) |
| **bake period** | A pause between the control plane and node upgrades: nodes remain on N-1 and rollback is available without reverting them. | [39](39/en.md) |
| **Basic / Enhanced scanning** | ECR CVE-scanning modes: basic scans OS packages natively; enhanced continuously scans OS and language packages through Amazon Inspector. | [20](20/en.md) |
| **behavior / stabilizationWindowSeconds** | An HPA section that smooths scaling speed and fluctuations through stabilization windows and policies. | [35](35/en.md) |
| **bin packing** | Packing pods onto nodes according to their requests. | [14](14/en.md) |
| **blue/green cluster** | A new cluster on the target version alongside the old one, with workload migration and traffic switching. | [03](03/en.md), [38](38/en.md) |
| **bootstrap.sh** | A kubelet configuration script for AL2 from user data. | [45](45/en.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | An access-configuration field at creation; when `true` (the default), the cluster creator receives administrator permissions in it. | [04](04/en.md), [05](05/en.md) |
| **Bottlerocket** | A minimal OS for containers: read-only root, whole-image updates, API management, and control and admin containers instead of open SSH. | [10](10/en.md) |
| **Burstable (T series)** | A baseline CPU share plus CPU credits; not suitable for production nodes. | [0.4](00-4-ec2/en.md) |
| **Capacity** | The full capacity of an instance in CPU, memory, and pods. | [14](14/en.md) |
| **Capacity Blocks** | Reserved GPU/Trainium capacity for training. | [0.4](00-4-ec2/en.md) |
| **capacity type** | The node capacity type (`spot`/`on-demand`); labels `karpenter.sh/capacity-type` and `eks.amazonaws.com/capacityType`. | [13](13/en.md) |
| **CapacityProvisioned** | A pod annotation with the actually provisioned vCPU and memory combination after rounding; it determines the cost. | [15](15/en.md) |
| **cert-manager** | A controller that issues certificates inside the cluster as `Secret` resources; ClusterIssuer or Issuer specifies the source. | [29](29/en.md) |
| **CFS throttling** | Container slowdown after it exceeds its CPU limit. | [14](14/en.md) |
| **chargeback** | Costs are actually charged to the team's budget. | [43](43/en.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | Cilium CRDs with L7 and FQDN rules and a cluster-wide scope. | [08](08/en.md), [30](30/en.md) |
| **CloudTrail** | The AWS API-call log; for EKS it records operations on the cluster as an AWS resource (management events), not events inside Kubernetes. | [21](21/en.md) |
| **CloudWatch Application Signals** | APM on top of OTel (SLOs, latency, errors), enabled by the `amazon-cloudwatch-observability` add-on. | [36](36/en.md) |
| **CloudWatch Logs** | AWS log storage; log groups and log streams, Logs Insights queries, and charges for ingestion and storage. | [34](34/en.md) |
| **CloudWatch Logs Insights** | A log query language (`fields`, `filter`, `sort`, `stats`); the primary tool for investigating the audit log. | [21](21/en.md) |
| **Cluster Autoscaler (CA)** | A node autoscaler that works on top of an Auto Scaling group: it changes group `desiredSize` based on unschedulable pods and underutilization. Instance types are fixed by the group's launch template. | [11](11/en.md) |
| **cluster creator admin** | The IAM principal that created the cluster automatically receives administrator access. | [47](47/en.md) |
| **Cluster endpoint** | The cluster's Kubernetes API address. A public endpoint is accessible from the Internet and restricted only by a CIDR list; a private endpoint is accessible from the VPC and restricted by the cluster security group. | [01](01/en.md), [02](02/en.md) |
| **Cluster insights** | Automatic EKS cluster checks; `UPGRADE_READINESS` is for upgrade readiness, while `ROLLBACK_READINESS` is for the ability to roll back and is available for 7 days. | [03](03/en.md), [38](38/en.md) |
| **Cluster security group** | A group automatically created for the cluster and attached to these interfaces and managed node group nodes. | [02](02/en.md), [45](45/en.md) |
| **cluster version rollback** | Rolling back the EKS control plane to the prior minor version after an in-place upgrade, within a 7-day window, while retaining etcd, workloads, and volumes. | [03](03/en.md), [39](39/en.md) |
| **ClusterIssuer / Issuer** | cert-manager objects that describe the certificate source for the whole cluster or for a namespace. | [29](29/en.md) |
| **ClusterMesh** | Connecting the Pod Networks of several Cilium clusters through `clustermesh-apiserver`; unique `cluster-id` values and non-overlapping PodCIDRs are required. | [08](08/en.md) |
| **CMK (customer managed key)** | Your KMS key: unlike the default AWS owned key, it gives you control over the key policy and decryption auditing in CloudTrail. | [18](18/en.md) |
| **CNI chaining** | A mode in which VPC CNI assigns addresses and configures interfaces while Cilium adds policy and observability on top; `aws-node` remains. | [08](08/en.md), [30](30/en.md) |
| **`cni-metrics-helper`** | A component that scrapes `awscni_*` from `aws-node` pods and sends aggregates to CloudWatch. | [06](06/en.md) |
| **composite recovery point** | A composite point for EKS that groups cluster state and volume backups as one unit. | [41](41/en.md) |
| **Compute Savings Plans** | An hourly spending commitment for 1–3 years in exchange for a discount, flexible across instance families, Region, and Fargate/Lambda; the commitment is hourly, does not carry between hours, does not apply to Spot, and its use is shown by Savings Plans utilization (used) and coverage (covered) reports in Cost Explorer. | [43](43/en.md) |
| **Compute SP / EC2 Instance SP** | A flexible plan (EC2, Fargate, Lambda) / a deeper discount limited to one family in a Region. | [0.4](00-4-ec2/en.md) |
| **configurationValues** | An add-on field for declarative configuration without manually editing manifests. | [37](37/en.md) |
| **connection draining** | Draining active connections when a target is deregistered; `deregistration_delay.timeout_seconds` (default 300). | [40](40/en.md) |
| **conntrack** | The node kernel's connection table; new connections are dropped when it is full. | [46](46/en.md) |
| **Consolidated billing** | The organization's combined bill; volume discounts and Savings Plans apply to all accounts. | [0.1](00-1-aws/en.md) |
| **Consolidation** | Voluntary consolidation for cost; `WhenEmpty` and `WhenEmptyOrUnderutilized` policies, empty/single/multi-node methods, and the `consolidateAfter` parameter. | [11](11/en.md), [12](12/en.md) |
| **Container Insights** | CloudWatch monitoring for EKS: an agent collects node and pod metrics, with dashboards and alarms in CloudWatch. | [33](33/en.md) |
| **ContainerResource** | An HPA metric type that calculates utilization for one pod container rather than all of them together; useful where a sidecar dilutes the application metric. | [35](35/en.md) |
| **context propagation** | Passing a `trace id` between services through headers (W3C Trace Context), so that the trace is not broken. | [36](36/en.md) |
| **continuous profiling** | Continuous collection of CPU and memory hotspots in code; in AWS, Amazon CodeGuru Profiler; eBPF profilers include Pyroscope and Parca. | [36](36/en.md) |
| **Control plane** | API server, scheduler, controller manager, and etcd; in EKS, they run in the AWS account outside your VPC and are not visible in `kubectl get pods -n kube-system`. | [01](01/en.md) |
| **control plane logging** | Delivery of EKS control plane logs (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`) to CloudWatch Logs. | [34](34/en.md) |
| **core add-ons** | `vpc-cni`, `kube-proxy`, and `coredns`: the required core installed for every cluster. | [37](37/en.md) |
| **cost allocation** | Allocating AWS resource cost to Kubernetes objects (namespace, Deployment, label) by consumption or requests. | [43](43/en.md) |
| **cost allocation tags** | AWS tags for breaking down the bill; user-defined tags must be activated in the Billing console. | [43](43/en.md) |
| **Cost and Usage Report** | Detailed AWS billing in S3; reading it through Athena lets OpenCost/Kubecost compare allocation against the actual discounted bill. | [43](43/en.md) |
| **Cost Anomaly Detection** | An AWS service that uses ML to detect anomalous spending growth and sends alerts to email or SNS (Slack/Teams through AWS Chatbot). | [43](43/en.md) |
| **crash-consistent / application-consistent** | A snapshot without stopping writes versus one coordinated at the application level; only the former is available for EKS in AWS Backup. | [41](41/en.md) |
| **Cross-account ENI** | Network interfaces that EKS creates in your subnets for communication between the control plane and nodes, the kubelet API, webhooks, and OIDC. | [02](02/en.md) |
| **cross-AZ traffic** | Data transfer between Availability Zones; charged for data transfer, normally in both directions. | [31](31/en.md) |
| **cross-zone load balancing** | A load-balancer mode that distributes traffic across targets in all zones; it balances load more evenly but increases cross-AZ traffic. | [31](31/en.md) |
| **Custom networking** | A mode where secondary ENIs and pod addresses are taken from the subnet and security groups in an `ENIConfig`, one per AZ, selected using a label from `ENI_CONFIG_LABEL_DEF`. | [07](07/en.md) |
| **custom.metrics.k8s.io** | The API for custom cluster-object metrics for HPA (Pods, Object). | [35](35/en.md) |
| **Data Firehose** | A managed stream buffer and router to S3, OpenSearch, and other destinations. | [34](34/en.md) |
| **Data plane** | Your nodes and everything that runs on them. | [01](01/en.md) |
| **Delegated administrator** | An organization account that manages GuardDuty/Security Hub for the entire organization and sees findings from all members; assigned per Region. | [0.1](00-1-aws/en.md), [21](21/en.md) |
| **`deletionProtection`** | A flag that prevents cluster deletion. | [04](04/en.md) |
| **deprecated / removed API** | An `apiVersion` is declared deprecated and then removed; manifests using it cannot be applied after removal. | [38](38/en.md) |
| **describe-addon-versions** | An EKS API operation that returns add-on versions, their Kubernetes minor-version compatibility, and `defaultVersion`. | [37](37/en.md) |
| **`describe-target-health`** | A command that shows the state and reason for target group targets. | [46](46/en.md) |
| **Digest** | The `sha256` hash of image content, an immutable identifier; deployment by digest guarantees that the exact built artifact runs, unlike a movable tag. | [20](20/en.md) |
| **Disruption budget** | A limit on the rate of voluntary disruptions: a fraction/number of nodes, windows defined by `schedule` and `duration`, and binding to `reasons`. | [12](12/en.md) |
| **DNS-01** | An ACME method for verifying domain ownership through a TXT record; cert-manager creates it in Route 53. | [29](29/en.md) |
| **Drift** | A node's divergence from the desired state (a new AMI, changed selectors, or `requirements`); handled before consolidation. | [12](12/en.md) |
| **Dual-stack** | A VPC and subnets with IPv4 and IPv6 (`/56` and `/64`); IPv6 mode removes the shortage of pod addresses. | [0.3](00-3-vpc/en.md) |
| **EBS / instance store** | A network volume in one AZ / ephemeral local NVMe storage. | [0.4](00-4-ec2/en.md) |
| **EBS CSI driver** | `aws-ebs-csi-driver`, a managed add-on with the `ebs.csi.aws.com` provisioner; manages the EBS volume lifecycle. | [23](23/en.md) |
| **EC2NodeClass** | A CRD (`karpenter.k8s.aws/v1`) with AWS settings: AMIs, an IAM role, subnets and SGs, disks, and IMDS. | [12](12/en.md) |
| **ECR** | AWS's managed OCI image registry; a private registry per account and Region at `<account-id>.dkr.ecr.<region>.amazonaws.com` and the public `public.ecr.aws`. | [20](20/en.md) |
| **EFS** | Amazon Elastic File System, a managed regional NFS with elastic capacity and ReadWriteMany mode. | [24](24/en.md) |
| **EFS CSI driver** | `aws-efs-csi-driver`, a managed add-on with the `efs.csi.aws.com` provisioner; operates on top of a pre-created file system. | [24](24/en.md) |
| **EKS audit log** | A control-plane log type (`audit`): Kubernetes audit JSON events recording who performed which verb on which resource, from where, and with what result; written to CloudWatch Logs. | [21](21/en.md) |
| **EKS authenticator** | A control-plane webhook that validates a presigned STS token and maps an IAM identity to a Kubernetes subject. | [47](47/en.md) |
| **EKS Auto Mode** | A mode where AWS manages appliance nodes (Bottlerocket, read-only root, no SSH or SSM, 21-day lifetime), Karpenter scaling, and built-in networking, DNS, EBS CSI, and ELB. | [01](01/en.md), [09](09/en.md) |
| **EKS Cluster State** | Kubernetes object manifests (Secret, ConfigMap, StatefulSet, PVC, RBAC, CRD, and so on) plus cluster configuration. | [41](41/en.md) |
| **EKS Pod Identity** | A mechanism for assigning an IAM role to a pod through an agent on the node and the EKS API, without a cluster OIDC provider or a trust policy tied to a specific cluster. | [17](17/en.md), [47](47/en.md) |
| **EKS Pod Identity Agent** | The `eks-pod-identity-agent` add-on, running as a `DaemonSet` on nodes and serving pods temporary credentials through a local endpoint. | [17](17/en.md) |
| **EKS-optimized AMI** | An AWS image with node components at the required versions; families include AL2023, Bottlerocket, Windows, and the retiring AL2. | [10](10/en.md) |
| **eksctl** | The official EKS CLI; works through CloudFormation and is imperative. | [0.5](00-5-tools/en.md) |
| **enableNetworkPolicy** | A VPC CNI managed add-on setting that enables enforcement of standard NetworkPolicy. | [30](30/en.md) |
| **Encryption at rest** | Encryption of ECR layers: SSE-S3 (AES-256) by default, optionally SSE-KMS with the `aws/ecr` key or a customer managed key; set at creation and immutable. | [20](20/en.md) |
| **endpoint service** | Publishing your own service (behind an NLB) as a PrivateLink target for consumers in other VPCs and accounts. | [31](31/en.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | Boolean access-mode flags; `true` and `false` by default. | [02](02/en.md) |
| **enforcer** | A CNI component that turns NetworkPolicy into actual traffic filters; absent in EKS by default until enabled. | [30](30/en.md) |
| **Enhanced subnet discovery** | Subnets tagged `kubernetes.io/role/cni=1` without `ENIConfig`. | [07](07/en.md) |
| **ENI** | Elastic network interface; the number of ENIs per instance and IPv4 addresses per ENI depend on the instance type. | [0.3](00-3-vpc/en.md), [06](06/en.md) |
| **Envelope encryption** | Two-key encryption: a DEK encrypts data and a KEK (a KMS key) encrypts the DEK. EKS uses it for etcd secrets through Kubernetes KMS provider v2. | [18](18/en.md) |
| **ephemeral ports** | The high range `1024-65535` used for return traffic; it must be allowed manually in an NACL. | [46](46/en.md) |
| **eviction threshold** | A memory buffer below which the kubelet evicts pods. | [14](14/en.md) |
| **kubeconfig exec plugin** | The `exec` section that invokes `aws eks get-token`; the file has no long-lived token, and `client-go` caches acquired credentials until `status.expirationTimestamp`. | [0.5](00-5-tools/en.md) |
| **Expander** | A Cluster Autoscaler strategy for selecting a node group when a pod fits several: `least-waste` (default), `priority`, `most-pods`, or `random`. | [11](11/en.md) |
| **Extended support** | The phase after standard support (about 12 months): the version is still supported, but at a higher per-cluster-hour charge; enabled by default. | [03](03/en.md), [38](38/en.md) |
| **External Secrets Operator (ESO)** | A controller that reads a secret from AWS and creates a native `Secret` from it; its objects are `SecretStore`/`ClusterSecretStore` and `ExternalSecret`. | [18](18/en.md) |
| **external-dns** | A controller that synchronizes DNS records at a provider with Kubernetes objects (Ingress, Service); it works with Route 53 in AWS. | [29](29/en.md) |
| **external.metrics.k8s.io** | The API for external metrics (queues, topics) for HPA (the External type). | [35](35/en.md) |
| **externalTrafficPolicy** | A Service policy: `Cluster` (forwarding to any node, SNAT) or `Local` (local pods only, preserving the client IP). | [26](26/en.md) |
| **`failed to assign an IP address to container`** | VPC CNI could not assign a pod an IP: the node or subnet ran out of addresses. | [46](46/en.md) |
| **failurePolicy** | The response to an unavailable webhook: `Fail` stops admission, while `Ignore` lets the object bypass validation. | [22](22/en.md) |
| **Fargate** | Running a pod in a dedicated micro-VM without nodes; no DaemonSet, privileges, `HostNetwork`, GPU, or node access. Charged by pod vCPU and memory. | [09](09/en.md) |
| **fargate-scheduler** | An EKS scheduler that runs alongside kube-scheduler and directs profile-matching pods to Fargate. | [15](15/en.md) |
| **Fargate profile** | A cluster-level object with selectors (a namespace plus optional labels), a pod execution role, and private subnets; determines which pods go to Fargate. It cannot be changed, only recreated. | [15](15/en.md) |
| **Finding** | A GuardDuty finding; sent to Security Hub and EventBridge for alerting and response. | [21](21/en.md) |
| **Fluent Bit** | A lightweight C log forwarder, run as a DaemonSet on every node; reads log files, enriches them, and sends them to destinations. | [34](34/en.md) |
| **Forbidden (403)** | An authorization failure: RBAC does not grant permission for the action. | [47](47/en.md) |
| **game day** | An exercise that tests DR and incident scenarios in practice. | [48](48/en.md) |
| **Gatekeeper** | A policy engine built on OPA; rules are written in Rego, using the `ConstraintTemplate` model (template plus schema) and a `Constraint` (instance). | [22](22/en.md) |
| **Gateway** | An entry point with listeners (protocol, port, TLS); owned by the platform team. In VPC Lattice, it maps to a Service Network. | [28](28/en.md) |
| **Gateway API** | A Kubernetes traffic-management standard and Ingress successor: a set of typed resources with separated roles. | [28](28/en.md) |
| **gateway endpoint** | A VPC endpoint type for S3 and DynamoDB through a route-table entry; free of charge. | [25](25/en.md), [31](31/en.md) |
| **GatewayClass** | An implementation template with the `controllerName` field; determines which controller handles a Gateway (analogous to IngressClass). | [28](28/en.md) |
| **GitOps** | A model in which desired state is described in Git and an agent continuously reconciles the cluster to it (principles formulated by OpenGitOps, a CNCF project). | [44](44/en.md) |
| **GitOps Toolkit** | A set of Flux controllers (source, kustomize, helm, image, and others). | [44](44/en.md) |
| **Golden image** | A reproducible custom image built on top of an optimized AMI through an image builder. | [10](10/en.md) |
| **graceful node shutdown** | A kubelet feature that terminates pods with a grace period when the OS stops. | [40](40/en.md) |
| **Grafana Loki** | A log store that indexes only stream labels; logs are compressed into chunks in object storage and queried with LogQL. Labels must be low-cardinality; structured metadata is available for high cardinality. Its native agent is Grafana Alloy (Promtail has been merged into it). | [34](34/en.md) |
| **`granted` (`assume`)** | Fast switching between SSO profiles and console sign-in. | [0.5](00-5-tools/en.md) |
| **Graviton** | AWS arm64 processors (the `g` suffix); require multi-arch images. | [0.4](00-4-ec2/en.md) |
| **GuardDuty EKS Protection** | Analyzes EKS audit logs for threats through GuardDuty's own independent stream, without requiring control-plane logging to be enabled. | [21](21/en.md) |
| **GuardDuty Runtime Monitoring** | Observes behavior on nodes through the `aws-guardduty-agent` (eBPF): processes, network, and files; does not support Fargate or Hybrid Nodes. | [21](21/en.md) |
| **Hard multi-tenancy** | Tenants in separate clusters/accounts; a hard boundary at the cost of complexity. | [22](22/en.md) |
| **HashiCorp Vault** | A non-AWS external secret store occupying the same role as Secrets Manager: pod authentication through Kubernetes, JWT/OIDC, or AWS IAM auth; delivery through Vault Agent Injector, Vault Secrets Operator, ESO, or CSI Driver with the Vault provider. | [18](18/en.md) |
| **head-based and tail-based sampling** | Deciding whether to record at ingress, before the request outcome, versus deciding at a gateway after assembling the trace (policies based on errors and latency). Tail-based requires all trace spans to arrive at one collector instance. | [36](36/en.md) |
| **helmfile** | A declarative description of a set of Helm releases with versions and values in one file. | [0.5](00-5-tools/en.md) |
| **hop limit (`httpPutResponseHopLimit`)** | The number of network hops for an IMDS response; at 1, a pod cannot reach IMDS while the node can. | [19](19/en.md) |
| **hosted zone** | A container for a domain's DNS records in Route 53; can be public (Internet) or private (associated with a VPC). | [29](29/en.md) |
| **HPA (HorizontalPodAutoscaler)** | A controller that changes the number of Deployment replicas based on a metric. | [35](35/en.md) |
| **HTTPRoute** | Routing rules by host, path, and headers to a backend; references a Gateway through `parentRefs`. In VPC Lattice, it maps to a VPC Lattice Service. | [28](28/en.md) |
| **hub-and-spoke** | A topology with a central Transit Gateway (hub) and team VPCs attached to it (spokes). | [32](32/en.md) |
| **Hubble** | Cilium's observability subsystem: a flow map and per-flow verdict, which VPC CNI network policy does not provide. | [08](08/en.md), [30](30/en.md) |
| **IAM Access Analyzer** | Finds external trusted entities (external access) in resource-based policies and trust policies. | [0.2](00-2-iam/en.md) |
| **IAM auth policy** | An IAM-format policy for authorizing traffic between services; in the controller, it is the `IAMAuthPolicy` resource. | [28](28/en.md) |
| **IAM database authentication** | Signing in to RDS or Aurora with a temporary token (`aws rds generate-db-auth-token`, 15 minutes by default) instead of a password; there is nothing to rotate. | [18](18/en.md) |
| **IAM Identity Center** | Single sign-on and access assignment through permission sets. | [0.1](00-1-aws/en.md) |
| **IAM OIDC identity provider** | An IAM object that registers the cluster issuer URL; role trust policies refer to it. Created once per cluster. | [16](16/en.md) |
| **IAM role** | An identity without permanent keys that is assumed temporarily. | [0.2](00-2-iam/en.md) |
| **IAM user / group** | A long-lived identity and a collection of such identities; avoided in production. | [0.2](00-2-iam/en.md) |
| **idle capacity** | The difference between paid-for node capacity and actual consumption; an indicator of excessive requests and poor bin-packing. | [43](43/en.md) |
| **image automation** | Flux controllers that commit new image tags back to Git. | [44](44/en.md) |
| **IMDS** | Instance Metadata Service at `169.254.169.254`; a source of metadata and node-role credentials. IMDSv1 has no token; IMDSv2 is session-based (`PUT` plus a token). | [0.2](00-2-iam/en.md), [0.4](00-4-ec2/en.md), [19](19/en.md) |
| **Immutable parameter** | A cluster parameter that cannot be changed after creation: `ipFamily`, custom `serviceIpv4Cidr`, VPC, cluster name, and IAM role. | [04](04/en.md) |
| **In-place upgrade** | Upgrading the same cluster to the next minor version: control plane, then add-ons, then nodes. | [03](03/en.md), [38](38/en.md) |
| **in-tree cloud provider** | AWS code built into Kubernetes components that creates a Classic Load Balancer by default for a Service of type LoadBalancer. | [26](26/en.md) |
| **in-tree provisioner** | The built-in `kubernetes.io/aws-ebs`, deprecated and without `gp3` or snapshots; the default `gp2` in EKS still uses it. | [23](23/en.md) |
| **IngressClass alb** | A class with the `ingress.k8s.aws/alb` controller; an Ingress with `ingressClassName: alb` is handled by AWS Load Balancer Controller. | [27](27/en.md) |
| **IngressGroup** | Combining multiple Ingresses with `group.name` into one shared ALB; `group.order` sets rule priority. | [27](27/en.md) |
| **INPUT / FILTER / OUTPUT** | The three types of Fluent Bit pipeline sections: reading, processing, and sending. | [34](34/en.md) |
| **`InsufficientCidrBlocks`** | An EC2 API error indicating a lack of contiguous blocks despite formally free addresses. | [07](07/en.md) |
| **Interface endpoint** | A PrivateLink-based VPC endpoint type: an ENI in a subnet, with an hourly charge plus data charges. | [31](31/en.md) |
| **Internet Gateway** | A free Internet gateway for public addresses. | [0.3](00-3-vpc/en.md) |
| **involuntary disruption** | Uncontrolled disruption: node/AZ failure, OOM, or Spot interruption; addressed by placement, not a PDB. | [40](40/en.md) |
| **ipamd** | A daemon inside `aws-node` that manages the node address pool: attaches secondary addresses and creates ENIs through the EC2 API. | [06](06/en.md) |
| **`ipFamily`** | The cluster address family, set only at creation. | [07](07/en.md) |
| **IRSA** | IAM Roles for Service Accounts: assigning an IAM role to a pod through an associated `ServiceAccount` based on OIDC federation. | [0.2](00-2-iam/en.md), [16](16/en.md), [47](47/en.md) |
| **Karpenter** | A node autoscaler that creates EC2 instances directly for specific unscheduled pods and selects types from the allowed range itself. | [11](11/en.md) |
| **KEDA** | An event-driven autoscaling extension: supplies metrics to HPA and manages it. | [35](35/en.md) |
| **`kms:CreateGrant`** | A permission without which the driver creates a volume with its CMK but cannot mount it: EBS encryption uses grants, and the permission is needed in the key policy too. | [23](23/en.md) |
| **krew** | A plugin manager: index, `search`, `install`, `upgrade`; supports custom indexes. | [0.5](00-5-tools/en.md) |
| **kube-prometheus-stack** | A Helm chart with Prometheus Operator, Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics. | [33](33/en.md) |
| **`kube-reserved` / `system-reserved`** | Resources reserved by the kubelet for Kubernetes and for the OS. | [14](14/en.md) |
| **kube-state-metrics** | A component that exposes Kubernetes object state (Pending, replicas, restarts) as metrics. | [33](33/en.md) |
| **Kubecost** | A product based on OpenCost with a UI, reports, and recommendations; EKS has an EKS-optimized bundle (add-on or Helm). | [43](43/en.md) |
| **`kubectl plugin list`** | What kubectl sees in `PATH`. | [0.5](00-5-tools/en.md) |
| **`kubeProxyReplacement`** | A Cilium mode where eBPF, rather than kube-proxy, balances Service/NodePort; `true` enables the replacement. Requires a modern kernel and ownership of load balancing. | [08](08/en.md) |
| **Kustomization / HelmRelease** | Flux CRDs: what and where to apply from a source. | [44](44/en.md) |
| **Kyverno** | A policy engine where a policy is a YAML resource (`ClusterPolicy`/`Policy`) with validate/mutate/generate/verifyImages rules; the action is `Enforce`/`Audit`. | [22](22/en.md) |
| **Landing zone** | A preconfigured multi-account structure (management, shared services, environments, teams); deployed, among other ways, through AWS Control Tower. | [0.1](00-1-aws/en.md), [32](32/en.md) |
| **Launch template** | A versioned instance template (AMI, type, disk, SG, user data, IMDS); a managed node group is always deployed through it. | [10](10/en.md) |
| **Launch template / Auto Scaling group** | A versioned launch template / an instance group with `min`, `desired`, and `max` across AZ subnets. | [0.4](00-4-ec2/en.md) |
| **Lifecycle policy** | Rules for automatically deleting images by age or count. | [20](20/en.md) |
| **limits** | The upper limit of container consumption. | [14](14/en.md) |
| **log group / log stream** | A group (usually per application) and a stream within it (usually per pod) in CloudWatch Logs. | [34](34/en.md) |
| **Managed / inline policy** | A reusable versioned policy / a policy embedded in a role. | [0.2](00-2-iam/en.md) |
| **Managed addon (EKS managed addon)** | An AWS-curated cluster component (VPC CNI, CoreDNS, kube-proxy, CSI) whose version EKS manages through its API. | [0.5](00-5-tools/en.md), [01](01/en.md), [37](37/en.md) |
| **managed collector (scraper)** | An AMP-managed agentless collector that scrapes EKS metrics and writes them to a workspace through remote-write. | [33](33/en.md) |
| **managed fields / server-side apply** | The mechanism by which an add-on declares and applies its fields; conflict resolution is based on it. | [37](37/en.md) |
| **Managed node group** | An EC2 group managed by EKS: AWS maintains the ASG and launch template and updates it with a command-triggered drain, but you are responsible for the OS and node contents. | [01](01/en.md), [09](09/en.md) |
| **Management account** | The root billing account, where workloads are not kept. | [0.1](00-1-aws/en.md) |
| **`matchLabelKeys`** | Pod label keys added to the placement constraint's `labelSelector`; with `pod-template-hash`, skew is calculated within one Deployment revision. | [40](40/en.md) |
| **max-pods** | Pod limit per node: `ENI * (IP per ENI - 1) + 2`; managed node groups have an upper limit (110 or 250). | [0.4](00-4-ec2/en.md), [06](06/en.md), [46](46/en.md) |
| **maxSkew** | The permitted difference in pod count between the fullest and emptiest domains. | [40](40/en.md) |
| **`memory_limiter`** | A Collector processor that limits memory use: at the threshold, it refuses incoming data rather than reaching `OOMKilled`; it is placed first. | [36](36/en.md) |
| **metric_relabel_configs** | A scrape-config section (`metricRelabelings` in a ServiceMonitor) that drops high-cardinality metrics (`drop` by `__name__`) and labels (`labeldrop`) before writing and remote-write; a tool for volume and cost control. | [33](33/en.md) |
| **Metrics API (`metrics.k8s.io`)** | The Kubernetes API for current resource metrics, the source for `kubectl top` and HPA resource metrics. | [33](33/en.md), [35](35/en.md) |
| **metrics-server** | A component that collects CPU and memory from kubelet and exposes them through the Metrics API for `kubectl top` and HPA; it has no history or storage. | [33](33/en.md) |
| **mount target** | An EFS network interface in a subnet of a specific AZ; the entry point for nodes in that zone, one per Availability Zone. | [24](24/en.md) |
| **Mountpoint for Amazon S3** | A client that exposes bucket objects through a file interface; the basis of the CSI driver. | [25](25/en.md) |
| **Mountpoint S3 CSI driver** | `aws-mountpoint-s3-csi-driver`, a managed add-on with the `s3.csi.aws.com` provisioner; static provisioning only. | [25](25/en.md) |
| **must have** | An item without which production release is dangerous and must be blocked. | [48](48/en.md) |
| **NACL** | A stateless filter at the subnet level; inbound and outbound rules are independent. | [46](46/en.md) |
| **namespace restore** | Selective restoration of up to 5 namespaces into an existing cluster without cluster-scoped resources (except associated PVs). | [42](42/en.md) |
| **NAT Gateway** | An AWS-managed address translation service that gives private subnets outbound Internet access; billed hourly and per gigabyte processed. | [0.3](00-3-vpc/en.md), [31](31/en.md) |
| **`ndots:5`** | A pod resolv.conf setting that causes names to iterate through search domains. | [46](46/en.md) |
| **nested (child) recovery point** | A point nested within a composite recovery point: cluster state or an individual volume. | [41](41/en.md) |
| **Network ACL** | A stateless subnet filter, with allow and deny rules ordered by rule number. | [0.3](00-3-vpc/en.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | The policy-enforcement mode when a pod starts: `standard` (default allow, with a window without policies) or `strict` (default deny). | [08](08/en.md), [30](30/en.md) |
| **NetworkPolicy** | A standard Kubernetes object that declares allowed pod ingress and egress; by itself it blocks nothing without an enforcer. | [30](30/en.md) |
| **nice to have** | An item that raises maturity and may be completed after production release. | [48](48/en.md) |
| **NLB (Network Load Balancer)** | An L4 (TCP/UDP) load balancer with high performance and static IPs; created by LBC from a LoadBalancer Service. | [26](26/en.md) |
| **node instance role** | The IAM role assumed by an EC2 node; kubelet uses it to access AWS APIs. | [45](45/en.md) |
| **Node Termination Handler (NTH)** | An AWS component for handling interruptions on managed and self-managed nodes without Karpenter; IMDS and Queue Processor modes. | [13](13/en.md) |
| **nodeadm** | A node initializer on AL2023 and Bottlerocket; its input is a `NodeConfig` YAML manifest (`apiVersion: node.eks.aws/v1alpha1`), replacing the `bootstrap.sh` script. | [10](10/en.md), [45](45/en.md) |
| **NodeClaim** | A Karpenter claim for a specific node; connects a `NodePool` and an actual `Node`. | [12](12/en.md) |
| **NodeCreationFailure** | A managed node group health issue: nodes did not join the cluster within 15 minutes of launch. | [45](45/en.md) |
| **NodeLocal DNSCache** | A local caching DNS service on a node that reduces load on CoreDNS and per-ENI throttling. | [46](46/en.md) |
| **NodePool** | A CRD (`karpenter.sh/v1`) that sets node boundaries: `requirements`, `limits`, `weight`, labels/taints, and the disruption policy. | [12](12/en.md) |
| **NodePool and NodeClass** | Objects that describe which nodes to launch and how; default ones in Auto Mode are immutable, while custom ones can be added. | [09](09/en.md) |
| **non-destructive restore** | A mode in which existing objects are not overwritten but skipped (skips are visible through SNS). | [42](42/en.md) |
| **NotReady with a live kubelet** | Usually means the CNI is not ready, so pods are not assigned IP addresses. | [45](45/en.md) |
| **OIDC issuer URL** | The cluster's public OIDC endpoint (`oidc.eks.<region>.amazonaws.com/id/`) with public signing keys for projected tokens. | [16](16/en.md) |
| **On-demand / Spot** | Pay-as-you-go / discounted capacity that can be interrupted with two minutes' notice. | [0.4](00-4-ec2/en.md) |
| **OOMKilled** | The kernel killing a container after it exceeds its memory limit. | [14](14/en.md) |
| **OpenCost** | An open, vendor-neutral cost-allocation standard and engine, a CNCF project; it takes consumption from Prometheus and AWS resource prices. | [43](43/en.md) |
| **OpenSearch Service** | Managed OpenSearch for full-text search and dashboards; charged per cluster (nodes). | [34](34/en.md) |
| **OpenTelemetry (OTel)** | A CNCF standard: shared APIs, SDKs, and protocol; it separates instrumentation from the backend. | [36](36/en.md) |
| **OpenTelemetry Collector** | A collector: receivers receive, processors process, and exporters send telemetry to backends. | [36](36/en.md) |
| **OpenTelemetry Operator** | An operator that performs auto-instrumentation by injecting an agent into a pod. | [36](36/en.md) |
| **OpenTofu** | An open Terraform fork compatible with the course modules; selected with the `terraform_binary = "tofu"` attribute. | [0.5](00-5-tools/en.md) |
| **OTLP** | A protocol for sending telemetry from an application to a collector and between collectors. | [36](36/en.md) |
| **OU** | A group of accounts to which policies are applied. | [0.1](00-1-aws/en.md) |
| **ownership** | Assigned responsibility for a domain or checklist item. | [48](48/en.md) |
| **Permissions boundary** | A permission ceiling for a role or user; it grants no permissions itself. | [0.2](00-2-iam/en.md) |
| **Placement group** | Controls instance placement: `cluster` (close together, minimal latency, one AZ), `partition` (different racks by partition, up to 7 per AZ), and `spread` (each on separate hardware, no more than 7 running per AZ). | [0.4](00-4-ec2/en.md) |
| **`placementGroupSelector`** | A custom `NodeClass` field that selects a placement group by name or ID. You create the group yourself in advance; a pod's group membership is set with `nodeSelector` on the `eks.amazonaws.com/placement-group-id` label. | [09](09/en.md), [12](12/en.md) |
| **Platform version** | The patch level and EKS control-plane feature set within a Kubernetes minor version, in the `eks.<n>` format; updated automatically by AWS. | [01](01/en.md), [02](02/en.md) |
| **pluto / kube-no-trouble (kubent)** | Tools for finding deprecated APIs: pluto in Git and Helm, kubent in a live cluster. | [38](38/en.md) |
| **Pod execution role** | The IAM role under which `kubelet` on Fargate infrastructure registers with the cluster and pulls images from ECR; set when the profile is created. The built-in log router also writes logs to its destination under this role, so it is this role that needs log-write permissions. | [15](15/en.md) |
| **Pod Identity association** | An EKS API record that binds `cluster + namespace + ServiceAccount` to an IAM role; created with `aws eks create-pod-identity-association`. | [17](17/en.md), [37](37/en.md) |
| **pod readiness gate** | An additional pod readiness condition; AWS Load Balancer Controller keeps `target-health.elbv2.k8s.aws` false until the target becomes `healthy`. | [40](40/en.md) |
| **Pod Security Admission (PSA)** | A built-in admission controller that applies Pod Security Standards to namespaces through labels; it replaced Pod Security Policies. | [19](19/en.md) |
| **Pod Security Standards** | The privileged, baseline, and restricted profiles (the strict one, for production). | [19](19/en.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | `strict` without source NAT versus `standard`, where traffic beyond the VPC uses the primary ENI under the node SG rules. | [46](46/en.md) |
| **PodDisruptionBudget (PDB)** | An object that limits the number of pods simultaneously evicted during voluntary disruptions (`minAvailable`/`maxUnavailable`). | [40](40/en.md) |
| **`pods.eks.amazonaws.com`** | The service principal in the Pod Identity role trust policy; shared by all clusters and accounts. EKS Auth API issues the role credentials through `AssumeRoleForPodIdentity`. | [17](17/en.md) |
| **Policy** | JSON with `Version`, `Statement`, `Effect`, `Action`, `Resource`, and `Condition`; it can be identity-based (on a principal) or resource-based (on the resource itself). | [0.2](00-2-iam/en.md) |
| **Policy engine** | An admission webhook with your rules (Kyverno, Gatekeeper); it validates and, when needed, changes objects according to those rules before they are written to etcd. | [22](22/en.md) |
| **`pollingInterval` and `cooldownPeriod`** | The KEDA source polling interval (30 seconds by default) and wait before scaling to zero (300 seconds by default); the latter applies only to scale-to-zero. | [35](35/en.md) |
| **Prefix delegation** | A mode where an ENI slot holds a `/28` prefix (16 addresses); enabled with `ENABLE_PREFIX_DELEGATION` and requires Nitro. | [07](07/en.md), [46](46/en.md) |
| **preserve_client_ip** | An NLB target group attribute that controls preservation of the client's source IP in `ip` mode. | [26](26/en.md) |
| **preStop** | A hook run before SIGTERM; used for a pause before termination. | [40](40/en.md) |
| **Principal** | The entity making a request: a user, role, or AWS service. | [0.2](00-2-iam/en.md) |
| **private / public endpoint** | The cluster API server access mode. | [45](45/en.md) |
| **Private hosted zone** | A Route 53 zone that EKS creates and associates with your VPC so the endpoint name resolves to a private address. | [02](02/en.md) |
| **Projected service account token** | An OIDC-compatible JWT with the SA identity, `sts.amazonaws.com` audience, and a lifetime; mounted into a pod and exchanged in STS for credentials. | [16](16/en.md) |
| **prometheus-adapter** | An adapter that publishes Prometheus metrics through the custom/external API. | [35](35/en.md) |
| **provisioningMode: efs-ap** | A StorageClass mode in which the driver creates an access point for every PVC. | [24](24/en.md) |
| **`publicAccessCidrs`** | The list of CIDRs allowed to access the public endpoint; by default, `0.0.0.0/0`. | [02](02/en.md) |
| **Pull through cache** | An ECR rule that caches images from an external registry (Docker Hub, Quay, `registry.k8s.io`, and others) in your private ECR on request. | [20](20/en.md) |
| **pull model** | An agent inside the cluster pulls from Git itself; push uses an external pipeline. | [44](44/en.md) |
| **QoS class** | `Guaranteed`, `Burstable`, or `BestEffort`; determines eviction order when memory is scarce. | [14](14/en.md) |
| **ReadWriteMany (RWX)** | An access mode: a volume is mounted read-write by many pods on many nodes simultaneously. | [24](24/en.md) |
| **Rebalance recommendation** | An early signal of an elevated reclaim risk that arrives before the two-minute notification; it allows moving workload in advance. | [13](13/en.md) |
| **recovery point** | A recovery point, the result of a successful backup job. | [41](41/en.md) |
| **ReferenceGrant** | A Gateway API resource in the target resource's namespace; it permits cross-namespace references (`backendRefs`, `certificateRefs`) from listed namespaces. | [28](28/en.md) |
| **Replication configuration** | ECR rules that copy images to other Regions and accounts; for cross-account replication, the receiving account allows the source `ecr:CreateRepository` and `ecr:ReplicateImage` in its registry policy. | [20](20/en.md) |
| **Repository creation template** | A settings template (encryption, lifecycle, immutability, policy) for repositories that ECR creates itself for pull-through cache by prefix; without it, a cache repository receives defaults (`MUTABLE`, SSE-S3, no policies). | [20](20/en.md) |
| **Repository policy / registry policy** | Resource-based policies for one repository and for the account's entire registry; `aws:PrincipalOrgID` works in them, so pull access can be granted to the entire organization at once. | [20](20/en.md), [32](32/en.md) |
| **requests** | The amount of resources used for packing and autoscaler decisions; the pod's reservation. | [14](14/en.md) |
| **resolveConflicts** | How an add-on handles field conflicts: `NONE`, `OVERWRITE`, or `PRESERVE`. | [37](37/en.md) |
| **Resource Modifiers** | A Velero ConfigMap with JSON patches for objects at restore time (`--resource-modifier-configmap`); used to remove fields incompatible with the target cluster. | [42](42/en.md) |
| **ResourceQuota / LimitRange** | A limit on total namespace consumption and defaults/bounds for an individual container, respectively. | [22](22/en.md) |
| **restore hook** | An init container or exec command run by Velero when restoring a pod. | [42](42/en.md) |
| **restore job** | An AWS Backup restore task; started with `start-restore-job`, tracked with `list-restore-jobs`/`describe-restore-job`. | [42](42/en.md) |
| **retention policy** | The log retention period in a log group, after which records are deleted; logs do not expire by default. | [34](34/en.md) |
| **right-sizing** | Aligning requests/limits with actual consumption to pack nodes more densely. | [14](14/en.md), [43](43/en.md) |
| **rollback readiness** | Readiness to roll back a version: the window and procedure are known. | [48](48/en.md) |
| **rollback readiness insights** | A `ROLLBACK_READINESS` cluster insight type that checks rollback readiness; statuses are PASSING/WARNING/ERROR/UNKNOWN. | [39](39/en.md) |
| **Root user** | The account owner with unlimited permissions, needed only for initial setup. | [0.1](00-1-aws/en.md) |
| **Route 53 Resolver** | The built-in VPC DNS service at the “CIDR plus 2” address, upstream for CoreDNS. | [0.3](00-3-vpc/en.md) |
| **Route table** | A subnet routing table; public and private subnets differ only in their default route. | [0.3](00-3-vpc/en.md) |
| **RPO** | The allowable amount of data loss; set by backup frequency. | [42](42/en.md) |
| **RTO** | The target time to restore a service after an incident. | [42](42/en.md) |
| **S3 Express One Zone** | A zonal storage class (directory buckets) with low latency and high IOPS in one AZ; unlike general-purpose buckets, it supports `append`. | [25](25/en.md) |
| **S3 Object Lock** | S3 bucket WORM protection: object-version immutability for a retention period (Governance/Compliance), protecting Velero backups from deletion and encryption. | [42](42/en.md) |
| **sampling** | Recording a fraction rather than all traces to control volume and cost. | [36](36/en.md) |
| **sampling rules** | X-Ray rules that set the fraction of recorded requests through a reservoir and fixed rate. | [36](36/en.md) |
| **Savings Plans / RI** | A 30-70% discount for a 1- or 3-year commitment. | [0.4](00-4-ec2/en.md) |
| **scale-to-zero** | Scaling a Deployment down to zero replicas while idle; KEDA supports it, HPA does not. | [35](35/en.md) |
| **ScaledJob** | A KEDA CRD for scaling the number of parallel Jobs to match units of work. | [35](35/en.md) |
| **ScaledObject** | A KEDA CRD that describes the scaling target and triggers for a Deployment. | [35](35/en.md) |
| **scaler** | A KEDA metric source: `aws-sqs-queue`, `aws-cloudwatch`, `prometheus`, `kafka`, `cron`, and dozens of others. | [35](35/en.md) |
| **Schedule** | A Velero object for periodic backups by cron; it sets the RPO. | [42](42/en.md) |
| **SCP (Service Control Policy)** | A restrictive policy on an OU or account: it sets the maximum permissions and grants nothing itself. | [0.1](00-1-aws/en.md), [0.2](00-2-iam/en.md) |
| **Secondary CIDR** | An additional IPv4 block on a VPC; for EKS, typically from `100.64.0.0/10` (RFC 6598). | [07](07/en.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | A driver that mounts a secret from AWS as files in a volume on a node; the `SecretProviderClass` object, with optional sync to `Secret`. | [18](18/en.md) |
| **Security group** | A stateful firewall on an ENI, allow-only, with another SG as a possible source. | [0.3](00-3-vpc/en.md), [46](46/en.md) |
| **`SecurityGroupPolicy`** | A resource that associates an SG with pods by selector (security groups for pods); a pod with a branch ENI no longer inherits node SG rules. | [46](46/en.md) |
| **self-heal** | Automatic rollback of drift to the state in Git. | [44](44/en.md) |
| **self-managed addon** | A component installed by Helm or manifest; its lifecycle and compatibility are entirely the engineer's responsibility. | [37](37/en.md) |
| **Self-managed node** | An EC2 instance that you launch and join yourself (an access entry of type `EC2_LINUX`); you own the entire node lifecycle. | [09](09/en.md) |
| **service map** | A map of services and their relationships, with latency and error rate on the edges. | [36](36/en.md) |
| **Service Network** | A VPC Lattice boundary for a set of services; client VPCs are associated with it to access the services. | [28](28/en.md) |
| **Service Quotas** | Per-account, per-Region service limits that can be increased on request. | [0.1](00-1-aws/en.md) |
| **`serviceIpv4Cidr`** | The Service address range, virtual and unrelated to the VPC. | [06](06/en.md) |
| **ServiceMonitor, PodMonitor** | Prometheus Operator CRDs that declaratively describe which endpoints to scrape. | [33](33/en.md) |
| **Session tags** | Session tags (cluster, namespace, SA) that Pod Identity adds to an STS request and that are used for ABAC; in policies, `aws:PrincipalTag/kubernetes-namespace` and `aws:PrincipalTag/eks-cluster-name`; they require `sts:TagSession` in the trust policy. | [17](17/en.md) |
| **shared costs** | Shared cluster costs (control plane, system namespaces, idle) allocated to teams by rule or displayed separately. | [43](43/en.md) |
| **Shared responsibility** | AWS is responsible for security of the cloud; you are responsible for security in the cloud. | [0.1](00-1-aws/en.md), [01](01/en.md) |
| **shared services account** | An account with shared resources (ECR, private DNS zones, observability) that the other accounts use. | [32](32/en.md) |
| **shared VPC** | A model where an owner shares subnets through RAM and other accounts launch their resources in them, including EKS nodes. | [32](32/en.md) |
| **showback** | Teams are shown their costs without money changing hands. | [43](43/en.md) |
| **SNAT** | Replacing a pod's source address with the node address for outbound traffic; disabled with the `AWS_VPC_K8S_CNI_EXTERNALSNAT` variable. | [06](06/en.md) |
| **Soft multi-tenancy** | Tenants in one cluster (namespace, RBAC, ResourceQuota, LimitRange, NetworkPolicy, policies); the control plane and kernel are shared. | [22](22/en.md) |
| **span** | An individual operation within a trace (handling, call, database request) with a duration and attributes; spans form a trace tree. | [36](36/en.md) |
| **split-horizon DNS** | One name with different answers outside and inside a VPC through a pair of public and private zones. | [29](29/en.md) |
| **Spot interruption notice** | A notification two minutes before an instance is stopped or terminated; a hard limit for graceful shutdown. | [13](13/en.md) |
| **Spot instance** | Discounted spare EC2 capacity that AWS can reclaim at any time when needed for on-demand demand. | [13](13/en.md) |
| **Spot pool** | An instance type plus Availability Zone combination; capacity is reclaimed by pool. | [13](13/en.md) |
| **ssl-redirect** | An annotation that enables an HTTP-to-HTTPS redirect to the specified listener port. | [27](27/en.md) |
| **SSM Session Manager** | SSH-free instance access through the SSM agent. | [45](45/en.md) |
| **Staging labels** | Secret version labels in Secrets Manager: `AWSCURRENT` is read by default, `AWSPENDING` is the value under validation during rotation, and `AWSPREVIOUS` is the previous value. | [18](18/en.md) |
| **Stakater Reloader** | A controller that performs a rolling restart of a Deployment by annotation when a mounted `Secret` or `ConfigMap` changes, so that the pod receives the new value. | [18](18/en.md) |
| **Standard support** | The support phase of an EKS minor version (about 14 months), normal operation without a version surcharge. | [03](03/en.md), [38](38/en.md), [48](48/en.md) |
| **State** | The mapping file between Terraform code and real resources; stored in S3 with versioning and write locking. | [0.5](00-5-tools/en.md), [04](04/en.md) |
| **stdout/stderr** | Standard container output streams; by Kubernetes convention, an application writes logs there rather than to files inside the container. | [34](34/en.md) |
| **STS** | The temporary credentials service; `sts:AssumeRole`, `sts:AssumeRoleWithWebIdentity`. | [0.2](00-2-iam/en.md) |
| **Subnet CIDR reservation** | Reserving a contiguous block within a subnet for prefixes. | [07](07/en.md) |
| **subnet IP exhaustion** | A subnet has no free addresses remaining for ENIs and pods. | [46](46/en.md) |
| **sync waves** | The order in which Argo CD applies resources in waves within sync phases. | [44](44/en.md) |
| **Tag immutability** | Repository mode `IMMUTABLE`, which prohibits overwriting a tag with a different image; `MUTABLE` (the default) permits overwrites. | [20](20/en.md) |
| **target EKS cluster** | An existing cluster that receives a restore; or one AWS Backup creates as part of the restore (`newCluster=true`). | [42](42/en.md) |
| **target-type** | The NLB target type: `instance` (through a node's `NodePort`) or `ip` (directly to a pod IP; requires VPC CNI and is mandatory on Fargate). | [26](26/en.md), [27](27/en.md) |
| **`terminationGracePeriod`** | The limit for draining a node; when present, drift proceeds even through blocking PDBs and `do-not-disrupt`. | [12](12/en.md) |
| **terminationGracePeriodSeconds** | The time between SIGTERM and SIGKILL when terminating a pod (30 by default). | [40](40/en.md) |
| **terragrunt** | A wrapper around Terraform: shared backend, `env.hcl`, `dependency`, `run-all`, and DRY modules without copy-paste. | [0.5](00-5-tools/en.md) |
| **Thanos** | A component set that adds long-term Prometheus storage in object storage: `sidecar` uploads blocks to S3, `store gateway` reads them back, `compactor` compacts them, performs downsampling, and applies retention, `querier` provides unified PromQL and HA-pair deduplication, and `ruler` evaluates rules over history. | [33](33/en.md) |
| **throughput mode** | The EFS throughput mode: Elastic, Bursting, or Provisioned. | [24](24/en.md) |
| **topology aware routing** | A preference for endpoints in the client's Zone, enabled by the Service field `trafficDistribution: PreferClose`. | [31](31/en.md) |
| **topologySpreadConstraints** | A pod field for evenly distributing replicas across domains (`maxSkew`, `topologyKey`, `whenUnsatisfiable`, `minDomains`). | [40](40/en.md) |
| **trace** | The complete path of a request through services, with a shared `trace id`. | [36](36/en.md) |
| **Transit Gateway** | A regional router hub with transitive routing between attached VPCs, VPNs, and Direct Connect; shared through RAM. | [32](32/en.md) |
| **TriggerAuthentication** | A KEDA CRD with trigger access parameters; for AWS, the `aws` provider uses IRSA or Pod Identity. | [35](35/en.md) |
| **Trust policy** | A role trust policy: a `Federated` principal (the OIDC provider ARN), the `sts:AssumeRoleWithWebIdentity` `Action`, and `StringEquals` conditions on `sub` and `aud`. | [0.2](00-2-iam/en.md), [16](16/en.md), [47](47/en.md) |
| **TXT registry** | The external-dns mechanism that marks its records with a TXT marker; the owner is set by `--txt-owner-id`. | [29](29/en.md) |
| **Unauthorized (401)** | Authentication failure: the identity is not proven or is not mapped. | [47](47/en.md) |
| **`unhealthyPodEvictionPolicy`** | A PDB field: `IfHealthyBudget` (the default) does not allow evicting unhealthy pods when the application is already disrupted, while `AlwaysAllow` always permits it. | [40](40/en.md) |
| **upgrade insights** | A type of insights that flags upgrade readiness and deprecated APIs. | [38](38/en.md) |
| **Upgrade policy (`supportType`)** | A cluster configuration field with values `STANDARD` and `EXTENDED` that defines behavior at the end of standard support. Extended support is enabled by default; it cannot be exited by changing the policy, only by upgrading. | [03](03/en.md) |
| **`useCachedMetrics` and `fallback`** | Caching a value within the polling interval and the replica count when a source is unavailable; together they reduce the risk of API throttling and `<unknown>` in `TARGETS`. | [35](35/en.md) |
| **User data** | A script or configuration run on an instance's first start; it starts bootstrap and configures `kubelet`. | [0.4](00-4-ec2/en.md), [10](10/en.md) |
| **ValidatingAdmissionPolicy** | In-apiserver CEL validation (Kubernetes 1.30+) without an external webhook; paired with `ValidatingAdmissionPolicyBinding` (what to apply it to and the `Deny`/`Warn`/`Audit` action). | [22](22/en.md) |
| **Vault Lock** | WORM protection of a vault against backup deletion; governance mode (removable through IAM) and compliance mode (immutable after the grace time). | [41](41/en.md) |
| **Velero** | Kubernetes-native backup and restore; objects in S3 (BackupStorageLocation), volumes through CSI snapshots or File System Backup. | [42](42/en.md) |
| **velero-plugin-for-aws** | The official Velero plugin for AWS: an object store for S3 (BSL) and a volume snapshotter for EBS snapshots. | [42](42/en.md) |
| **Version skew** | The kubelet lag behind the API server permitted by upstream policy; the reason for the order “control plane first, then nodes.” | [03](03/en.md), [37](37/en.md) |
| **version skew policy** | The Kubernetes rule that nodes cannot be newer than the control plane; it dictates rollback order (nodes first, then the control plane). | [38](38/en.md), [39](39/en.md) |
| **VersionRollback** | The update type in an `update-cluster-version` response during a rollback. | [39](39/en.md) |
| **VictoriaLogs** | A dependency-free log database without schema or index configuration; columnar on-disk storage, LogsQL queries, ingestion through Elasticsearch bulk, Loki push, OTLP, and syslog protocols; also available as a cluster (`vlinsert`, `vlstorage`, `vlselect`). | [34](34/en.md) |
| **VictoriaMetrics** | A metrics-storage replacement, not an add-on: `vmagent` for collection, `vmsingle` or a `vminsert`/`vmstorage`/`vmselect` cluster, `vmalert` for rules, retention via the `-retentionPeriod` flag, and MetricsQL as an extension of PromQL. | [33](33/en.md) |
| **volume node affinity conflict** | A scheduler event when a volume's `nodeAffinity` points to a Zone with no suitable node. | [23](23/en.md) |
| **`volumeBindingMode`** | When a volume is provisioned: `Immediate` (when a PVC appears) or `WaitForFirstConsumer` (when a pod is scheduled). | [23](23/en.md) |
| **VolumeSnapshot / Content / Class** | CSI snapshot objects: a request, a snapshot in AWS, and a class. | [23](23/en.md) |
| **voluntary disruption** | Intentional pod eviction: drain, node upgrade, consolidation; protected by a PDB. | [40](40/en.md) |
| **VPC** | An isolated network in a Region; the primary CIDR (`/16` ... `/28`) is immutable and can only be expanded with a secondary CIDR. | [0.3](00-3-vpc/en.md) |
| **VPC CNI** | The AWS network plugin that assigns pods real private addresses from VPC subnets; the `aws-node` DaemonSet in `kube-system`. | [06](06/en.md) |
| **VPC CNI network policy** | The built-in eBPF implementation of `NetworkPolicy`: a controller in the control plane plus the `aws-network-policy-agent` in `aws-node`; enabled by the add-on parameter `enableNetworkPolicy`. | [08](08/en.md), [30](30/en.md) |
| **VPC endpoint** | Private access to an AWS service: gateway (S3, DynamoDB) or interface (PrivateLink). | [0.3](00-3-vpc/en.md), [31](31/en.md) |
| **VPC endpoint (PrivateLink)** | A private entry point to an AWS service within a VPC; mandatory for ECR, S3, STS, EKS, and others on a private data plane. | [19](19/en.md) |
| **VPC Flow Logs** | Records of accepted and rejected flows; the `action = REJECT` filter in CloudWatch Logs Insights is a SecOps and diagnostics tool. | [0.3](00-3-vpc/en.md) |
| **VPC Lattice** | A managed application-networking service for east-west connectivity between VPCs and accounts without sidecars or peering. | [28](28/en.md) |
| **VPC peering** | A direct one-to-one connection between two VPCs; non-transitive and requiring non-overlapping CIDRs. | [32](32/en.md) |
| **wafv2-acl-arn** | An annotation that associates an AWS WAF v2 Web ACL with an ALB to filter requests. | [27](27/en.md) |
| **warm pool** | A reserve of preallocated IPv4 addresses on a node for fast pod startup. | [06](06/en.md) |
| **`WARM_PREFIX_TARGET`** | A reserve of prefixes on a node; `WARM_IP_TARGET` and `MINIMUM_IP_TARGET` take precedence over it. | [07](07/en.md) |
| **workspace** | An isolated metrics store in AMP with its own remote-write endpoint and Prometheus-compatible API. | [33](33/en.md) |
| **X-Amzn-Trace-Id** | An X-Ray header with `Root`, `Parent`, and `Sampled` fields; the ADOT X-Ray propagator maps it to W3C `traceparent`, preserving the end-to-end `trace id`. | [36](36/en.md) |
| **ZoneId (`euc1-az1`)** | A stable Availability Zone name, identical across all accounts. | [0.1](00-1-aws/en.md) |
| **`adot` add-on** | The managed EKS add-on that deploys the ADOT Operator to manage collectors. | [36](36/en.md) |
| **Account** | An isolated resource space and billing unit; its 12-digit number is part of an ARN and trust policy. | [0.1](00-1-aws/en.md) |
| **Secondary private address** | An additional IPv4 address on a node ENI that is assigned to a pod. | [06](06/en.md) |
| **Diversification** | Multiple instance types across several AZs so the loss of one pool does not remove a critical share of nodes. | [13](13/en.md) |
| **Readiness domain** | One operational axis (control plane, nodes, security, networking, storage, observability, operations, incidents), assessed separately. | [48](48/en.md) |
| **Drift** | A difference between the actual state and the state described in code or Git. | [04](04/en.md), [44](44/en.md) |
| **dependency between stacks** | Passing outputs from one stack into another stack's inputs (the Terragrunt `dependency` block). | [04](04/en.md) |
| **EC2 instance** | A virtual machine; for EKS, a node with containerd and kubelet. | [0.4](00-4-ec2/en.md) |
| **local cache** | A Mountpoint data cache on a node volume (`cache: emptyDir`/`ephemeral`) that speeds repeated reads; the metadata cache is set with `metadata-ttl`. | [25](25/en.md) |
| **Node scaling versus pod scaling** | Different levels: nodes are scaled by CA and Karpenter; pods by HPA, VPA, and KEDA. | [11](11/en.md) |
| **Micro-VM** | A dedicated virtual machine for one pod with its own kernel, CPU, memory, and network interface; the Fargate isolation boundary. | [15](15/en.md) |
| **Object storage** | A key-value model: an object (bytes plus metadata) under a string key, immutable and updated as a whole through `PutObject`. | [25](25/en.md) |
| **rollback window (7 days)** | The period after an upgrade during which rollback is available; after it expires, the rollback and its insights are unavailable. | [39](39/en.md) |
| **kubectl plugin** | A `kubectl-<name>` file in `PATH`, available as `kubectl <name>`. | [0.5](00-5-tools/en.md) |
| **Subnet** | Part of a VPC CIDR in one AZ. | [0.3](00-3-vpc/en.md) |
| **Full replacement** | `aws-node` is removed and Cilium is the sole CNI with its own IPAM: ENI IPAM (real VPC addresses) or cluster-pool (overlay/VXLAN, virtual addresses). | [08](08/en.md) |
| **prefix** | The part of a key before `/`, from which Mountpoint emulates a directory; S3 has no real directories. | [25](25/en.md) |
| **forced upgrade** | An automatic version increase after extended support expires; such a cluster cannot be rolled back. | [38](38/en.md) |
| **Provider** | A Terraform plugin (`aws`, `kubernetes`, `helm`). | [0.5](00-5-tools/en.md) |
| **progressive delivery** | Canary/blue-green application deployment (Argo Rollouts, Flagger). | [44](44/en.md) |
| **Production checklist** | A systematic readiness checklist by domain, where every item is either complete or marked as a known risk. | [48](48/en.md) |
| **Profile** | A named set of parameters: Region, role, SSO. | [0.5](00-5-tools/en.md) |
| **Region** | A geographic location (`eu-central-1`) to which resources belong. | [0.1](00-1-aws/en.md) |
| **external mode** | The `aws-load-balancer-type` annotation value that delegates Service reconciliation to the external LBC controller instead of the in-tree provider. | [26](26/en.md) |
| **EBS access modes** | `ReadWriteOnce` (one node) and `ReadWriteOncePod` (exactly one pod); `ReadWriteMany` is possible only as Multi-Attach `io2` in `volumeMode: Block` mode in one AZ and without a file system. Shared file access requires EFS or FSx. | [23](23/en.md) |
| **reconciliation** | A continuous loop that compares the desired state (Git) with the actual state (cluster). | [44](44/en.md) |
| **static provisioning** | A PV is described manually with `bucketName`; the driver has neither dynamic provisioning nor bucket creation. | [25](25/en.md) |
| **Stack** | An independently applicable infrastructure unit with its own state. | [0.5](00-5-tools/en.md), [04](04/en.md) |
| **Rotation strategy** | `single user` (the password of one user changes, with a short risk window for failures that retries with a delay address) or `alternating users` (two users take turns, valid credentials exist at all times, and a secret with superuser permissions is required). | [18](18/en.md) |
| **Spot strategy** | How a pool is selected: `capacity-optimized(-prioritized)` versus `lowest-price`; capacity-oriented strategies are interrupted less often. | [0.4](00-4-ec2/en.md) |
| **Tag** | A key/value pair; EKS controllers find resources by tags, and an activated cost allocation tag is used in billing to break down the bill. | [0.1](00-1-aws/en.md) |
| **Instance type** | `family + generation + suffix . size`, for example `m7g.xlarge`. | [0.4](00-4-ec2/en.md) |
| **control plane log types** | `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`; written to CloudWatch Logs only after being enabled. | [02](02/en.md) |
| **EKS managed capability for Argo CD** | Argo CD as an EKS Capability: controllers in the AWS control plane, targets only EKS clusters by ARN, and access to them through EKS access entries. | [44](44/en.md) |
| **kubernetes filter** | The Fluent Bit FILTER that adds namespace, pod, container, labels, and annotations to records. | [34](34/en.md) |
| **Argo CD sharding** | Distributing connected clusters among application-controller replicas. | [44](44/en.md) |
| **--force** | A flag that bypasses insights checks (ERROR/WARNING/UNKNOWN), but not prerequisites (window, one minor version, created-on-version, feature compatibility). | [39](39/en.md) |
| **/var/log/containers** | The directory on a node containing links to container log files; the point from which a collector retrieves logs. | [34](34/en.md) |