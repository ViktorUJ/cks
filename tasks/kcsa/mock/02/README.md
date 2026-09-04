# KCSA Mock Exam 02

> **Training simulation.** An original 60-question KCSA practice exam, not an official Linux Foundation exam.

Allow **90 minutes**. Work **closed-book**: do not use documentation, search, notes, tools, or external websites. Choose one best answer. Distribution: Overview 8, Cluster Component Security 13, Security Fundamentals 13, Threat Model 10, Platform Security 10, Compliance and Security Frameworks 6.

Mock 02 uses independent scenarios from Mock 01. The explanation states the direct control; the other options are real but address a different layer, scope, or enforcement point.

## Overview of Cloud Native Security

### 1. **A Deployment manifest in Git contains an unsafe `securityContext`. An operator manually fixes the running Pod, but the Deployment later recreates it with the original unsafe settings. Which statement best explains why?**

- [ ] A. NetworkPolicy controllers restore Pod security settings from the selected network rules.
- [ ] B. Workload controllers recreate Pods from the declared template, so the source Deployment manifest must be corrected.
- [ ] C. The container runtime restores Pod security settings from previously cached Secret objects.
- [ ] D. Service controllers rewrite Pod security settings whenever endpoint membership changes.

<details><summary>Answer</summary>

**Correct answer:** B

Kubernetes workload controllers reconcile actual state toward the declared workload template. A manual change to a running Pod is therefore not a durable fix when the owning Deployment still contains the unsafe configuration. The Deployment template or its source of truth must be corrected. See [chapter 02](../../course/02/ru.md).
</details>


### 2. **A managed Kubernetes API endpoint is reachable from the public Internet, although only a small corporate network should administer the cluster. Which cloud/infrastructure control most directly reduces exposure before Kubernetes credentials are evaluated?**

- [ ] A. Increase the replica count of application Deployments in every namespace.
- [ ] B. Require every application image to use an immutable digest.
- [ ] C. Restrict the control-plane endpoint to approved source networks or a private endpoint using provider/network controls.
- [ ] D. Increase the default CPU and memory requests for system Pods.

<details><summary>Answer</summary>

**Correct answer:** C

Restricting the Kubernetes API endpoint at the cloud or infrastructure network boundary reduces which networks can reach the control plane before Kubernetes authentication and authorization are evaluated. Image pinning, workload replica counts, and resource requests solve different problems. See [chapter 04](../../course/04/ru.md).
</details>
### 3. **A password is committed in source. Which 4C layer is first involved?**

- [ ] A. Cluster
- [ ] B. Code
- [ ] C. Container
- [ ] D. Cloud

<details><summary>Answer</summary>

**Correct answer:** B

A password committed into source code is a Code-layer (the innermost of the 4Cs) exposure, since it originates in the application's source rather than the cluster, container, or cloud infrastructure. a: the Cluster layer covers Kubernetes infrastructure, not source code. c: the Container layer concerns image content and runtime, not source repositories. d: the Cloud layer concerns provider infrastructure. See [chapter 03](../../course/03/ru.md).
</details>

### 4. **A team wants to know only whether their currently deployed image has any newly disclosed critical CVE, without re-reviewing the whole artifact. What should they rely on?**

- [ ] A. The image's build timestamp
- [ ] B. The name of the container registry
- [ ] C. The number of layers in the image
- [ ] D. Recurring vulnerability scans against the deployed image

<details><summary>Answer</summary>

**Correct answer:** D

Recurring vulnerability scanning checks the components in a deployed image against an updated vulnerability database, which is how newly disclosed CVEs affecting an already-running image can be detected. A: a build timestamp says nothing about vulnerabilities disclosed later. B: the registry name identifies where the image is stored, not its vulnerability status. C: the number of layers is a packaging detail and does not establish whether a CVE affects the image. See [chapter 06](../../course/06/ru.md).
</details>
### 5. **A scan reports no known CVEs. What can be concluded?**

- [ ] A. The artifact was signed by an identity accepted by the organization's current artifact trust policy.
- [ ] B. The scan proved that the artifact contains no malicious logic and no unknown vulnerabilities.
- [ ] C. The artifact automatically satisfies every security policy that the organization applies before deployment.
- [ ] D. The scanner found no known vulnerabilities within the vulnerability data, configuration, and coverage used for that scan.

<details><summary>Answer</summary>

**Correct answer:** D

A vulnerability scanner reports findings within its data and scan coverage at a particular point in time. A clean scan does not establish signature trust, prove absence of malicious or unknown flaws, or satisfy unrelated deployment controls. See [chapter 06](../../course/06/ru.md).
</details>
### 6. **A team wants to know, before merging a pull request, whether a proposed dependency upgrade introduces a newly known vulnerability. When is this check most useful?**

- [ ] A. Run the dependency check only after the changed artifact reaches production and the deployment has completed successfully.
- [ ] B. Run the dependency check only during a scheduled annual audit, independent of when dependency changes are proposed.
- [ ] C. Rely on post-release user reports to identify whether a dependency change introduced a security problem into the application.
- [ ] D. Run an automated dependency and vulnerability check in CI before merge or artifact creation so the risky change can be stopped early.

<details><summary>Answer</summary>

**Correct answer:** D

A dependency check is most useful before the change is accepted and packaged, because the pipeline can block or remediate the risk before deployment. Production-only checks, annual reviews, and user reports are later detection points rather than an effective pre-merge gate. See [chapter 05](../../course/05/ru.md).
</details>
### 7. **A production image still contains the compiler, package manager, build caches, and source tree even though the application only needs one compiled binary at runtime. Which change most directly reduces that unnecessary runtime attack surface?**

- [ ] A. Keep the complete build toolchain in the final image and grant the container additional Linux capabilities for maintenance.
- [ ] B. Replace the immutable image digest with a mutable `latest` tag so build tools can be updated after deployment.
- [ ] C. Give the runtime registry credential push permission so the running Pod can rebuild and republish its own image.
- [ ] D. Use a multi-stage build and copy only the required runtime artifact and dependencies into a minimal final image.

<details><summary>Answer</summary>

**Correct answer:** D

A multi-stage build keeps compilers and other build-only tooling in a builder stage while copying only the required runtime artifact and dependencies into the final image. Reducing unnecessary packages and tools decreases runtime attack surface.

This does not replace SCA, image scanning, signing, provenance, or runtime hardening; it addresses a different image-minimization competency. See [chapter 06](../../course/06/ru.md).
</details>
### 8. **A source review finds unsafe deserialization logic that could process attacker-controlled data before the application image is built. Which action most directly addresses the risk at the Code layer?**

