# KCSA Mock Exam 01

> **Training simulation.** This is an original practice mock of approximately 60 questions, not an official Linux Foundation contract or a reproduction of the real exam.

Allow **90 minutes** to complete it. As of 2026-09-01, the LF Multiple Choice FAQ lists a passing score of **75% or above**; before registering, confirm the KCSA conditions on the official Linux Foundation page. Practice in a closed-book setting: do not use documentation, search, notes, tools, or external websites. There are no hands-on tasks: choose one most accurate answer for every question.

The question distribution follows the instructional domain weights: Overview - 8, Cluster Component Security - 13, Security Fundamentals - 13, Threat Model - 10, Platform Security - 10, Compliance and Security Frameworks - 6.

## Overview of Cloud Native Security - questions 1-8

### 1. How does the 4C model help select a control for a Kubernetes risk?

a. It separates protection into Cloud, Cluster, Container, and Code layers
b. It limits analysis to the container image only
c. It proves that only the provider is responsible for security
d. It replaces threat modeling with a single vulnerability table

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** The 4C model divides the attack surface and controls into Cloud, Cluster, Container, and Code, which helps select the layer-appropriate control for a given risk. Option b incorrectly narrows analysis to only the container image, ignoring the Cloud, Cluster, and Code layers; option c incorrectly claims the model proves the provider bears sole responsibility; and option d incorrectly claims the model replaces threat modeling with a single table. See [chapter 03](../../course/03/ru.md).

</details>

### 2. What most accurately describes shared responsibility in managed Kubernetes?

a. The customer is responsible only for paying for resources
b. The provider is responsible for every workload configuration
c. Shared responsibility eliminates the need for IAM
d. Responsibility boundaries depend on the service, while the customer still secures its data and configuration

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** In a managed service, the provider operates part of the platform, but the customer remains responsible for workload, identity, and data configuration, so responsibility boundaries depend on the service while the customer still secures its own data and configuration. Options a, b, and c each deny or oversimplify shared responsibility by assigning it entirely to one party or dismissing IAM. See [chapter 04](../../course/04/ru.md).

</details>

### 3. What risk does workload access to a cloud provider metadata service create?

a. NetworkPolicy encrypts requests to the metadata service
b. The Pod automatically receives cluster-admin privileges
c. The image registry stops checking signatures
d. A process may obtain temporary cloud credentials if access is not restricted

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A metadata service can issue temporary cloud credentials to a workload, so unrestricted access to it lets a process obtain those credentials — this is the risk. Options a, b, and c describe unrelated or incorrect mechanisms (NetworkPolicy encrypting requests, automatic cluster-admin grants, and registries no longer checking signatures) rather than the metadata-access risk. See [chapter 04](../../course/04/ru.md).

</details>

### 4. Which is an example of a preventive control?

a. A postmortem after an incident
b. An audit log that records an API request already made
c. Falco reporting a suspicious system call
d. An admission policy that rejects a privileged Pod

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** An admission policy prevents an unsafe object from being created, which makes it the preventive control here. Option c (Falco reporting a suspicious system call) is a detection control that observes activity as it happens; option a (a postmortem after an incident) is a post-incident analysis / lessons-learned activity that happens after the fact, not a detection or prevention control; and option b is a record of an action that already happened, not a control that stops it. See [chapter 15](../../course/15/ru.md), which contains the explicit preventive/detective/evidence distinction.

</details>

### 5. What is the primary purpose of a sandbox runtime such as gVisor or Kata?

a. Make all images trusted without inspection
b. Automatically create an SBOM
c. Replace RBAC for API users
d. Strengthen the isolation boundary between a workload and the host

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A sandbox runtime strengthens workload isolation from the host. Image inspection, RBAC, and SBOMs solve different problems. See [chapter 05](../../course/05/ru.md).

</details>

### 6. Why is an immutable digest preferable to the `latest` tag when pinning an image?

