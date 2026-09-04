# KCSA Mock Exam 01

> **Training simulation.** This is an original practice mock of approximately 60 questions, not an official Linux Foundation contract or a reproduction of the real exam.

Allow **90 minutes** to complete it. As of 2026-09-01, the LF Multiple Choice FAQ lists a passing score of **75% or above**; before registering, confirm the KCSA conditions on the official Linux Foundation page. Practice in a closed-book setting: do not use documentation, search, notes, tools, or external websites. There are no hands-on tasks: choose one most accurate answer for every question.

The question distribution follows the instructional domain weights: Overview - 8, Cluster Component Security - 13, Security Fundamentals - 13, Threat Model - 10, Platform Security - 10, Compliance and Security Frameworks - 6.

## Overview of Cloud Native Security - questions 1-8

### 1. **How does the 4C model help select a control for a Kubernetes risk?**

- [ ] A. It separates protection into Cloud, Cluster, Container, and Code layers
- [ ] B. It limits analysis to the container image only
- [ ] C. It proves that only the provider is responsible for security
- [ ] D. It replaces threat modeling with a single vulnerability table

<details><summary>Answer</summary>

**Correct answer:** A

The 4C model divides the attack surface and controls into Cloud, Cluster, Container, and Code, which helps select the layer-appropriate control for a given risk. Option b incorrectly narrows analysis to only the container image, ignoring the Cloud, Cluster, and Code layers; option c incorrectly claims the model proves the provider bears sole responsibility; and option d incorrectly claims the model replaces threat modeling with a single table. See [chapter 03](../../course/03/ru.md).

</details>

### 2. **What most accurately describes shared responsibility in managed Kubernetes?**

- [ ] A. The provider secures the managed control plane, so the customer no longer needs to secure workload identities, configuration, or application data.
- [ ] B. The customer remains responsible for every platform layer, including provider-managed control-plane hosts and the provider physical infrastructure.
- [ ] C. Responsibility is divided only by namespace: the provider secures system namespaces and the customer secures all other Kubernetes namespaces.
- [ ] D. The boundary depends on the managed service: the provider operates defined platform layers while the customer still secures its workloads, identities, configuration, and data.

<details><summary>Answer</summary>

**Correct answer:** D

Managed Kubernetes changes which platform layers the provider operates; it does not transfer all security responsibility. The customer still owns controls that remain inside its service boundary, including workload configuration, identities, and data. See [chapter 04](../../course/04/ru.md).

</details>
### 3. **What risk does workload access to a cloud provider metadata service create?**

- [ ] A. The metadata service automatically encrypts every request from a Pod and prevents the workload from receiving any cloud credential.
- [ ] B. Access to the metadata service automatically converts the Pod ServiceAccount into a Kubernetes cluster-admin identity.
- [ ] C. A workload reaching the metadata service causes the image registry to stop verifying signatures for that deployed artifact.
- [ ] D. A workload process may obtain temporary cloud credentials from the metadata service if network and identity access are not sufficiently restricted.

<details><summary>Answer</summary>

**Correct answer:** D

Cloud metadata services can expose temporary cloud credentials to eligible workloads. If a compromised process can reach an overly permissive metadata endpoint, those credentials can become an escalation path into the cloud boundary. The metadata service does not grant Kubernetes `cluster-admin`, alter registry verification, or automatically provide transport protection. See [chapter 04](../../course/04/ru.md).

</details>
### 4. **Which is an example of a preventive control?**

- [ ] A. A postmortem after an incident
- [ ] B. An audit log that records an API request already made
- [ ] C. Falco reporting a suspicious system call
- [ ] D. An admission policy that rejects a privileged Pod

<details><summary>Answer</summary>

**Correct answer:** D

An admission policy prevents an unsafe object from being created, which makes it the preventive control here. Option c (Falco reporting a suspicious system call) is a detection control that observes activity as it happens; option a (a postmortem after an incident) is a post-incident analysis / lessons-learned activity that happens after the fact, not a detection or prevention control; and option b is a record of an action that already happened, not a control that stops it. See [chapter 15](../../course/15/ru.md), which contains the explicit preventive/detective/evidence distinction.

</details>

### 5. **What is the primary purpose of a sandbox runtime such as gVisor or Kata?**

- [ ] A. A sandbox runtime verifies image signatures and establishes artifact provenance before the image is pulled onto a worker node.
- [ ] B. A sandbox runtime generates an SBOM for every container and blocks packages that are missing from the inventory.
- [ ] C. A sandbox runtime replaces Kubernetes RBAC by deciding which authenticated API users may create or update workload objects.
- [ ] D. A sandbox runtime strengthens the execution-isolation boundary between a workload and the host compared with a typical shared-kernel runtime.

<details><summary>Answer</summary>

**Correct answer:** D

gVisor and Kata Containers strengthen the execution boundary between workload and host using different isolation designs. They do not replace artifact signing/provenance, SBOM generation, or Kubernetes API authorization. See [chapter 05](../../course/05/ru.md).

</details>
### 6. **Why is an immutable digest preferable to the `latest` tag when pinning an image?**

- [ ] A. A digest always contains fewer vulnerabilities
- [ ] B. A digest automatically signs an image
- [ ] C. The Kubernetes API prohibits the `latest` tag
- [ ] D. A digest identifies specific immutable image content