- [ ] A. Increase the Deployment replica count so more Pods can process the same input.
- [ ] B. Fix the vulnerable code and use code review or SAST to detect unsafe patterns before the artifact is built.
- [ ] C. Change the application Service from `ClusterIP` to `LoadBalancer` so traffic follows a different path.
- [ ] D. Increase the retention period of etcd snapshots so the application can be restored after an incident.

<details><summary>Answer</summary>

**Correct answer:** B

A source-level vulnerability is primarily a Code-layer problem. Secure coding, review, and static analysis can address the flaw before it is packaged into an image. Scaling, Service exposure, and etcd backup retention do not fix unsafe application logic. See [chapter 06](../../course/06/ru.md).
</details>

## Kubernetes Cluster Component Security

### 9. **A production cluster exposes its `etcd` client endpoint to a broad internal network. Which control most directly reduces the resulting risk?**

- [ ] A. Enforce the restricted Pod Security Standard across application namespaces and reject privileged workload specifications.
- [ ] B. Require short-lived projected ServiceAccount tokens for application Pods that call the Kubernetes API.
- [ ] C. Restrict network reachability to intended control-plane clients and require mutually authenticated TLS.
- [ ] D. Apply namespace ResourceQuota policies to cap aggregate CPU, memory, and workload object consumption.

<details><summary>Answer</summary>

**Correct answer:** C

`etcd` should not be broadly reachable. Network restrictions and mutually authenticated TLS limit access to the intended control-plane clients, protecting cluster state from direct exposure. Namespace labels, ServiceAccount tokens, and ResourceQuota do not secure the `etcd` endpoint. See [chapter 07](../../course/07/ru.md).
</details>

### 10. **An operator has a valid etcd snapshot, but the team has never tested restoration from it. What security/availability risk remains?**

- [ ] A. Snapshot integrity alone proves recovery will work because it automatically validates every dependency needed by the restored control plane.
- [ ] B. Backup existence does not prove recoverability; restoration must be tested with controlled procedures and the dependencies required for recovery.
- [ ] C. Keeping a valid snapshot removes the need to protect etcd credentials because lost cluster state can always be recreated from backup.
- [ ] D. Creating a snapshot automatically validates certificates, DNS, storage, and control-plane configuration that a future restore will depend on.

<details><summary>Answer</summary>

**Correct answer:** B

A backup is useful only if it can be restored correctly. Restore tests verify procedures, dependencies, permissions, certificates, storage behavior, and operational assumptions. Snapshot existence by itself is not evidence that recovery will succeed. See [chapter 07](../../course/07/ru.md).
</details>
### 11. **What does kubelet `--authorization-mode=AlwaysAllow` mean after a caller has been authenticated?**

- [ ] A. It rejects every authenticated kubelet API request.
- [ ] B. It changes kube-proxy to an IPVS data plane.
- [ ] C. It enables node audit logging for every kubelet request.
- [ ] D. It accepts every authenticated kubelet API request without a permission check.

<details><summary>Answer</summary>

**Correct answer:** D

`AlwaysAllow` skips kubelet authorization. Authentication still decides whether a caller has an identity, but once accepted, no per-action permission decision is made. See [chapter 08](../../course/08/ru.md).
</details>

### 12. **A cluster administrator wants kube-apiserver-to-etcd traffic to survive a future migration to a different etcd deployment without re-architecting trust. Which practice supports this goal while keeping the connection encrypted and mutually authenticated?**

- [ ] A. Disable certificate verification during migration and restore it after the new etcd cluster is online.
- [ ] B. Reuse the kube-apiserver serving certificate as the shared client credential for all etcd endpoints.
- [ ] C. Use a dedicated etcd CA or CA chain so client and peer trust can be managed and rotated independently.
- [ ] D. Store etcd private keys in a ConfigMap so every control-plane node can retrieve them during migration.

<details><summary>Answer</summary>

**Correct answer:** C

A dedicated etcd CA or CA chain keeps etcd client/peer trust independent from unrelated cluster certificates and allows that trust to be migrated or rotated without conflating different PKI roles. Disabling verification removes authentication, reusing the API-server serving certificate mixes trust purposes, and ConfigMap is not appropriate storage for TLS private keys. See [chapter 07](../../course/07/ru.md).
</details>
### 13. **A Pod uses `hostNetwork: true`. Which statement is the safest assumption about ordinary Kubernetes `NetworkPolicy`?**

- [ ] A. Every CNI must enforce Pod selectors for `hostNetwork` Pods exactly as it does for ordinary pod-network traffic.
- [ ] B. Every CNI must ignore `hostNetwork` Pods, so NetworkPolicy can never affect their traffic.
- [ ] C. `hostNetwork` creates another isolated network namespace and therefore separates the Pod from node interfaces.
- [ ] D. Behavior is network-plugin dependent, so ordinary NetworkPolicy must not be assumed to provide a universal host firewall for `hostNetwork` Pods.

<details><summary>Answer</summary>

**Correct answer:** D

Kubernetes documents `NetworkPolicy` behavior for `hostNetwork` Pods as implementation-dependent. A network plugin may be able to distinguish and apply policy to that traffic, or it may treat the traffic like ordinary node-IP traffic. Therefore `NetworkPolicy` must not be presented as a universal host firewall for `hostNetwork` Pods. Limit `hostNetwork` through RBAC/admission and validate the behavior of the selected network implementation. See [chapter 13](../../course/13/ru.md).
</details>

### 14. **Why should `kube-scheduler` and `kube-controller-manager` use distinct authenticated identities rather than one shared broadly privileged identity?**

- [ ] A. Separate identities let each component receive only required API permissions and make audit records attributable to the component that performed the action.
- [ ] B. A shared identity is required for Kubernetes leader election and prevents either component from operating when separate credentials are configured.
- [ ] C. Separate component identities automatically encrypt Pod-to-Pod traffic and therefore remove the need for workload transport-security controls.
- [ ] D. A shared identity causes admission controllers to skip control-plane requests and therefore reduces the amount of authorization required.

<details><summary>Answer</summary>

**Correct answer:** A

Separate component identities support least privilege and better audit attribution. Leader election does not require a single shared identity, and API identity does not provide Pod transport encryption or bypass admission. See [chapter 07](../../course/07/ru.md).
</details>
### 15. **Which practice best supports evidence of unexpected kubelet-configuration changes after an approved hardening baseline is established?**