a. A digest always contains fewer vulnerabilities
b. A digest automatically signs an image
c. The Kubernetes API prohibits the `latest` tag
d. A digest identifies specific immutable image content

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A digest identifies specific, immutable image content by its cryptographic hash, so it cannot be silently retargeted the way a mutable tag such as `latest` can. Options a, b, and c make unsupported claims: a digest does not reduce the number of vulnerabilities, does not sign an image, and the Kubernetes API does not prohibit the `latest` tag. See [chapter 06](../../course/06/ru.md).

</details>

### 7. Which approach best reduces the risk of a secret accidentally committed to source code?

a. Store the secret only in a private Git branch
b. Rename the file containing the secret
c. Remove the secret from the code, revoke it, and use managed secret storage
d. Base64-encode the secret before committing it

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Remove the secret from the code and revoke it, then deliver it through appropriate secret management. Base64, a private branch, and renaming do not resolve an exposure. See [chapter 06](../../course/06/ru.md).

</details>

### 8. Which statement about isolation and segmentation is correct?

a. A single `Service` provides complete tenant isolation
b. Isolation commonly combines namespaces, RBAC, NetworkPolicy, and stronger runtime boundaries when needed
c. RBAC provides L3/L4 packet filtering
d. A Namespace by itself blocks all network traffic between tenants

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Tenant protection is layered. A Namespace does not automatically provide network isolation, RBAC does not filter packets, and a Service is not a security boundary. See [chapter 05](../../course/05/ru.md).

</details>

## Kubernetes Cluster Component Security - questions 9-21

### 9. What is the role of kube-apiserver in a request security pipeline?

a. It receives the request and performs authentication, authorization, and admission
b. It runs containers on a worker node
c. It creates NetworkPolicy rules at the CNI level
d. It stores only container images

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** The API server is the central API pipeline point: authentication, authorization, and then admission. The other options describe different components or functions. See [chapter 07](../../course/07/ru.md).

</details>

### 10. Why does etcd access require strict protection?

a. Compromise of etcd can expose cluster state and sensitive data
b. etcd applies Pod Security Standards
c. etcd replaces kube-apiserver for user authentication
d. etcd stores only temporary metrics

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** etcd stores critical cluster state, including sensitive data, so its compromise is very serious and justifies strict protection. Options b, c, and d assign etcd an incorrect role: etcd does not apply Pod Security Standards, does not replace kube-apiserver for authentication, and stores far more than temporary metrics. See [chapter 07](../../course/07/ru.md).

</details>

### 11. Which kubelet configuration is especially dangerous without additional protection?

a. Using `containerd` rather than Docker
b. Using the `kube-system` namespace
c. An exposed, unauthenticated kubelet API
d. Having a CNI plugin

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** An unauthenticated kubelet API exposes a dangerous remote entry point to a node. Using a particular runtime, CNI, or namespace is not by itself equivalent to this vulnerability. See [chapter 08](../../course/08/ru.md).

</details>

### 12. Why is access to a container runtime socket dangerous on a node?

a. It can allow container management and bring an attacker close to host control
b. It permits only reading image manifests
c. It works only within one Namespace
d. It eliminates the need for TLS on the API server

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** A runtime socket often grants strong container-management privileges and therefore creates a risk of host control, which is the danger here. Options b, c, and d incorrectly limit its significance: the socket permits far more than reading manifests, it is not confined to one Namespace, and it has no relationship to API server TLS. See [chapter 08](../../course/08/ru.md).

</details>

### 13. Which Linux backend modes does kube-proxy support in current Kubernetes?

a. Only `nftables`
b. Only eBPF and IPVS
c. Only `iptables` and IPVS
d. `iptables`, `nftables`, and IPVS

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** kube-proxy Linux modes are `iptables`, `nftables`, and IPVS. eBPF may be used by a CNI, but it is not in this list of kube-proxy modes. See [chapter 08](../../course/08/ru.md).

</details>

### 14. Which statement about IPVS in kube-proxy is correct?

