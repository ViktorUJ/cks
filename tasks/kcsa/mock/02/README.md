# KCSA Mock Exam 02

> **Training simulation.** An original 60-question KCSA practice exam, not an official Linux Foundation exam.

Allow **90 minutes**. Work **closed-book**: do not use documentation, search, notes, tools, or external websites. Choose one best answer. Distribution: Overview 8, Cluster Component Security 13, Security Fundamentals 13, Threat Model 10, Platform Security 10, Compliance and Security Frameworks 6.

Mock 02 uses independent scenarios from Mock 01. The explanation states the direct control; the other options are real but address a different layer, scope, or enforcement point.

## Overview of Cloud Native Security

### 1. A managed control plane is patched by the provider. What remains the customer's task?

a. Configure workload identity and data access
b. Operate provider hypervisors
c. Approve provider employees
d. Replace provider routers

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** The provider patches and operates the managed control plane, but the customer still owns workload identity (RBAC, ServiceAccounts) and data access configuration under the shared-responsibility model. b: operating provider hypervisors is the provider's infrastructure responsibility, not the customer's. c: the customer does not approve the provider's own staff. d: replacing provider network hardware is entirely outside customer scope. See [chapter 04](../../course/04/ru.md).

</details>

### 2. A managed Kubernetes provider secures the underlying node infrastructure. Who is responsible for defining which Pods may talk to which Pods?

a. The cloud provider's infrastructure team
b. The container runtime vendor
c. No one; this is automatic in every managed cluster
d. The customer, using Kubernetes-native controls such as NetworkPolicy

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Under the shared-responsibility model, a managed provider secures the infrastructure layer, but defining workload-level network rules such as which Pods may communicate is the customer's configuration responsibility, typically expressed through NetworkPolicy. a: the provider's infrastructure team does not define application-level traffic rules. b: a container runtime vendor builds the runtime, not workload network policy. c: this is never automatic — NetworkPolicy must be explicitly authored and enforced by a supporting CNI. See [chapter 13](../../course/13/ru.md).

</details>


### 3. A password is committed in source. Which 4C layer is first involved?

a. Cluster
b. Code
c. Container
d. Cloud

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** A password committed into source code is a Code-layer (the innermost of the 4Cs) exposure, since it originates in the application's source rather than the cluster, container, or cloud infrastructure. a: the Cluster layer covers Kubernetes infrastructure, not source code. c: the Container layer concerns image content and runtime, not source repositories. d: the Cloud layer concerns provider infrastructure. See [chapter 03](../../course/03/ru.md).

</details>

### 4. A team wants to know only whether their currently deployed image has any newly disclosed critical CVE, without re-reviewing the whole artifact. What should they rely on?

a. Recurring vulnerability scans against the deployed image
b. The image's build timestamp
c. The name of the container registry
d. The number of layers in the image

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Recurring vulnerability scanning checks a deployed image's known components against an updated vulnerability database, which is exactly how newly disclosed CVEs affecting an already-running image are detected. b: a build timestamp says nothing about vulnerabilities disclosed afterward. c: the registry name identifies where the image is stored, not its vulnerability status. d: the number of layers is a packaging detail unrelated to CVEs. See [chapter 06](../../course/06/ru.md).

</details>


### 5. A scan reports no known CVEs. What can be concluded?

a. The image is signed
b. No malicious code exists
c. The image is trusted
d. No known findings were detected within scan coverage

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A scanner reports only what it checked against its known-vulnerability database at that time; a clean result means no known findings were detected within that scan's coverage, not that the image is free of every possible issue. a: a clean scan says nothing about whether the image is signed. b: absence of known CVEs does not prove absence of malicious code, which scanners are not designed to detect exhaustively. c: whether an artifact counts as "trusted" is policy-dependent, but a vulnerability scan alone — without at least signature and, where required, provenance evidence — does not establish that trust under most supply-chain policies. See [chapter 06](../../course/06/ru.md).

</details>

### 6. A team wants to know, before merging a pull request, whether a proposed dependency upgrade introduces a newly known vulnerability. At which point in the pipeline should this check run to be most useful?

a. Only manually, after the artifact has already been deployed to production
b. Only once a year during an annual audit
c. Only by asking end users to report problems after release
d. As an automated dependency/vulnerability check during CI, before the change is merged or built into an artifact

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Running an automated dependency/vulnerability check during CI, before a change is merged or built, catches a newly introduced risk while it is cheapest and fastest to address, rather than after it is already running. a: checking only after production deployment delays detection past the point where prevention was possible. b: an annual audit leaves long windows where new dependency vulnerabilities go unnoticed. c: relying on end-user reports is reactive and does not prevent the vulnerable dependency from shipping in the first place. See [chapter 05](../../course/05/ru.md).

</details>


### 7. What does an artifact repository not prove by itself?

a. Artifact traceability
b. Artifact retention
c. Artifact integrity and safety
d. Access governance

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** An artifact repository can store, retain, and control access to artifacts, but storage and access control alone do not prove that an artifact's content is unmodified (integrity, which requires digests, signatures, and verification) or that it is free of vulnerabilities or malicious content (safety, which requires scanning and other checks) — these are two distinct properties, neither of which follows from repository storage by itself. a: a repository can support traceability (which artifact came from where). b: retention is a basic repository function. d: access governance (who can push/pull) is also a repository function — none of these three is the missing guarantee, but integrity and safety specifically are not proven by storage alone. See [chapter 06](../../course/06/ru.md).

</details>