- [ ] A. Continuously compare the configuration with the approved baseline and protect the resulting change records.
- [ ] B. Capture one screenshot at hardening time and disable subsequent configuration monitoring.
- [ ] C. Grant every workload cluster-admin so configuration changes are easier to investigate.
- [ ] D. Mount the host filesystem into every workload and rely on manual file comparisons.

<details><summary>Answer</summary>

**Correct answer:** A

Continuous configuration/FIM monitoring can detect and record deviations relative to an approved baseline when its evidence is protected. It is evidence of observed changes, not absolute proof that no historical tampering ever occurred. See [chapter 08](../../course/08/ru.md).
</details>

### 16. **Which setting exposes host processes to a Pod?**

- [ ] A. readOnlyRootFilesystem: true
- [ ] B. hostPID: true
- [ ] C. runAsNonRoot: true
- [ ] D. allowPrivilegeEscalation: false

<details><summary>Answer</summary>

**Correct answer:** B

`hostPID: true` shares the node's process namespace with the Pod, exposing host process information and IDs to containers in that Pod. a: `readOnlyRootFilesystem: true` restricts writes and reduces risk. c: `runAsNonRoot: true` also reduces risk by blocking root execution. d: `allowPrivilegeEscalation: false` blocks escalation and reduces risk — none of these three exposes host processes. See [chapter 09](../../course/09/ru.md).
</details>

### 17. **What does hostNetwork do?**

- [ ] A. Grants RBAC
- [ ] B. Creates a NetworkPolicy
- [ ] C. Uses the node network namespace
- [ ] D. Encrypts traffic

<details><summary>Answer</summary>

**Correct answer:** C

`hostNetwork: true` makes a Pod share the node's network namespace instead of getting its own, giving it visibility into host network interfaces and ports. a: hostNetwork does not grant RBAC permissions. b: it does not create a NetworkPolicy object. d: sharing the host network namespace does not itself encrypt any traffic. See [chapter 09](../../course/09/ru.md).
</details>

### 18. **An attacker obtains a copy of a storage snapshot but does not have the storage decryption keys. Which control most directly protects the data contained in that snapshot?**

- [ ] A. A Namespace label that identifies the application team responsible for the stored workload data.
- [ ] B. A Deployment rollout that replaces running Pods after the snapshot has already been copied.
- [ ] C. Encryption of the stored data at rest with decryption keys protected separately from the snapshot.
- [ ] D. A ServiceAccount that gives the application read-only access to selected Kubernetes API resources.

<details><summary>Answer</summary>

**Correct answer:** C

Encryption at rest protects snapshot contents when the attacker obtains the storage data but not the required decryption key material. Key access and storage encryption therefore have to be protected separately.

Namespace labels, Pod rollouts, and Kubernetes API identities do not make an already copied storage snapshot confidential. See [chapter 09](../../course/09/ru.md).
</details>

### 19. **An administrator uses `kubectl` from one workstation to manage both test and production clusters. Which practice most directly reduces wrong-cluster actions and limits credential blast radius?**

- [ ] A. Use one shared `cluster-admin` identity and one default context for every environment.
- [ ] B. Disable TLS certificate verification so switching between cluster endpoints cannot fail.
- [ ] C. Copy the production bearer token into shell aliases used for routine administration.
- [ ] D. Use separate contexts and identities for environments, verify the active context before sensitive actions, and keep permissions least-privilege.

<details><summary>Answer</summary>

**Correct answer:** D

`kubeconfig` contexts select the cluster, user, and namespace used by `kubectl`. Separate contexts and identities, explicit context checks, and least-privilege permissions reduce both accidental production actions and the impact of credential compromise. Shared administrator credentials, disabled TLS verification, and copied bearer tokens increase risk. See [chapter 09](../../course/09/ru.md).
</details>
### 20. **An administrator receives a `kubeconfig` from an untrusted source. Its user entry contains an `exec` credential plugin that points to a local executable. What is the main security concern?**

- [ ] A. The `exec` entry only changes the default namespace and cannot run code on the administrator's workstation.
- [ ] B. Kubernetes automatically converts the executable into a CNI plugin and runs it only inside cluster Pods.
- [ ] C. A Kubernetes client may execute the configured credential helper locally, so untrusted kubeconfig files and exec plugins must be reviewed before use.
- [ ] D. The `exec` entry automatically disables certificate verification for every cluster listed in the kubeconfig.

<details><summary>Answer</summary>

**Correct answer:** C

A kubeconfig can reference an exec-based credential plugin. A client such as `kubectl` may execute that configured helper on the administrator's workstation to obtain credentials. Therefore a kubeconfig from an untrusted source is not merely passive connection metadata and must be reviewed before use.

The exec plugin is not a CNI plugin, does not merely select a namespace, and does not inherently disable TLS verification. See [chapter 09](../../course/09/ru.md).
</details>

### 21. **A kubelet does not need its legacy unauthenticated read-only HTTP endpoint. Which configuration most directly removes that exposure?**

- [ ] A. Set `--authorization-mode=AlwaysAllow`.
- [ ] B. Enable `hostNetwork` for node workloads.
- [ ] C. Set `--anonymous-auth=true`.
- [ ] D. Set `--read-only-port=0`.

<details><summary>Answer</summary>

**Correct answer:** D

The kubelet legacy read-only port provides an unauthenticated endpoint and should be disabled when it is not required. Setting `--read-only-port=0` removes that listener. `AlwaysAllow` weakens authorization, `--anonymous-auth=true` permits unauthenticated callers on the authenticated kubelet API path, and `hostNetwork` is unrelated to kubelet endpoint authentication. See [chapter 08](../../course/08/ru.md).
</details>

## Kubernetes Security Fundamentals - questions 22-34

### 22. **A user may create RoleBindings in a namespace but must not be able to bind permissions they do not already hold. Which Kubernetes authorization rule is relevant?**

- [ ] A. Creating a RoleBinding permits any Role or ClusterRole to be referenced without checking the caller's effective permissions.
- [ ] B. The caller normally needs the referenced permissions unless explicitly authorized to `bind` that Role or ClusterRole.
- [ ] C. NetworkPolicy decides which Role or ClusterRole a RoleBinding may reference based on the source namespace.
- [ ] D. ResourceQuota prevents privilege expansion by limiting the number and scope of RoleBinding objects.

<details><summary>Answer</summary>

**Correct answer:** B

Kubernetes prevents privilege escalation through role binding: a caller normally needs to already hold the permissions contained in the referenced Role or ClusterRole at the relevant scope. Explicit `bind` permission on that role is the special authorization that can bypass that normal restriction.