a. IPVS has been deprecated since Kubernetes v1.35; `nftables` is recommended for new deployments
b. IPVS is the recommended replacement for `nftables`
c. IPVS was removed in Kubernetes v1.25
d. IPVS is an implementation of NetworkPolicy

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** IPVS has been deprecated since Kubernetes v1.35, and `nftables` is recommended as its replacement for new installations, which matches option a. Option b reverses the recommendation (nftables replaces IPVS, not the other way around), c gives the wrong removal/deprecation date, and d confuses kube-proxy Service routing with the separate NetworkPolicy mechanism. See [chapter 08](../../course/08/ru.md).

</details>

### 15. What is true about kube-proxy and NetworkPolicy?

a. kube-proxy encrypts ingress traffic
b. NetworkPolicy is needed only for LoadBalancer Services
c. kube-proxy provides Service routing but does not replace CNI policy enforcement
d. kube-proxy replaces NetworkPolicy for Pod-to-Pod isolation

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** kube-proxy implements Service networking, whereas the CNI enforces NetworkPolicy — these are separate mechanisms, which matches option c. Option a incorrectly assigns encryption to kube-proxy, option b wrongly limits NetworkPolicy to LoadBalancer Services only, and option d incorrectly claims kube-proxy replaces NetworkPolicy for Pod isolation. See [chapter 08](../../course/08/ru.md).

</details>

### 16. Which measure best reduces the risk of worker node compromise?

a. Disable audit logging
b. Mount `hostPath` into every Pod
c. Give every Pod `privileged: true`
d. Restrict node access, protect kubelet and runtime sockets, and apply least privilege

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Node security combines restricted access, hardened kubelet and runtime configuration, and least privilege, which is the measure in option d. Options a and b raise risk instead of reducing it (disabling audit logging removes evidence, and mounting hostPath everywhere expands host exposure), and c (granting every Pod `privileged: true`) removes containment rather than reducing risk. See [chapter 08](../../course/08/ru.md).

</details>

### 17. Which `securityContext` most directly reduces the risk of a process running with root UID?

a. `hostNetwork: true`
b. `privileged: true`
c. `hostPID: true`
d. `runAsNonRoot: true`

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** `runAsNonRoot: true` requires a process not to run as root, which most directly reduces this risk. Options a, b, and c instead expand privilege or host visibility: `hostNetwork: true` shares the host network namespace, `privileged: true` grants broad host access, and `hostPID: true` exposes host process information. See [chapter 09](../../course/09/ru.md).

</details>

### 18. Why does `hostPath` require special care?

a. It can expose host data or sockets to a container
b. It works only with `StatefulSet`
c. It prevents a Pod from reading its own filesystem
d. It automatically encrypts volume data

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** `hostPath` connects a Pod to the host filesystem and can expose sensitive host paths and sockets, which is why it requires special care. Options b, c, and d are incorrect: `hostPath` is not limited to `StatefulSet`, it does not prevent a Pod from reading its own filesystem, and it does not automatically encrypt volume data. See [chapter 09](../../course/09/ru.md).

</details>

### 19. Which client artifact needs special protection because it can contain a cluster endpoint and credentials?

a. `NetworkPolicy`
b. `kubeconfig`
c. `Containerfile`
d. `RuntimeClass`

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** A `kubeconfig` can contain endpoints, certificates, and tokens. The other objects are not typical client credential bundles. See [chapter 09](../../course/09/ru.md).

</details>

### 20. Which protection is most suitable when Pod traffic must allow only a specific flow?

a. Sign the container image
b. Use `NetworkPolicy` if the CNI supports it
c. Enable `hostNetwork`
d. Increase the Deployment replica count

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** NetworkPolicy expresses permitted Pod flows when the CNI enforces it. Signing, replicas, and `hostNetwork` do not provide the required segmentation. See [chapter 09](../../course/09/ru.md).

</details>

### 21. Which pair of components belongs to the control plane rather than node components?

a. kube-proxy and CRI-O
b. kubelet and kube-proxy
c. kube-scheduler and kube-controller-manager
d. containerd and CNI

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** The scheduler and controller manager are control-plane components. kubelet, kube-proxy, and runtimes are node components. See [chapter 07](../../course/07/ru.md).

</details>

## Kubernetes Security Fundamentals - questions 22-34