<details><summary>Answer</summary>

**Correct answer:** D

A digest identifies specific, immutable image content by its cryptographic hash, so it cannot be silently retargeted the way a mutable tag such as `latest` can. Options a, b, and c make unsupported claims: a digest does not reduce the number of vulnerabilities, does not sign an image, and the Kubernetes API does not prohibit the `latest` tag. See [chapter 06](../../course/06/ru.md).

</details>

### 7. **Which approach best reduces the risk of a secret accidentally committed to source code?**

- [ ] A. Move the secret to a private branch, keep the same credential active, and rely on repository visibility to prevent further exposure.
- [ ] B. Rename the file, add it to `.gitignore`, keep the exposed credential active, and leave the existing repository history unchanged.
- [ ] C. Remove the secret from source, revoke or rotate the exposed credential, and deliver the replacement through appropriate secret management.
- [ ] D. Base64-encode the secret, recommit the encoded value, keep the original credential active, and restrict access to the repository.

<details><summary>Answer</summary>

**Correct answer:** C

Once a credential has been committed, removing the visible line is not enough: the credential should be revoked or rotated and the replacement should be delivered through an appropriate secret-management path. Private branches, renaming, `.gitignore`, or base64 do not invalidate an exposed credential. See [chapter 06](../../course/06/ru.md).

</details>
### 8. **Which statement about isolation and segmentation is correct?**

- [ ] A. A single `Service` provides complete tenant isolation
- [ ] B. Isolation commonly combines namespaces, RBAC, NetworkPolicy, and stronger runtime boundaries when needed
- [ ] C. RBAC provides L3/L4 packet filtering
- [ ] D. A Namespace by itself blocks all network traffic between tenants

<details><summary>Answer</summary>

**Correct answer:** B

Tenant protection is layered. A Namespace does not automatically provide network isolation, RBAC does not filter packets, and a Service is not a security boundary. See [chapter 05](../../course/05/ru.md).

</details>

## Kubernetes Cluster Component Security - questions 9-21

### 9. **What is the role of kube-apiserver in a request security pipeline?**

- [ ] A. It receives the request and performs authentication, authorization, and admission
- [ ] B. It runs containers on a worker node
- [ ] C. It creates NetworkPolicy rules at the CNI level
- [ ] D. It stores only container images

<details><summary>Answer</summary>

**Correct answer:** A

The API server is the central API pipeline point: authentication, authorization, and then admission. The other options describe different components or functions. See [chapter 07](../../course/07/ru.md).

</details>

### 10. **Why does etcd access require strict protection?**

- [ ] A. etcd stores critical Kubernetes state and can contain sensitive API data, so compromise can affect both confidentiality and cluster integrity.
- [ ] B. etcd applies Pod Security Standards to new workloads and therefore directly decides whether privileged Pods may be admitted.
- [ ] C. etcd authenticates end users instead of kube-apiserver and therefore holds the primary login policy for every Kubernetes client.
- [ ] D. etcd stores only temporary monitoring metrics, so strict protection is required mainly to preserve historical observability data.

<details><summary>Answer</summary>

**Correct answer:** A

etcd stores Kubernetes API state and can contain sensitive objects. Direct compromise can therefore expose data and undermine cluster integrity. Pod Security Admission, user authentication, and monitoring storage are different functions. See [chapter 07](../../course/07/ru.md).

</details>
### 11. **Which kubelet configuration is especially dangerous without additional protection?**

- [ ] A. Using `containerd` rather than Docker
- [ ] B. Using the `kube-system` namespace
- [ ] C. An exposed, unauthenticated kubelet API
- [ ] D. Having a CNI plugin

<details><summary>Answer</summary>

**Correct answer:** C

An unauthenticated kubelet API exposes a dangerous remote entry point to a node. Using a particular runtime, CNI, or namespace is not by itself equivalent to this vulnerability. See [chapter 08](../../course/08/ru.md).

</details>

### 12. **Why is access to a container runtime socket dangerous on a node?**

- [ ] A. It can allow container management and bring an attacker close to host control
- [ ] B. It permits only reading image manifests
- [ ] C. It works only within one Namespace
- [ ] D. It eliminates the need for TLS on the API server

<details><summary>Answer</summary>

**Correct answer:** A

A runtime socket often grants strong container-management privileges and therefore creates a risk of host control, which is the danger here. Options b, c, and d incorrectly limit its significance: the socket permits far more than reading manifests, it is not confined to one Namespace, and it has no relationship to API server TLS. See [chapter 08](../../course/08/ru.md).

</details>

### 13. **Which Linux backend modes does kube-proxy support in current Kubernetes?**

- [ ] A. Only `nftables`
- [ ] B. Only eBPF and IPVS
- [ ] C. Only `iptables` and IPVS
- [ ] D. `iptables`, `nftables`, and IPVS

<details><summary>Answer</summary>

**Correct answer:** D

kube-proxy Linux modes are `iptables`, `nftables`, and IPVS. eBPF may be used by a CNI, but it is not in this list of kube-proxy modes. See [chapter 08](../../course/08/ru.md).

</details>

### 14. **Which statement about IPVS in kube-proxy is correct?**