`bind` applies to RoleBinding/ClusterRoleBinding. `escalate` instead applies to creating or modifying Role/ClusterRole rules beyond the caller's own permissions. See [chapter 10](../../course/10/ru.md).
</details>

### 23. **What does a ServiceAccount provide?**

- [ ] A. An API identity
- [ ] B. Network isolation
- [ ] C. Automatic permissions
- [ ] D. At-rest encryption

<details><summary>Answer</summary>

**Correct answer:** A

A ServiceAccount's core role is to provide a workload with an API identity; separate RoleBindings or ClusterRoleBindings then grant that identity permissions. b: a ServiceAccount has no effect on network isolation. c: it does not automatically carry any permissions by itself. d: it plays no role in at-rest encryption. See [chapter 10](../../course/10/ru.md).
</details>

### 24. **An earlier configured authorizer returns `Deny`, while a later authorizer would have returned `Allow`. What result does kube-apiserver use?**

- [ ] A. `Deny`, because a decisive authorization verdict ends evaluation before later authorizers are consulted.
- [ ] B. `Allow`, because any later `Allow` overrides an earlier `Deny` in the configured authorizer chain.
- [ ] C. `NoOpinion`, because conflicting decisive verdicts cancel and force authorization to restart without either result.
- [ ] D. Admission decides the final authorization result after both authorizers have returned their independent verdicts.

<details><summary>Answer</summary>

**Correct answer:** A

Configured Kubernetes authorizers are evaluated in order. Once one returns a decisive `Allow` or `Deny`, evaluation stops; later authorizers are not consulted. Admission runs only after successful authorization and cannot overturn an authorization denial. See [chapter 10](../../course/10/ru.md).
</details>

### 25. **A `RoleBinding` in namespace `team-a` references a `ClusterRole` that grants `get` and `list` on Pods. What access does that binding grant?**

- [ ] A. The permissions apply cluster-wide because the referenced `ClusterRole` is a cluster-scoped object.
- [ ] B. The permissions apply only to node identities because a namespaced binding cannot grant access to ordinary users or ServiceAccounts.
- [ ] C. No permissions are granted because a `RoleBinding` is not allowed to reference a `ClusterRole`.
- [ ] D. The referenced permissions are granted only within `team-a`; a `ClusterRoleBinding` would be required to grant them cluster-wide.

<details><summary>Answer</summary>

**Correct answer:** D

A `RoleBinding` is namespaced. It may reference either a `Role` in the same namespace or a `ClusterRole`, but the permissions granted by that binding apply only within the `RoleBinding`'s namespace.

A `ClusterRoleBinding` grants the referenced `ClusterRole` permissions at cluster scope. The fact that the role object itself is a `ClusterRole` does not make a namespaced `RoleBinding` cluster-wide.

See [chapter 10](../../course/10/ru.md).
</details>

### 26. **A namespace has no Pod Security Admission labels, and the cluster has no explicit PSA defaults in `PodSecurityConfiguration`. What built-in PSA default is effectively used?**

- [ ] A. `restricted` for enforce, audit and warn.
- [ ] B. `baseline` for enforce, audit and warn.
- [ ] C. No Pod Security Admission policy is evaluated at all.
- [ ] D. `privileged` for enforce, audit and warn, using the `latest` policy version.

<details><summary>Answer</summary>

**Correct answer:** D

PSA has built-in defaults. Without namespace labels or configured defaults, its default profile for enforce/audit/warn is `privileged` with version `latest`, which is permissive and therefore rarely blocks or flags a Pod. PodSecurityPolicy does not reappear as a fallback. See [chapter 11](../../course/11/ru.md).
</details>

### 27. **Why cannot PSA block database egress?**

- [ ] A. It encrypts traffic
- [ ] B. It grants RBAC
- [ ] C. It validates PSS, not network flows
- [ ] D. It is a CNI

<details><summary>Answer</summary>

**Correct answer:** C

Pod Security Admission validates Pod specification fields against a Pod Security Standard; it has no visibility into or control over network traffic such as database egress, which is a NetworkPolicy/CNI concern. a: PSA does not encrypt traffic. b: PSA does not grant RBAC permissions. d: PSA is an admission control mechanism, not a CNI. See [chapter 11](../../course/11/ru.md).
</details>

### 28. **How can a Secret reach a process?**

- [ ] A. It grants RBAC
- [ ] B. It always encrypts etcd
- [ ] C. It cannot be an env var
- [ ] D. It may be injected as an environment variable

<details><summary>Answer</summary>

**Correct answer:** D

A Secret's data can be delivered to a container process by injecting it as an environment variable, which is one of the standard consumption mechanisms alongside volume mounts. a: a Secret does not itself grant RBAC permissions. b: using a Secret does not automatically encrypt etcd; that requires a separate EncryptionConfiguration. c: a Secret can in fact be exposed as an environment variable, so this option is factually false. See [chapter 12](../../course/12/ru.md).
</details>

### 29. **For classic broad Kubernetes impersonation, which RBAC verb can authorize a caller to act as another user, group, or ServiceAccount?**

- [ ] A. `bind` on a referenced Role or ClusterRole.
- [ ] B. `impersonate` on the relevant identity resource.
- [ ] C. `escalate` on a Role or ClusterRole being created or modified.
- [ ] D. `update` on a namespaced `NetworkPolicy` resource.

<details><summary>Answer</summary>

**Correct answer:** B

The classic Kubernetes impersonation mechanism uses the `impersonate` verb on the relevant identity attribute. This permission is sensitive because, once the impersonation request is accepted, authorization evaluates the request using the impersonated identity.

Kubernetes v1.36 also has beta `ConstrainedImpersonation`, enabled by default, with narrower `impersonate:*` and `impersonate-on:*` permissions. Existing classic `impersonate` RBAC rules continue to work, so B is the correct answer to the classic broad-impersonation question.

`bind` governs RBAC role binding, while `escalate` governs creation or modification of Role/ClusterRole rules containing permissions beyond those held by the caller. See [chapter 10](../../course/10/ru.md).
</details>
### 30. **Two NetworkPolicy objects both select the same Pod: one denies all ingress, and another explicitly allows ingress from a specific label selector on port 443. What is the resulting behavior for that Pod, assuming a supporting CNI?**

- [ ] A. Ingress on port 443 from the matching label is allowed; all other ingress remains denied, because NetworkPolicy rules for a Pod are additive
- [ ] B. The Pod's ingress is fully denied, because a deny-all policy always overrides an allow policy
- [ ] C. The Pod's ingress is fully allowed, because a more specific policy always disables a broader one
- [ ] D. The two policies conflict and Kubernetes rejects the second policy at creation