### 22. How does authentication differ from authorization in Kubernetes?

a. Authentication determines permissions; authorization verifies identity
b. Authorization runs only in etcd
c. Authentication verifies who makes a request; authorization determines the permitted action
d. They are two names for admission control

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Authentication establishes identity and authorization determines permitted actions, which matches option c. Option a reverses the two concepts, option b incorrectly claims authorization runs only in etcd, and option d incorrectly conflates authentication/authorization with admission control, which is a separate later stage. See [chapter 10](../../course/10/ru.md).

</details>

### 23. Which mechanism is suitable for federating a user's identity with the Kubernetes API?

a. `hostPath`
b. OIDC
c. IPVS
d. `ResourceQuota`

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** OIDC integrates an external identity provider with API server authentication. The other options concern storage, networking, or quota. See [chapter 10](../../course/10/ru.md).

</details>

### 24. Why should every workload not thoughtlessly use the default `ServiceAccount`?

a. It prevents Deployments from running
b. It disables DNS
c. It encrypts Secrets twice
d. Its token and permissions can become unnecessary attack surface

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** The default ServiceAccount's token and its permissions can become unnecessary attack surface if a workload is compromised, which is the reason to avoid using it thoughtlessly. Options a, b, and c are incorrect: using the default ServiceAccount does not prevent Deployments from running, does not disable DNS, and does not encrypt Secrets twice. See [chapter 10](../../course/10/ru.md).

</details>

### 25. What does the least-privilege principle mean in RBAC?

a. Grant `cluster-admin` to avoid access errors
b. Grant only the minimum necessary verbs, resources, and scope
c. Use only ABAC
d. Create a `ClusterRoleBinding` for every Pod

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Least privilege limits verbs, resources, and scope to the necessary minimum. Option a (granting `cluster-admin` broadly) directly creates excessive privileges. Option c (using only ABAC) is not inherently a violation of least privilege — ABAC can express fine-grained policy — but compared with Kubernetes RBAC it is generally harder to manage and audit consistently, and excessive privilege is a possible policy outcome rather than an inherent property of ABAC itself. Option d (a ClusterRoleBinding for every Pod) is unnecessary and grants broader, cluster-wide scope than most Pods require. See [chapter 10](../../course/10/ru.md).

</details>

### 26. What is the most accurate purpose of Pod Security Admission?

a. Encrypt Secrets in etcd
b. Check an image signature without a policy
c. Apply Pod Security Standards through Namespace labels in enforce, audit, and warn modes
d. Replace kubelet on every node

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** PSA applies PSS through Namespace labels in `enforce`, `audit`, and `warn` modes, or through cluster-wide defaults configured in the admission controller's own configuration when a Namespace has no labels of its own — Namespace labels take precedence over an applicable cluster-wide default where both exist. The other options belong to different subsystems. See [chapter 11](../../course/11/ru.md).

</details>

### 27. Which Pod Security Standards profile permits the broadest set of privileges?

a. `restricted`
b. `baseline`
c. `audit`
d. `privileged`

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** The `privileged` profile is the most permissive. `baseline` and `restricted` impose limits, while `audit` is a PSA mode rather than a PSS profile. See [chapter 11](../../course/11/ru.md).

</details>

### 28. How should base64 in a `Secret` object be understood?

a. It is encryption at rest
b. It is a digital signature format
c. It is encoding, not cryptographic protection of content
d. It is an RBAC check

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Base64 reversibly encodes a representation of data and does not provide confidentiality, which matches option c. Options a, b, and d describe other mechanisms: base64 is not encryption at rest, not a digital signature format, and has no relationship to RBAC checks. See [chapter 12](../../course/12/ru.md).

</details>

### 29. How can a Kubernetes Secret be protected at rest?

a. Configure EncryptionConfiguration, use KMS when appropriate, and restrict access with RBAC
b. Put the Secret into a ConfigMap
c. Rely only on base64
d. Enable `hostNetwork`

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Protecting a Secret at rest requires EncryptionConfiguration and, where appropriate, KMS; RBAC restricts access. The other answers do not provide this protection. See [chapter 12](../../course/12/ru.md).