### 8. A team is deciding where to store non-secret application configuration (such as a feature-flag list) versus a database password. Which split is correct?

a. Both belong in a ConfigMap, since ConfigMap is simpler to edit.
b. Non-secret configuration in a ConfigMap; the password in a Secret with restricted RBAC access.
c. Both belong in a Secret, since Secret is more secure for any data.
d. Both belong directly in the container image, since that avoids extra Kubernetes objects.

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Non-sensitive settings belong in a ConfigMap, while sensitive values such as a database password belong in a Secret with restricted RBAC access — this split keeps sensitive data out of ordinary configuration and lets access be controlled specifically for it. a: storing the password in a ConfigMap forgoes the access-control conventions intended for sensitive data. c: using a Secret for non-sensitive data adds no benefit and blurs the intended distinction. d: baking either value into the image makes it hard to change without a rebuild and exposes it to anyone with image access. See [chapter 12](../../course/12/ru.md).

</details>

## Kubernetes Cluster Component Security

### 9. Only an admin subnet may reach the API endpoint. What control is this?

a. Network reachability restriction
b. Authorization
c. Authentication
d. Admission validation

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Restricting network reachability so that only an administrative subnet can reach the API endpoint is a network-layer control that operates before any Kubernetes credential is even evaluated. b: authorization decides what an already-authenticated identity may do, which happens after the request reaches the API server. c: authentication verifies identity, which also happens only once a request arrives at the API server. d: admission validation runs even later, after authentication and authorization. See [chapter 07](../../course/07/ru.md).

</details>

### 10. An etcd snapshot is stolen. What protects stored Secret values?

a. A liveness probe
b. A PDB
c. A Service selector
d. API-server encryption at rest

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** API-server encryption at rest (EncryptionConfiguration) is what protects Secret values stored in etcd, so a stolen etcd snapshot without that encryption exposes plaintext Secret data — encryption at rest is the control that mitigates this. a: a liveness probe checks container health and has no bearing on stored data. b: a PodDisruptionBudget limits voluntary disruptions, unrelated to data protection. c: a Service selector routes traffic and does not protect stored data. See [chapter 07](../../course/07/ru.md).

</details>

### 11. A security review finds that a node's kubelet is configured with `--authorization-mode=AlwaysAllow`. What is the direct implication of this setting, independent of whether anonymous authentication is also enabled?

a. It disables the kubelet entirely.
b. It forces all kubelet traffic to use IPVS.
c. It automatically enables audit logging for the node.
d. Any request that reaches the kubelet API and is accepted by its authentication step is authorized to perform any action, without a further permission check.

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** `--authorization-mode=AlwaysAllow` skips authorization entirely for the kubelet API, so any authenticated caller is treated as permitted to do anything, which is a distinct risk from anonymous authentication itself. a: this setting does not disable the kubelet process. b: it has no relationship to kube-proxy's IPVS mode. c: it does not enable or configure audit logging. See [chapter 08](../../course/08/ru.md).

</details>


### 12. A cluster administrator wants kube-apiserver-to-etcd traffic to survive a future migration to a different etcd deployment without re-architecting trust. Which practice supports this goal while keeping the connection encrypted and mutually authenticated?

a. Disabling TLS between the API server and etcd to simplify the migration.
b. Sharing the API server's own serving certificate directly with etcd clients.
c. Using a dedicated CA (or CA chain) for etcd's client/peer certificates, kept independent of unrelated cluster PKI, so etcd's trust relationships can be managed and rotated on their own.
d. Storing etcd's TLS private key in a ConfigMap for easy retrieval during migration.

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Using a dedicated CA (or CA chain) for etcd's own client and peer TLS keeps etcd's trust relationships independent of unrelated cluster certificates, so etcd's certificates and trust can be rotated or migrated without disturbing other components' PKI. a: disabling TLS removes encryption and authentication entirely, which is the opposite of the stated goal. b: reusing the API server's own serving certificate for etcd clients conflates two different trust relationships and complicates rotation. d: a private key must never be stored in a ConfigMap, which provides no confidentiality or access control appropriate for key material. See [chapter 07](../../course/07/ru.md).

</details>

### 13. Which kubelet authorization mode should a hardened cluster use instead of `AlwaysAllow`?

a. Webhook, delegating authorization decisions to the API server
b. AlwaysAllow
c. NodeRestriction
d. AlwaysDeny

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Configuring the kubelet's authorization mode as Webhook delegates authorization decisions to the API server's authorizer chain (such as RBAC), avoiding the risk of trusting every request. b: `AlwaysAllow` is the historical/legacy value for this setting (still available via the deprecated CLI flag) that grants every request without any check; current tooling such as `kubeadm` configures `authorization.mode: Webhook` by default, but a cluster or node that still has `AlwaysAllow` configured (for example through an older or custom setup) carries this same risk and should be moved to Webhook. c: NodeRestriction is an admission plugin that limits what a kubelet identity can modify; it is not a kubelet authorization mode setting. d: `AlwaysDeny` would block all kubelet API requests, breaking normal operation. See [chapter 08](../../course/08/ru.md).

</details>


### 14. A cluster administrator wants component-to-component control-plane traffic (for example API server to etcd) to be both encrypted and mutually authenticated. What should be configured?