<details><summary>Answer</summary>

**Correct answer:** A

Multiple NetworkPolicy objects selecting the same Pod are additive: the union of all matching allow rules applies, so the specific allow on port 443 opens exactly that path while everything else remains blocked by the deny-all baseline. b and c both wrongly assume one policy type universally overrides another; NetworkPolicy has no such precedence rule. d is incorrect because Kubernetes does not reject a second NetworkPolicy for overlapping selection. See [chapter 13](../../course/13/ru.md).
</details>

### 31. **A NetworkPolicy ingress rule contains one `from` entry with both a `namespaceSelector` and a `podSelector`. Which sources match that single entry?**

- [ ] A. Any Pod that matches either selector, even when its Namespace does not match the namespace selector.
- [ ] B. Every Pod in the policy's own Namespace, because `podSelector` in `from` cannot select remote namespaces.
- [ ] C. Pods that match the `podSelector` and are located in Namespaces that match the `namespaceSelector`.
- [ ] D. No Pods; Kubernetes rejects a `from` item whenever both selectors appear in the same list element.

<details><summary>Answer</summary>

**Correct answer:** C

When `namespaceSelector` and `podSelector` are present in the same `from` entry, they are combined: the source Pod must match the Pod selector **and** belong to a Namespace matching the Namespace selector. Separate list entries represent alternative allowed sources.

This tests selector composition rather than repeating the default-deny/explicit-allow competency. See [chapter 13](../../course/13/ru.md).
</details>

### 32. **Beyond the authenticated caller identity, which audit fields provide useful **corroborating context** about the reported client and network origin during investigation?**

- [ ] A. The Secret data value included in the event
- [ ] B. The Pod resource limits at request time
- [ ] C. The cluster NetworkPolicy count
- [ ] D. `userAgent` and `sourceIPs`

<details><summary>Answer</summary>

**Correct answer:** D

`userAgent` and `sourceIPs` can support correlation, but they do not prove that a specific Pod or Job made the request. `userAgent` is client-reported, and forwarded source IP values can be client-controlled. Correlate them with authenticated identity, workload metadata and trusted network/runtime telemetry. See [chapter 14](../../course/14/ru.md).
</details>


### 33. **One Kubernetes API request generated audit events at multiple audit stages. Which field most directly lets an investigator correlate those events as the same request?**

- [ ] A. `auditID`
- [ ] B. `resourceVersion`
- [ ] C. Pod UID
- [ ] D. Service `clusterIP`

<details><summary>Answer</summary>

**Correct answer:** A

Kubernetes audit events for the same API request share an `auditID`, allowing an investigator to correlate events emitted at different audit stages for that request. `resourceVersion`, Pod UID, and Service `clusterIP` identify different resources or state and are not the request-correlation identifier. See [chapter 14](../../course/14/ru.md).
</details>
### 34. **An External Secrets Operator synchronizes a value from an external secret manager into a normal Kubernetes `Secret`. Which security consequence remains true after synchronization?**

- [ ] A. Because the source is external, the synchronized value never exists in the Kubernetes API or its backing storage.
- [ ] B. Once synchronized, access policy in the external manager replaces Kubernetes RBAC for every consumer of the resulting Secret.
- [ ] C. The value is now also a Kubernetes Secret, so API authorization, etcd protection, and workload exposure still need to be controlled.
- [ ] D. Synchronization converts the value into public certificate metadata and removes the normal confidentiality requirements for Secret data.

<details><summary>Answer</summary>

**Correct answer:** C

After synchronization into a Kubernetes `Secret`, the value is subject to the same Kubernetes exposure paths as other Secret data: API authorization, backing-store protection, workload delivery, node exposure, and logging mistakes still matter. The external manager remains an additional control plane, not a replacement for Kubernetes controls. See [chapter 12](../../course/12/ru.md).
</details>

## Kubernetes Threat Model - questions 35-44

### 35. **An attacker compromises a CI job and publishes a malicious but syntactically valid image to the approved registry using legitimate pipeline credentials. What should the Kubernetes threat model conclude?**

- [ ] A. Treat successful registry authentication as sufficient artifact trust because the approved registry recorded a legitimate pipeline identity.
- [ ] B. Treat the event only as a registry-storage problem because a syntactically valid artifact was accepted through normal repository controls.
- [ ] C. Treat runtime NetworkPolicy as proof that the build path remained trustworthy because policy limits traffic after the image starts.
- [ ] D. Treat the compromised build and deployment pipeline as a malicious-code path and require artifact trust evidence beyond successful registry authentication.

<details><summary>Answer</summary>

**Correct answer:** D

Registry authentication establishes which credential was used; it does not prove that a compromised builder produced benign content. The threat model must include the pipeline as a malicious-code path and use independent artifact trust evidence plus deployment/runtime controls. See [chapter 16](../../course/16/ru.md).
</details>
### 36. **A threat model identifies production Secrets as sensitive assets. What should the team determine next to make the model actionable?**

- [ ] A. Identify identities, data paths, and trust boundaries that can expose or modify the Secrets, then map controls and evidence.
- [ ] B. Compare Service names and select the shortest one as the primary security boundary for the Secrets.
- [ ] C. Assume etcd encryption removes the need to review RBAC identities that can read the Secrets through the API.
- [ ] D. Standardize namespace labels first, regardless of which identities or data flows can reach the Secrets.

<details><summary>Answer</summary>

**Correct answer:** A

An actionable threat model connects a sensitive asset to realistic identities, access paths, trust boundaries, threats, controls, and evidence. Encryption at rest protects one storage boundary but does not eliminate API authorization or other exposure paths. See [chapter 15](../../course/15/ru.md).
</details>
### 37. **A namespace user cannot read node files directly, but can create Pods and the admission configuration still permits `privileged: true` with `hostPath: /`. What should the threat model conclude?**

- [ ] A. The user cannot affect the node because RBAC does not grant `get nodes`.
- [ ] B. Workload-creation permission can become a privilege-escalation path to host access when dangerous Pod specifications are admitted.
- [ ] C. NetworkPolicy automatically blocks the `hostPath` mount before the Pod starts.
- [ ] D. Encryption at rest for Secrets prevents a privileged Pod from accessing the host filesystem.

<details><summary>Answer</summary>

**Correct answer:** B

API permissions must be analyzed together with the objects those permissions can create. If a user can create an admitted privileged Pod with a sensitive host mount, workload creation can become a path to node-level privilege escalation even without direct node API permissions. See [chapter 16](../../course/16/ru.md).
</details>