- [ ] A. IPVS remains available but has been deprecated since Kubernetes v1.35; `nftables` is recommended for new Linux deployments.
- [ ] B. IPVS became the default kube-proxy backend in v1.35, while `nftables` entered deprecation for new clusters.
- [ ] C. IPVS support was removed completely in v1.35, so selecting `mode: ipvs` is rejected by kube-proxy.
- [ ] D. IPVS is the Kubernetes NetworkPolicy enforcement engine rather than a backend for Service traffic handling.

<details><summary>Answer</summary>

**Correct answer:** A

Kubernetes deprecated kube-proxy IPVS mode beginning with v1.35, but it remains available in current releases. The Kubernetes project recommends `nftables` for new Linux deployments where supported. IPVS is a Service-proxy backend, not a NetworkPolicy implementation. See [chapter 08](../../course/08/ru.md).

</details>
### 15. **What is true about kube-proxy and NetworkPolicy?**

- [ ] A. kube-proxy encrypts Pod ingress traffic, so a CNI does not need to implement NetworkPolicy enforcement on worker nodes.
- [ ] B. NetworkPolicy applies only to LoadBalancer Services, and kube-proxy evaluates those policies before forwarding Service traffic.
- [ ] C. kube-proxy handles Service traffic, while NetworkPolicy enforcement is provided by a network implementation that supports the policy API.
- [ ] D. kube-proxy replaces NetworkPolicy for Pod isolation whenever its Service backend uses iptables, nftables, or IPVS mode.

<details><summary>Answer</summary>

**Correct answer:** C

kube-proxy implements Service traffic handling; it is not the NetworkPolicy enforcement engine. NetworkPolicy needs a network implementation that supports that API. See [chapter 08](../../course/08/ru.md).

</details>
### 16. **Which measure best reduces the risk of worker node compromise?**

- [ ] A. Disable node audit and runtime telemetry to reduce local security overhead.
- [ ] B. Mount host filesystem paths into workloads that need routine troubleshooting access.
- [ ] C. Run application Pods privileged so they can repair node-level problems themselves.
- [ ] D. Restrict node access, protect kubelet/runtime sockets, and apply least privilege.

<details><summary>Answer</summary>

**Correct answer:** D

Restricting administrative access, protecting kubelet and runtime sockets, and applying least privilege reduce the worker node's exposed attack paths and blast radius. Disabling telemetry, broadly mounting host paths, or running workloads privileged weakens node security. See [chapter 08](../../course/08/ru.md).

</details>
### 17. **Which `securityContext` most directly reduces the risk of a process running with root UID?**

- [ ] A. `hostNetwork: true`
- [ ] B. `privileged: true`
- [ ] C. `hostPID: true`
- [ ] D. `runAsNonRoot: true`

<details><summary>Answer</summary>

**Correct answer:** D

`runAsNonRoot: true` requires a process not to run as root, which most directly reduces this risk. Options a, b, and c instead expand privilege or host visibility: `hostNetwork: true` shares the host network namespace, `privileged: true` grants broad host access, and `hostPID: true` exposes host process information. See [chapter 09](../../course/09/ru.md).

</details>

### 18. **Why does `hostPath` require special care?**

- [ ] A. It can expose host data or sockets to a container
- [ ] B. It works only with `StatefulSet`
- [ ] C. It prevents a Pod from reading its own filesystem
- [ ] D. It automatically encrypts volume data

<details><summary>Answer</summary>

**Correct answer:** A

`hostPath` connects a Pod to the host filesystem and can expose sensitive host paths and sockets, which is why it requires special care. Options b, c, and d are incorrect: `hostPath` is not limited to `StatefulSet`, it does not prevent a Pod from reading its own filesystem, and it does not automatically encrypt volume data. See [chapter 09](../../course/09/ru.md).

</details>

### 19. **Which client artifact needs special protection because it can contain a cluster endpoint and credentials?**

- [ ] A. `NetworkPolicy`
- [ ] B. `kubeconfig`
- [ ] C. `Containerfile`
- [ ] D. `RuntimeClass`

<details><summary>Answer</summary>

**Correct answer:** B

A `kubeconfig` can contain endpoints, certificates, and tokens. The other objects are not typical client credential bundles. See [chapter 09](../../course/09/ru.md).

</details>

### 20. **Which statement best describes the role of a CNI plugin in Kubernetes Pod networking?**

- [ ] A. It authenticates Kubernetes API users and evaluates their RBAC permissions.
- [ ] B. It configures Pod network connectivity, such as interfaces, addressing, and routing, according to the selected networking implementation.
- [ ] C. It signs image provenance attestations before a workload reaches admission control.
- [ ] D. It schedules pending Pods onto nodes by evaluating resource requests and placement constraints.

<details><summary>Answer</summary>

**Correct answer:** B

A CNI implementation provides Pod network connectivity, typically configuring interfaces, addresses, routes, and related networking state. Some CNI implementations also enforce Kubernetes `NetworkPolicy`, but CNI networking itself is distinct from API authentication/RBAC, artifact signing, and scheduling. See [chapter 09](../../course/09/ru.md).

</details>
### 21. **Which pair of components belongs to the control plane rather than node components?**

- [ ] A. kube-proxy and CRI-O
- [ ] B. kubelet and kube-proxy
- [ ] C. kube-scheduler and kube-controller-manager
- [ ] D. containerd and CNI