a. Mutual TLS between the relevant control-plane components
b. A ResourceQuota on the kube-system namespace
c. A PodDisruptionBudget for the API server
d. A HorizontalPodAutoscaler for etcd

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Mutual TLS authenticates both endpoints of a control-plane connection and encrypts the traffic between them, which is exactly what is needed for encrypted, mutually authenticated component-to-component communication. b: a ResourceQuota limits aggregate namespace resource consumption, not transport security. c: a PodDisruptionBudget limits voluntary disruptions, unrelated to encryption. d: a HorizontalPodAutoscaler adjusts replica counts and has no role in securing transport. See [chapter 07](../../course/07/ru.md).

</details>


### 15. A team wants evidence, after the fact, that a specific worker node's kubelet configuration has not been tampered with since it was hardened. Which practice most directly supports this?

a. File integrity or configuration monitoring on the node that records and alerts on unexpected changes to kubelet configuration files.
b. disabled monitoring
c. cluster-admin for all Pods
d. hostPath everywhere

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** File integrity or configuration monitoring on the node directly detects and provides evidence of unexpected changes to kubelet's own configuration, which is exactly the after-the-fact evidence this scenario needs. b: disabling monitoring removes visibility and provides no evidence at all. c: granting cluster-admin to all Pods increases risk and provides no configuration-tampering evidence. d: mounting hostPath everywhere increases host-level exposure and provides no such evidence either. See [chapter 08](../../course/08/ru.md).

</details>

### 16. Which setting exposes host processes to a Pod?

a. readOnlyRootFilesystem: true
b. hostPID: true
c. runAsNonRoot: true
d. allowPrivilegeEscalation: false

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** `hostPID: true` shares the node's process namespace with the Pod, exposing host process information and IDs to containers in that Pod. a: `readOnlyRootFilesystem: true` restricts writes and reduces risk. c: `runAsNonRoot: true` also reduces risk by blocking root execution. d: `allowPrivilegeEscalation: false` blocks escalation and reduces risk — none of these three exposes host processes. See [chapter 09](../../course/09/ru.md).

</details>

### 17. What does hostNetwork do?

a. Grants RBAC
b. Creates a NetworkPolicy
c. Uses the node network namespace
d. Encrypts traffic

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** `hostNetwork: true` makes a Pod share the node's network namespace instead of getting its own, giving it visibility into host network interfaces and ports. a: hostNetwork does not grant RBAC permissions. b: it does not create a NetworkPolicy object. d: sharing the host network namespace does not itself encrypt any traffic. See [chapter 09](../../course/09/ru.md).

</details>

### 18. What protects a stolen storage snapshot?

a. A label
b. A rollout
c. Storage encryption with key access control
d. A ServiceAccount

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Encrypting the storage backend and controlling access to the decryption keys is what protects data if a storage snapshot is stolen — without the key, the stolen snapshot's contents remain unreadable. a: a label is metadata and provides no protection for snapshot contents. b: a rollout replaces running Pods but has no effect on an already-stolen snapshot. d: a ServiceAccount provides API identity, unrelated to protecting storage snapshot contents. See [chapter 09](../../course/09/ru.md).

</details>

### 19. What evidence supports certificate rotation?

a. An HPA metric
b. A Namespace label
c. A Dockerfile comment
d. Expiry monitoring and rotation records

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Expiry monitoring paired with rotation records provides auditable evidence that certificates are tracked and rotated before they expire, supporting the practice. a: an HPA metric concerns autoscaling, unrelated to certificate lifecycle. b: a Namespace label carries no rotation evidence. c: a Dockerfile comment is not operational evidence of anything happening in the cluster. See [chapter 18](../../course/18/ru.md).

</details>

### 20. Why is direct etcd user access dangerous?

a. It rotates certificates
b. It scans images
c. It bypasses normal API-server controls
d. It creates Services

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Direct user access to etcd bypasses the API server entirely, which means authentication, authorization, and admission controls configured at the API server are never evaluated for that access — this is the danger. a: direct etcd access does not itself rotate certificates. b: it does not scan images. d: it does not create Service objects. See [chapter 07](../../course/07/ru.md).

</details>

### 21. What limits untrusted networks before API credentials are evaluated?

a. A RoleBinding
b. A PSS profile
c. A Secret volume
d. A firewall or authorized-network restriction

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A firewall or a managed-service authorized-network restriction limits which networks can reach the control-plane endpoint before any Kubernetes credential is presented or evaluated. a: a RoleBinding is an authorization construct evaluated only after a request reaches the API server. b: a Pod Security Standards profile governs Pod specifications, not network reachability to the control plane. c: a Secret volume delivers data to a Pod and has no bearing on control-plane network access. See [chapter 07](../../course/07/ru.md).

</details>

## Kubernetes Security Fundamentals

### 22. A Pod does not use the API. What avoids mounting an unnecessary token?

a. hostNetwork: true
b. A ConfigMap
c. automountServiceAccountToken: false
d. cluster-admin

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Setting `automountServiceAccountToken: false` on a Pod that does not call the API prevents an unused token from being mounted and becoming unnecessary attack surface. a: `hostNetwork: true` is unrelated to token mounting. b: a ConfigMap holds configuration data and does not control token mounting. d: granting cluster-admin increases risk rather than avoiding unnecessary token exposure. See [chapter 10](../../course/10/ru.md).

</details>

### 23. What does a ServiceAccount provide?

a. An API identity
b. Network isolation
c. Automatic permissions
d. At-rest encryption

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** A ServiceAccount's core role is to provide a workload with an API identity; separate RoleBindings or ClusterRoleBindings then grant that identity permissions. b: a ServiceAccount has no effect on network isolation. c: it does not automatically carry any permissions by itself. d: it plays no role in at-rest encryption. See [chapter 10](../../course/10/ru.md).