</details>

### 30. What is the role of `NetworkPolicy` in a namespace with default-deny?

a. It automatically removes every ServiceAccount
b. It defines allowed ingress and/or egress flows for selected Pods
c. It updates iptables on the control plane without a CNI
d. It encrypts all HTTP requests

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** With default-deny, NetworkPolicy opens only explicitly allowed flows for selected Pods. Options a, c, and d concern other functions. See [chapter 13](../../course/13/ru.md).

</details>

### 31. Which statement about NetworkPolicy is true?

a. It replaces TLS
b. It applies only to `NodePort`
c. Effective enforcement requires a CNI that supports NetworkPolicy
d. Every CNI must implement it without exception

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** The NetworkPolicy API is insufficient without CNI implementation. Option a is too absolute, while b and d incorrectly limit its purpose. See [chapter 13](../../course/13/ru.md).

</details>

### 32. What does Kubernetes audit logging record?

a. Events and requests processed by the Kubernetes API server
b. Every kernel system call in a container
c. Only network packets between Pods
d. Only kubelet errors

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** The API server generates and processes audit events, after which a configured backend stores them. System calls and packets are other observability sources. See [chapter 14](../../course/14/ru.md).

</details>

### 33. What is the most accurate distinction between audit logging and runtime detection?

a. Both mechanisms provide only encryption at rest
b. Audit records API actions; runtime detection observes the behavior of running workloads and nodes
c. Runtime detection creates RoleBindings
d. Audit replaces NetworkPolicy; runtime detection replaces RBAC

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Audit observes API operations; runtime detection observes activity in running workloads and hosts. The other answers confuse independent controls. See [chapter 14](../../course/14/ru.md).

</details>

### 34. What does `LimitRange` limit, unlike `ResourceQuota`?

a. Only access to the Kubernetes API
b. Network connections between Namespaces
c. Request/limit values of individual containers and objects in a Namespace
d. Only total consumption across the entire cluster

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** `LimitRange` sets or limits resource request/limit values on individual containers and objects within a Namespace, unlike `ResourceQuota`, which controls aggregate Namespace-wide usage. Options a, b, and d are incorrect: `LimitRange` is not about API access, it does not control network connections between Namespaces, and it applies to individual objects rather than only total cluster-wide consumption. See [chapter 13](../../course/13/ru.md).

</details>

## Kubernetes Threat Model - questions 35-44

### 35. What is a trust boundary in a Kubernetes threat model?

a. A point where the level of trust changes and an interaction requires validation or protection
b. The maximum size of a container image
c. A Service type
d. Any Namespace with a label

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** A trust boundary is a transition between levels of trust. A Namespace and Service can participate in a model but are not themselves the definition of a boundary. See [chapter 15](../../course/15/ru.md).

</details>

### 36. Which scenario is an example of persistence in Kubernetes?

a. A Service sends traffic to an endpoint
b. A Pod receives a new IP after being recreated
c. An attacker creates a mechanism that survives a restart and restores access
d. A user reads API documentation

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Persistence retains or restores an attacker's access, which matches the scenario in option c, where a mechanism survives a restart. Options a, b, and d describe ordinary operation: a Service forwarding traffic, a Pod receiving a new IP after normal recreation, and a user reading documentation are not persistence mechanisms. See [chapter 16](../../course/16/ru.md).

</details>

### 37. Which measure directly reduces the risk of workload resource-exhaustion DoS?

a. `kubeconfig` rotation
b. `ResourceQuota` and requests/limits
c. Image signing
d. OIDC authentication

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Quota and requests/limits constrain excessive resource consumption. Authentication, signing, and rotation address other risks. See [chapter 16](../../course/16/ru.md).

</details>

### 38. Which sign most closely indicates malicious code execution in a container?

a. A Namespace contains a label
b. A Service uses ClusterIP
c. A Deployment has three replicas
d. A process starts an unexpected shell or downloads and runs a malicious payload

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Unexpectedly obtaining and running a payload is a characteristic malicious-execution indicator. The other events are ordinary by themselves. See [chapter 16](../../course/16/ru.md).