<details><summary>Answer</summary>

**Correct answer:** C

The scheduler and controller manager are control-plane components. kubelet, kube-proxy, and runtimes are node components. See [chapter 07](../../course/07/ru.md).

</details>

## Kubernetes Security Fundamentals - questions 22-34

### 22. **How does authentication differ from authorization in Kubernetes?**

- [ ] A. Authentication decides which API actions are permitted, while authorization proves the credential belongs to the claimed identity.
- [ ] B. Authorization evaluates requests only inside etcd, while authentication is the only access decision made by kube-apiserver.
- [ ] C. Authentication establishes who is making the request, while authorization decides whether that identity may perform the requested action.
- [ ] D. Authentication and authorization are two names for admission control and both operate only after the object has been stored.

<details><summary>Answer</summary>

**Correct answer:** C

Authentication establishes the caller identity. Authorization then determines whether that identity is allowed to perform the requested action. Admission is a separate later stage of API request processing. See [chapter 10](../../course/10/ru.md).

</details>
### 23. **Which mechanism is suitable for federating a user's identity with the Kubernetes API?**

- [ ] A. `hostPath`
- [ ] B. OIDC
- [ ] C. IPVS
- [ ] D. `ResourceQuota`

<details><summary>Answer</summary>

**Correct answer:** B

OIDC integrates an external identity provider with API server authentication. The other options concern storage, networking, or quota. See [chapter 10](../../course/10/ru.md).

</details>

### 24. **Why should every workload not thoughtlessly use the default `ServiceAccount`?**

- [ ] A. It automatically gives every Pod `cluster-admin` whenever a projected ServiceAccount token is present.
- [ ] B. It prevents a workload controller from creating replacement Pods when the current Pod terminates.
- [ ] C. It disables cluster DNS for workloads unless each Deployment creates a dedicated ServiceAccount object.
- [ ] D. Its API identity and automatically mounted token can become unnecessary credential attack surface when the workload does not need Kubernetes API access.

<details><summary>Answer</summary>

**Correct answer:** D

A workload should not receive an API credential it does not need. Unnecessary ServiceAccount-token exposure increases the impact of application compromise. The default ServiceAccount does not automatically grant `cluster-admin`, does not control controller reconciliation, and does not provide DNS. See [chapter 10](../../course/10/ru.md).

</details>
### 25. **What does the least-privilege principle mean in RBAC?**

- [ ] A. Grant `cluster-admin` to avoid access errors
- [ ] B. Grant only the minimum necessary verbs, resources, and scope
- [ ] C. Use only ABAC
- [ ] D. Create a `ClusterRoleBinding` for every Pod

<details><summary>Answer</summary>

**Correct answer:** B

Least privilege limits verbs, resources, and scope to the necessary minimum. Option a (granting `cluster-admin` broadly) directly creates excessive privileges. Option c (using only ABAC) is not inherently a violation of least privilege — ABAC can express fine-grained policy — but compared with Kubernetes RBAC it is generally harder to manage and audit consistently, and excessive privilege is a possible policy outcome rather than an inherent property of ABAC itself. Option d (a ClusterRoleBinding for every Pod) is unnecessary and grants broader, cluster-wide scope than most Pods require. See [chapter 10](../../course/10/ru.md).

</details>

### 26. **What is the most accurate purpose of Pod Security Admission?**

- [ ] A. Encrypt Kubernetes `Secret` objects at rest by sending their stored data to an external KMS provider.
- [ ] B. Authenticate end users by validating OIDC tokens before the API request reaches Kubernetes authorization.
- [ ] C. Evaluate Pod specifications against Pod Security Standards through namespace policy modes such as `enforce`, `audit`, and `warn`.
- [ ] D. Implement Pod-to-Pod packet filtering by programming the CNI network data plane from `NetworkPolicy` rules.

<details><summary>Answer</summary>

**Correct answer:** C

Pod Security Admission evaluates Pod specifications against the Pod Security Standards and supports the `enforce`, `audit`, and `warn` policy modes. It does not provide authentication, storage encryption, or CNI network enforcement. See [chapter 11](../../course/11/ru.md).

</details>
### 27. **Which Pod Security Standards profile permits the broadest set of privileges?**

- [ ] A. `restricted`
- [ ] B. `baseline`
- [ ] C. `audit`
- [ ] D. `privileged`

<details><summary>Answer</summary>

**Correct answer:** D

The `privileged` profile is the most permissive. `baseline` and `restricted` impose limits, while `audit` is a PSA mode rather than a PSS profile. See [chapter 11](../../course/11/ru.md).

</details>

### 28. **How should base64 in a `Secret` object be understood?**

- [ ] A. It is encryption at rest
- [ ] B. It is a digital signature format
- [ ] C. It is encoding, not cryptographic protection of content
- [ ] D. It is an RBAC check

<details><summary>Answer</summary>

**Correct answer:** C

Base64 reversibly encodes a representation of data and does not provide confidentiality, which matches option c. Options a, b, and d describe other mechanisms: base64 is not encryption at rest, not a digital signature format, and has no relationship to RBAC checks. See [chapter 12](../../course/12/ru.md).

</details>

### 29. **How can a Kubernetes Secret be protected at rest?**