</details>

### 24. An earlier authorizer returns Deny. A later one would Allow. What is the decision?

a. Deny; the first decisive verdict wins
b. NoOpinion
c. Admission changes it
d. Allow; any Allow wins

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** In the Kubernetes authorization chain, configured authorizers are evaluated in order, and the first decisive `Allow` or `Deny` wins immediately — later authorizers are not consulted once a decisive verdict is reached, so an earlier `Deny` stands even if a later authorizer would have said `Allow`. b: `NoOpinion` is what non-decisive authorizers return, not the outcome once a Deny has already occurred. c: admission control runs after authorization and cannot override an authorization Deny. d: the chain is not an 'any Allow wins' model; a decisive Deny immediately ends evaluation. See [chapter 10](../../course/10/ru.md).

</details>

### 25. Which is validating admission, not authorization?

a. RBAC
b. Webhook authorizer
c. Node authorizer
d. NodeRestriction

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** NodeRestriction is a validating admission plugin that limits what a kubelet's own identity can modify (for example preventing it from labeling arbitrary nodes or pods outside its own), rather than being an authorization decision itself. a: RBAC is an authorization mechanism, not an admission plugin. b: a webhook authorizer is explicitly part of the authorization chain. c: the Node authorizer is also an authorization-chain component that grants kubelets access to their own resources — it is the authorization-side counterpart to NodeRestriction's admission-side enforcement. See [chapter 10](../../course/10/ru.md).

</details>

### 26. A namespace currently has no Pod Security Admission labels set, and the cluster has no explicit cluster-wide enforce/audit/warn defaults configured through `PodSecurityConfiguration`. What is the practical consequence for Pod admission in that namespace?

a. Every Pod is automatically rejected until labels are added
b. The cluster falls back to the deprecated PodSecurityPolicy admission controller
c. NetworkPolicy objects in that namespace stop being enforced
d. The admission controller's own built-in default applies, which is an effectively permissive `privileged` profile in `enforce` mode — this rarely blocks a Pod, but it is still a real applied policy, not "no PSS check at all"

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** When neither namespace labels nor explicit cluster-wide defaults are configured, Pod Security Admission still applies its own built-in default, which corresponds to the `privileged` profile in `enforce` mode — a profile that is unrestricted and therefore rarely rejects a Pod in practice, but it is a real, applied policy rather than a complete absence of PSS checking. Namespace labels and explicit cluster-wide defaults are two ways to override this built-in default with something more restrictive; the absence of both does not mean "nothing is checked," it means the permissive built-in default is what is checked against. a: PSA's built-in default does not block every Pod — the opposite is true, since `privileged` is unrestricted. b: PodSecurityPolicy was removed from Kubernetes and does not come back as a fallback. c: NetworkPolicy enforcement is independent of PSA configuration and is governed by the CNI instead. See [chapter 11](../../course/11/ru.md).

</details>


### 27. Why cannot PSA block database egress?

a. It encrypts traffic
b. It grants RBAC
c. It validates PSS, not network flows
d. It is a CNI

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Pod Security Admission validates Pod specification fields against a Pod Security Standard; it has no visibility into or control over network traffic such as database egress, which is a NetworkPolicy/CNI concern. a: PSA does not encrypt traffic. b: PSA does not grant RBAC permissions. d: PSA is an admission control mechanism, not a CNI. See [chapter 11](../../course/11/ru.md).

</details>

### 28. How can a Secret reach a process?

a. It grants RBAC
b. It always encrypts etcd
c. It cannot be an env var
d. It may be injected as an environment variable

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A Secret's data can be delivered to a container process by injecting it as an environment variable, which is one of the standard consumption mechanisms alongside volume mounts. a: a Secret does not itself grant RBAC permissions. b: using a Secret does not automatically encrypt etcd; that requires a separate EncryptionConfiguration. c: a Secret can in fact be exposed as an environment variable, so this option is factually false. See [chapter 12](../../course/12/ru.md).

</details>

### 29. A cluster already has EncryptionConfiguration enabled for Secrets. A user with `get secrets` permission queries the API for a Secret. What do they receive?

a. An error, because encrypted Secrets cannot be read through the API
b. The decrypted Secret value, because encryption at rest does not change API-level authorization decisions
c. Only the Secret's name, without any data
d. A prompt to provide the cluster's KMS key directly

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Encryption at rest protects data as stored in etcd; it does not change what the API server returns to an already-authorized caller, so a permitted `get secrets` request still returns the decrypted value. a: encrypted storage does not block authorized API reads. c: the API does not truncate the response to just the name for an authorized reader. d: end users are never expected to supply a raw KMS key to read a Secret through the API. See [chapter 12](../../course/12/ru.md).

</details>


### 30. Two NetworkPolicy objects both select the same Pod: one denies all ingress, and another explicitly allows ingress from a specific label selector on port 443. What is the resulting behavior for that Pod, assuming a supporting CNI?

a. Ingress on port 443 from the matching label is allowed; all other ingress remains denied, because NetworkPolicy rules for a Pod are additive
b. The Pod's ingress is fully denied, because a deny-all policy always overrides an allow policy
c. The Pod's ingress is fully allowed, because a more specific policy always disables a broader one
d. The two policies conflict and Kubernetes rejects the second policy at creation

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Multiple NetworkPolicy objects selecting the same Pod are additive: the union of all matching allow rules applies, so the specific allow on port 443 opens exactly that path while everything else remains blocked by the deny-all baseline. b and c both wrongly assume one policy type universally overrides another; NetworkPolicy has no such precedence rule. d is incorrect because Kubernetes does not reject a second NetworkPolicy for overlapping selection. See [chapter 13](../../course/13/ru.md).