</details>

### 39. Which control reduces an attacker's risk of lateral movement in the cluster network?

a. Segmentation with NetworkPolicy and TLS/mTLS protection for traffic where needed
b. Converting a Secret to base64
c. Disabling admission control
d. Increasing `terminationGracePeriodSeconds`

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Segmentation with NetworkPolicy limits lateral-movement paths, while TLS/mTLS protects the required channels. Options b, c, and d do not address this risk. See [chapter 16](../../course/16/ru.md).

</details>

### 40. Why is Secret access often considered access to sensitive data?

a. A Secret is available only to kubelet and nobody else
b. A Secret can contain credentials, keys, and tokens that unlock other systems
c. A Secret cannot be mounted into a Pod
d. A Secret is always automatically encrypted everywhere

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Credentials and keys in a Secret can unlock access beyond a single Pod. Option a falsely assumes automatic protection, while c and d are incorrect. See [chapter 16](../../course/16/ru.md).

</details>

### 41. Which Pod setting creates an explicit risk of privilege escalation?

a. `seccompProfile: RuntimeDefault`
b. `readOnlyRootFilesystem: true`
c. `runAsNonRoot: true`
d. `allowPrivilegeEscalation: true`

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** `allowPrivilegeEscalation: true` explicitly permits a process to gain more privileges than its parent process, creating the described risk. Options a, b, and c are restrictive settings that reduce risk instead: `seccompProfile: RuntimeDefault` restricts syscalls, `readOnlyRootFilesystem: true` prevents filesystem writes, and `runAsNonRoot: true` blocks running as root. See [chapter 16](../../course/16/ru.md).

</details>

### 42. What relationship between data flow and threat modeling is useful?

a. It describes only replica placement
b. A data flow consists only of YAML manifests
c. Data flows show where data crosses trust boundaries and where controls are needed
d. Data flow eliminates the need for authentication

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Data flow analysis shows where data crosses trust boundaries and where controls are needed, which is the useful relationship to threat modeling here. Options a, b, and d are incorrect: a data flow is not limited to replica placement or to YAML manifests, and it does not eliminate the need for authentication. See [chapter 15](../../course/15/ru.md).

</details>

### 43. What is a typical goal of an attacker on the network?

a. Intercept, alter, or exploit insufficiently protected network traffic
b. Delete an unnecessary label
c. Create a `ConfigMap`
d. Reduce a container image's size

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** A network attacker seeks to read, alter, or exploit traffic. Options b, c, and d are not network-channel attacks. See [chapter 16](../../course/16/ru.md).

</details>

### 44. Which combination best reduces the risk of container escape after application compromise?

a. Only audit level `Metadata`
b. Privileged mode, hostPID, and hostPath
c. Minimum privileges, PSS/PSA, seccomp, and restricted capabilities
d. More replicas only

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Minimum privilege, PSA/PSS, seccomp, and reduced capabilities create several independent preventive barriers against container escape, which matches option c. Option a (relying only on `Metadata`-level audit) does not itself increase or reduce escape risk — it affects audit evidence and observability, not prevention, so it does not address the risk asked about here. Option b actively creates escape paths through privileged mode, hostPID, and hostPath. Option d (adding replicas only) does nothing to reduce escape risk, since replicas do not change per-container privilege or isolation. See [chapter 16](../../course/16/ru.md).

</details>

## Platform Security - questions 45-54

### 45. What does the software supply chain describe in cloud native systems?

a. The chain from source code and dependencies through build, registry, deployment, and runtime
b. Only the network packet path from a client to a Service
c. Only user RBAC
d. Only etcd backups

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** The supply chain covers an artifact's journey from source code and dependencies through build, registry, deployment, and runtime, which matches option a. Option b describes network data flow, not the supply chain, and options c and d each narrow the concept to a single unrelated area (RBAC alone, or etcd backups alone). See [chapter 17](../../course/17/ru.md).

</details>

### 46. What is an SBOM?

