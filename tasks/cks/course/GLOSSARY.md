[Русская версия](GLOSSARY_RU.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# CKS course glossary

[← Course contents](README.md) · [Cheatsheet](CHEATSHEET.md) · [Troubleshooting index (RU)](TROUBLESHOOTING_INDEX_RU.md)

An alphabetical reference of CKS terms. Terms are in English; descriptions are in English. The “Chapters” column links to explanations, while “Lab/Task” identifies confirmed practical uses (left empty for purely theoretical terms). Ready-to-use snippets for many terms are in the [cheatsheet](CHEATSHEET.md).

| Term | Description | Chapters | Lab/Task |
|--------|----------|-------|--------------|
| **4C** | A model of the Cloud, Cluster, Container, and Code layers for assessing Kubernetes security. | [02](02/README.md) | |
| **Admission control** | An API server request-processing stage after authentication and authorization, before the object is stored in etcd. | [01](01/README.md), [20](20/README.md) | labs/107 (Task 6) |
| **Admission policy** | A rule that permits, modifies, or rejects a Kubernetes API request. | [01](01/README.md), [20](20/README.md) | labs/107 (Task 6), labs/108 |
| **Admission scan** | A check at workload creation that uses scan results or associated attestations. | [28](28/README.md) | |
| **Admission verification** | Mandatory verification of image origin or signature before the API server persists a Pod. | [26](26/README.md) | labs/111 (Task 9a) |
| **aescbc** | A Kubernetes API-data encryption provider using AES-CBC with PKCS#7 padding; its key is stored in protected configuration. It has no built-in ciphertext authentication (no HMAC/AEAD) and is considered a weak/legacy option compared with `aesgcm` or KMS v2 because CBC is vulnerable to padding-oracle attacks. | [21](21/README.md) | labs/109 (Task 2) |
| **aesgcm** | An AES-GCM AEAD provider for API-data encryption; keys require scheduled rotation. | [21](21/README.md) | |
| **allow-list / allowlist** | An explicit list of permitted actions, sources, or destinations; anything unlisted is denied. | [12](12/README.md), [15](15/README.md), [17](17/README.md) | labs/112 (Task 9) |
| **anonymous authentication** | Mapping a request without credentials to `system:anonymous`; usually disabled for the API and kubelet. | [12](12/README.md) | labs/104 (Task 5) |
| **AppArmor** | Path-based Linux MAC that limits process operations to those allowed by a profile. | [03](03/README.md), [16](16/README.md) | labs/106 (Tasks 1-2) |
| **apparmor_parser** | A utility for checking, loading, replacing, and unloading AppArmor profiles. | [16](16/README.md) | labs/106 (Task 1) |
| **Artifact** | A build output, such as an OCI image, SBOM, chart, or provenance. | [25](25/README.md) | labs/111 |
| **Artifact repository** | A controlled artifact store: a registry, package repository, or chart repository. | [25](25/README.md) | |
| **attack surface** | All interfaces, components, and entry points through which an attack or misconfiguration is possible. | [02](02/README.md), [14](14/README.md), [24](24/README.md) | labs/105 |
| **Attribution** | Associating an event with a process, container, Pod, identity, node, and time. | [30](30/README.md) | labs/112 (Task 6) |
| **audience** | The intended recipient of a ServiceAccount token; a service should accept only tokens with its own audience. | [11](11/README.md) | labs/104 (Task 2) |
| **audit / enforce / warn** | Independent PSA modes: record a violation, reject a Pod, or return a warning. | [19](19/README.md), [31](31/README.md) | labs/107 (Tasks 1, 3-4) |
| **audit backend** | A local file backend or webhook backend receiving events selected by an audit policy. | [32](32/README.md) | labs/112 (Tasks 4, 8) |
| **audit event** | An API server record of one Kubernetes API request. | [32](32/README.md) | labs/112 (Task 4) |
| **audit policy** | Ordered rules defining the audit level and excluded event stages. | [32](32/README.md) | labs/112 (Task 4) |
| **auditID** | An identifier linking all audit stages of a single API request. | [32](32/README.md) | |
| **Base image** | The image in a `FROM` instruction that supplies the initial filesystem of a build stage. | [24](24/README.md) | labs/111 (Task 3) |
| **Bound ServiceAccount token** | A short-lived TokenRequest API token bound to a ServiceAccount and Pod. | [11](11/README.md) | labs/104 (Task 2) |
| **BPF filter** | A filter program run by the kernel for a syscall in seccomp filter mode. | [17](17/README.md) | labs/106 (Tasks 4-5) |
| **break-glass access** | Controlled temporary privileged access for an emergency or incident. | [10](10/README.md), [15](15/README.md) | |
| **Build context** | The files sent to a builder; `.dockerignore` reduces this set. | [24](24/README.md) | |
| **CAP_SYS_ADMIN** | An excessively broad Linux capability that is dangerous for ordinary workloads. | [03](03/README.md) | labs/106 (Task 5) |
| **capability** | An individual Linux privilege drawn from root powers; a secure baseline drops `ALL` and restores only what is needed. | [03](03/README.md), [18](18/README.md) | labs/107 (Task 2) |
| **CEL** | Common Expression Language, used by the built-in ValidatingAdmissionPolicy. | [20](20/README.md) | labs/107 (Task 6), labs/108, labs/111 (Task 9a), labs/112 (Task 9) |
| **cgroup** | A process group with limits and accounting for CPU, memory, PIDs, and other resources. | [03](03/README.md) | |
| **CI gate** | A mandatory check that blocks the next pipeline stage on a non-zero exit code. | [27](27/README.md), [28](28/README.md) | |
| **Cilium** | An eBPF-based Kubernetes CNI and security platform. | [06](06/README.md), [23](23/README.md) | labs/102, labs/110 (Task 4) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | A cluster-wide Cilium policy; its broad scope requires a particularly careful rollout. | [06](06/README.md) | |
| **CiliumNetworkPolicy (CNP)** | A namespaced Cilium policy resource with L3/L4/L7 rules. | [06](06/README.md) | labs/102 (Task 3) |
| **cipher suite** | A set of TLS cryptographic algorithms compatible with the certificate and clients. | [09](09/README.md) | labs/103 (Task 5) |
| **CIS Kubernetes Benchmark** | CIS recommendations for secure configuration of Kubernetes components and nodes. | [01](01/README.md), [07](07/README.md) | labs/103 (Tasks 1, 7) |
| **CKS** | Certified Kubernetes Security Specialist, a practical Kubernetes security certification. | [01](01/README.md), [33](33/README.md) | |
| **Clair** | A service-based vulnerability scanner and indexer for container images. | [28](28/README.md) | |
| **complain** | An AppArmor mode that logs policy violations without blocking them. | [16](16/README.md) | |
| **condition** | A Boolean Falco expression over event fields that determines whether a rule fires. | [29](29/README.md) | labs/112 (Tasks 3, 7, 9) |
| **Constraint** | A Gatekeeper template instance with parameters, matching scope, and an action. | [20](20/README.md) | |
| **ConstraintTemplate** | A Rego template and parameter schema for a new Gatekeeper constraint type. | [20](20/README.md) | |
| **container escape** | Escaping expected container isolation to access node or other tenant resources. | [03](03/README.md) | |
| **Container runtime sandbox** | A runtime adding an isolation boundary between a workload and the host kernel. | [22](22/README.md) | labs/110 (Tasks 1-3) |
| **Confidential computing / TEE** | A hardware-isolated CPU area (Intel SGX, AMD SEV) protecting in-memory data even from the hypervisor and cloud provider; Kubernetes exposes it through a special `RuntimeClass` (confidential containers), while the hardware guarantee lies outside the Kubernetes API. | [30](30/README.md) | |
| **context** | A named combination of cluster, user, and namespace in kubeconfig. | [33](33/README.md) | |
| **Correlation** | Linking events from different sources into a single incident timeline. | [30](30/README.md) | labs/112 (Task 6) |
| **Cosign** | A Sigstore tool for signing and verifying OCI artifacts. | [26](26/README.md) | labs/111 (Tasks 7, 9a, 9c) |
| **CRI** | Container Runtime Interface; `crictl` accesses the runtime through a CRI socket. | [14](14/README.md), [30](30/README.md) | labs/112 (Task 6) |
| **CRI socket** | The kubelet-runtime communication endpoint, such as `/run/containerd/containerd.sock`. | [14](14/README.md) | |
| **CVE** | An identifier for a publicly known vulnerability. | [13](13/README.md), [28](28/README.md) | labs/111 (Task 1) |
| **CycloneDX** | An OWASP format for component inventory and security analysis in an SBOM. | [25](25/README.md), [28](28/README.md) | labs/111 (Task 7) |
| **daemon.json** | The Docker daemon configuration file, usually `/etc/docker/daemon.json`. | [14](14/README.md) | |
| **DaemonSet** | A Kubernetes workload maintaining an agent Pod on every selected node. | [29](29/README.md) | |
| **defense in depth** | Independent protection layers that reduce the impact of one control failing. | [01](01/README.md), [02](02/README.md) | labs/104 (Task 3) |
| **deny-list** | A policy whose default action allows syscalls while specific syscalls are denied. | [17](17/README.md) | |
| **Digest** | The immutable SHA-256 identifier of a particular image manifest or artifact, unlike a mutable tag. | [09](09/README.md), [24](24/README.md), [25](25/README.md), [26](26/README.md) | labs/111 (Tasks 3-5, 9c) |
| **distroless** | A minimal runtime image without a package manager and usually without a shell. | [24](24/README.md), [31](31/README.md) | labs/111 (Task 7) |
| **docker group** | A group with Docker socket access that should be treated as root-equivalent. | [14](14/README.md) | labs/105 (Task 6) |
| **Docker socket** | `/var/run/docker.sock`, the local Docker daemon API; access is almost equivalent to root on the host. | [14](14/README.md) | labs/105 (Task 6) |
| **drop-in** | A separate configuration file extending a base configuration, for example systemd or SSH. | [15](15/README.md) | |
| **eBPF** | A Linux kernel mechanism for restricted programs; Cilium uses it for the datapath and Falco for events. | [06](06/README.md), [29](29/README.md) | labs/112 (Task 1) |
| **egress policy** | A NetworkPolicy specifying permitted outbound Pod connections. | [04](04/README.md), [05](05/README.md) | labs/101 (Tasks 2, 4, 6) |
| **encryption at rest** | Encryption of data stored in etcd, on disk, in snapshots, and in backups. | [21](21/README.md) | labs/109 |
| **EncryptionConfiguration** | The encryption-provider configuration read by kube-apiserver. | [21](21/README.md) | labs/109 (Task 2) |
| **enforce** | An AppArmor or PSA mode that actually blocks policy violations. | [16](16/README.md), [19](19/README.md) | labs/106 (Task 1), labs/107 (Task 1) |
| **Entity** | A predefined Cilium address group, such as `world`, `cluster`, or `host`. | [06](06/README.md) | |
| **envelope encryption** | Encrypting an object with a DEK, which is itself protected by an external KEK. | [21](21/README.md) | |
| **evidence** | A verifiable artifact confirming a result: an API object, log, profile, scanner report, or network test. | [33](33/README.md) | |
| **exemption** | A narrow PSA bypass for a trusted namespace, username, or RuntimeClass; it grants no RBAC permissions. | [19](19/README.md) | |
| **Exfiltration** | Unauthorized transfer of data across a trust boundary. | [02](02/README.md), [30](30/README.md) | |
| **failurePolicy** | The API server action when a webhook/policy is unavailable or errors: usually `Fail` or `Ignore`. | [20](20/README.md) | labs/107 (Task 6) |
| **Falco** | A runtime security-event rule engine using kernel events and container/Kubernetes metadata. | [29](29/README.md), [30](30/README.md) | labs/112 (Tasks 1-3, 6-7, 9) |
| **Falco rule override** | A local change to a Falco rule condition or exceptions without editing the vendor ruleset. | [29](29/README.md), [30](30/README.md) | labs/112 (Task 7) |
| **falco_rules.local.yaml** | The preferred file for local overrides and custom Falco rules. | [29](29/README.md), [30](30/README.md) | labs/112 (Tasks 3, 7, 9) |
| **False positive** | A finding inapplicable to a particular resource; it requires a narrow, documented exception. | [27](27/README.md) | |
| **fixed version** | The component version in which the vendor fixed a CVE. | [13](13/README.md), [28](28/README.md) | |
| **footprint** | The packages, processes, ports, sockets, and configuration that increase a node's attack surface. | [14](14/README.md) | labs/105 (Tasks 1-2) |
| **Gatekeeper** | An OPA-based Kubernetes policy engine with the `ConstraintTemplate` and `Constraint` model. | [20](20/README.md), [26](26/README.md) | |
| **Grype** | An Anchore ecosystem scanner for container images and SBOMs. | [28](28/README.md) | |
| **gVisor** | A sandbox runtime with a userspace kernel; its OCI runtime and CRI handler are often called `runsc`. | [03](03/README.md), [22](22/README.md) | labs/110 (Tasks 1-3) |
| **handler** | The runtime name in CRI configuration; it must match `RuntimeClass.spec.handler`. | [22](22/README.md) | labs/110 (Task 1) |
| **Hardware root of trust** | A cryptographic trust chain rooted in a physical device (TPM/vTPM), used to verify node boot-chain integrity (BIOS/UEFI → bootloader → kernel → runtime); verification lies outside the Kubernetes API. | [30](30/README.md) | |
| **host endpoint** | A node network endpoint, rather than an ordinary Pod in the CNI dataplane. | [05](05/README.md) | |
| **host firewall** | Traffic filtering on the node itself, for example with `ufw`, `iptables`, or `nftables`. | [15](15/README.md) | labs/105 (Task 3) |
| **host namespace** | A node namespace shared by a Pod through `hostPID`, `hostNetwork`, or `hostIPC`. | [18](18/README.md) | labs/101 (Task 7) |
| **Host PID** | The container process PID in the node PID namespace, needed for `/proc` and `strace`. | [30](30/README.md) | labs/112 (Task 6) |
| **HSM (Hardware Security Module)** | A physical cryptographic-key storage device (for example for a kube-apiserver CA private key or KMS master key) that prevents software extraction of the private key. | [21](21/README.md), [30](30/README.md) | |
| **Hubble** | Observability of Cilium network flows. | [06](06/README.md) | labs/102 (Task 5) |
| **identity** | A label-derived Cilium endpoint identifier; distinct from the `identity` provider. | [06](06/README.md), [21](21/README.md) | labs/102 |
| **ImagePolicyWebhook** | An admission plugin delegating image decisions to an external backend through `ImageReview`. | [26](26/README.md) | |
| **IMDS** | Instance Metadata Service, the cloud provider's instance metadata endpoint. | [05](05/README.md) | labs/101 (Task 5) |
| **IMDSv2** | The AWS IMDS variant requiring a temporary token for metadata requests. | [05](05/README.md) | |
| **Immutable infrastructure** | An approach that replaces a production artifact with a new verified version instead of changing it at runtime. | [02](02/README.md), [31](31/README.md) | |
| **include** | A directive loading an external file: SSH `Include`, AppArmor `#include`, or `include:` in check configuration. | [15](15/README.md), [16](16/README.md), [27](27/README.md) | labs/105 (Task 5) |
| **Ingress** | Traffic entering a Pod, or the Kubernetes API object routing external HTTP/HTTPS to a Service; the context determines the meaning. | [04](04/README.md), [08](08/README.md) | labs/101 (Task 2), labs/103 (Task 4) |
| **IngressClass** | Selection of an Ingress implementation, such as NGINX Ingress Controller. | [08](08/README.md) | |
| **Inner packet** | The original Pod-to-Pod flow visible before encryption or after decryption. | [23](23/README.md) | labs/110 (Task 5) |
| **ipBlock** | An ingress/egress rule for a CIDR or individual IP; `except` excludes addresses and subnets. | [04](04/README.md), [05](05/README.md) | labs/101 (Task 6) |
| **IPsec ESP** | An IP-level protected payload providing confidentiality and integrity between Security Associations. | [23](23/README.md) | |
| **Kata Containers** | A runtime launching a Pod sandbox in a lightweight VM with a guest kernel. | [03](03/README.md), [22](22/README.md) | |
| **KEK/DEK** | Key Encryption Key and Data Encryption Key in envelope encryption. | [21](21/README.md) | |
| **kernel module** | A loadable kernel module, one way Falco captures events. | [29](29/README.md) | labs/105 (Task 7) |
| **Keyless signing** | Signing with a short-lived certificate after OIDC authentication instead of a persistent local signing key. | [26](26/README.md) | labs/111 (Task 7) |
| **Kill chain** | The sequence of attack phases from initial access to an objective, such as exfiltration. | [02](02/README.md), [30](30/README.md) | labs/112 (Task 6) |
| **kube-bench** | A configuration-checking tool using CIS Kubernetes Benchmark profiles. | [07](07/README.md), [33](33/README.md) | labs/103 (Tasks 1, 7) |
| **kube-linter** | A Kubernetes YAML and Helm chart linter with best-practice checks. | [27](27/README.md) | labs/111 (Task 2) |
| **kubelet** | The Kubernetes node agent; its secured endpoint usually listens on port `10250`. | [05](05/README.md), [07](07/README.md) | labs/103 (Task 2), labs/105 (Task 8) |
| **kubesec** | A Kubernetes manifest scanner reporting a security score and controls. | [27](27/README.md) | labs/111 (Tasks 2, 4) |
| **Kyverno** | A Kubernetes-native policy engine with YAML rules: `validate`, `mutate`, `generate`, and `verifyImages`. | [20](20/README.md), [26](26/README.md), [31](31/README.md) | labs/108, labs/111 (Task 9a), labs/112 (Task 9) |
| **L3/L4** | The network layer and transport protocol/port in a Cilium policy. | [06](06/README.md) | labs/102 (Task 2) |
| **L7** | The protocol layer, such as HTTP method/path or DNS (Cilium Kafka filtering is deprecated). | [06](06/README.md) | labs/102 (Task 3) |
| **lateral movement** | An attacker moving from a compromised workload to other systems, data, or identities. | [02](02/README.md), [04](04/README.md) | |
| **least privilege** | Granting an identity only the minimum necessary permissions, scope, and duration. | [02](02/README.md), [10](10/README.md), [15](15/README.md) | labs/104 (Task 1) |
| **legacy annotation** | An obsolete AppArmor beta annotation, read for migration but not used for new Pods. | [16](16/README.md) | |
| **level** | The data detail in an audit event: `None`, `Metadata`, `Request`, or `RequestResponse`. | [32](32/README.md) | labs/112 (Task 4) |
| **Linkerd identity** | A Linkerd mTLS identity, usually derived from a ServiceAccount. | [23](23/README.md) | |
| **live-restore** | A Docker mode keeping containers running when the daemon restarts. | [14](14/README.md) | |
| **Localhost** | The Kubernetes type for an AppArmor/seccomp profile preloaded on a node. | [16](16/README.md), [17](17/README.md) | labs/106 (Tasks 2, 4) |
| **localhostProfile** | A JSON profile path relative to the kubelet seccomp root. | [17](17/README.md) | labs/106 (Task 4) |
| **MAC** | Mandatory Access Control, an access policy enforced in addition to UID/GID and mode bits. | [03](03/README.md), [16](16/README.md) | |
| **macro** | A reusable named fragment of a Falco condition. | [29](29/README.md) | labs/112 (Task 7) |
| **mTLS** | TLS in which both client and server present certificates. | [23](23/README.md) | labs/110 (Task 6) |
| **Multi-stage build** | A Dockerfile with separate build and runtime stages connected by `COPY --from=`. | [24](24/README.md) | |
| **Mutating admission webhook** | A webhook adding to or modifying an object before validation. | [20](20/README.md) | labs/108 (Task 5) |
| **namespace** | An isolated view of a kernel resource for a process group; distinct from a Kubernetes namespace. | [03](03/README.md) | labs/106 (Task 6) |
| **namespaceSelector** | Selecting Kubernetes namespaces by labels for a cross-namespace NetworkPolicy rule. | [04](04/README.md) | labs/101 (Task 6) |
| **network namespace** | Isolation of a process's interfaces, routes, and network stack. | [03](03/README.md) | |
| **no_new_privs** | A kernel flag preventing additional privileges through `exec`; enabled by `allowPrivilegeEscalation: false`. | [18](18/README.md) | |
| **Node authorizer** | An authorizer for kubelet-identity actions on the Node and Pod objects it needs. | [12](12/README.md) | |
| **Node encryption** | Protection of inter-node traffic; not equivalent to the identity of a particular workload. | [23](23/README.md) | labs/110 (Tasks 4-5) |
| **NodeRestriction** | An admission plugin further restricting kubelet to its node and the Pods assigned to it. | [12](12/README.md) | |
| **Notary Project / Notation** | An OCI signing ecosystem with X.509 trust policy; Kubernetes enforcement requires admission integration. | [26](26/README.md) | |
| **OCI** | An open standard for container-image and artifact formats used by registries and signing tools. | [25](25/README.md), [26](26/README.md) | labs/111 |
| **OPA** | Open Policy Agent, a policy engine executing declarative Rego rules. | [20](20/README.md), [27](27/README.md) | |
| **Outer packet** | An encrypted packet between node IPs on the physical network. | [23](23/README.md) | labs/110 (Task 5) |
| **partial credit** | Credit for independent, correctly completed parts of a task. | [33](33/README.md) | |
| **PeerAuthentication** | An Istio inbound mTLS policy; `STRICT` rejects plaintext. | [23](23/README.md) | labs/110 (Task 6) |
| **Performance-based** | An exam format requiring results in a working environment rather than selecting test answers. | [01](01/README.md), [33](33/README.md) | |
| **PID namespace** | Isolation of the process list and process PIDs. | [03](03/README.md) | |
| **Pod UID** | The immutable UID of a specific Pod instance, more reliable than its name for correlation. | [30](30/README.md) | |
| **podSelector** | Selecting Pods by labels within the NetworkPolicy namespace. | [04](04/README.md) | labs/101 (Tasks 2, 6) |
| **PolicyReport** | A report of policy-check outcomes, when the policy engine installs this API. | [31](31/README.md) | |
| **private key** | The secret part of an asymmetric key pair; used according to the protocol/tool for TLS identity (chapters 07-08) or a Cosign signing key (lab 111). Both require restricted access, usually `0600`. | [07](07/README.md), [08](08/README.md) | labs/111 (Task 9a) |
| **profiling** | Process performance-diagnostic endpoints; disable with `--profiling=false` unless needed. | [07](07/README.md), [12](12/README.md) | labs/103 (Task 3) |
| **projected volume** | A volume combining tokens, ConfigMaps, downward API, and other sources into Pod files. | [11](11/README.md) | labs/104 (Task 2) |
| **provenance** | Metadata about an artifact's source, inputs, builder, and build process (attestation). Verifiable origin is separate from plain signature verification: `cosign sign`/`verify` proves a signature/identity, not the entire build history; Sigstore provides `cosign attest`/`verify-attestation` for provenance. | [09](09/README.md), [25](25/README.md), [26](26/README.md) | |
| **provider** | A mechanism encrypting and decrypting specified API resources. | [21](21/README.md) | labs/109 (Task 2) |
| **PSA** | Pod Security Admission, the built-in validating admission controller for PSS. | [19](19/README.md), [31](31/README.md) | labs/107 (Tasks 1, 3-4) |
| **PSP** | PodSecurityPolicy, the PSA predecessor removed in Kubernetes 1.25. | [19](19/README.md) | |
| **PSS** | Pod Security Standards: the predefined `privileged`, `baseline`, and `restricted` profiles. | [19](19/README.md) | labs/107 |
| **purl** | Package URL, a package identifier including its ecosystem and version. | [25](25/README.md) | |
| **re-encryption** | Rewriting old API objects through a new encryption provider or key. | [21](21/README.md) | labs/109 (Task 2) |
| **read-only kubelet port** | A legacy unauthenticated kubelet port that must be disabled with `0`. | [07](07/README.md), [09](09/README.md), [12](12/README.md) | labs/103 (Task 2) |
| **read-only root filesystem** | A mode preventing image-layer changes; permitted writes go to volumes. | [18](18/README.md), [31](31/README.md), [33](33/README.md) | labs/107 (Task 5), labs/112 (Task 5) |
| **Registry allowlist** | A policy permitting images only from explicitly listed registry/repository identities. Specify exact versus prefix matching: lab 112 shows that prefix/`startsWith` can admit lookalikes (`library/busybox-evil` for `library/busybox`), so it uses exact matching. | [26](26/README.md) | labs/112 (Task 9) |
| **release cadence** | The frequency of minor and patch releases. | [13](13/README.md) | |
| **remediation** | Removing a risk by updating an artifact, dependency, or base image and verifying the result. | [28](28/README.md) | |
| **Rendered manifest** | The final YAML after `helm template` or `kustomize build`, to be analyzed before deployment. | [27](27/README.md) | |
| **RoleBinding** | A namespaced binding of a Role or ClusterRole to a subject, such as a ServiceAccount. | [10](10/README.md), [11](11/README.md) | labs/104 (Task 1) |
| **Rootless Podman** | A Podman mode where an ordinary user performs build/run, rather than a root daemon. | [24](24/README.md) | |
| **rotation** | Renaming and deleting old log files by size, count, or age. | [21](21/README.md), [32](32/README.md) | labs/112 (Task 4) |
| **rule** | A named Falco detector with a condition, output, and priority. | [29](29/README.md) | labs/112 (Tasks 3, 7, 9) |
| **runtime detection** | Detecting suspicious behavior of a running process using syscalls/eBPF and runtime metadata. | [01](01/README.md), [29](29/README.md), [30](30/README.md) | labs/112 |
| **Runtime mutation** | Changing the filesystem or configuration of a running container. | [31](31/README.md) | labs/112 (Task 5) |
| **runtime overhead** | Fixed additional CPU/memory accounted for by the scheduler for Pods of a chosen RuntimeClass. | [22](22/README.md) | |
| **RuntimeClass** | A cluster-scoped Kubernetes resource selecting a CRI handler and optional overhead/scheduling constraints. | [19](19/README.md), [22](22/README.md) | labs/110 (Task 1) |
| **RuntimeDefault** | A profile supplied by the chosen container runtime for AppArmor or seccomp. | [16](16/README.md), [17](17/README.md), [18](18/README.md) | labs/106 (Task 3), labs/107 (Task 2) |
| **sandbox pool** | Dedicated nodes with a prepared runtime, label, taint, and capacity. | [22](22/README.md) | labs/110 |
| **sandboxed runtime** | A runtime with a stronger isolation boundary, such as gVisor or Kata Containers. | [03](03/README.md), [22](22/README.md) | labs/110 (Tasks 1-3) |
| **SCMP_ACT_ERRNO** | A seccomp action returning an error for a syscall without executing it. | [17](17/README.md) | labs/106 (Task 4) |
| **SCMP_ACT_LOG** | A seccomp action allowing a syscall and requesting kernel logging. | [17](17/README.md) | |
| **seccomp** | A Linux mechanism filtering a process's system calls. | [03](03/README.md), [17](17/README.md), [18](18/README.md) | labs/106 (Tasks 3-5, 7) |
| **SECCOMP audit record** | A kernel/audit record of a seccomp-related event. | [17](17/README.md) | |
| **Secret mount** | Temporarily mounting a credential for one build command without writing it into the final layer. | [24](24/README.md) | |
| **security advisory** | A vendor's primary notice of affected versions, exploit conditions, mitigation, and a fixed version. | [13](13/README.md) | |
| **SecurityContext** | Kubernetes fields defining the identity and restrictions of a process or Pod. | [18](18/README.md), [33](33/README.md) | labs/106, labs/107 (Task 2) |
| **self-signed certificate** | A certificate signed by its own key rather than a trusted CA; suitable for tests but not trusted by default. | [08](08/README.md) | labs/103 (Task 4) |
| **SELinux** | Label-based MAC with type enforcement, complementing ordinary access permissions. | [03](03/README.md) | |
| **ServiceAccount (SA)** | A namespaced identity for Pods and processes in the Kubernetes API. | [11](11/README.md), [23](23/README.md) | labs/104 (Tasks 2-3) |
| **severity** | A finding's severity class: `LOW`, `MEDIUM`, `HIGH`, or `CRITICAL`. | [28](28/README.md) | labs/111 (Task 1) |
| **SHA-256 checksum** | A 256-bit file digest verifying byte-for-byte equality with a published artifact. | [09](09/README.md) | labs/103 (Task 6) |
| **shim** | A containerd process or binary connecting containerd with a particular runtime. | [22](22/README.md) | labs/110 (Task 1) |
| **Sidecar** | A proxy or other helper container alongside an application that intercepts or serves traffic. | [23](23/README.md) | labs/110 (Task 6) |
| **SLSA** | A maturity model for software supply-chain security practices. | [25](25/README.md) | |
| **Software supply chain** | The path of source, dependencies, build systems, and artifacts to a running workload. | [25](25/README.md) | labs/111 |
| **SPDX** | An open standard describing packages, licenses, and their relationships in an SBOM. | [25](25/README.md), [28](28/README.md) | labs/111 (Task 6) |
| **SSRF** | Server-Side Request Forgery, a vulnerability causing a server to request an attacker-chosen address. | [05](05/README.md) | labs/101 (Task 5) |
| **stage** | The audit-event creation stage: `RequestReceived`, `ResponseStarted`, `ResponseComplete`, or `Panic`. | [32](32/README.md) | labs/112 (Task 4) |
| **static analysis** | Checking Dockerfiles, manifests, and policies without running a workload. | [27](27/README.md) | labs/111 (Task 2) |
| **static Pod** | A Pod from a node-local manifest, managed by kubelet without scheduling through the Kubernetes API. | [07](07/README.md), [09](09/README.md), [12](12/README.md), [32](32/README.md), [33](33/README.md) | labs/103, labs/104 (Task 5), labs/112 (Task 4) |
| **sudoers** | A policy of commands a user can execute as another user; edit with `visudo`. | [15](15/README.md) | |
| **SUID/SGID** | Special file bits running a program with the owner's effective UID or the group's GID. | [15](15/README.md) | |
| **support window** | The supported version branches receiving security patches. | [13](13/README.md) | |
| **Syft** | A tool generating SBOMs from images, filesystems, or archives. | [25](25/README.md) | labs/111 (Task 7) |
| **syscall** | A system call through which a process requests a kernel operation. | [03](03/README.md), [17](17/README.md), [29](29/README.md) | labs/106 (Tasks 4-5) |
| **system:unauthenticated** | The anonymous subject's group; bindings require the same review as those for `system:anonymous`. | [12](12/README.md) | |
| **systemd unit** | A definition of a service, socket, timer, or other entity managed by systemd. | [14](14/README.md) | labs/105 (Task 1) |
| **TLS minimum version** | The minimum TLS version a server will negotiate with a client. | [09](09/README.md) | labs/103 (Task 5) |
| **TLS Secret** | A `kubernetes.io/tls` Secret containing `tls.crt` and `tls.key`. | [08](08/README.md) | labs/103 (Task 4) |
| **TLS termination** | Completing the TLS handshake and decrypting traffic at an ingress controller. | [08](08/README.md) | labs/103 (Task 4) |
| **toFQDNs** | A Cilium egress rule using DNS names and observed DNS responses. | [06](06/README.md) | labs/102 (Task 4) |
| **TokenRequest API** | An API issuing short-lived ServiceAccount tokens. | [11](11/README.md) | labs/104 (Task 2) |
| **Transparent encryption** | Datapath encryption without application, Service, or URL changes; Cilium applies it on nodes. | [23](23/README.md) | labs/110 (Task 4) |
| **triage** | Rapidly classifying a finding or event by source, risk, scope, and next action. | [33](33/README.md) | |
| **Trivy** | A scanner for images, SBOMs, filesystems, secrets, and configuration/IaC. | [28](28/README.md), [33](33/README.md) | labs/111 (Tasks 1, 5, 8) |
| **Unconfined** | No seccomp filter for a container; a temporary exception, not a baseline. | [17](17/README.md) | labs/106 (Task 5) |
| **Unix socket** | A local filesystem IPC endpoint; its permissions determine who can access a daemon API. | [14](14/README.md) | labs/105 (Task 6) |
| **userns-remap** | A Docker daemon feature (`dockerd --userns-remap`) remapping container UID/GID on the host within Docker itself; separate from Kubernetes Pod user namespaces (`hostUsers: false`) tested in lab 106. | [14](14/README.md) | |
| **Validating admission webhook** | A webhook that permits or rejects an object. | [20](20/README.md) | |
| **ValidatingAdmissionPolicy** | Built-in CEL validation in the API server without an external webhook; applied through a binding. | [20](20/README.md) | labs/107 (Task 6) |
| **version skew** | The allowed version difference between Kubernetes components; kubelet must not be newer than the API server. | [13](13/README.md) | |
| **webhook collector** | An HTTPS endpoint receiving audit events for centralized storage and analysis. | [32](32/README.md) | labs/112 (Task 8) |
| **WireGuard** | A VPN protocol with peer key pairs; the public key identifies the permitted peer. | [23](23/README.md) | labs/110 (Tasks 4-5) |
| **Workload identity** | A cryptographically verifiable workload identity, usually linked to ServiceAccount/namespace in a mesh. | [23](23/README.md) | labs/110 (Task 6) |
| **Writable layer** | A mutable layer added by the runtime over read-only image layers. | [31](31/README.md) | |
| **Zero trust** | Rejecting implicit trust based on network, namespace, or location. | [02](02/README.md) | |