</details>


### 31. A namespace has default-deny egress in place through NetworkPolicy. A new requirement appears: Pods in that namespace must also be able to resolve internal DNS names for other Services. What is most likely still needed for this to work correctly?

a. Nothing further; default-deny egress never affects DNS resolution.
b. A ResourceQuota increase for the namespace.
c. An explicit egress rule permitting traffic to the cluster's DNS Service/port, since default-deny egress can also block DNS queries unless specifically allowed.
d. Disabling NetworkPolicy for the entire cluster.

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Default-deny egress blocks all outbound traffic not explicitly allowed, which includes DNS queries to the cluster's DNS Service unless a rule specifically permits that traffic; without such a rule, Pods can lose the ability to resolve names. a is a common but incorrect assumption. b (ResourceQuota) does not affect network policy. d removes protection cluster-wide rather than solving the specific DNS-egress gap. See [chapter 13](../../course/13/ru.md).

</details>


### 32. An investigator needs to determine whether a suspicious `Secret` read happened through a legitimate scheduled job or an unexpected identity. Beyond the caller identity, which additional audit field is most useful for this determination?

a. The `userAgent` and `sourceIPs` fields recorded with the audit event
b. The Secret's `data` field value included in the event
c. The Pod's resource limits at the time of the request
d. The cluster's current NetworkPolicy count

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** The `userAgent` and `sourceIPs` fields recorded in an audit event help distinguish a known automation client and expected network origin from an unusual client or unexpected source, supporting this kind of investigation. b: Kubernetes audit policy can technically be configured to include request/response bodies (`Request`/`RequestResponse` levels), but doing so for Secret reads is a known bad practice specifically because it would write the Secret's value into the audit log — the recommended practice is to keep Secret-related audit rules at the `Metadata` level precisely to avoid this, so relying on a logged Secret value would itself be a defect, not a legitimate investigative tool. c: Pod resource limits are unrelated to identifying the calling context. d: the cluster-wide NetworkPolicy count has no bearing on who made this specific request. See [chapter 14](../../course/14/ru.md).

</details>


### 33. A Namespace has a `ResourceQuota` capping total CPU requests at 10 cores. A new Pod's manifest requests 2 cores of CPU but specifies no CPU limit. What happens when this Pod is submitted?

a. The `ResourceQuota` for CPU requests is evaluated against the requested 2 cores, and the missing CPU limit does not by itself block admission unless a `LimitRange` in the namespace requires one.
b. Ingress rejects the Pod because it lacks a CPU limit.
c. The `ResourceQuota` automatically assigns a default CPU limit equal to the request.
d. HPA blocks the Pod until a limit is specified.

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** `ResourceQuota` accounts for the namespace's aggregate consumption against declared requests (and limits, where specified); a missing CPU limit is not itself something `ResourceQuota` blocks — that depends on whether a separate `LimitRange` in the namespace requires a limit to be set. b: Ingress has no role in resource accounting. c: `ResourceQuota` does not assign defaults to individual objects; that is the role of `LimitRange`. d: HorizontalPodAutoscaler adjusts replica counts and has no admission-time blocking role. See [chapter 13](../../course/13/ru.md).

</details>

### 34. What caps total CPU and memory for a namespace?

a. LimitRange alone
b. A container limit alone
c. ResourceQuota
d. A Service

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** `ResourceQuota` caps the aggregate CPU and memory (and object counts) consumed by all workloads within a namespace, which is the namespace-wide total this scenario asks about. a: `LimitRange` alone constrains individual containers/objects, not the namespace total. b: a single container's limit only bounds that one container, not the namespace aggregate. d: a Service has no role in resource accounting. See [chapter 13](../../course/13/ru.md).

</details>

## Kubernetes Threat Model

### 35. A CI credential crosses into the Kubernetes API. What is this transition?

a. An image layer
b. A StorageClass
c. A Service selector
d. A trust boundary

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** The point where a CI/CD credential crosses from the build system into the Kubernetes API is a trust boundary — a transition between two different trust levels that requires validation. a: an image layer is a filesystem construct, not a trust transition. b: a StorageClass configures how volumes are provisioned, unrelated to trust boundaries. c: a Service selector routes traffic and does not represent a change in trust level. See [chapter 15](../../course/15/ru.md).

</details>

### 36. Why is arbitrary Pod creation security-sensitive?

a. It can expose Secrets or privileged identities
b. It changes DNS only
c. It encrypts etcd
d. It disables TLS

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Arbitrary Pod creation is security-sensitive because a newly created Pod could mount Secrets or run under a highly privileged ServiceAccount identity, exposing sensitive material or elevated permissions. b: creating a Pod does not change cluster DNS configuration by itself. c: it does not encrypt etcd. d: it does not disable TLS anywhere in the cluster. See [chapter 10](../../course/10/ru.md).

</details>

### 37. A security review needs to confirm, months after deployment, exactly which source dependencies were present in a production image at the time it was deployed. Which artifact should have been generated and retained at build time to answer this?