a. A policy that permits a Pod in the cluster
b. Proof of a user's API identity
c. A replacement for a digital signature
d. An inventory of components and dependencies in a software artifact

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** An SBOM describes an artifact's composition and dependencies. Admission, authentication, and signature have different purposes. See [chapter 17](../../course/17/ru.md).

</details>

### 47. What does a digital image signature establish when verification succeeds?

a. The image uses only one layer
b. The image automatically complies with SLSA
c. The signature is associated with a specific artifact and a trusted key or identity according to policy
d. The image has no vulnerabilities

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** A signature associates the verified artifact with a signer or trusted identity according to policy; it does not guarantee the absence of vulnerabilities and is not equivalent to SLSA. See [chapter 17](../../course/17/ru.md).

</details>

### 48. What does provenance do?

a. It describes an artifact's origin and build process
b. It replaces an SBOM dependency list
c. It encrypts the network between Pods
d. It sets ResourceQuota

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Provenance states how and where an artifact originated. It does not replace an SBOM, encryption, or quota. See [chapter 17](../../course/17/ru.md).

</details>

### 49. What is true about SLSA?

a. It is a synonym for SBOM
b. It is a framework of supply-chain integrity levels and requirements, not a single artifact file
c. It is a Kubernetes authorization mode
d. It is a runtime sandbox

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** SLSA is a framework for assessing supply-chain integrity, not an SBOM format or Kubernetes component. See [chapter 17](../../course/17/ru.md).

</details>

### 50. What can admission control do for an image repository?

a. Automatically create a NetworkPolicy
b. Allow only images from approved registries
c. Update a kubelet certificate
d. Recompile an image on a node

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** An admission policy can reject a workload whose image comes from an unapproved registry. The other actions are not admission tasks. See [chapter 17](../../course/17/ru.md).

</details>

### 51. How does a validating admission webhook differ from a mutating admission webhook?

a. Both work only with Secrets
b. Mutating can modify an object before storage; validating accepts or rejects it
c. There is no difference between them
d. Validating changes the object; mutating only audits it

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** A mutating webhook changes an object in the admission chain; a validating webhook decides whether to accept or reject it. Option d reverses these roles (it assigns object-changing to validating and audit-only to mutating), option a incorrectly limits both webhook types to Secrets only, and option c incorrectly claims there is no difference between them. See [chapter 17](../../course/17/ru.md).

</details>

### 52. Which task is part of security observability?

a. Replace all controls with one dashboard
b. Correlate logs, metrics, and traces to detect anomalies and investigate them
c. Give every ServiceAccount administrator permissions
d. Hide audit events from the operator

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Correlating logs, metrics, and traces to detect anomalies and investigate them is a core observability task, which matches option b. Options a, c, and d each eliminate or weaken required controls instead: replacing all controls with one dashboard loses signal, granting every ServiceAccount administrator permissions violates least privilege, and hiding audit events from the operator removes evidence rather than supporting observability. See [chapter 18](../../course/18/ru.md).

</details>

### 53. How does a service mesh typically help secure service-to-service traffic?

a. It eliminates the need for certificates
b. It is a type of NetworkPolicy
c. It provides mTLS and traffic policies without changing business code in every service
d. It replaces the container runtime

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** A service mesh can provide workloads with mTLS and traffic policies. It does not replace runtime or PKI, nor is it NetworkPolicy. See [chapter 18](../../course/18/ru.md).

</details>

### 54. What is PKI used for in Kubernetes?

a. Trusted authentication and TLS encryption for connections between components and clients
b. Managing CPU limits
c. Creating an SBOM
d. Replacing an image registry

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** PKI provides party authentication and TLS connection protection. Resources, registries, and SBOMs are not its primary purpose. See [chapter 18](../../course/18/ru.md).

</details>

## Compliance and Security Frameworks - questions 55-60

### 55. How should the CIS Kubernetes Benchmark be used?

a. As a mechanism for running container images
b. As a mandatory replacement for all internal organizational requirements
c. As a user authentication system
d. As a set of recommendations and checks for assessing secure Kubernetes configuration

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** The CIS Benchmark is a practical set of recommendations and checks for secure configuration. It neither replaces all requirements nor runs containers or authenticates users. See [chapter 19](../../course/19/ru.md).