### 38. **A namespace has CPU and memory `ResourceQuota`, but a compromised credential can still generate a very high rate of Kubernetes API requests. Which conclusion is most accurate?**

- [ ] A. Namespace workload quota also guarantees a safe kube-apiserver request rate because both controls ultimately account for Kubernetes resource usage.
- [ ] B. Pod CPU limits automatically impose an equivalent request-rate limit on all authenticated API calls made with credentials from that workload.
- [ ] C. Workload quota and API request exhaustion are different availability paths, so API abuse needs controls appropriate to identity and request processing.
- [ ] D. Encryption at rest for Kubernetes Secrets prevents request flooding because encrypted API objects require less control-plane processing capacity.

<details><summary>Answer</summary>

**Correct answer:** C

`ResourceQuota` constrains selected namespace resources; it is not a general per-identity API request-rate control. API/control-plane exhaustion is a different availability path and requires controls appropriate to request processing, identity, authorization, prioritization/rate handling, and monitoring. See [chapter 16](../../course/16/ru.md).
</details>
### 39. **A compromised frontend Pod attempts to contact an unexpected external address. Which pair provides prevention plus useful network evidence?**

- [ ] A. Pod Security Admission plus a PersistentVolumeClaim.
- [ ] B. Restrictive egress policy plus network-flow/connection telemetry.
- [ ] C. A RoleBinding plus an SBOM inventory for the image.
- [ ] D. A ConfigMap plus a rolling restart of the Deployment.

<details><summary>Answer</summary>

**Correct answer:** B

Egress policy can restrict destinations, while flow/connection telemetry shows attempted or successful unusual communication. The other pairs address different security or operational concerns. See [chapter 16](../../course/16/ru.md).
</details>

### 40. **Responders find that an attacker created a malicious CronJob and used a compromised Kubernetes credential to recreate access after cleanup. Which response most directly removes both identified persistence paths?**

- [ ] A. Delete only the currently running Pod and keep the credential active for later investigation.
- [ ] B. Change the Service name and increase the Deployment replica count.
- [ ] C. Remove the malicious controller, revoke or rotate the compromised credential, and review related access for additional persistence.
- [ ] D. Restart kube-proxy without changing the attacker-controlled objects or credentials.

<details><summary>Answer</summary>

**Correct answer:** C

Effective persistence removal addresses the mechanisms that can recreate attacker access. Deleting the malicious controller removes one persistence source, while revoking or rotating the compromised credential removes the second. Related RBAC bindings, workloads, and audit evidence should also be reviewed for additional footholds. Deleting only a child Pod or restarting unrelated components does not remove the persistence mechanisms. See [chapter 16](../../course/16/ru.md).
</details>
### 41. **An attacker gains root access on a worker node that hosts several application Pods. Which threat-model assumption is safest for incident response?**

- [ ] A. Treat Pod-mounted credentials and other sensitive data on that node as potentially exposed, contain the node, and rotate or revoke affected credentials as appropriate.
- [ ] B. Kubernetes RBAC guarantees that host root cannot access credentials already mounted into Pods on that node.
- [ ] C. etcd encryption at rest automatically protects Pod memory, mounted volumes, and projected credentials from host root.
- [ ] D. NetworkPolicy prevents a root user on the node from reading local Pod files or process memory.

<details><summary>Answer</summary>

**Correct answer:** A

A compromised worker node crosses a high-trust boundary. Host root can potentially access Pod files, mounted credentials, runtime state, and other sensitive material belonging to workloads on that node, so responders should contain the node and evaluate credential rotation/revocation. RBAC, etcd encryption at rest, and NetworkPolicy protect different boundaries and do not make a compromised host root trustworthy. See [chapter 16](../../course/16/ru.md).
</details>
### 42. **A compromised workload reads a credential and writes it to stdout; centralized logging then collects that output. Which conclusion is most accurate?**

- [ ] A. TLS to the log collector makes the credential safe to retain because transport encryption removes its sensitivity after successful delivery.
- [ ] B. Kubernetes RBAC automatically redacts secret values from application stdout before log agents can read and forward the generated output.
- [ ] C. etcd encryption at rest prevents a credential from appearing in application logs after an authorized workload obtains the value.
- [ ] D. The logging pipeline becomes another sensitive-data path, so secrets should be avoided or redacted and access to retained logs restricted.

<details><summary>Answer</summary>

**Correct answer:** D

Once a credential is written to logs, it exists in another data path and storage system. TLS protects transport but not the retained plaintext value; RBAC and etcd encryption do not automatically redact application output. See [chapter 16](../../course/16/ru.md).
</details>
### 43. **A web application Pod is exploited through an RCE. Its mounted ServiceAccount can create `ClusterRoleBinding` objects and is explicitly allowed to `bind` the built-in `cluster-admin` `ClusterRole`. What is the most important threat-model conclusion?**

- [ ] A. The RCE remains confined to the application because Kubernetes API permissions are unrelated to workload compromise.
- [ ] B. The compromised workload identity can turn application compromise into cluster privilege escalation; reduce its RBAC permissions and avoid unnecessary credentials.
- [ ] C. Image signing automatically prevents the stolen ServiceAccount credential from being used.
- [ ] D. A Pod CPU limit prevents the compromised process from calling the Kubernetes API.

<details><summary>Answer</summary>

**Correct answer:** B

A compromised application inherits the effective permissions of credentials available to the workload. Here the identity can both create a `ClusterRoleBinding` and bind the privileged `cluster-admin` role, so an application-level RCE can become cluster-level privilege escalation.

Mere `create` permission on `ClusterRoleBinding` alone would not necessarily be sufficient: Kubernetes normally requires the caller to already hold the permissions in the referenced role or to have explicit `bind` permission on that role. Workload identities should therefore use least-privilege RBAC, and unnecessary API credentials should not be mounted. See [chapter 10](../../course/10/ru.md).
</details>
### 44. **Why should an `etcd` backup be identified as a high-value asset in a Kubernetes threat model?**

- [ ] A. It may contain sensitive cluster state and is needed for recovery, so access, integrity, confidentiality, and restore handling matter.
- [ ] B. It applies Pod Security Standards to workloads whenever the live API server is unavailable during an incident.
- [ ] C. It converts stored Kubernetes Secret values into public certificates while a restore operation is being performed.
- [ ] D. It replaces API-server authorization checks for clients that are restoring cluster resources from backup.

<details><summary>Answer</summary>

**Correct answer:** A