- [ ] A. Configure API-server encryption for stored data, use an external KMS where appropriate, and keep Secret API access least-privilege.
- [ ] B. Move the value to a ConfigMap and rely on the namespace name to protect it.
- [ ] C. Keep the value only base64-encoded and allow broad read access to the Secret.
- [ ] D. Enable `hostNetwork` so Secret data bypasses the Kubernetes storage path.

<details><summary>Answer</summary>

**Correct answer:** A

EncryptionConfiguration protects stored API data such as Secrets; KMS can separate key management; RBAC still limits API access. ConfigMap, base64 and host networking do not provide Secret encryption at rest. See [chapter 12](../../course/12/ru.md).

</details>

### 30. **What is the role of `NetworkPolicy` in a namespace with default-deny?**

- [ ] A. It automatically removes every ServiceAccount
- [ ] B. It defines allowed ingress and/or egress flows for selected Pods
- [ ] C. It updates iptables on the control plane without a CNI
- [ ] D. It encrypts all HTTP requests

<details><summary>Answer</summary>

**Correct answer:** B

With default-deny, NetworkPolicy opens only explicitly allowed flows for selected Pods. Options a, c, and d concern other functions. See [chapter 13](../../course/13/ru.md).

</details>

### 31. **A source Pod and a destination Pod are both isolated by NetworkPolicy. The source Pod's egress policy allows the destination, but the destination Pod's ingress policies do not allow the source. Assuming a supporting network plugin, what happens?**

- [ ] A. The connection is allowed because an allowed source egress rule is sufficient even when destination ingress does not allow the source.
- [ ] B. The connection is allowed whenever both Pods are in namespaces that contain at least one NetworkPolicy object.
- [ ] C. The connection is denied because the source egress policy and the destination ingress policy must both allow the connection.
- [ ] D. The connection result is decided by kube-proxy, which overrides Pod ingress and egress isolation when a Service is involved.

<details><summary>Answer</summary>

**Correct answer:** C

For a connection between two Pods, the source Pod's applicable egress policy and the destination Pod's applicable ingress policy must both allow the connection. An allow on only one side is not sufficient.

This tests the two-sided connection rule rather than repeating the separate competency that a supporting network plugin is required for NetworkPolicy enforcement. See [chapter 13](../../course/13/ru.md).

</details>
### 32. **What does Kubernetes audit logging record?**

- [ ] A. Events and requests processed by the Kubernetes API server
- [ ] B. Every kernel system call in a container
- [ ] C. Only network packets between Pods
- [ ] D. Only kubelet errors

<details><summary>Answer</summary>

**Correct answer:** A

The API server generates and processes audit events, after which a configured backend stores them. System calls and packets are other observability sources. See [chapter 14](../../course/14/ru.md).

</details>

### 33. **What is the most accurate distinction between audit logging and runtime detection?**

- [ ] A. Audit logging records container kernel syscalls, while runtime detection records only Kubernetes API object changes.
- [ ] B. Audit logging records Kubernetes API activity, while runtime detection observes behavior occurring in running workloads and nodes.
- [ ] C. Audit logging enforces Pod network segmentation, while runtime detection grants permissions to workload ServiceAccounts.
- [ ] D. Audit logging verifies image signatures, while runtime detection encrypts Kubernetes `Secret` objects stored in etcd.

<details><summary>Answer</summary>

**Correct answer:** B

Kubernetes audit logging records API activity. Runtime detection observes execution and host/workload behavior that may occur independently of an API request. These sources complement each other and do not replace network policy, RBAC, signature verification, or storage encryption. See [chapter 14](../../course/14/ru.md).

</details>
### 34. **A Role grants `list` on `secrets` in one namespace but does not grant `get` on any specifically named Secret. What is the security consequence?**

- [ ] A. `list` returns only Secret names and metadata, so it cannot expose any Secret data values from the namespace.
- [ ] B. `list` is equivalent to `get` on one specifically named Secret and cannot return other Secret objects in the namespace.
- [ ] C. `list` can return multiple Secret objects and their data, so namespace-wide `list secrets` is broad sensitive-data access.
- [ ] D. Encryption at rest makes `list secrets` return only ciphertext, even when the API caller is authorized to read Secret objects.

<details><summary>Answer</summary>

**Correct answer:** C

An authorized list operation can return multiple Secret objects, including their API data fields. That makes namespace-wide `list secrets` broad sensitive-data access. Encryption at rest protects storage, not values returned to an authorized API reader. See [chapter 12](../../course/12/ru.md).

</details>

## Kubernetes Threat Model - questions 35-44

### 35. **What is a trust boundary in a Kubernetes threat model?**

- [ ] A. A transition where trust assumptions change, so data or identity crossing it requires validation or protection.
- [ ] B. A configured maximum size for a container image stored in a registry.
- [ ] C. A Service exposure mode such as `ClusterIP`, `NodePort`, or `LoadBalancer`.
- [ ] D. Any Namespace simply because one or more labels have been attached to it.

<details><summary>Answer</summary>

**Correct answer:** A

A trust boundary is where assumptions about trust change and an interaction crosses between those contexts. Kubernetes objects can lie on either side of a boundary, but a Service type or Namespace label is not the definition of a trust boundary. See [chapter 15](../../course/15/ru.md).