</details>

### 56. What is STRIDE's role in security work?

a. Collect runtime system calls
b. Sign container images
c. Categorize threats during threat modeling
d. Store Secrets

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** STRIDE categorizes threats during threat modeling, which matches option c. Options a, b, and d concern unrelated security controls: collecting runtime system calls is a detection mechanism, signing container images is a supply-chain control, and storing Secrets is a data-protection mechanism — none of them is what STRIDE does. See [chapter 19](../../course/19/ru.md).

</details>

### 57. How is MITRE ATT&CK for Containers useful to a security team?

a. It provides attack tactics and techniques that help map detection and mitigations
b. It establishes the exam passing score
c. It replaces the Kubernetes API
d. It encrypts etcd data

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** ATT&CK helps connect known techniques with controls and detection. It is not a Kubernetes component, an exam rule, or encryption. See [chapter 19](../../course/19/ru.md).

</details>

### 58. Which example best represents automation and tooling for compliance?

a. Read YAML manually once without criteria
b. Run configuration scans and policy checks regularly in CI/CD and review their results
c. Sign every Pod manually on a node
d. Disable audit to reduce log volume

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Repeatable automated checks in CI/CD provide measurable verification and early feedback. Option a does not scale, c weakens evidence, and d is not typical compliance automation. See [chapter 19](../../course/19/ru.md).

</details>

### 59. Why cannot SBOM, signature, provenance, and SLSA be considered interchangeable?

a. Only SBOM is related to security
b. They answer different questions: composition, integrity/signer, origin, and a supply-chain assurance framework
c. They all name the same JSON format
d. SLSA replaces all policy engines

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** An SBOM addresses composition, a signature addresses integrity and signer, provenance addresses origin, and SLSA addresses an assurance framework. They complement rather than replace one another. See [chapter 19](../../course/19/ru.md).

</details>

### 60. What is the most accurate interpretation of a reproducible build in the supply-chain context?

a. It is the same as encryption at rest
b. It is a way to authorize a request to kube-apiserver
c. It is a universal synonym for every SLSA level
d. It is a useful repeatable-build property, but not a universal substitute for SLSA requirements or levels

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A reproducible build is a useful, verifiable repeatable-build property, but it is not a universal substitute for SLSA's own requirements or levels, which matches option d. Options a, b, and c conflate unrelated concepts: a reproducible build is not encryption at rest, not an API authorization mechanism, and not a universal synonym for every SLSA level. See [chapter 19](../../course/19/ru.md).

</details>

## Score review and remediation
| Domain | Questions | How to interpret the result | What to review after mistakes |
|---|---:|---|---|
| Overview of Cloud Native Security | 1-8 | Mistakes indicate gaps in 4C, shared responsibility, and core controls. | [Chapters 03-06](../../course/03/ru.md) |
| Kubernetes Cluster Component Security | 9-21 | Mistakes show uncertainty about the control plane, node, and kube-proxy boundaries. | [Chapters 07-09](../../course/07/ru.md) |
| Kubernetes Security Fundamentals | 22-34 | Mistakes mean identity, policies, Secrets, and audit need review. | [Chapters 10-14](../../course/10/ru.md) |
| Kubernetes Threat Model | 35-44 | Mistakes suggest difficulty connecting a threat, trust boundary, and control. | [Chapters 15-16](../../course/15/ru.md) |
| Platform Security | 45-54 | Mistakes require review of supply chain, admission, observability, and PKI. | [Chapters 17-18](../../course/17/ru.md) |
| Compliance and Security Frameworks | 55-60 | Mistakes reveal confusion among frameworks, evidence, and automation. | [Chapter 19](../../course/19/ru.md) |

After review, repeat the missed topics without hints and then take the questions again under time pressure. This mock measures preparation but does not replace current Linux Foundation registration and exam rules.

[Mock exams](../README.md) · [Course contents](../../course/README_RU.md) · [Exam strategy](../../course/20/ru.md)