a. The current output of a fresh vulnerability scan run today.
b. An SBOM captured and stored alongside the build, tied to that image's digest.
c. The image's current running Pod logs.
d. The cluster's current NetworkPolicy objects.

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** An SBOM generated at build time and retained (associated with the specific image digest) is exactly the artifact that answers "what dependencies were present in this image when it was built," regardless of how much has changed since then. a: a fresh scan today reflects the current vulnerability database, not what dependencies existed at build time, and does not by itself list dependencies. c: Pod logs record runtime application output, not build-time dependency composition. d: NetworkPolicy objects describe current network rules, unrelated to historical dependency composition. See [chapter 17](../../course/17/ru.md).

</details>


### 38. A tenant exhausts memory and harms neighbors. What threat is primary?

a. Spoofing
b. Repudiation
c. Denial of service
d. PKI failure

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** A tenant consuming excessive memory and starving other tenants' workloads on the same node or cluster is a denial-of-service condition, since it degrades or denies service to others. a: spoofing involves impersonating an identity, not resource exhaustion. b: repudiation involves denying having performed an action. d: PKI failure concerns certificate/key infrastructure problems, unrelated to resource exhaustion. See [chapter 16](../../course/16/ru.md).

</details>

### 39. A compromised Pod sends data to an unusual external IP. What pair helps?

a. ConfigMap and rollout
b. Egress policy and network telemetry
c. RoleBinding and SBOM
d. PSA and PVC

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** An egress NetworkPolicy can restrict which external destinations a Pod may reach, and network telemetry (flow logs, connection records) can reveal that a compromised Pod is contacting an unusual external IP — together detection and restriction. a: a ConfigMap and a rollout neither detect nor restrict egress traffic. c: a RoleBinding and an SBOM concern API authorization and software inventory, not network egress. d: PSA and a PersistentVolumeClaim concern Pod security validation and storage, not egress detection. See [chapter 16](../../course/16/ru.md).

</details>

### 40. A ServiceAccount lists Secrets unexpectedly. What evidence helps?

a. A liveness probe
b. An image tag
c. Audit events with identity and verb
d. Quota status

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Audit events that record the calling identity and the verb performed (such as `list` on Secrets) provide direct evidence of which ServiceAccount listed Secrets and when. a: a liveness probe reports container health, not API access history. b: an image tag identifies a container image version, unrelated to Secret access. d: quota status shows resource consumption, not who accessed which API resource. See [chapter 14](../../course/14/ru.md).

</details>

### 41. An unexpected shell runs in a container. What detected it after start?

a. Admission validation
b. Runtime detection
c. At-rest encryption
d. Provenance

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Runtime detection tools observe the behavior of already-running containers (such as an unexpected shell process starting), which is how this activity is caught after the container has started. a: admission validation runs only at object creation time, before the container starts running, so it cannot see post-start shell activity. c: at-rest encryption protects stored data and has no visibility into running-process behavior. d: provenance records build origin, not runtime behavior. See [chapter 18](../../course/18/ru.md).

</details>

### 42. A stolen credential is used as another user. Which STRIDE threat?

a. Disclosure
b. Tampering
c. DoS
d. Spoofing

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Using a stolen credential to act as another user is impersonating an identity, which STRIDE categorizes as Spoofing. a: Disclosure (Information Disclosure) concerns unauthorized exposure of data, not identity impersonation. b: Tampering concerns unauthorized modification of data, not identity theft. c: Denial of Service concerns availability disruption, not identity misuse. See [chapter 15](../../course/15/ru.md).

</details>

### 43. Which current ATT&CK Containers tactic covers disabling defenses?

a. Exfiltration
b. Defense Impairment
c. Collection
d. Initial Access

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** In the current MITRE ATT&CK Containers matrix, the tactic covering actions that disable or weaken defensive controls is named Defense Impairment. a: Exfiltration concerns moving data out, not disabling defenses. c: Collection concerns gathering data, not disabling defenses. d: Initial Access concerns gaining a foothold, which is a different stage than impairing existing defenses. See [chapter 15](../../course/15/ru.md).

</details>

### 44. How should sensitive etcd backups be protected?

a. Encryption plus restricted access and evidence
b. A Namespace label
c. cluster-admin
d. Base64 only

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Encrypting etcd backups plus restricting who can access them and keeping records of that access together protect sensitive backup content and provide accountability. b: a Namespace label carries no protective value for backup files. c: granting cluster-admin widens access rather than restricting it. d: base64 alone is reversible encoding, not encryption, and provides no real confidentiality. See [chapter 12](../../course/12/ru.md).

</details>

## Platform Security

### 45. A private registry stores an image. What still establishes artifact trust?

a. ClusterIP
b. Digest, trusted signature, and admission verification
c. A larger node pool
d. A Namespace name

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Even when an image is pulled from a private registry, artifact trust still requires an immutable digest to identify exact content, a signature from a trusted identity to assert authenticity, and admission-time verification to enforce that policy before the workload runs. a: a ClusterIP is a Service networking detail, unrelated to artifact trust. c: a larger node pool is a capacity concern, not a trust mechanism. d: a Namespace name provides no cryptographic assurance about an image. See [chapter 17](../../course/17/ru.md).

</details>

### 46. What can reject an unsigned image before creation?