</details>

### 36. **Which scenario is an example of persistence in Kubernetes?**

- [ ] A. A Service sends traffic to an endpoint
- [ ] B. A Pod receives a new IP after being recreated
- [ ] C. An attacker creates a mechanism that survives a restart and restores access
- [ ] D. A user reads API documentation

<details><summary>Answer</summary>

**Correct answer:** C

Persistence retains or restores an attacker's access, which matches the scenario in option c, where a mechanism survives a restart. Options a, b, and d describe ordinary operation: a Service forwarding traffic, a Pod receiving a new IP after normal recreation, and a user reading documentation are not persistence mechanisms. See [chapter 16](../../course/16/ru.md).

</details>

### 37. **Which measure directly reduces the risk of workload resource-exhaustion DoS?**

- [ ] A. `kubeconfig` rotation
- [ ] B. `ResourceQuota` and requests/limits
- [ ] C. Image signing
- [ ] D. OIDC authentication

<details><summary>Answer</summary>

**Correct answer:** B

Quota and requests/limits constrain excessive resource consumption. Authentication, signing, and rotation address other risks. See [chapter 16](../../course/16/ru.md).

</details>

### 38. **Which sign most closely indicates malicious code execution in a container?**

- [ ] A. A namespace receives a routine label during an approved deployment.
- [ ] B. A Service remains reachable through its expected `ClusterIP` address.
- [ ] C. A Deployment scales from two replicas to three during normal load.
- [ ] D. A process opens an unexpected shell and downloads or executes an unapproved payload.

<details><summary>Answer</summary>

**Correct answer:** D

An unexpected shell followed by retrieval or execution of an unapproved payload is a strong behavioral indicator of malicious code execution. The other events can be ordinary Kubernetes operations when they match the expected workload and change context. See [chapter 16](../../course/16/ru.md).

</details>
### 39. **Which control reduces an attacker's risk of lateral movement in the cluster network?**

- [ ] A. Apply network segmentation and protect permitted service traffic with TLS/mTLS where required.
- [ ] B. Encode a Secret value with base64 before storing it in a Kubernetes Secret.
- [ ] C. Disable admission policies so workloads can communicate without policy-related deployment failures.
- [ ] D. Increase Pod termination grace periods so existing network connections remain open longer.

<details><summary>Answer</summary>

**Correct answer:** A

Network segmentation reduces the paths available for lateral movement, while TLS/mTLS protects the permitted connections where identity and transport protection are required. Base64 is only encoding; disabling admission controls and extending termination periods do not constrain lateral movement. See [chapter 16](../../course/16/ru.md).

</details>
### 40. **Why is Secret access often considered access to sensitive data?**

- [ ] A. A Secret is available only to kubelet and nobody else
- [ ] B. A Secret can contain credentials, keys, and tokens that unlock other systems
- [ ] C. A Secret cannot be mounted into a Pod
- [ ] D. A Secret is always automatically encrypted everywhere

<details><summary>Answer</summary>

**Correct answer:** B

Credentials and keys in a Secret can unlock access beyond a single Pod. Option a falsely assumes automatic protection, while c and d are incorrect. See [chapter 16](../../course/16/ru.md).

</details>

### 41. **Which Pod setting creates an explicit risk of privilege escalation?**

- [ ] A. `seccompProfile: RuntimeDefault`
- [ ] B. `readOnlyRootFilesystem: true`
- [ ] C. `runAsNonRoot: true`
- [ ] D. `allowPrivilegeEscalation: true`

<details><summary>Answer</summary>

**Correct answer:** D

`allowPrivilegeEscalation: true` explicitly permits a process to gain more privileges than its parent process, creating the described risk. Options a, b, and c are restrictive settings that reduce risk instead: `seccompProfile: RuntimeDefault` restricts syscalls, `readOnlyRootFilesystem: true` prevents filesystem writes, and `runAsNonRoot: true` blocks running as root. See [chapter 16](../../course/16/ru.md).

</details>

### 42. **Why should a Kubernetes threat-model data-flow diagram include external systems such as CI, an image registry, an identity provider, cloud IAM, and external databases?**

- [ ] A. Because kube-scheduler depends on every external system to select a node, so all of them are mandatory inputs to Pod placement.
- [ ] B. Because systems outside Kubernetes can be treated as trusted infrastructure once TLS is enabled, so they should be grouped outside the threat model.
- [ ] C. Because credentials, artifacts, and sensitive data can cross those boundaries, creating attack paths that a Kubernetes-object-only diagram would miss.
- [ ] D. Because Kubernetes threat modeling excludes internal cluster objects and should document only CI, registry, identity, cloud, and database systems.

<details><summary>Answer</summary>

**Correct answer:** C

Threat modeling must include relevant systems and flows on both sides of cluster boundaries. CI, registries, identity providers, cloud services, and external data stores can introduce credentials or artifacts and can receive sensitive data. Omitting them can hide real attack paths. See [chapter 15](../../course/15/ru.md).

</details>
### 43. **What is a typical goal of an attacker on the network?**

- [ ] A. Intercept or alter traffic that crosses an insufficiently protected network boundary.
- [ ] B. Change CPU requests without interacting with the API or workload.
- [ ] C. Resize an image layer without affecting its distributed artifact.
- [ ] D. Rename a Namespace without changing any network or identity control.