An etcd backup can expose much of the same sensitive state as the live datastore and is also critical to recovery. Threat modeling should therefore cover unauthorized access, tampering, key protection, retention, and controlled restoration. See [chapter 15](../../course/15/ru.md).
</details>

## Platform Security - questions 45-54

### 45. **A private registry is used by both CI and Kubernetes nodes. CI must push images, while runtime identities only need to pull them. Which control best limits the impact of a stolen runtime registry credential?**

- [ ] A. Use separate least-privilege registry identities so runtime credentials have pull-only access.
- [ ] B. Give CI and every node the same credential with both push and pull permissions.
- [ ] C. Use a mutable `latest` tag for every production workload.
- [ ] D. Disable registry authentication because the registry is on a private network.

<details><summary>Answer</summary>

**Correct answer:** A

Registry credentials should follow least privilege. CI identities that publish artifacts may need push access, while workload/node pull credentials should not gain write access to the repository. A private network does not remove the need for registry authentication and authorization. See [chapter 17](../../course/17/ru.md).
</details>


### 46. **Which control can reject an unsigned image before the workload is admitted?**

- [ ] A. A runtime detector that alerts after the container has already started.
- [ ] B. An admission webhook that invokes a trusted signature verifier before admission.
- [ ] C. A HorizontalPodAutoscaler that adjusts replica count from observed metrics.
- [ ] D. API audit logging that records the request and result after processing.

<details><summary>Answer</summary>

**Correct answer:** B

An admission webhook can call external signature-verification logic before the object is accepted. Runtime detection is post-start, HPA is scaling, and audit logging records rather than blocks. A built-in CEL policy can validate request-visible data but cannot itself perform an arbitrary external registry signature lookup. See [chapter 17](../../course/17/ru.md).
</details>

### 47. **A validating admission webhook performs mandatory image-signature verification. The verifier becomes temporarily unreachable. Which setting best prevents workloads from being silently admitted without that required check?**

- [ ] A. Set `failurePolicy: Ignore` so the API request continues whenever verification cannot run.
- [ ] B. Set `failurePolicy: Fail` so an error or timeout in the required webhook blocks the admission request.
- [ ] C. Add `hostNetwork: true` to workloads so they can bypass the webhook service path.
- [ ] D. Replace the validating webhook with a `ResourceQuota`.

<details><summary>Answer</summary>

**Correct answer:** B

For a mandatory admission check, `failurePolicy: Fail` provides fail-closed behavior: if the webhook cannot be called or returns an applicable error, the request is rejected rather than admitted without the control. `Ignore` is fail-open for webhook call failures and can temporarily bypass a required check. `hostNetwork` and `ResourceQuota` do not implement artifact-signature verification. See [chapter 17](../../course/17/ru.md).
</details>
### 48. **A security team wants flow-level evidence showing which Pod initiated an unexpected connection, its destination, and whether Cilium policy allowed or denied the flow. Which source is most directly suited to that investigation?**

- [ ] A. Hubble network-flow visibility associated with the Cilium data plane.
- [ ] B. `ResourceQuota.status` showing namespace resource consumption and configured hard limits.
- [ ] C. An SBOM describing the packages and dependencies contained in the application artifact.
- [ ] D. kube-scheduler placement events showing why a pending Pod was assigned to a node.

<details><summary>Answer</summary>

**Correct answer:** A

Hubble provides Cilium network-flow observability and can show workload network connections and policy verdict context. `ResourceQuota` is resource-governance data, an SBOM describes artifact composition, and scheduler events describe placement rather than network flows. Hubble observes traffic; it does not replace `NetworkPolicy`. See [chapter 18](../../course/18/ru.md).
</details>
### 49. **A policy requires that any artifact lacking a minimum SLSA Build level be blocked from deployment. Which control point should evaluate this requirement?**

- [ ] A. A NetworkPolicy that inspects provenance metadata before permitting registry traffic.
- [ ] B. An admission verifier that retrieves the attestation and checks the required SLSA Build level before admission.
- [ ] C. A ResourceQuota that evaluates provenance and blocks Pods when the SLSA level is too low.
- [ ] D. Kubelet authentication settings that validate an image's SLSA Build level during startup.

<details><summary>Answer</summary>

**Correct answer:** B

Enforcing a minimum SLSA Build level requires retrieving and evaluating artifact attestation/provenance, typically through an admission webhook or external verifier. A CEL ValidatingAdmissionPolicy cannot perform arbitrary external retrieval itself. See [chapter 17](../../course/17/ru.md).
</details>


### 50. **A Kubernetes API client trusts a CA that did not issue the kube-apiserver certificate. What is the expected result if certificate verification is enforced?**

- [ ] A. TLS verification fails because the server certificate cannot chain to a CA trusted by the client.
- [ ] B. RBAC installs the missing CA automatically before the API request reaches authorization.
- [ ] C. NetworkPolicy signs a replacement server certificate for the kube-apiserver endpoint.
- [ ] D. Kubernetes authorizes the API request first and verifies the TLS certificate afterward.

<details><summary>Answer</summary>

**Correct answer:** A

TLS server verification happens before a Kubernetes API request can reach authentication or authorization. If the kube-apiserver certificate cannot be validated to a CA trusted by the client, the TLS connection fails. RBAC and NetworkPolicy do not repair PKI trust. See [chapter 18](../../course/18/ru.md).
</details>
### 51. **Ingress terminates TLS then uses HTTP backend. What does its certificate protect?**

- [ ] A. Image signing
- [ ] B. The client-to-Ingress TLS hop
- [ ] C. Backend RBAC
- [ ] D. End-to-end backend encryption

<details><summary>Answer</summary>

**Correct answer:** B

When Ingress terminates TLS and then forwards plaintext HTTP to the backend, the Ingress certificate only protects the hop between the external client and the Ingress controller, not anything beyond it. a: Ingress TLS termination has nothing to do with image signing. c: Ingress does not enforce backend RBAC. d: because TLS is terminated at the Ingress, there is no end-to-end encryption all the way to the backend under this configuration. See [chapter 18](../../course/18/ru.md).
</details>

### 52. **Why are short-lived automatically rotated workload certificates preferable to long-lived shared certificates in a service mesh?**

- [ ] A. They reduce the useful lifetime of stolen credentials and preserve distinct identities instead of sharing one credential across unrelated workloads.
- [ ] B. They replace service authorization by allowing any workload with a currently valid certificate to call every authenticated service.
- [ ] C. They guarantee that application code contains no exploitable vulnerability as long as certificate rotation completes before expiry.
- [ ] D. They improve workload separation by assigning the same long-lived certificate and private key to all services in the mesh.