a. Runtime detection
b. An admission webhook that calls out to an external signature-verification service
c. HPA
d. Audit logging

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** An admission webhook can call out to external verification logic — such as a signature-verification service or registry attestation API — to check whether an incoming workload's image reference is signed, and reject it before creation if it lacks a required signature. A built-in `ValidatingAdmissionPolicy` evaluates CEL expressions only against request-visible data already present in the admission request (such as image name/tag strings or labels); it cannot itself perform a cryptographic signature lookup against a registry unless that verification result is somehow already present in the request, so rejecting an unsigned image based on an actual signature check specifically requires the webhook path. a: runtime detection only observes containers that are already running, too late to prevent creation. c: HorizontalPodAutoscaler adjusts replica counts and has no admission role. d: audit logging records events after they occur and does not block creation. See [chapter 17](../../course/17/ru.md).

</details>

### 47. A team's admission policy currently allows any image from a specific trusted registry hostname, with no other check. What supply-chain risk does this policy leave open?

a. This policy is equivalent to verifying a digest, so no further risk remains.
b. The registry could serve any content pushed to it under that hostname, including a compromised or unintended artifact, since the policy only checks where the image came from, not what it actually is.
c. This policy is equivalent to verifying a signature, so no further risk remains.
d. This policy already satisfies SLSA's highest Build track level.

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Trusting a registry hostname alone only restricts where an image is pulled from; it does nothing to confirm the specific content is the intended, unmodified artifact, so a compromised push to that same trusted registry would still pass this policy. a: allowlisting a hostname is not equivalent to pinning or verifying a digest, which identifies exact content. c: it is not equivalent to signature verification, which asserts a specific trusted identity signed that exact artifact. d: a registry allowlist alone says nothing about SLSA Build track requirements, which concern the build process, not registry location. See [chapter 17](../../course/17/ru.md).

</details>


### 48. Two teams disagree about whether an SBOM alone is sufficient evidence that an artifact was built by an authorized, trusted process. Which statement correctly resolves this disagreement?

a. No — an SBOM only inventories the artifact's components and dependencies; it does not describe or attest to how or by whom the artifact was built, which is what provenance/attestation evidence is for.
b. Yes — an SBOM inherently proves the build process was trusted.
c. Yes — because an SBOM always includes a cryptographic signature over the build pipeline.
d. No — because SBOMs are only produced for container base images, never for application layers.

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** An SBOM answers the question of what components and dependencies are present in an artifact; it does not attest to the build process or origin, which is the specific role of provenance/attestation evidence. b and c incorrectly attribute build-trust or signature properties to an SBOM by itself. d is a factually incorrect restriction on what SBOMs can cover. See [chapter 17](../../course/17/ru.md).

</details>


### 49. A policy requires that any artifact lacking a minimum SLSA build level be blocked from deployment. Which control point should evaluate this requirement?

a. A NetworkPolicy on the deployment namespace
b. An admission webhook that retrieves and checks the artifact's provenance/attestation against the required SLSA level before allowing the workload
c. A ResourceQuota on the namespace
d. The kubelet's `--anonymous-auth` setting

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Enforcing a minimum SLSA build level requires retrieving and evaluating the artifact's provenance/attestation evidence, which is typically stored outside the admission request itself (for example in a transparency log or the registry). An admission webhook can perform that external retrieval and check before allowing Pod creation. A built-in `ValidatingAdmissionPolicy` cannot itself fetch attestation from an external source through CEL alone — it can only evaluate data already present in the admission request — so this specific requirement depends on the webhook path unless the attestation result has somehow already been embedded in admission-visible fields beforehand. a: NetworkPolicy governs traffic, not artifact provenance. c: ResourceQuota limits aggregate resource consumption, unrelated to supply-chain evidence. d: the kubelet's anonymous-auth setting concerns kubelet API access, not admission-time artifact checks. See [chapter 17](../../course/17/ru.md).

</details>


### 50. What does mTLS not decide for the Kubernetes API?

a. Mesh identity
b. Peer authentication
c. RBAC permissions
d. Traffic encryption

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** Mutual TLS establishes and encrypts a secure channel and authenticates both peers, but it says nothing about what actions an authenticated peer is authorized to perform — that decision belongs to the API server's configured authorization chain (commonly RBAC, but potentially other authorizers as well). a: mesh identity is part of what mTLS in a service mesh does establish. b: peer authentication is exactly what mTLS decides. d: traffic encryption is exactly what mTLS provides — none of these three is what mTLS leaves undecided, but authorization decisions specifically are. See [chapter 18](../../course/18/ru.md).

</details>

### 51. Ingress terminates TLS then uses HTTP backend. What does its certificate protect?

a. Image signing
b. The client-to-Ingress TLS hop
c. Backend RBAC
d. End-to-end backend encryption

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** When Ingress terminates TLS and then forwards plaintext HTTP to the backend, the Ingress certificate only protects the hop between the external client and the Ingress controller, not anything beyond it. a: Ingress TLS termination has nothing to do with image signing. c: Ingress does not enforce backend RBAC. d: because TLS is terminated at the Ingress, there is no end-to-end encryption all the way to the backend under this configuration. See [chapter 18](../../course/18/ru.md).

</details>

### 52. What is mesh workload identity for?

a. Encrypting etcd
b. Authenticating service peers
c. Replacing a digest
d. Scheduling Pods

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Mesh workload identity lets services in a mesh cryptographically authenticate each other as specific peers before establishing mTLS connections. a: mesh identity does not encrypt etcd, which is a separate control-plane concern. c: it does not replace an image digest, which identifies artifact content rather than runtime identity. d: it has no role in Pod scheduling decisions. See [chapter 18](../../course/18/ru.md).

</details>

### 53. What built-in admission mechanism uses CEL?