<details><summary>Answer</summary>

**Correct answer:** A

A network attacker seeks to intercept, alter, or exploit traffic across an insufficiently protected boundary. See [chapter 16](../../course/16/ru.md).

</details>

### 44. **Which combination best reduces the risk of container escape after application compromise?**

- [ ] A. Increase audit detail while leaving workload isolation unchanged.
- [ ] B. Enable privileged mode, host namespaces, and broad host mounts.
- [ ] C. Combine least privilege, PSS/PSA, seccomp, and reduced capabilities.
- [ ] D. Increase replicas without changing the container isolation boundary.

<details><summary>Answer</summary>

**Correct answer:** C

Least privilege, PSS/PSA, seccomp, and reduced capabilities form independent preventive barriers against container escape. See [chapter 16](../../course/16/ru.md).

</details>

## Platform Security - questions 45-54

### 45. **What does the software supply chain describe in cloud-native systems?**

- [ ] A. The path from source and dependencies through build and artifact storage to deployment and runtime.
- [ ] B. The network path from an external client through a Service to a selected application Pod.
- [ ] C. The authorization path from an authenticated Kubernetes identity to an RBAC decision.
- [ ] D. The recovery path from an etcd snapshot to restored control-plane state after an outage.

<details><summary>Answer</summary>

**Correct answer:** A

The software supply chain covers how source, dependencies and build processes produce an artifact and how that artifact is stored, promoted and deployed. Network flow, RBAC and datastore recovery are separate concerns. See [chapter 17](../../course/17/ru.md).

</details>

### 46. **What is an SBOM?**

- [ ] A. A policy that permits a Pod in the cluster
- [ ] B. Proof of a user's API identity
- [ ] C. A replacement for a digital signature
- [ ] D. An inventory of components and dependencies in a software artifact

<details><summary>Answer</summary>

**Correct answer:** D

An SBOM describes an artifact's composition and dependencies. Admission, authentication, and signature have different purposes. See [chapter 17](../../course/17/ru.md).

</details>

### 47. **What does successful verification of a trusted image signature show?**

- [ ] A. The image has no known or unknown vulnerabilities.
- [ ] B. The artifact meets every requirement of every SLSA track.
- [ ] C. A trusted signing identity made a cryptographic assertion over the verified artifact.
- [ ] D. The image was built from only one filesystem layer.

<details><summary>Answer</summary>

**Correct answer:** C

Successful signature verification establishes that a cryptographic assertion over the verified artifact validates under the trusted signing identity/key and policy. It does not prove vulnerability-free content, an arbitrary SLSA level, or a particular image-layer count. See [chapter 17](../../course/17/ru.md).

</details>

### 48. **What does provenance do?**

- [ ] A. It describes an artifact's origin and build process
- [ ] B. It replaces an SBOM dependency list
- [ ] C. It encrypts the network between Pods
- [ ] D. It sets ResourceQuota

<details><summary>Answer</summary>

**Correct answer:** A

Provenance states how and where an artifact originated. It does not replace an SBOM, encryption, or quota. See [chapter 17](../../course/17/ru.md).

</details>

### 49. **What is true about SLSA?**

- [ ] A. A format used only to list packages in an SBOM.
- [ ] B. A supply-chain framework with track-specific levels and requirements.
- [ ] C. A Kubernetes authorization mode for workload admission.
- [ ] D. A container runtime used to isolate untrusted workloads.

<details><summary>Answer</summary>

**Correct answer:** B

SLSA v1.2 is a supply-chain assurance framework with independent tracks such as Build and Source, each with its own requirements and levels. It is not an SBOM format, Kubernetes authorizer, or runtime. See [chapter 17](../../course/17/ru.md).

</details>

### 50. **What can admission control do for an image repository?**

- [ ] A. Automatically create a NetworkPolicy
- [ ] B. Allow only images from approved registries
- [ ] C. Update a kubelet certificate
- [ ] D. Recompile an image on a node

<details><summary>Answer</summary>

**Correct answer:** B

An admission policy can reject a workload whose image comes from an unapproved registry. The other actions are not admission tasks. See [chapter 17](../../course/17/ru.md).

</details>

### 51. **How does a validating admission webhook differ from a mutating admission webhook?**

- [ ] A. Mutating and validating admission webhooks both only inspect Secret objects and neither webhook type can change an admitted object.
- [ ] B. A mutating webhook can modify an object during admission, while a validating webhook decides whether the resulting request is accepted.
- [ ] C. Mutating and validating admission webhooks have the same behavior; the distinction changes only the name of the configuration object.
- [ ] D. A validating webhook modifies the object before storage, while a mutating webhook can only record an audit event about the request.

<details><summary>Answer</summary>

**Correct answer:** B

Mutating admission can modify an object during admission. Validating admission evaluates the resulting request and accepts or rejects it. The webhook types do not have identical behavior and are not limited to Secrets. See [chapter 17](../../course/17/ru.md).

</details>
### 52. **Which task is part of security observability?**

- [ ] A. Rely on a dashboard instead of collecting the underlying security signals.
- [ ] B. Correlate logs, metrics, traces, and events to investigate anomalies.
- [ ] C. Grant broad privileges so monitoring tools can access every resource.
- [ ] D. Suppress audit events that would otherwise generate investigation noise.

