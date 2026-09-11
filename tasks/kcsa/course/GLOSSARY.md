[Русская версия](GLOSSARY_RU.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# KCSA Course Glossary

English terms are retained in their original form because they are needed to read KCSA questions and answer choices. The descriptions explain their meaning, but do not replace practicing terminology in English MCQs (multiple choice questions).

| Term | Description | Common confusion | Chapters |
|---|---|---|---|
| `4C model` | A model of the Cloud, Cluster, Container, and Code layers for analyzing cloud native security. | It is not limited to cloud infrastructure alone. | [03](03/README.md) |
| `ABAC` | Authorization based on request and subject attributes. | It is not role-based RBAC. | [10](10/README.md) |
| `Access control` | Restricting access to a resource based on rules and identity. | It is broader than authentication alone. | [10](10/README.md) |
| `admission` | The stage of validating or modifying an API request after authentication and authorization. | Clarify the term from context; do not substitute a related concept. | [07](07/README.md) |
| `Admission control` | The API stage after authentication and authorization that admits or modifies an object. | It does not confirm identity or grant permissions. | [11](11/README.md), [17](17/README.md) |
| `Admission policy` | A declarative rule for validating objects during admission. | It is not an audit policy. | [17](17/README.md) |
| `Admission webhook` | An external webhook participating in mutating or validating admission. | It is not an application network webhook. | [17](17/README.md) |
| `Alert` | A signal that requires attention or action according to a rule. | It does not replace primary logs and metrics. | [18](18/README.md) |
| `Allowlist` | An explicit list of permitted sources, actions, or objects. | It is not equivalent to the absence of deny rules. | [09](09/README.md), [17](17/README.md) |
| `Anomaly detection` | Identifying a deviation from expected behavior. | An anomaly alone does not prove an attack. | [18](18/README.md) |
| `API server` | The component that accepts Kubernetes API requests and coordinates access to state. | It does not store state in place of etcd. | [07](07/README.md) |
| `Artifact` | A development or build output, such as an image, package, or SBOM. | It is not necessarily a container image. | [06](06/README.md), [17](17/README.md) |
| `Attack surface` | The set of points through which a system can be attacked. | It is not a single discovered vulnerability. | [02](02/README.md), [16](16/README.md) |
| `Attack vector` | A specific path or method for carrying out an attack. | It is narrower than the attack surface. | [15](15/README.md), [16](16/README.md) |
| `audit` | A PSA mode that records violations in the audit log without rejecting the request. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `Audit backend` | A configured location for storing or forwarding API Server audit events. | The API Server creates events; the backend stores or receives them. | [14](14/README.md) |
| `audit event` | A `kube-apiserver` record of processing a Kubernetes API request. | Clarify the term from context; do not substitute a related concept. | [14](14/README.md) |
| `audit level` | The level of detail in a Kubernetes audit event, such as `Metadata` or `RequestResponse`. | Clarify the term from context; do not substitute a related concept. | [20](20/README.md) |
| `Audit logging` | Recording Kubernetes API request events. | It does not replace runtime process detection. | [14](14/README.md) |
| `Audit policy` | A configuration that defines which API events to record and at what level of detail. | It is not an admission policy. | [14](14/README.md) |
| `auditID` | An identifier linking events from different stages of one request. | Clarify the term from context; do not substitute a related concept. | [14](14/README.md) |
| `Authentication` | Establishing who makes a request. | It does not answer whether the action is permitted. | [10](10/README.md) |
| `Authorization` | Checking whether an already known subject can perform an action. | It does not establish identity. | [10](10/README.md) |
| `Authorization mode` | A configured mechanism for making API permission decisions. | It is not an authentication method. | [10](10/README.md) |
| `Availability` | Accessibility of data or a service to an authorized user. | It is not confidentiality or integrity. | [02](02/README.md), [16](16/README.md) |
| `Backup` | A copy of data for recovery after loss or corruption. | A backup must be protected like the original data. | [07](07/README.md), [12](12/README.md) |
| `Base64` | Reversible byte encoding for textual representation. | It is not encryption. | [12](12/README.md) |
| `baseline` | A profile that blocks common privilege-escalation paths. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `Baseline profile` | A PSS level that blocks known dangerous settings while preserving compatibility. | It is not the strictest restricted profile. | [11](11/README.md) |
| `Bearer token` | A token whose presentation grants the holder's permissions. | It is not a password that can safely be placed in code. | [10](10/README.md) |
| `bind` | A special RBAC permission to bind a Role/ClusterRole without needing to hold all permissions of the role being bound. | Clarify the term from context; do not substitute a related concept. | [10](10/README.md) |
| `blast radius` | The scope of impact from compromising one component. | Clarify the term from context; do not substitute a related concept. | [16](16/README.md) |
| `Bound ServiceAccount token` | A short-lived token bound to a ServiceAccount and Pod. | It is not the old long-lived Secret token. | [10](10/README.md) |
| `Build provenance` | Provenance containing build information for an artifact. | It is not a signature or an SBOM. | [17](17/README.md), [19](19/README.md) |
| `CA` | A certificate authority trusted to issue or verify certificates. | It is not a private key. | [18](18/README.md) |
| `capability` | A distinct Linux privilege that can be granted or revoked independently of UID 0. | Clarify the term from context; do not substitute a related concept. | [09](09/README.md) |
| `CEL` | Common Expression Language - an expression language built into the Kubernetes API for conditions and rules without executing arbitrary code. | It is not a general-purpose language for arbitrary code. | [17](17/README.md) |
| `Certificate` | A document containing a public key and identity, signed by a trusted CA. | It does not contain the private key. | [18](18/README.md) |
| `Certificate authority` | The full name of a CA as a trusted PKI party. | It is not any TLS certificate. | [18](18/README.md) |
| `CIA triad` | Three security goals: confidentiality, integrity, and availability. | It is not a threat model or control. | [02](02/README.md), [15](15/README.md) |
| `Cilium` | A CNI and set of networking tools that can enforce NetworkPolicy. | It is not the NetworkPolicy API resource itself. | [13](13/README.md) |
| `CIS Kubernetes Benchmark` | A set of recommendations for secure Kubernetes configuration. | It is a recommendation framework, not a ready-made control. | [05](05/README.md), [19](19/README.md) |
| `CKS` | Certified Kubernetes Security Specialist, a practical performance-based Kubernetes security certification. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `Cloud` | The external 4C model layer: provider infrastructure, IAM, and services. | It is not synonymous with a Kubernetes cluster. | [03](03/README.md), [04](04/README.md) |
| `Cloud IAM` | Managing identities and permissions for cloud resources. | It does not replace Kubernetes RBAC. | [04](04/README.md) |
| `Cluster-admin` | The built-in ClusterRole with unrestricted permissions for all cluster resources. | It should not be used as an everyday identity. | [10](10/README.md), [16](16/README.md) |
| `ClusterRole` | A set of permitted API actions without a namespace boundary, for cluster resources or all namespaces. | It is not a Role, which is limited to one namespace. | [10](10/README.md) |
| `ClusterRoleBinding` | A binding of a subject to a ClusterRole across the entire cluster. | It is not a RoleBinding that applies in only one namespace. | [10](10/README.md) |
| `CNI` | The standard and plugins for connecting containers to the Kubernetes network. | Clarify the term from context; do not substitute a related concept. | [09](09/README.md), [13](13/README.md) |
| `Code` | The 4C layer for source code, dependencies, and development practices. | It is not an already built image. | [03](03/README.md), [06](06/README.md) |
| `Compliance` | Conformance with applicable requirements supported by verifiable evidence. | It does not guarantee the absence of all risks. | [19](19/README.md) |
| `Confidentiality` | Protecting data from disclosure to unauthorized parties. | It is not integrity or availability. | [02](02/README.md), [12](12/README.md) |
| `Container` | An isolated process with an image and runtime constraints. | It is not a Pod, which can contain multiple containers. | [03](03/README.md), [09](09/README.md) |
| `container escape` | An escape by a process from container isolation to worker-node resources. | Clarify the term from context; do not substitute a related concept. | [16](16/README.md) |
| `Container image` | An immutable template of files and metadata for running a container. | It is not a running container. | [06](06/README.md), [17](17/README.md) |
| `Container registry` | A service for storing and distributing container images. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `Container runtime` | A software layer that runs containers on a node through CRI. | It is not kubelet. | [08](08/README.md) |
| `context` | The cluster, user, and namespace selection used by `kubectl`. | Clarify the term from context; do not substitute a related concept. | [09](09/README.md) |
| `Control` | A specific measure that reduces the likelihood or impact of risk. | It is not a framework that structures measures. | [05](05/README.md), [19](19/README.md) |
| `Control plane` | The logical set of components that manage Kubernetes state. | It is not a worker node. | [07](07/README.md) |
| `Controller Manager` | A component that runs controllers to bring state to the desired state. | It does not select a node for a Pod. | [07](07/README.md) |
| `CRI` | The Kubernetes interface between kubelet and a container runtime. | It is not CNI or CSI. | [08](08/README.md) |
| `CronJob` | A Kubernetes resource that creates Jobs on a schedule. | An attacker can use it for cluster persistence, not only for its intended purpose. | [16](16/README.md) |
| `CVE` | An identifier for a publicly known vulnerability. | A CVE is not confirmed exploitation. | [06](06/README.md), [16](16/README.md) |
| `Data flow` | The path by which data moves between system participants. | It is not a trust boundary, though it crosses one. | [15](15/README.md) |
| `Default deny` | A starting policy that denies traffic not explicitly allowed. | It is not denial of all API access. | [13](13/README.md) |
| `default-deny` | An approach in which traffic in a selected direction is denied until an explicit policy allows it. | Clarify the term from context; do not substitute a related concept. | [13](13/README.md) |
| `Defense in depth` | A combination of independent protection layers. | It does not mean duplicating the same control. | [02](02/README.md), [05](05/README.md) |
| `Denial of Service` | Disruption of availability through resource exhaustion or overload. | It is not any slow system performance. | [16](16/README.md) |
| `Deployment` | A Kubernetes resource for managing ReplicaSet and Pod updates. | It is not a separate security boundary. | [02](02/README.md), [09](09/README.md) |
| `Detection` | Identifying an already observable event or deviation. | It does not prevent an object before creation. | [14](14/README.md), [18](18/README.md) |
| `Digest` | A cryptographic identifier for specific artifact content. | It does not prove the author, security, or origin. | [06](06/README.md), [17](17/README.md) |
| `distractor` | A plausible but incorrect answer choice. | Clarify the term from context; do not substitute a related concept. | [20](20/README.md) |
| `Distroless` | A minimal runtime image without a usual shell or package manager. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `DNS` | A name-resolution service for services and external addresses. | It is not a network segmentation mechanism. | [09](09/README.md) |
| `DoS` | Denial of service from resource exhaustion or overload. | Clarify the term from context; do not substitute a related concept. | [16](16/README.md) |
| `Egress` | Outbound network traffic from a selected Pod. | It is not ingress traffic to a Pod. | [13](13/README.md), [18](18/README.md) |
| `Encryption` | Cryptographic protection of data using a key. | It is not reversible encoding. | [04](04/README.md), [12](12/README.md) |
| `Encryption at rest` | Encryption of stored data, for example in etcd. | It does not protect API reads by a subject with permission. | [07](07/README.md), [12](12/README.md) |
| `Encryption in transit` | Encryption of data while it is transferred over a network. | It does not replace authorization or segmentation. | [04](04/README.md), [18](18/README.md) |
| `EncryptionConfiguration` | API Server configuration for encrypting API resources in etcd. | It is not an RBAC policy. | [12](12/README.md) |
| `Endpoint` | An address or network access point for a service or component. | It is not Kubernetes EndpointSlice in every context. | [04](04/README.md), [09](09/README.md) |
| `enforce` | A PSA mode that rejects a rule-violating `Pod`. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `envelope encryption` | An approach where data is encrypted with a data key that is protected by a KMS key. | Clarify the term from context; do not substitute a related concept. | [12](12/README.md) |
| `escalate` | A special RBAC permission to create or modify a Role/ClusterRole with permissions beyond the caller's own permissions. | Clarify the term from context; do not substitute a related concept. | [10](10/README.md) |
| `Etcd` | The state store of the Kubernetes control plane. | It is not an API Server. | [07](07/README.md), [12](12/README.md) |
| `Evidence` | Verifiable proof that a control or process operates. | It is not the compliance requirement itself. | [14](14/README.md), [19](19/README.md) |
| `Exploit` | Code or a technique that uses a vulnerability. | Not every vulnerability has a known exploit. | [16](16/README.md) |
| `External Secrets Operator` | An operator that synchronizes secrets from external storage. | Kubernetes Secret risks remain after synchronization. | [12](12/README.md) |
| `Falco` | A runtime detection tool for container and node behavior. | It does not replace API request audit logging. | [16](16/README.md), [18](18/README.md) |
| `Firewall` | A network control that filters traffic at a defined boundary. | It is not NetworkPolicy within Kubernetes. | [04](04/README.md) |
| `FQDN` | A fully qualified domain name for a network destination. | It is not an IP address or identity. | [09](09/README.md), [18](18/README.md) |
| `Framework` | A structure for evaluating risk, requirements, or completeness of controls. | It is not a technical control by itself. | [05](05/README.md), [19](19/README.md) |
| `Grafana` | A tool for visualizing dashboards and alerts from observability data. | Clarify the term from context; do not substitute a related concept. | [18](18/README.md) |
| `gVisor` | A sandbox runtime that adds isolation between a workload and the node kernel. | It does not replace PSS, RBAC, or NetworkPolicy. | [05](05/README.md) |
| `hard multi-tenancy` | Tenant isolation with strong, often infrastructure-level boundaries. | Clarify the term from context; do not substitute a related concept. | [05](05/README.md) |
| `Hash` | The output of a hash function, used to verify data identity. | It is not a signature that verifies an author. | [06](06/README.md), [17](17/README.md) |
| `HIPAA` | A US regime for protecting health information. | It is not a Kubernetes resource. | [19](19/README.md) |
| `hostPath` | A volume that mounts a worker-node filesystem path into a `Pod`. | Clarify the term from context; do not substitute a related concept. | [09](09/README.md) |
| `Hubble` | A tool for observing Cilium network flows. | Clarify the term from context; do not substitute a related concept. | [18](18/README.md) |
| `Identity` | A representation of the subject on whose behalf an action is performed. | It is not a set of permissions. | [10](10/README.md), [18](18/README.md) |
| `Image digest` | A Digest that pins specific image content. | It is not a mutable tag. | [06](06/README.md), [17](17/README.md) |
| `Image policy` | An image admission rule based on source, signature, or properties. | It is not a scanner report. | [17](17/README.md) |
| `image registry` | A store of container images and related metadata. | Clarify the term from context; do not substitute a related concept. | [17](17/README.md) |
| `Image tag` | A human-readable image label that can be changed. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `impersonate` | The classic Kubernetes permission for impersonating another identity; v1.36 also has beta ConstrainedImpersonation with narrower verbs. | Clarify the term from context; do not substitute a related concept. | [10](10/README.md) |
| `Incident response` | Preparation and actions for detecting, containing, and recovering after an incident. | It is not limited to collecting logs. | [14](14/README.md), [16](16/README.md) |
| `Ingress` | Inbound network traffic to a selected Pod. | It is not the Ingress object for HTTP routing. | [13](13/README.md), [18](18/README.md) |
| `Integrity` | The property of data remaining accurate and unmodified without authorization. | It is not confidentiality. | [02](02/README.md), [19](19/README.md) |
| `iptables` | A mode for implementing `Service` traffic redirection in `kube-proxy`. | Clarify the term from context; do not substitute a related concept. | [08](08/README.md) |
| `IPVS` | A `Service` load-balancing mode in `kube-proxy` that is being deprecated since Kubernetes v1.35. | Clarify the term from context; do not substitute a related concept. | [08](08/README.md) |
| `Isolation` | Limiting the effect of one subject or workload on another. | It is broader than network segmentation alone. | [05](05/README.md), [13](13/README.md) |
| `KCNA` | Kubernetes and Cloud Native Associate, a broad introductory cloud native certification. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `KCSA` | Kubernetes and Cloud Native Security Associate, a conceptual certification in cloud native and Kubernetes security. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `kill chain` | A model of the sequence of attack stages from initial access to impact. | Clarify the term from context; do not substitute a related concept. | [15](15/README.md), [19](19/README.md) |
| `KMS` | A service or plugin for managing encryption keys. | It is not the data encryption provider itself. | [12](12/README.md) |
| `KMS v2` | The currently recommended API for API Server integration with KMS; KMS v1 was deprecated in v1.28 and disabled by default in v1.29. | Clarify the term from context; do not substitute a related concept. | [12](12/README.md) |
| `kube-apiserver` | The full process name of the API Server control-plane component. | It is not kubelet API or kube-proxy. | [07](07/README.md) |
| `kube-bench` | A tool that compares Kubernetes component configuration against CIS Benchmark checks. | It does not assess application business logic or replace a complete audit. | [05](05/README.md), [19](19/README.md) |
| `Kube-proxy` | A node component that configures kernel rules (`iptables`, `nftables`, IPVS) for routing to `Service`; it is not itself a userspace traffic proxy. | It does not enforce NetworkPolicy; the kernel, not it, forwards packets. | [08](08/README.md) |
| `Kubeconfig` | A file containing a cluster address, trusted CA, and client credentials. | It is not harmless configuration without secrets. | [09](09/README.md) |
| `Kubelet` | A node agent that runs Pods through a container runtime. | It is not a scheduler. | [08](08/README.md) |
| `Kubelet API` | The Kubelet HTTPS interface for operations and diagnostics on a node. | Clarify the term from context; do not substitute a related concept. | [08](08/README.md) |
| `Kubernetes API` | The interface for managing cluster resources through the API Server. | It is not kubelet API. | [07](07/README.md), [10](10/README.md) |
| `L3/L4/L7` | Control layers: IP network, transport ports, and application protocol. | Clarify the term from context; do not substitute a related concept. | [13](13/README.md) |
| `lateral movement` | An attacker's move from a compromised resource to another resource. | Clarify the term from context; do not substitute a related concept. | [15](15/README.md), [16](16/README.md) |
| `Least privilege` | Granting only the minimum necessary permissions. | It does not mean zero permissions for everyone. | [02](02/README.md), [10](10/README.md) |
| `level` | The amount of data in an event: `None`, `Metadata`, `Request`, or `RequestResponse`. | Clarify the term from context; do not substitute a related concept. | [14](14/README.md) |
| `LimitRange` | Constraints and defaults for containers in a namespace. | It does not set the namespace aggregate budget as ResourceQuota does. | [11](11/README.md), [16](16/README.md) |
| `Log backend` | A log receiver or store. | It is not itself the source of all events. | [14](14/README.md), [18](18/README.md) |
| `Logging` | Collecting discrete records of events. | It is not monitoring or complete observability. | [14](14/README.md), [18](18/README.md) |
| `MCQ` | Multiple choice question - the KCSA exam question format. | It is not the same as a hands-on task in CKS. | [01](01/README.md), [20](20/README.md) |
| `Metric` | A numeric measurement of state or behavior over time. | It does not contain the full context of a log. | [18](18/README.md) |
| `MITM` | Man-in-the-middle, interception or substitution of network communication. | Clarify the term from context; do not substitute a related concept. | [16](16/README.md) |
| `MITRE ATT&CK` | A knowledge base of attacker tactics and techniques. | It is not a preventive control. | [15](15/README.md), [19](19/README.md) |
| `MITRE ATT&CK for Containers` | A knowledge base of tactics and techniques describing attacker behavior in container environments. | Clarify the term from context; do not substitute a related concept. | [15](15/README.md) |
| `mock exam` | A practice exam that simulates the format and time limit. | Clarify the term from context; do not substitute a related concept. | [20](20/README.md) |
| `Monitoring` | Observing known system indicators and thresholds. | It is narrower than observability. | [18](18/README.md) |
| `most appropriate` | An instruction to select the most direct and suitable answer among those acceptable in meaning. | Clarify the term from context; do not substitute a related concept. | [20](20/README.md) |
| `mTLS` | TLS with mutual verification of connection parties. | It does not define an allowlist of network flows. | [18](18/README.md) |
| `Multi-stage build` | A build with a separate builder stage and minimal final stage. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `multi-tenancy` | Use of one platform by multiple teams or organizations with access and resource separation. | Clarify the term from context; do not substitute a related concept. | [13](13/README.md) |
| `multiple choice` | A question with answer options in which the most correct option must be selected. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `Mutating admission webhook` | A webhook that can change an object before it is persisted. | It is not a validating webhook, which only admits or rejects. | [17](17/README.md) |
| `MutatingAdmissionPolicy` | A built-in declarative CEL admission policy that modifies matching API objects without a separate webhook. | It is not an external mutating admission webhook. | [17](17/README.md) |
| `Namespace` | A logical Kubernetes scope for resources, permissions, and quotas. | It is not by itself a network wall. | [05](05/README.md), [13](13/README.md) |
| `Network segmentation` | Separation of network paths between zones or workloads. | It is not synonymous with general isolation. | [13](13/README.md), [18](18/README.md) |
| `NetworkPolicy` | An API resource that describes permitted Pod ingress and egress. | It does not replace kube-proxy, RBAC, or TLS. | [13](13/README.md) |
| `nftables` | A `kube-proxy` mode; on supported Linux it is recommended as a replacement for deprecated IPVS. | Clarify the term from context; do not substitute a related concept. | [08](08/README.md) |
| `Node` | A Kubernetes worker or control-plane machine. | It is not a Pod. | [07](07/README.md), [08](08/README.md) |
| `Node authorization` | The authorization mechanism for API requests from kubelet. | It is not a Node object. | [08](08/README.md), [10](10/README.md) |
| `Observability` | The ability to understand system state from logs, metrics, and traces. | It is not limited to one monitoring dashboard. | [18](18/README.md) |
| `OIDC` | An identification protocol for API Server trust in an external issuer. | It is not generic Kubernetes OAuth authorization. | [10](10/README.md) |
| `OPA` | A general-purpose policy engine, often used through Gatekeeper. | It is not the built-in ValidatingAdmissionPolicy. | [17](17/README.md) |
| `OpenID Connect` | The full name of OIDC as an identification layer over OAuth 2.0. | It does not replace an RBAC decision. | [10](10/README.md) |
| `OWASP Kubernetes Top 10` | A catalog of common Kubernetes risk classes from OWASP (Open Worldwide Application Security Project, an open web application security project). | It is not a list of mandatory YAML fields. | [05](05/README.md) |
| `PeerAuthentication` | An Istio resource that defines the mTLS receiving mode for a service mesh or part of it. | `STRICT` requires mTLS but does not replace authorization or NetworkPolicy. | [18](18/README.md) |
| `performance-based` | A format that assesses a completed practical action in an environment, not just a selected answer. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `persistence` | An attacker's ability to retain access after the initial entry point is removed. | Clarify the term from context; do not substitute a related concept. | [16](16/README.md) |
| `PKI` | Infrastructure of keys, certificates, and chains of trust. | Clarify the term from context; do not substitute a related concept. | [18](18/README.md) |
| `Pod` | The smallest deployable Kubernetes unit, with one or more containers. | It is not a separate container. | [09](09/README.md), [11](11/README.md) |
| `Pod Security Admission` | The built-in admission mechanism for enforcing Pod Security Standards. | It is not the removed PSP. | [11](11/README.md) |
| `Pod Security Standards` | A set of privileged, baseline, and restricted levels for Pod settings. | It is not a specific admission plugin. | [11](11/README.md) |
| `Policy` | A rule defining desired or permitted behavior. | Not every policy is technically enforced by itself. | [13](13/README.md), [17](17/README.md) |
| `policy engine` | A mechanism that applies rules to API objects, often in the admission path. | Clarify the term from context; do not substitute a related concept. | [05](05/README.md) |
| `Private key` | A secret cryptographic key for signing or authentication. | It must not be published with a certificate. | [09](09/README.md), [18](18/README.md) |
| `privileged` | A container mode with very broad permissions relative to the host. | Clarify the term from context; do not substitute a related concept. | [09](09/README.md), [11](11/README.md) |
| `proctored` | An exam supervised by a proctor for compliance with rules. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `proctoring` | A supervised exam-taking procedure monitored under provider rules. | Clarify the term from context; do not substitute a related concept. | [20](20/README.md) |
| `Prometheus` | A system for collecting and storing metrics. | Clarify the term from context; do not substitute a related concept. | [18](18/README.md) |
| `Provenance` | A record of an artifact's origin, sources, and creation process. | It is not a digest, signature, or SBOM. | [17](17/README.md), [19](19/README.md) |
| `PSA` | Pod Security Admission, the built-in admission controller that enforces PSS. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `PSP` | The PodSecurityPolicy mechanism removed in Kubernetes v1.25. | It is not the current PSA replacement. | [11](11/README.md) |
| `PSS` | Pod Security Standards, the three standard security profiles for `Pod`. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `Public key` | The public portion of a key pair for verifying signatures or encryption. | It must not be stored as a private key. | [18](18/README.md) |
| `RBAC` | Authorization based on roles and subject bindings to permissions. | It is not authentication. | [10](10/README.md) |
| `RCE` | Remote code execution, executing code remotely through a vulnerability. | Clarify the term from context; do not substitute a related concept. | [16](16/README.md) |
| `Registry` | A registry for storing and serving container images. | It does not automatically confirm image security. | [06](06/README.md), [17](17/README.md) |
| `ResourceQuota` | A limit on aggregate resource consumption in a namespace. | It does not define container bounds as LimitRange does. | [13](13/README.md), [16](16/README.md) |
| `restricted` | A strict least-privilege profile for application workloads. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `Risk` | A combination of the likelihood of an unwanted event and its consequences. | It is not a threat or vulnerability. | [15](15/README.md), [19](19/README.md) |
| `Role` | A set of permitted API actions in a namespace. | It does not assign permissions without a RoleBinding. | [10](10/README.md) |
| `Role / ClusterRole` | A set of rules in one namespace / at cluster level. | Clarify the term from context; do not substitute a related concept. | [10](10/README.md) |
| `RoleBinding` | A binding of a subject to a Role or ClusterRole in a namespace. | It is not authentication itself. | [10](10/README.md) |
| `RoleBinding / ClusterRoleBinding` | Binding a role to a user, group, or `ServiceAccount`. | Clarify the term from context; do not substitute a related concept. | [10](10/README.md) |
| `Runtime class` | Selecting a runtime class for running a Pod. | It is not runtime detection. | [05](05/README.md), [09](09/README.md) |
| `Runtime detection` | Detecting process behavior after a workload starts. | It does not replace API request audit logging. | [16](16/README.md), [18](18/README.md) |
| `runtime socket` | A Unix socket through which a client manages a container runtime. | Clarify the term from context; do not substitute a related concept. | [08](08/README.md) |
| `Sandbox` | A strengthened execution boundary for untrusted workloads. | It does not replace least privilege. | [05](05/README.md) |
| `SAST` | Static code analysis without running the application. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `SBOM` | An inventory of components and dependencies in a software artifact. | It is not a signature or provenance. | [06](06/README.md), [17](17/README.md) |
| `SCA` | Analysis of dependencies and their known risks. | It is not a runtime scanner. | [06](06/README.md) |
| `Scheduler` | The component that selects a node for a new Pod. | It does not run containers on a node. | [07](07/README.md) |
| `Secret` | A Kubernetes API object for small sensitive data. | Base64 in `data` is not encryption. | [12](12/README.md) |
| `Secret scanning` | Searching for credentials and other secrets in code, history, and artifacts. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `SecurityContext` | Privilege and constraint settings for a process or Pod. | It does not replace PSS, RBAC, or NetworkPolicy. | [09](09/README.md), [11](11/README.md) |
| `Segmentation` | Dividing a system into zones with limited interactions. | It is one approach to isolation, not its complete synonym. | [13](13/README.md), [15](15/README.md) |
| `Service identity` | A service identity: the account of a component or workload used to call the API. | It is not the identity of a human operator. | [07](07/README.md) |
| `Service mesh` | An infrastructure layer for service connectivity, identity, and often mTLS. | It does not replace NetworkPolicy. | [18](18/README.md) |
| `ServiceAccount` | A Kubernetes identity for processes in a Pod. | It grants no permissions without RBAC. | [10](10/README.md), [12](12/README.md) |
| `Shared responsibility` | Distribution of security responsibilities between provider and customer. | It does not mean that the provider secures the customer's workload. | [04](04/README.md) |
| `SIEM` | A system for centralizing and correlating security events. | It is not the source of API Server audit events. | [14](14/README.md), [18](18/README.md) |
| `Signature` | Cryptographic proof binding data to a signing key. | It is not a digest, SBOM, or provenance. | [06](06/README.md), [17](17/README.md) |
| `SLSA` | A supply-chain requirement framework with independent Build and Source tracks. | It is not a universal name for a reproducible build. | [17](17/README.md), [19](19/README.md) |
| `SLSA v1.2` | A requirement framework with independent Build and Source tracks; the level is stated together with the track. | Clarify the term from context; do not substitute a related concept. | [17](17/README.md), [19](19/README.md) |
| `snapshot` | A consistent backup copy of `etcd` state at a particular time. | Clarify the term from context; do not substitute a related concept. | [07](07/README.md) |
| `SOC 2` | An assessment of service organization controls against the Trust Services Criteria. | It is not a Kubernetes security standard. | [19](19/README.md) |
| `soft multi-tenancy` | Separation of trusted teams in a shared cluster using logical controls. | Clarify the term from context; do not substitute a related concept. | [05](05/README.md) |
| `Software supply chain` | The path of code, dependencies, build, and delivery to runtime. | It is not limited to a container registry. | [06](06/README.md), [17](17/README.md) |
| `SPIFFE` | A workload identity standard for distributed systems. | It is not a TLS certificate by itself. | [18](18/README.md) |
| `stage` | A point in request processing: `RequestReceived`, `ResponseStarted`, `ResponseComplete`, or `Panic`. | Clarify the term from context; do not substitute a related concept. | [14](14/README.md) |
| `STRIDE` | A threat-modeling framework with six categories. | It is not a log of actual attacks. | [15](15/README.md), [19](19/README.md) |
| `Subject` | A user, group, or ServiceAccount on whose behalf a request acts. | It is not a Role or permission. | [10](10/README.md) |
| `Supply chain` | The chain for creating and delivering a software artifact. | It is not one build stage. | [17](17/README.md), [19](19/README.md) |
| `Syscall` | A process system call to the OS kernel. | It is not a Kubernetes API call. | [16](16/README.md), [18](18/README.md) |
| `Tag` | A human-readable reference to an image version. | It can be mutable and is not a digest. | [06](06/README.md) |
| `Threat` | A possible cause or scenario for an unwanted event. | It is not a vulnerability or assessed risk. | [15](15/README.md), [16](16/README.md) |
| `Threat model` | A description of system assets, boundaries, flows, and threats. | It is not a list of CVEs. | [15](15/README.md), [19](19/README.md) |
| `TLS` | A protocol for connection encryption and authentication. | It does not replace NetworkPolicy or authorization. | [07](07/README.md), [18](18/README.md) |
| `TLS termination` | The point where a component terminates TLS and decrypts a connection. | Clarify the term from context; do not substitute a related concept. | [18](18/README.md) |
| `Token` | Credentials presented for authentication. | It is not automatically RBAC-restricted access. | [10](10/README.md) |
| `Trace` | A connected request path through distributed services. | It is not a single log record. | [18](18/README.md) |
| `Trust boundary` | A point where trust, permissions, or data control changes. | It does not necessarily align with a namespace. | [15](15/README.md) |
| `Trusted image` | An image with verifiable origin and a set of trust controls. | Clarify the term from context; do not substitute a related concept. | [06](06/README.md) |
| `Trusted registry` | A registry that policy permits to provide images. | It does not prove the absence of CVEs in an image. | [06](06/README.md), [17](17/README.md) |
| `ValidatingAdmissionPolicy` | A built-in declarative CEL admission policy for API object validation; it is cluster-scoped and applied through a separate `ValidatingAdmissionPolicyBinding`. | It is not "in a namespace" - namespace scope is set through a binding/`matchResources`. | [17](17/README.md) |
| `version-light` | An exam characteristic in which key concepts matter more than attachment to one Kubernetes version. | Clarify the term from context; do not substitute a related concept. | [01](01/README.md) |
| `Vulnerability` | A weakness that a threat or exploit can use. | It is not a threat or risk. | [06](06/README.md), [16](16/README.md) |
| `Vulnerability scanner` | A tool for finding known vulnerabilities from component data. | It does not prevent runtime behavior. | [06](06/README.md), [17](17/README.md) |
| `warn` | A PSA mode that shows a client warning without rejecting the request. | Clarify the term from context; do not substitute a related concept. | [11](11/README.md) |
| `Webhook` | An HTTP handler called by Kubernetes or another component. | Not every webhook is related to admission. | [10](10/README.md), [17](17/README.md) |
| `webhook backend` | A backend that forwards audit events to an HTTPS collector or SIEM. | Clarify the term from context; do not substitute a related concept. | [14](14/README.md) |
| `Workload` | A running application and the Kubernetes resource that manages it. | It is not one container image. | [03](03/README.md), [09](09/README.md) |
| `Zero trust` | An approach with no implicit trust in a network, identity, or location. | It does not mean prohibiting all interactions. | [02](02/README.md), [18](18/README.md) |
| `Trust boundary` | A transition point between participants or contexts with different trust levels. | Clarify the term from context; do not substitute a related concept. | [15](15/README.md) |
| `Threat model` | A description of a system's assets, participants, flows, trust boundaries, threats, and controls. | Clarify the term from context; do not substitute a related concept. | [15](15/README.md) |
| `Data flow` | Transfer of a request, state, or data between components. | Clarify the term from context; do not substitute a related concept. | [15](15/README.md) |
| `Service identity` | The account of a component used to call the Kubernetes API. | Clarify the term from context; do not substitute a related concept. | [07](07/README.md) |
## Lexical traps

- [Authentication](10/README.md) establishes identity, [authorization](10/README.md) checks permission, and [admission control](11/README.md) assesses object admissibility after the first two stages.
- [Audit logging](14/README.md) covers API events, while [runtime detection](18/README.md) covers process behavior after it starts.
- [Encryption](12/README.md) requires a key to protect data; [Base64](12/README.md) is only reversible encoding.
- [Digest](06/README.md) pins content, [signature](17/README.md) binds data to a key, [SBOM](17/README.md) lists components, and [provenance](17/README.md) describes origin.
- [Isolation](13/README.md) covers several boundaries; [segmentation](13/README.md) divides them into zones and paths.
- [Control](05/README.md) reduces risk; [framework](19/README.md) helps select and assess controls.
- [Vulnerability](16/README.md) is a weakness, [threat](15/README.md) is a possible scenario, and [risk](19/README.md) is an assessment of likelihood and impact.
- [Logging](18/README.md) preserves events, [monitoring](18/README.md) tracks known indicators, and [observability](18/README.md) makes it possible to explain state from different signals.
- [CIA triad](02/README.md) combines [confidentiality](12/README.md), [integrity](19/README.md), and [availability](16/README.md).

[Table of contents and study route](README.md)