a. ResourceQuota
b. NetworkPolicy
c. ValidatingAdmissionPolicy
d. PDB

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** ValidatingAdmissionPolicy is the built-in Kubernetes admission mechanism that uses the Common Expression Language (CEL) to express validation rules without requiring an external webhook. a: ResourceQuota enforces aggregate namespace limits and does not use CEL. b: NetworkPolicy defines traffic rules and does not use CEL for admission. d: a PodDisruptionBudget limits voluntary disruptions and has no relation to CEL-based admission. See [chapter 17](../../course/17/ru.md).

</details>

### 54. What proves an image was blocked before running?

a. A DNS log
b. A liveness failure
c. An admission rejection record
d. A CPU graph

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** A recorded admission rejection (for example a validating webhook or policy denial event) is direct evidence that an image was blocked before it could run. a: a DNS log records name resolution activity, not admission decisions. b: a liveness failure occurs only after a container is already running. d: a CPU graph shows resource usage, not admission outcomes. See [chapter 17](../../course/17/ru.md).

</details>

## Compliance and Security Frameworks

### 55. An organization currently relies on a single manual configuration review performed once before each major release. What is the most direct compliance risk of this approach compared to continuous automated checks?

a. Manual review is inherently less accurate than any automated tool at detecting misconfigurations
b. Manual review cannot be documented for an auditor
c. Manual review always takes longer than an automated scan
d. Configuration drift introduced between releases is not detected until the next manual review, leaving a window where violations go unnoticed

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** Because the review only happens once per release, any configuration change made afterward is not checked again until the next manual review, creating a detection gap for drift or new violations introduced in between. a is not necessarily true — a careful manual review can be accurate — the issue here is frequency/coverage over time, not raw accuracy. b is false; manual reviews can be documented. c is not a compliance risk claim and is not always true either. See [chapter 19](../../course/19/ru.md).

</details>


### 56. What is a strong compliance mapping?

a. Requirement to HPA metric
b. Requirement to a vague statement
c. Requirement to control to reviewable evidence
d. Requirement to image tag

<details>
<summary>Answer and explanation</summary>

**Correct answer: c.** A strong compliance mapping traces a specific requirement to the specific control that satisfies it and then to reviewable evidence proving the control is in place and operating. a: mapping a requirement to an unrelated autoscaling metric provides no relevant evidence. b: mapping to a vague statement cannot be verified or audited. d: mapping to an image tag says nothing about whether the underlying requirement is actually met. See [chapter 19](../../course/19/ru.md).

</details>

### 57. A team wants a checklist specifically focused on common Kubernetes-related security misconfigurations and risks for application teams, distinct from general cloud-native threat modeling. Which resource fits best?

a. MITRE ATT&CK for Containers
b. STRIDE
c. SLSA
d. The OWASP Kubernetes Top Ten

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** The OWASP Kubernetes Top Ten is a checklist-style resource that catalogs common Kubernetes-specific security risks and misconfigurations for practitioners, matching this need. a: MITRE ATT&CK for Containers catalogs adversary tactics and techniques rather than providing a misconfiguration checklist. b: STRIDE is a general threat-modeling categorization method, not Kubernetes-specific. c: SLSA is a supply-chain integrity framework, unrelated to a general misconfiguration checklist. See [chapter 19](../../course/19/ru.md).

</details>


### 58. Why should automated configuration and policy checks run on a recurring schedule rather than only once at cluster creation?

a. Cluster configuration and workloads change over time, so a one-time check cannot detect later drift or newly introduced violations
b. Recurring checks are required only for regulatory paperwork, not for security
c. A single check at creation time is mathematically equivalent to continuous checking
d. Recurring checks eliminate the need for any manual review ever

<details>
<summary>Answer and explanation</summary>

**Correct answer: a.** Kubernetes clusters and workloads change continuously through new deployments, configuration edits, and policy updates; only recurring automated checks can catch drift or newly introduced violations that a single point-in-time check would miss. b: the security value of recurring checks is independent of any paperwork requirement. c: a one-time check cannot be mathematically equivalent to continuous monitoring since state changes afterward. d: automated checks reduce but do not eliminate the value of periodic manual review for judgment-based findings. See [chapter 19](../../course/19/ru.md).

</details>


### 59. Why retain automated configuration-check results?

a. To give scanner cluster-admin
b. To show repeatable evidence and drift
c. To remove audit logs
d. To eliminate all review

<details>
<summary>Answer and explanation</summary>

**Correct answer: b.** Retaining automated configuration-check results over time shows repeatable evidence of compliance and reveals configuration drift between checks, supporting both audits and ongoing security posture tracking. a: granting a scanner cluster-admin is an unnecessary and risky privilege escalation, not a reason to retain results. c: retaining results has nothing to do with removing audit logs, and doing so would itself be harmful. d: retaining automated results supports review; it does not eliminate the need for it. See [chapter 19](../../course/19/ru.md).

</details>

### 60. What makes a temporary privileged-workload exception reviewable?

a. A screenshot
b. A mutable tag
c. A workload name
d. Owner, scope, expiry, approval, and compensating controls

<details>
<summary>Answer and explanation</summary>

**Correct answer: d.** A reviewable temporary exception for a privileged workload needs a clear owner, a bounded scope, an expiry date, documented approval, and compensating controls to offset the added risk during the exception period. a: a screenshot is informal and not a structured, auditable record. b: a mutable tag says nothing about who approved the exception or for how long. c: a workload name alone provides no accountability, time bound, or compensating controls. See [chapter 19](../../course/19/ru.md).

</details>