<details><summary>Answer</summary>

**Correct answer:** B

Security observability correlates logs, metrics, traces, and events to detect and investigate anomalies. See [chapter 18](../../course/18/ru.md).

</details>

### 53. **How does a service mesh typically help secure service-to-service traffic?**

- [ ] A. It removes the need for workload identity and certificates.
- [ ] B. It acts as the NetworkPolicy implementation for every Kubernetes CNI.
- [ ] C. It can provide workload mTLS, identity-aware traffic policy, and telemetry.
- [ ] D. It replaces the container runtime used by every worker node.

<details><summary>Answer</summary>

**Correct answer:** C

A service mesh can provide workload mTLS, identity-aware traffic policy, and telemetry; it does not replace PKI, CNI NetworkPolicy, or the container runtime. See [chapter 18](../../course/18/ru.md).

</details>

### 54. **What is PKI used for in Kubernetes?**

- [ ] A. Establishing certificate-based identity and trust for TLS-protected component/client connections.
- [ ] B. Assigning CPU and memory requests to workloads during admission.
- [ ] C. Generating dependency inventories for container images during CI.
- [ ] D. Replacing registries with a built-in Kubernetes artifact store.

<details><summary>Answer</summary>

**Correct answer:** A

PKI establishes certificate-based identity and trust for TLS-protected connections between Kubernetes components and clients. See [chapter 18](../../course/18/ru.md).

</details>

## Compliance and Security Frameworks - questions 55-60

### 55. **How should the CIS Kubernetes Benchmark be used?**

- [ ] A. As a mechanism for running container images
- [ ] B. As a mandatory replacement for all internal organizational requirements
- [ ] C. As a user authentication system
- [ ] D. As a set of recommendations and checks for assessing secure Kubernetes configuration

<details><summary>Answer</summary>

**Correct answer:** D

The CIS Benchmark is a practical set of recommendations and checks for secure configuration. It neither replaces all requirements nor runs containers or authenticates users. See [chapter 19](../../course/19/ru.md).

</details>

### 56. **What is STRIDE's role in security work?**

- [ ] A. Collect runtime system calls
- [ ] B. Sign container images
- [ ] C. Categorize threats during threat modeling
- [ ] D. Store Secrets

<details><summary>Answer</summary>

**Correct answer:** C

STRIDE categorizes threats during threat modeling, which matches option c. Options a, b, and d concern unrelated security controls: collecting runtime system calls is a detection mechanism, signing container images is a supply-chain control, and storing Secrets is a data-protection mechanism — none of them is what STRIDE does. See [chapter 19](../../course/19/ru.md).

</details>

### 57. **How is MITRE ATT&CK for Containers useful to a security team?**

- [ ] A. Mapping adversary tactics and techniques to relevant detections and mitigations.
- [ ] B. Defining the passing score and exam domains for KCSA candidates.
- [ ] C. Providing the authorization layer for Kubernetes API requests.
- [ ] D. Encrypting Secret data stored in etcd by the API server.

<details><summary>Answer</summary>

**Correct answer:** A

ATT&CK for Containers helps map adversary tactics and techniques to detections and mitigations. See [chapter 19](../../course/19/ru.md).

</details>

### 58. **Which example best represents automation and tooling for compliance?**

- [ ] A. Perform an undocumented manual YAML review once before the first release.
- [ ] B. Run repeatable configuration/policy checks in CI/CD and retain reviewable results.
- [ ] C. Manually approve and sign every running Pod directly on each node.
- [ ] D. Disable audit events so compliance reports contain less operational data.

<details><summary>Answer</summary>

**Correct answer:** B

Repeatable configuration and policy checks in CI/CD provide measurable verification and reviewable evidence. See [chapter 19](../../course/19/ru.md).

</details>

### 59. **A service organization wants an independent report on whether its controls are suitably designed and operated over a stated period against Trust Services Criteria. Which compliance context best matches that goal?**

- [ ] A. PCI DSS
- [ ] B. SOC 2
- [ ] C. STRIDE
- [ ] D. SLSA

<details><summary>Answer</summary>

**Correct answer:** B

SOC 2 is an assurance/reporting context for service-organization controls against the Trust Services Criteria. PCI DSS focuses on cardholder-data requirements, STRIDE is a threat-modeling method, and SLSA is a software supply-chain assurance framework. See [chapter 19](../../course/19/ru.md).

</details>

### 60. **Which statement best describes a reproducible build?**

- [ ] A. A build whose output is encrypted at rest; identical rebuild output is not required.
- [ ] B. A build that runs on Kubernetes and therefore inherits the cluster's authorization guarantees.
- [ ] C. A build whose artifact is signed; a matching rebuild from the same inputs is not required.
- [ ] D. A build where the same source, defined environment, and instructions can reproduce bit-for-bit identical specified artifacts.

<details><summary>Answer</summary>

**Correct answer:** D

Reproducibility means the specified artifact can be independently recreated bit-for-bit from the same source code, defined build environment, and build instructions. This property can strengthen verification, but by itself it does not establish a trusted signer, authenticated provenance, or a SLSA track/level. See [chapter 19](../../course/19/ru.md).

</details>