<details><summary>Answer</summary>

**Correct answer:** A

Short-lived credentials reduce the exposure window after theft, and separate workload identities improve attribution and authorization. Certificate rotation does not replace authorization, remove application vulnerabilities, or justify sharing one identity across workloads. See [chapter 18](../../course/18/ru.md).
</details>
### 53. **Which built-in admission mechanism uses CEL specifically to validate API objects and can reject a non-compliant request without an external webhook?**

- [ ] A. `ResourceQuota`
- [ ] B. `NetworkPolicy`
- [ ] C. `ValidatingAdmissionPolicy`
- [ ] D. `PodDisruptionBudget`

<details><summary>Answer</summary>

**Correct answer:** C

`ValidatingAdmissionPolicy` provides built-in declarative validation with CEL and can reject a request. Kubernetes v1.36 also has stable `MutatingAdmissionPolicy`, which uses CEL for mutation rather than validation; therefore the question specifies validation to make `ValidatingAdmissionPolicy` uniquely correct. See [chapter 17](../../course/17/ru.md).
</details>

### 54. **A security team wants a numeric time series of Kubernetes API authentication failures so it can graph the rate over time and alert on an unusual increase. Which component is primarily suited to collecting and storing those metrics?**

- [ ] A. Falco, which primarily detects runtime behavior such as suspicious process or syscall activity.
- [ ] B. Hubble, which primarily provides Cilium network-flow visibility and policy-verdict context.
- [ ] C. Prometheus, which collects and stores numeric time-series metrics that can feed queries, dashboards, and alerts.
- [ ] D. NetworkPolicy, which defines allowed network flows but is not a time-series metrics datastore.

<details><summary>Answer</summary>

**Correct answer:** C

Prometheus is designed to collect and store numeric time-series metrics. Those metrics can then be queried directly or visualized and alerted on through tools such as Grafana.

Falco focuses on runtime detection, Hubble on Cilium network-flow observability, and NetworkPolicy on traffic enforcement. See [chapter 18](../../course/18/ru.md).
</details>

## Compliance and Security Frameworks - questions 55-60

### 55. **A CIS Kubernetes Benchmark check targets a control-plane setting that a managed provider does not expose to the customer. What is the best compliance treatment?**

- [ ] A. Mark the whole cluster failed regardless of applicability, because every CIS recommendation must be directly configurable by the customer.
- [ ] B. Mark the control passed without evidence, because provider ownership alone proves that the managed setting satisfies the benchmark.
- [ ] C. Document applicability and provider ownership or evidence for that control, then assess the customer-owned controls separately.
- [ ] D. Grant application workloads cluster-admin so they can inspect or modify the provider-managed control-plane setting themselves.

<details><summary>Answer</summary>

**Correct answer:** C

A managed-service control can be provider-owned or not customer-configurable. Document applicability and obtain appropriate provider evidence while assessing the controls the customer actually owns. Provider ownership alone is not proof of compliance, and broad workload privilege is not an acceptable inspection mechanism. See [chapter 19](../../course/19/ru.md).
</details>
### 56. **What is a strong compliance mapping?**

- [ ] A. Requirement to HPA metric
- [ ] B. Requirement to a vague statement
- [ ] C. Requirement to control to reviewable evidence
- [ ] D. Requirement to image tag

<details><summary>Answer</summary>

**Correct answer:** C

A strong compliance mapping traces a specific requirement to the specific control that satisfies it and then to reviewable evidence proving the control is in place and operating. a: mapping a requirement to an unrelated autoscaling metric provides no relevant evidence. b: mapping to a vague statement cannot be verified or audited. d: mapping to an image tag says nothing about whether the underlying requirement is actually met. See [chapter 19](../../course/19/ru.md).
</details>

### 57. **An organization processes payment-card data in workloads running on Kubernetes. Which framework most directly defines compliance requirements for protecting cardholder data?**

- [ ] A. SLSA v1.2
- [ ] B. PCI DSS
- [ ] C. STRIDE
- [ ] D. MITRE ATT&CK for Containers

<details><summary>Answer</summary>

**Correct answer:** B

PCI DSS defines requirements for protecting cardholder data and the systems that process it. STRIDE and MITRE ATT&CK are threat-analysis frameworks, while SLSA addresses software supply-chain assurance rather than payment-card compliance. See [chapter 19](../../course/19/ru.md).
</details>


### 58. **Compliance scan results are retained for a later audit. Which additional property most improves their value as evidence?**

- [ ] A. Store results with timestamps and provenance in access-controlled, tamper-evident or immutable evidence storage.
- [ ] B. Keep the most recent result only on a developer workstation with ordinary file permissions.
- [ ] C. Let the scanner overwrite prior results whenever remediation changes the current compliance state.
- [ ] D. Remove historical results after each run so auditors see only the newest status.

<details><summary>Answer</summary>

**Correct answer:** A

Timestamps, provenance, and protected tamper-evident or immutable storage help show what was checked, when it was checked, and whether the retained evidence was later altered. Overwriting or deleting history weakens auditability. See [chapter 19](../../course/19/ru.md).
</details>
### 59. **A compliance team keeps scan evidence for twelve months. What should determine that retention period?**

- [ ] A. Applicable legal, regulatory, contractual, and internal evidence-retention requirements.
- [ ] B. The number of Pods currently running in the cluster.
- [ ] C. The kube-proxy backend mode.
- [ ] D. The default ServiceAccount name.

<details><summary>Answer</summary>

**Correct answer:** A

Evidence retention should follow applicable legal, regulatory, contractual, and internal requirements. Cluster size, kube-proxy implementation, and a default ServiceAccount name do not determine compliance retention obligations. See [chapter 19](../../course/19/ru.md).
</details>

### 60. **What makes a temporary privileged-workload exception reviewable?**

- [ ] A. A screenshot, an informal owner note, and no fixed date when the exception must end.
- [ ] B. A mutable image tag, broad workload scope, and approval recorded only in an ephemeral chat.
- [ ] C. A workload name, indefinite duration, and no documented control to compensate for the added privilege.
- [ ] D. A named owner, bounded scope, explicit expiry, recorded approval, and documented compensating controls.

<details><summary>Answer</summary>

**Correct answer:** D

A temporary security exception should be attributable, bounded, time-limited, approved, and accompanied by compensating controls. Those properties make it possible to review whether the exception is still justified and to remove it when the approved period ends. See [chapter 19](../../course/19/ru.md).
</details>
