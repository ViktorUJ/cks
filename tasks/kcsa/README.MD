# KCSA example questions

**What is a primary security advantage of using a cloud provider’s managed Kubernetes service?**
- A. Regular security patching and updates.
- B. Automatic scaling of CPU and memory resources.
- C. Built-in integration with developer IDE tools.
- D. Unlimited data storage capacities.

<details><summary>Answer</summary>

**Correct answer:** A

A managed Kubernetes provider operates the control plane and delivers its security patches, which is the stated control-plane advantage. Autoscaling, IDE integration, and unlimited storage are unrelated operational claims, not the managed-control-plane security benefit.
</details>

---

**Which of the following is a recommended practice to secure Kubernetes infrastructure on a cloud provider?**
- A. Run all pods with root privileges by default.
- B. Regularly audit and apply Kubernetes security patches.
- C. Enable anonymous access to Kubernetes API endpoints.
- D. Utilize public container images from unverified sources.

<details><summary>Answer</summary>

**Correct answer:** B

Regularly auditing and applying Kubernetes security patches closes known vulnerabilities before they can be exploited. Running Pods as root by default, allowing anonymous API access, and pulling unverified public images all expand attack surface instead of reducing it.
</details>

---

**Which security control directly ensures that only approved identities can perform permitted Kubernetes API actions?**
- A. A Service load balancer.
- B. A Deployment replica count.
- C. Authentication followed by authorization, such as RBAC.
- D. A PersistentVolumeClaim.

<details><summary>Answer</summary>

**Correct answer:** C

Authentication establishes caller identity, and authorization (such as RBAC) then decides which API verbs and resources that identity may use; together they are the control that ensures only approved identities perform permitted actions. A load balancer, a Deployment replica count, and a PersistentVolumeClaim have no role in identity or permission decisions.
</details>

---

**Which pairing correctly distinguishes a threat-modeling/security framework from a compliance framework?**
- A. OWASP is only a storage framework; HIPAA is a container runtime.
- B. STRIDE is a threat-modeling framework; PCI DSS is a compliance framework.
- C. PCI DSS is a threat-modeling framework; STRIDE is a compliance framework.
- D. MITRE ATT&CK is a compliance certification; CIS is an authentication protocol.

<details><summary>Answer</summary>

**Correct answer:** B

STRIDE is a threat-modeling framework used to categorize threats, while PCI DSS is a compliance framework defining payment-card data requirements; that pairing is accurate. The other options either invert those roles or invent unrelated categories (a storage framework, a container runtime, a compliance certification, an authentication protocol) for OWASP, HIPAA, MITRE ATT&CK, and CIS.
</details>

---

**Which of the following is not one of the 4Cs of Cloud Native Security?**
- A. Culture.
- B. Code.
- C. Cloud.
- D. Cluster.

<details><summary>Answer</summary>

**Correct answer:** A

The cloud-native security model's four Cs are Cloud, Cluster, Container, and Code. Culture can matter organizationally, but it is not one of those four layers, which is why it is the correct answer to the 'which is not' question.
</details>

---

**In the context of the 4Cs of Cloud Native Security, what does the “Cluster” focus on?**
- A. Protecting the infrastructure that the applications run on.
- B. Securing interactions with external APIs.
- C. Implementing continuous integration pipelines.
- D. Managing container runtime vulnerabilities.

<details><summary>Answer</summary>

**Correct answer:** A

The Cluster layer of the 4Cs model covers the security of the Kubernetes cluster infrastructure and its components (API server, etcd, kubelet, networking) that host workloads. Interactions with external APIs, CI pipeline implementation, and container runtime vulnerabilities belong to other 4Cs layers or to the Container layer specifically, not to the Cluster layer.
</details>

---

**What best describes what a Kubernetes namespace provides on its own?**
- A. Managing storage volumes.
- B. A naming scope for objects, and a boundary to which RBAC, ResourceQuota, and NetworkPolicy can be attached.
- C. Running scheduled tasks.
- D. Installing additional software packages.

<details><summary>Answer</summary>

**Correct answer:** B

A namespace scopes object names and provides a boundary to which RBAC, ResourceQuota, LimitRange, and NetworkPolicy can be attached; it is an organizational/policy scope, not by itself a hard workload security boundary. It does not manage storage volumes, run scheduled tasks, or install software packages.
</details>

---

**Which of the following is a technique to provide isolation for applications running within Kubernetes?**
- A. Replica sets.
- B. Persistent volumes.
- C. Network policies.
- D. Storage classes.

<details><summary>Answer</summary>

**Correct answer:** C

NetworkPolicy can restrict permitted ingress and egress between selected Pods, provided the cluster's CNI plugin enforces network policies, making it the isolation technique among the choices. ReplicaSets manage replica counts, PersistentVolumes provide storage, and StorageClasses define how volumes are provisioned; none of the three isolate network traffic.
</details>

---

**Which practice most directly reduces the risk of deploying a vulnerable container image?**
- A. Scan images for vulnerabilities before deployment.
- B. Allow images from any public repository.
- C. Always use the `latest` tag.
- D. Disable image provenance checks.

<details><summary>Answer</summary>

**Correct answer:** A

Scanning images for known vulnerabilities before deployment identifies risks while there is still time to remediate them, which most directly reduces the risk of deploying a vulnerable image. The `latest` tag is mutable and hides which content is actually running, and unrestricted public sources or disabled provenance checks remove rather than add supply-chain assurance.
</details>

---

**What is a key benefit of using an artifact repository in a Kubernetes environment?**
- A. It provides automatic scaling of Kubernetes nodes.
- B. It retains and access-controls deployment artifacts, supporting — but not by itself guaranteeing — their integrity.
- C. It facilitates communication between microservices.
- D. It allows for storing logs from the Kubernetes clusters.

<details><summary>Answer</summary>

**Correct answer:** B

An artifact repository can retain, access-control, and help verify the deployment artifacts a cluster pulls from, which supports artifact integrity efforts; a repository alone is not itself a cryptographic integrity guarantee, and true integrity still depends on digests, signatures, and verification performed on top of it. Node autoscaling, service-to-service communication, and cluster log storage are unrelated functions of a repository.
</details>

---

**What is an effective method for securing application code in Kubernetes?**
- A. Using integrated development environments (IDEs).
- B. Implementing code reviews and static analysis tools.
- C. Disabling network encryption.
- D. Running applications with root privileges.

<details><summary>Answer</summary>

**Correct answer:** B

Code reviews and static analysis tools find insecure implementation patterns before code is built into a container image, making them an effective method for securing application code. Using an IDE by itself is not a security control, and disabling network encryption or running as root introduces risk rather than reducing it.
</details>

---

**Which approach enhances workload security in Kubernetes clusters?**
- A. Regularly applying security patches and updates to container images.
- B. Deploying all applications in the default namespace.
- C. Allowing unrestricted network access to pods.
- D. Using privileged containers for all applications.

<details><summary>Answer</summary>

**Correct answer:** A

Regularly applying security patches and updates to container images removes known vulnerabilities from workloads, which enhances workload security. Deploying everything in the default namespace, allowing unrestricted Pod network access, and using privileged containers for all applications all weaken workload security instead.
</details>

---

**Which of the following can be used to secure communication between the API Server and other Kubernetes components?**
- A. Network policies.
- B. iptables configuration.
- C. TLS certificates.
- D. Role-based access control.

<details><summary>Answer</summary>

**Correct answer:** C

TLS certificates authenticate the API server and other components to each other and encrypt their traffic in transit, securing component-to-component communication. NetworkPolicy governs selected workload traffic rather than control-plane component links, iptables rules alone do not provide component identity, and RBAC authorizes API requests but does not encrypt transport.
</details>

---
**A configured Kubernetes API server accepts a bearer token. What does this token establish before authorization?**
- A. The caller's Pod Security Standard profile.
- B. The caller's NetworkPolicy egress rules.
- C. The caller's authenticated identity.
- D. The caller's image signature.

<details><summary>Answer</summary>

**Correct answer:** C

A bearer token is an authentication credential: the API server uses it to establish the caller's identity before authorization decides which verbs and resources that identity may use. A Pod Security Standard profile, NetworkPolicy egress rules, and an image signature are unrelated to what a bearer token establishes.
</details>
---

**What function does the Kubernetes Controller Manager serve in maintaining desired state configurations?**
- A. It allows direct configuration of the cluster’s network policies.
- B. It manages routine tasks such as node health checks and replication.
- C. It provides a web interface for monitoring cluster resources.
- D. It handles communication between Pods.

<details><summary>Answer</summary>

**Correct answer:** B

Controller Manager runs reconciliation controllers, including node-lifecycle and replication controllers, that continuously drive observed cluster state toward the desired state. Direct NetworkPolicy configuration, a monitoring web interface, and inter-Pod communication are not part of that reconciliation role.
</details>

---

**Which security measure is essential for protecting the Kubernetes Controller Manager?**
- A. Running the Controller Manager on a separate physical server.
- B. Enabling Role-Based Access Control (RBAC) for API authorization.
- C. Using a firewall to block all external traffic to nodes.
- D. Disabling all logging mechanisms to minimize data exposure.

<details><summary>Answer</summary>

**Correct answer:** B

RBAC restricts what the Controller Manager's own API credential is authorized to do, applying least privilege to a component that can otherwise reconcile many cluster-wide resources; this authorization control is the essential protection here, specifically for the controller's access to API resources, rather than for the process in general. Running on separate hardware or blocking all external traffic does not enforce least privilege on that credential, and disabling logging removes security evidence instead of protecting the component.
</details>

---

**What is the primary function of the Kubernetes Scheduler in a cluster?**
- A. To store and manage container images.
- B. To manage network policies.
- C. To assign Pods to nodes based on resource availability and constraints.
- D. To control access to the Kubernetes API.

<details><summary>Answer</summary>

**Correct answer:** C

The scheduler evaluates resource availability and placement constraints to assign each unscheduled Pod to a feasible node, which is its primary function. Image storage, network policy management, and API access control are handled by other Kubernetes components, not the scheduler.
</details>

---

**Which scheduler constraint requires a Pod to run only on nodes that match a specified label?**
- A. Required node affinity.
- B. A Service selector.
- C. A PodDisruptionBudget.
- D. A NetworkPolicy.

<details><summary>Answer</summary>

**Correct answer:** A

Required node affinity makes a matching node label a mandatory scheduling condition, restricting a Pod to nodes carrying that label. A Service selector identifies endpoints rather than constraining node placement, and a PodDisruptionBudget and a NetworkPolicy do not participate in node selection at all.
</details>

---

**Which kubelet hardening measure most directly prevents unauthenticated read access to its API?**
- A. Disable anonymous authentication and the read-only port, then protect kubelet TLS and authorization.
- B. Run every workload in the `kube-system` namespace.
- C. Expose the kubelet API on every network interface without controls.
- D. Enable unauthenticated access for health checks.

<details><summary>Answer</summary>

**Correct answer:** A

Disabling kubelet anonymous authentication and the read-only port, then requiring TLS and proper authorization for the kubelet API, most directly prevents unauthenticated reads of that API. Namespace placement has no effect on kubelet endpoint protection, and exposing the kubelet without controls or enabling unauthenticated health checks does the opposite of hardening it.
</details>

---

**What is a potential security risk if the Kubelet’s anonymous-auth is enabled?**
- A. Enhancing cluster performance by offloading tasks to the node.
- B. Increased latency in pod scheduling.
- C. Unauthorized access to sensitive data on the node.
- D. Debugging and troubleshooting becomes easier.

<details><summary>Answer</summary>

**Correct answer:** C

Anonymous kubelet access can let an unauthenticated caller retrieve node- and Pod-related information, which is the security risk. Debugging convenience, latency, and performance are not risks — they are unrelated or opposite claims about what anonymous access changes.
</details>

---

**What role does the container runtime play in Kubernetes?**
- A. It schedules pods and other workloads.
- B. It provides persistent storage services.
- C. It manages the cluster networking.
- D. It starts and stops containers on a node.

<details><summary>Answer</summary>

**Correct answer:** D

The container runtime uses the Container Runtime Interface to create, run, and stop containers on a node, which is its role. Pod scheduling, cluster networking, and persistent storage are the responsibilities of the scheduler, kube-proxy/CNI, and the storage subsystem respectively, not the container runtime.
</details>

---

**Which of the following is a common container runtime used in Kubernetes?**
- A. Nagios
- B. Syslog
- C. CRI-O
- D. HDFS

<details><summary>Answer</summary>

**Correct answer:** C

CRI-O is a CRI-compatible container runtime that Kubernetes nodes can use to run containers. Syslog is logging software, HDFS is a distributed storage system, and Nagios is a monitoring tool — none of them is a container runtime.
</details>

---

**What is the primary role of kube-proxy in a Kubernetes cluster?**
- A. To schedule Pod placement on nodes.
- B. To manage network storage volumes.
- C. To implement Service traffic forwarding on nodes.
- D. To deploy applications automatically.

<details><summary>Answer</summary>

**Correct answer:** C

kube-proxy programs node-level rules that forward traffic addressed to a Service's virtual IP to the Service's matching endpoints, which is its primary role. It does not schedule Pods, manage storage volumes, or deploy applications, and it does not itself encrypt traffic.
</details>

---

**Which measure best protects kube-proxy on a worker node from tampering?**
- A. Disable all Service routing.
- B. Disable required node hardening.
- C. Grant every Pod write access to kube-proxy configuration.
- D. Protect node access, kube-proxy configuration, and node credentials with least privilege and file permissions.

<details><summary>Answer</summary>

**Correct answer:** D

Protecting node access, the kube-proxy configuration, and the node's credentials with least privilege and correct file permissions prevents an attacker who reaches the node from altering Service-routing behavior. Disabling Service routing breaks application connectivity rather than protecting kube-proxy, disabling required node hardening removes protection, and giving every Pod write access to the configuration directly enables tampering.
</details>

---

**Which of the following is a primary security concern for pods in a Kubernetes cluster?**
- A. The graphical user interface performance.
- B. Container vulnerabilities and privilege escalation.
- C. Version compatibility with the operating system.
- D. Network latency between nodes.

<details><summary>Answer</summary>

**Correct answer:** B

Exploitable container vulnerabilities and excessive privileges that allow privilege escalation or container escape are the primary security concern for Pods. GUI performance, OS version compatibility, and inter-node network latency are operational concerns, not the principal Pod security threat.
</details>

---

**Which control most directly restricts which network communications a pod is allowed to send or receive?**
- A. By setting high availability for the scheduler.
- B. By configuring persistent volume claims.
- C. By encrypting the kube-proxy logs.
- D. By using NetworkPolicy to control allowed pod network communication.

<details><summary>Answer</summary>

**Correct answer:** D

NetworkPolicy expresses which network communications are allowed to and from selected Pods, provided the cluster's CNI implements policy enforcement; it controls Pod network communication specifically, not Pod behavior in general. Scheduler high availability, PersistentVolumeClaims, and encrypting kube-proxy logs have no effect on what a Pod is allowed to communicate with.
</details>

---

**Which of the following best describes the role of etcd in a Kubernetes cluster?**
- A. It serves as the user interface for managing containers.
- B. It acts as the scheduler for deploying resources in a cluster.
- C. It functions as the network load balancer.
- D. It is a database that stores the cluster configuration and state.

<details><summary>Answer</summary>

**Correct answer:** D

etcd is Kubernetes' consistent key-value store that holds cluster configuration and state, which is its role. It is not a user interface, a scheduler, or a network load balancer — those are separate components.
</details>

---

**Which measure protects etcd data in transit from unauthorized interception or modification?**
- A. Store etcd data in a ConfigMap.
- B. Configure mutual TLS for etcd client and peer communication.
- C. Disable etcd authentication.
- D. Expose the client port publicly.

<details><summary>Answer</summary>

**Correct answer:** B

Mutual TLS for etcd client and peer communication encrypts that traffic and authenticates both sides, protecting it from interception or modification in transit. Storing etcd data in a ConfigMap is not a transport-security mechanism, and disabling authentication or exposing the client port publicly removes protection instead of adding it.
</details>

---

**Which of the following is a primary security concern when using persistent storage in Kubernetes?**
- A. Unauthorized access to sensitive data.
- B. Storage performance degradation.
- C. Lack of storage capacity.
- D. High storage costs.

<details><summary>Answer</summary>

**Correct answer:** A

Persistent volumes may hold credentials, application data, or backups that unauthorized principals must not be able to read or alter, making unauthorized access the primary security concern. Storage cost, capacity, and performance are operational considerations, not the primary security issue with persistent storage.
</details>

---

**What is an accurate description of how a Kubernetes Secret relates to storing sensitive configuration?**
- A. It is an API object intended to hold sensitive values such as passwords, though using one does not by itself encrypt the data at rest.
- B. By increasing storage space.
- C. By improving the speed of data retrieval.
- D. By enhancing data encryption.

<details><summary>Answer</summary>

**Correct answer:** A

A Kubernetes Secret is an API object intended to hold sensitive values such as passwords, and it can be access-controlled through RBAC; using a Secret does not by itself provide encryption at rest, which requires separate EncryptionConfiguration. Increasing storage space, improving retrieval speed, and 'enhancing data encryption' in general terms are not what makes a Secret a security-relevant storage mechanism.
</details>

---

**What is the purpose of Kubernetes Pod Security Standards?**
- A. To specify which Kubernetes resources can be accessed by nodes.
- B. To provide guidelines for the isolation of Kubernetes workloads to protect the system from malicious pods.
- C. To restrict the version of Kubernetes that can be used.
- D. To ensure that only certain container registries can be used.

<details><summary>Answer</summary>

**Correct answer:** B

Pod Security Standards define workload hardening expectations — restrictions on privilege escalation, host access, and similar settings — intended to reduce malicious or overly privileged Pod behavior. They do not select which Kubernetes version, container registry, or node resources a workload may use.
</details>

---

**Which Pod Security Standards profile imposes the strongest workload restrictions?**
- A. Restricted.
- B. Audit.
- C. Privileged.
- D. Baseline.

<details><summary>Answer</summary>

**Correct answer:** A

The Restricted profile imposes the tightest set of Pod hardening requirements among the Pod Security Standards. Baseline permits more than Restricted, Privileged intentionally permits broad capabilities, and 'Audit' is an enforcement mode (record without blocking) rather than a profile.
</details>

---

**Which of the following accurately describes the role of Pod Security Admissions in Kubernetes?**
- A. They are responsible for scheduling pods to appropriate nodes.
- B. They handle communication between pods.
- C. They manage the lifecycle of Kubernetes nodes.
- D. They enforce policies that dictate what pods can run and how they can operate within a cluster.

<details><summary>Answer</summary>

**Correct answer:** D

Pod Security Admission validates Pod specifications against the namespace's selected Pod Security Standard at admission time, which is its role. Node lifecycle management, Pod-to-Pod communication, and scheduling Pods to nodes are handled by other components.
</details>

---
**A namespace uses Pod Security Admission with the `restricted` profile in `enforce` mode. What is the primary benefit?**
- A. It filters Pod-to-Pod packets.
- B. It authorizes users to read Secrets.
- C. It automatically upgrades Kubernetes.
- D. It rejects Pods that violate the selected Pod Security Standard before creation.

<details><summary>Answer</summary>

**Correct answer:** D

Pod Security Admission in `enforce` mode rejects a Pod that violates the selected Pod Security Standard before the Pod is created, which is the primary benefit here. RBAC (not this mechanism) authorizes API actions such as reading Secrets, NetworkPolicy (not this mechanism) filters Pod-to-Pod packets, and PSA has no role in upgrading Kubernetes.
</details>
---

**What is the primary security role of a Kubernetes ServiceAccount for a workload?**
- A. It provides the workload identity; RBAC bindings grant that identity permissions.
- B. It grants API permissions by itself.
- C. It encrypts the workload network traffic.
- D. It schedules the workload onto a node.

<details><summary>Answer</summary>

**Correct answer:** A

A ServiceAccount supplies a workload's API identity, while separate RoleBindings or ClusterRoleBindings determine what that identity is permitted to do; a ServiceAccount by itself grants no permissions. It does not encrypt network traffic or schedule the workload onto a node.
</details>

---

**Which authentication method allows Kubernetes to integrate with an external identity provider?**
- A. Client certificates.
- B. Integrating with OIDC (OpenID Connect).
- C. Static Bearer Token.
- D. Service Accounts.

<details><summary>Answer</summary>

**Correct answer:** B

OIDC (OpenID Connect) lets the API server delegate user authentication to a compatible external identity provider, which is the described integration method. Client certificates and static bearer tokens are direct, provider-independent credential methods, and ServiceAccounts authenticate in-cluster workloads rather than integrating an external identity provider.
</details>

---

**Which of the following Kubernetes components is responsible for making authorization decisions?**
- A. Controller Manager
- B. API Server
- C. Kubelet
- D. Scheduler

<details><summary>Answer</summary>

**Correct answer:** B

The API server hosts the authorization chain that evaluates each authenticated request against configured authorizers such as RBAC, making it the authorization decision point. The scheduler, Controller Manager, and kubelet perform placement, reconciliation, and node-level execution, not API authorization decisions.
</details>

---

**In Kubernetes, which of these is a role-based access control (RBAC) component?**
- A. an unrelated policy object
- B. Namespace
- C. ClusterRole
- D. ServiceAccount

<details><summary>Answer</summary>

**Correct answer:** C

A ClusterRole defines reusable, cluster-scoped RBAC permissions and is therefore an RBAC component. A ServiceAccount is an identity rather than a permission definition, a Namespace is a scope rather than an RBAC object, and an unrelated policy object is not part of RBAC at all.
</details>

---

**A team wants to avoid embedding a database password directly in a container image or plain ConfigMap. Which Kubernetes mechanism is designed for this case?**
- A. To provide high availability for pods.
- B. To monitor the health of Kubernetes nodes.
- C. A Secret, so the sensitive value can be access-controlled and kept out of the image and ordinary configuration.
- D. To configure network policies for namespaces.

<details><summary>Answer</summary>

**Correct answer:** C

A Secret is the Kubernetes object designed to hold sensitive values such as a database password, keeping it out of the image and out of ordinary non-sensitive configuration, and allowing RBAC-based access control. A, B, and D describe unrelated functions — availability, node health monitoring, and namespace network policy configuration are not what a Secret is for.
</details>

---
**A workload needs a database password. Which statement correctly distinguishes a Kubernetes Secret from an environment variable?**
- A. A Secret cannot be delivered as an environment variable.
- B. A Secret automatically grants the workload RBAC permissions.
- C. Environment variables automatically encrypt Secret data in etcd.
- D. A Secret is a Kubernetes object for sensitive data and can be injected as an environment variable; encryption at rest is a separate cluster configuration.

<details><summary>Answer</summary>

**Correct answer:** D

A Secret is a Kubernetes API object for sensitive data, and it can be delivered to a workload as an environment variable — the two are not mutually exclusive, so 'cannot be delivered as an environment variable' is false. Encryption at rest requires a separate API-server EncryptionConfiguration and is not automatic just because data is in a Secret or an environment variable, and neither a Secret nor an environment variable grants RBAC permissions by itself.
</details>
---

**Which Kubernetes feature can be used to limit the scope and traffic within certain namespaces to enhance isolation?**
- A. Network Policies
- B. Persistent Volumes
- C. ConfigMaps
- D. Node Selectors

<details><summary>Answer</summary>

**Correct answer:** A

NetworkPolicy can constrain the allowed ingress and egress of selected Pods within and across namespaces when the cluster's CNI enforces policies, which is how it limits scope and traffic to enhance isolation. ConfigMaps and PersistentVolumes hold data rather than control traffic, and node selectors affect scheduling, not network isolation.
</details>

---

**What is the primary benefit of using Kubernetes namespaces for isolation and segmentation in a cluster?**
- A. They allow you to create new API objects.
- B. They speed up pod deployment.
- C. They enable resource and access constraints within a cluster.
- D. They provide high availability for applications.

<details><summary>Answer</summary>

**Correct answer:** C

Namespaces provide a scope in which resource quotas, RBAC, and other access-related controls can be applied to segment tenants, which is the isolation/segmentation benefit referenced here. They do not themselves create new API object types, add high availability, or speed up Pod deployment.
</details>

---

**Which statement accurately describes Kubernetes audit event processing and storage?**
- A. kube-scheduler generates the events and etcd always stores them.
- B. kube-controller-manager stores every event in a ConfigMap.
- C. Every Pod generates the events and a Service stores them.
- D. kube-apiserver processes audit events and the configured audit backend stores them.

<details><summary>Answer</summary>

**Correct answer:** D

kube-apiserver generates and processes audit events for the requests it handles, then delivers them to whichever backend (log file or webhook) the audit policy configures, which correctly describes the audit pipeline. kube-scheduler, kube-controller-manager, and ordinary Pods do not generate or store audit events, and a Service is not an audit storage backend.
</details>

---

**What is the main purpose of Kubernetes audit logs?**
- A. To monitor network traffic
- B. To store application logs for debugging
- C. To track changes in resource usage over time
- D. To maintain a record of the sequence of activities affecting the cluster

<details><summary>Answer</summary>

**Correct answer:** D

Audit logs maintain a record of the sequence of API requests and other activities affecting the cluster, which is their main purpose. They do not capture raw network packets, do not by themselves track resource-usage trends over time, and are not a general application debug log.
</details>

---

**Which Kubernetes feature allows you to set policies for logging and monitoring cluster events?**
- A. Service Accounts
- B. Role-Based Access Control (RBAC)
- C. Pod Security Standards
- D. Audit Policies

<details><summary>Answer</summary>

**Correct answer:** D

Audit Policies define which API requests and at what stage they are recorded, which is the feature that lets an operator set logging/monitoring policy for cluster events. RBAC authorizes requests, Pod Security Standards validate Pod configuration, and ServiceAccounts provide identities — none of the three configures what gets audited.
</details>

---

**Which practice most directly reduces the risk that Kubernetes audit and application logs expose sensitive values such as credentials?**
- A. Configure the audit policy and application logging to redact or omit sensitive fields before they are written.
- B. Store logs in local pod storage.
- C. Enable read-only logging mode.
- D. Encrypt all logs with public keys.

<details><summary>Answer</summary>

**Correct answer:** A

Configuring the audit policy's level/field handling and application-side log redaction filters or omits sensitive fields such as credentials before they are ever written to a log, which most directly reduces this exposure. Storing logs in local Pod storage, enabling a read-only logging mode, or encrypting all logs with public keys do not, by themselves, prevent sensitive values from being written into logs in the first place.
</details>

---

**A team enables a NetworkPolicy that denies all ingress to a Pod except from a specific label selector, but traffic from unauthorized Pods is still reaching it. What is the most likely explanation?**
- A. Enabling root access for all containers overrides NetworkPolicy.
- B. The cluster's CNI plugin does not implement NetworkPolicy enforcement, so the policy object exists in the API but has no effect on actual traffic.
- C. Automated container image scanning disabled the policy.
- D. Scaling the cluster automatically bypasses NetworkPolicy.

<details><summary>Answer</summary>

**Correct answer:** B

NetworkPolicy is only enforced if the cluster's CNI plugin implements it; without that support, a policy object can exist in the Kubernetes API while having no actual effect on traffic, which explains the observed behavior. A, C, and D each describe an unrelated mechanism (container privilege, image scanning, and cluster autoscaling) that has no ability to override or bypass NetworkPolicy enforcement.
</details>

---

**What is the primary purpose of implementing Role-Based Access Control (RBAC) in Kubernetes?**
- A. To optimize pod scheduling decisions.
- B. To grant permissions to users and applications.
- C. To define quotas for namespaces.
- D. To manage pod restart policies.

<details><summary>Answer</summary>

**Correct answer:** B

RBAC's primary purpose is to grant specific users, groups, and workload identities permission to perform particular API actions. Optimizing scheduling decisions, defining namespace quotas, and managing Pod restart policies are handled by the scheduler, ResourceQuota, and Pod/container restart policy fields, not RBAC.
</details>

---

**Which Kubernetes resource is used to define permissions in RBAC?**
- A. an unrelated policy object
- B. Secret
- C. Namespace
- D. Role and ClusterRole

<details><summary>Answer</summary>

**Correct answer:** D

Role and ClusterRole are the RBAC resources that define the allowed API verbs and resources — the permission definitions themselves. Namespaces scope names, Secrets store sensitive data, and an unrelated policy object defines none of the RBAC rules.
</details>

---
**Two application teams share one cluster. Which design most directly creates an administrative security boundary rather than merely a naming boundary?**
- A. Disable API-server TLS.
- B. Use separate namespaces with least-privilege RBAC and applicable quotas and NetworkPolicies.
- C. Use a single Service for both teams.
- D. Place both teams in `default` and give both `cluster-admin`.

<details><summary>Answer</summary>

**Correct answer:** B

Separate namespaces paired with least-privilege RBAC and applicable ResourceQuotas/NetworkPolicies create an administrative boundary that is actually enforced, not just a naming convention. Disabling API-server TLS removes protection instead of creating a boundary, sharing one Service does not separate teams, and placing both teams in the `default` namespace with `cluster-admin` removes any boundary entirely.
</details>
---

**An administrator disables the API server's `--anonymous-auth` flag but leaves an overly broad ClusterRoleBinding granting `cluster-admin` to a rarely used ServiceAccount. What security gap remains?**
- A. None; disabling anonymous authentication is sufficient by itself.
- B. The API server will reject all requests until anonymous auth is re-enabled.
- C. Encryption at rest is automatically disabled as a side effect.
- D. Authentication alone does not limit what an authenticated identity can do; the overly broad RBAC grant still allows that ServiceAccount's credential to perform cluster-admin actions if it is ever used or stolen.

<details><summary>Answer</summary>

**Correct answer:** D

Authentication establishes identity, but authorization (RBAC) determines what an authenticated identity may do; disabling anonymous access does not narrow an already-overly-broad RBAC grant, so a compromised or misused ServiceAccount credential with `cluster-admin` remains a serious risk. A is false for the reason just given. B and C describe unrelated or incorrect side effects that do not follow from disabling anonymous authentication.
</details>

---

**What is the primary advantage of encrypting etcd data in Kubernetes?**
- A. Reduced latency for API server requests.
- B. Protection of sensitive cluster configuration data.
- C. Easier integration with third-party tools.
- D. Faster node scaling.

<details><summary>Answer</summary>

**Correct answer:** B

Encrypting etcd at rest protects sensitive Kubernetes state — including Secrets — if the underlying storage media or a backup is exposed to someone without cluster access, which is the primary advantage. It does not reduce API server request latency, scale nodes faster, or ease integration with third-party tools.
</details>

---

**Which Kubernetes feature allows you to encrypt Secrets and other sensitive data at rest?**
- A. Encryption Configuration
- B. Network Policies
- C. Persistent Volumes
- D. an unrelated policy object

<details><summary>Answer</summary>

**Correct answer:** A

The API server's EncryptionConfiguration specifies the providers used to encrypt Secrets and other resources at rest in etcd, which is the feature that provides this capability. NetworkPolicy secures network traffic rather than data at rest, PersistentVolumes provide storage capacity, and an unrelated policy object is not an encryption mechanism.
</details>

---

**Which of the following contributes to Kubernetes compliance with security best practices?**
- A. Regularly updating cluster components.
- B. Allowing privileged containers in all namespaces.
- C. Storing sensitive data directly in environment variables.
- D. Using the default namespace for all workloads.

<details><summary>Answer</summary>

**Correct answer:** A

Regularly updating cluster components applies vendor fixes for discovered vulnerabilities and supports meeting baseline security compliance expectations. Allowing privileged containers everywhere, storing sensitive data directly in environment variables without Secret protections, and placing all workloads in the default namespace all weaken rather than support compliance.
</details>

---

**What built-in mechanism applies Pod Security Standards in current Kubernetes?**
- A. HorizontalPodAutoscaler.
- B. StorageClass.
- C. A ServiceAccount token.
- D. Pod Security Admission using Namespace labels or cluster-wide admission-controller defaults.

<details><summary>Answer</summary>

**Correct answer:** D

Pod Security Admission enforces, audits, or warns on a Pod Security Standard profile either through labels set on a Namespace, or through cluster-wide defaults configured in the admission controller's own configuration (`PodSecurityConfiguration`) when a Namespace has no labels of its own; Namespace labels take precedence over an applicable cluster-wide default where both exist. A HorizontalPodAutoscaler, StorageClass, and ServiceAccount token play no role in applying those standards.
</details>

---

**Which Kubernetes feature can be used to restrict access to a specific namespace?**
- A. an unrelated policy object
- B. ConfigMaps
- C. RoleBinding
- D. Network Policies

<details><summary>Answer</summary>

**Correct answer:** C

A RoleBinding associates a Role, or a ClusterRole, with subjects within one particular namespace, which is how access to that namespace is restricted through RBAC. A ClusterRoleBinding is cluster-scoped and grants a ClusterRole's permissions across the entire cluster, not within a single namespace — a RoleBinding is the object that can still reference a ClusterRole while keeping the grant limited to its own namespace. NetworkPolicy regulates network traffic rather than API access, and ConfigMaps or an unrelated policy object do not grant or restrict permissions at all.
</details>

---

**Which admission-control action best prevents an untrusted image registry from being used?**
- A. A ResourceQuota verifies an image signature.
- B. kube-proxy scans container images.
- C. A validating admission policy rejects workloads whose image is outside approved registries.
- D. A Service changes the image registry.

<details><summary>Answer</summary>

**Correct answer:** C

A validating admission policy can reject a workload before it is created when its image registry is not on an approved list, which most directly prevents use of an untrusted registry. A ResourceQuota does not verify image signatures, kube-proxy only forwards Service traffic and does not scan images, and a Service cannot change which registry an image comes from.
</details>

---

**How can you minimize security risks when using container images in Kubernetes?**
- A. Allow any user to pull images from the cluster.
- B. Use a public image registry for all workloads.
- C. Verify image signatures and scan for vulnerabilities.
- D. Use the latest image tag without verification.

<details><summary>Answer</summary>

**Correct answer:** C

Verifying image signatures establishes that a specific artifact is associated with a trusted signing identity and was not altered afterward, and scanning for vulnerabilities finds known defects before deployment; together these reduce image-related risk, though neither one is the same as provenance (which specifically documents build origin and process) and a signature alone does not prove the absence of vulnerabilities. Allowing any user to pull images, using a public registry for all workloads, and using the `latest` tag without verification all remove rather than add supply-chain safeguards.
</details>

---

**Which of the following is a recommended practice for managing Kubernetes Secrets?**
- A. Use EncryptionConfiguration to encrypt Secrets at rest.
- B. Store Secrets in plaintext YAML files.
- C. Allow unrestricted access to all Secrets.
- D. Share Secrets between multiple namespaces without restrictions.

<details><summary>Answer</summary>

**Correct answer:** A

Using EncryptionConfiguration to encrypt Secrets at rest in etcd is the recommended safeguard for managing Secrets. Storing Secrets in plaintext YAML files, allowing unrestricted access to all Secrets, and sharing Secrets across namespaces without restriction all expose sensitive values instead of protecting them.
</details>

---

**An organization wants audit evidence that specifically shows whether a policy exception granted to a workload was ever actually reviewed and approved by an authorized person, not just recorded automatically by the system. Which type of evidence best supports this?**
- A. A manually signed-off approval record (e.g. a ticket or change record) referencing the exception, retained alongside the automated audit log.
- B. Reduced resource usage by the API server.
- C. Improved scalability for cluster nodes.
- D. Real-time monitoring of pod performance.

<details><summary>Answer</summary>

**Correct answer:** A

Automated audit logging records that an API action occurred and by which identity, but it does not by itself prove that a human reviewed and approved a policy exception — that requires a separate, deliberately retained approval record tied to the exception. B, C, and D describe unrelated operational properties (resource usage, node scalability, and Pod performance monitoring) that have nothing to do with evidencing human review and approval.
</details>

---
**A self-managed control-plane endpoint must be reachable only from an administration subnet before any Kubernetes credentials are evaluated. Which control is most direct?**
- A. A validating admission policy.
- B. RBAC for authenticated API requests.
- C. A firewall, security group, or other control-plane endpoint network restriction.
- D. A NetworkPolicy selecting application Pods.

<details><summary>Answer</summary>

**Correct answer:** C

A firewall, security group, or a managed-service authorized-network setting restricts network reachability to the control-plane endpoint before any Kubernetes credential is even evaluated, which is the most direct control here. RBAC and admission control act only after a request has already reached the API server, and NetworkPolicy normally governs workload-to-workload traffic rather than access to the control-plane endpoint itself.
</details>
---

**A team must provide non-secret application configuration without embedding it in an image. Which Kubernetes object should it use with least-privilege access?**
- A. A Secret exposed to every namespace.
- B. A ConfigMap.
- C. A hostPath volume.
- D. A privileged Pod.

<details><summary>Answer</summary>

**Correct answer:** B

A ConfigMap is the Kubernetes object for holding non-secret application configuration separately from the image, and it can be read under least-privilege access. A Secret should be reserved for sensitive data (and should not be exposed to every namespace), while privileged Pods and hostPath volumes create unnecessary exposure unrelated to configuration delivery.
</details>

---
**A platform wants to admit only an approved container artifact. Which chain provides the strongest integrity decision?**
- A. An immutable digest, signature from a trusted identity, and admission verification.
- B. A local image cache without updates.
- C. A private registry name alone.
- D. A mutable image tag and vulnerability scan.

<details><summary>Answer</summary>

**Correct answer:** A

A private registry name alone only controls where an artifact is stored and distributed from — it does not prove artifact integrity. An immutable digest identifies the exact content, a signature from a trusted identity asserts authenticity, and admission-time verification enforces that the artifact meets policy before the workload is created; together this chain gives the strongest integrity decision. A local unpatched cache and a mutable tag with only a vulnerability scan address different or weaker concerns.
</details>
---

**Which statement about the Controller Manager's own security posture is accurate?**
- A. It requires no credentials because it runs inside the control plane.
- B. Its own client credentials to the API server should be scoped with least privilege, since it can reconcile many cluster-wide resources.
- C. It replaces RBAC for all workload identities.
- D. It is exempt from audit logging.

<details><summary>Answer</summary>

**Correct answer:** B

Because the Controller Manager's controllers can reconcile many cluster-wide resources, its own API credentials should be scoped with least privilege rather than given broad standing access. A: every control-plane component still authenticates with credentials. C: RBAC still governs workload identities separately. D: API requests made by the Controller Manager are still subject to the configured audit policy like any other caller.
</details>

---

**A workload stores credentials on a PersistentVolume backed by network storage. If the underlying storage backend is compromised outside of Kubernetes, what protects the data?**
- A. To replicate data across multiple nodes.
- B. To store pod configurations for scaling purposes.
- C. To provide storage for logs generated by pods.
- D. Whatever encryption-at-rest or access controls the storage backend itself provides; a PersistentVolume abstracts access but does not add its own encryption.

<details><summary>Answer</summary>

**Correct answer:** D

A PersistentVolume abstracts a storage backend so Pods can consume it consistently, but it does not itself add encryption or access control beyond what the underlying backend provides; protection against a backend-level compromise depends on that backend's own encryption-at-rest and access controls. A, B, and C describe unrelated or incorrect functions — a PV is not primarily about cross-node replication, is not a place to store Pod configuration, and is not specifically a log store.
</details>

---

**How does Kubernetes ensure a pod's DNS resolution within the cluster?**
- A. By configuring PodSecurityPolicies.
- B. By using Network Policies.
- C. By using ConfigMaps for IP mapping.
- D. Through kube-dns or CoreDNS services.

<details><summary>Answer</summary>

**Correct answer:** D

CoreDNS (or the legacy, now-superseded kube-dns) provides cluster DNS resolution and service discovery for Pods, which answers how DNS resolution is ensured; kube-dns is historical and CoreDNS is the current default. NetworkPolicy controls traffic rather than resolving names, PodSecurityPolicy (itself removed from current Kubernetes) controls Pod settings, and ConfigMaps are not the cluster's DNS resolver.
</details>

---

**Which workload controller supports a controlled rolling update that can reduce the security risk of replacing vulnerable stateless Pods?**
- A. CronJob.
- B. ConfigMap.
- C. Deployment.
- D. PersistentVolume.

<details><summary>Answer</summary>

**Correct answer:** C

A Deployment manages stateless replicas and supports a controlled rolling update strategy that can replace vulnerable Pods with patched ones while maintaining availability, which addresses this security-relevant update need. A CronJob schedules finite work, a ConfigMap only holds configuration, and a PersistentVolume stores data — none of them performs a rolling update of stateless replicas.
</details>

---

**A security-relevant service caches decryption keys in memory and needs each replica to keep the same identity and its own dedicated persistent volume across restarts, so that a security review can trace exactly which replica handled which data. Which controller fits, and why not the alternative?**
- A. Only StatefulSets can mount PersistentVolumeClaims, so a Deployment cannot be used at all.
- B. A StatefulSet fits, since it gives each replica a stable identity and a distinct PVC per replica; a Deployment could still mount a PVC but does not provide that stable per-replica identity and mapping.
- C. Either fits equally, since Deployments automatically encrypt every PersistentVolume.
- D. Neither fits, since PersistentVolumeClaims cannot be mounted by workloads.

<details><summary>Answer</summary>

**Correct answer:** B

A StatefulSet gives each replica a stable, ordered identity and can provision a distinct PersistentVolumeClaim per replica via a volumeClaimTemplate, which supports the traceability requirement in this scenario; a Deployment can also mount a PVC, but its replicas are interchangeable and do not carry that stable per-replica identity and volume mapping. A and D make false claims about PVC mounting being exclusive to StatefulSets or impossible for workloads in general. C is false — PersistentVolume encryption is never automatic regardless of controller type.
</details>

---

**Which autoscaling control should be paired with resource requests and limits to help a workload scale safely under changing load?**
- A. NetworkPolicy.
- B. ClusterRoleBinding.
- C. HorizontalPodAutoscaler.
- D. ServiceAccount.

<details><summary>Answer</summary>

**Correct answer:** C

HorizontalPodAutoscaler adjusts workload replica counts based on observed CPU, memory, or custom metrics, and should be paired with sensible resource requests/limits to scale safely under load. NetworkPolicy, ClusterRoleBinding, and ServiceAccount provide traffic control, authorization bindings, or identity, not replica scaling.
</details>

---

**A cluster is scaling to absorb a sudden legitimate traffic spike, but new Pods remain `Pending` due to insufficient node capacity, creating an availability risk. Which component can add eligible nodes automatically, if the environment supports it, to help restore capacity?**
- A. Pod Security Admission, since it can approve additional nodes.
- B. An admission webhook, since it can provision infrastructure.
- C. CoreDNS, since it manages cluster scaling internally.
- D. Cluster Autoscaler, which can provision (or remove) eligible nodes in supporting environments when Pods are unschedulable due to capacity.

<details><summary>Answer</summary>

**Correct answer:** D

Cluster Autoscaler is the component that can add or remove eligible nodes in environments that support it, specifically responding to Pods that cannot be scheduled due to insufficient capacity, which directly addresses the availability risk in this scenario. Pod Security Admission validates Pod specifications rather than provisioning nodes, an admission webhook is a request-time hook with no node-provisioning role, and CoreDNS provides cluster DNS resolution, not capacity management.
</details>

---

**Which controller is appropriate for a one-off security scan that runs to completion?**
- A. Job.
- B. CronJob.
- C. DaemonSet.
- D. Deployment.

<details><summary>Answer</summary>

**Correct answer:** A

A Job creates Pods that run until successful completion, matching the requirement for a one-off security scan. A Deployment is meant to run continuously, a CronJob schedules repeated Jobs rather than running once, and a DaemonSet targets nodes continuously rather than completing a single scan.
</details>

---

**Which controller is appropriate for a required node-security agent that should run one Pod on each eligible node?**
- A. DaemonSet.
- B. Service.
- C. Job.
- D. StatefulSet.

<details><summary>Answer</summary>

**Correct answer:** A

A DaemonSet maintains exactly one Pod on every eligible node, including nodes added after the DaemonSet is created, which fits a required per-node security agent. A Service exposes endpoints rather than running Pods, a Job terminates after completion, and a StatefulSet manages ordered per-replica identities rather than guaranteed per-node coverage.
</details>

---

**A set of backend Pods is recreated frequently and gets new Pod IPs each time. Internal callers need one address that keeps working across those recreations. Which Kubernetes object provides that stable address, and how does this relate to NetworkPolicy?**
- A. A Service, which presents a stable virtual network endpoint for callers; NetworkPolicy is independent of this and instead selects Pods directly by label, namespace, or IP block, regardless of any Service.
- B. Ingress, which routes HTTP(S) traffic to Services rather than grouping Pods directly.
- C. A PersistentVolumeClaim, which requests storage rather than providing network identity.
- D. A ConfigMap, which holds configuration data rather than providing network identity.

<details><summary>Answer</summary>

**Correct answer:** A

A Service selects a set of Pods and presents a stable virtual network endpoint that remains consistent even as individual Pods are recreated with new IPs, which is what internal callers need here. NetworkPolicy is a separate mechanism: it selects Pods through `podSelector`, and its peers through `podSelector`/`namespaceSelector` or `ipBlock` — it does not select or depend on a Service at all, and its Pod-label-based matching is already unaffected by Pod IP changes independent of whether a Service exists. Ingress exposes HTTP(S) routes to Services rather than grouping Pods directly, a PersistentVolumeClaim requests storage, and a ConfigMap holds configuration data — none of the three provides this stable network address.
</details>

---

**An Ingress resource for an internal application terminates TLS at the Ingress controller and forwards plaintext HTTP to the backend Pods. What security gap does this configuration leave, if any?**
- A. None; TLS termination at Ingress always protects the entire path to the backend.
- B. It restricts network access between namespaces automatically.
- C. The segment between the Ingress controller and the backend Pods is unencrypted unless separately secured (e.g. via a service mesh or backend TLS).
- D. It manages the deployment of pods on specific nodes.

<details><summary>Answer</summary>

**Correct answer:** C

When an Ingress controller terminates TLS and forwards plaintext HTTP, only the client-to-Ingress segment is encrypted by that TLS; the Ingress-to-backend segment needs its own protection (such as a service mesh with mTLS or separately configured backend TLS) if it must also be encrypted. A is false for the reason just stated. B and D describe unrelated Ingress capabilities — Ingress does not itself restrict cross-namespace traffic or manage Pod-to-node placement.
</details>

---
**What is kube-proxy's KCSA-level responsibility for a Kubernetes Service?**
- A. It implements Service virtual-IP routing rules to endpoints using its configured proxy mode.
- B. It enforces Pod Security Standards.
- C. It encrypts application traffic.
- D. It schedules Pods onto nodes.

<details><summary>Answer</summary>

**Correct answer:** A

kube-proxy implements Service virtual-IP routing to matching endpoints using its configured proxy mode; on Linux, current modes include `iptables`, `nftables`, and the deprecated IPVS mode, with Kubernetes v1.37 defaulting to `iptables`. It does not enforce Pod Security Standards, encrypt application traffic, or schedule Pods onto nodes.
</details>
---

**A security policy selects workloads by `app=payments`. What is the security-relevant purpose of that label?**
- A. It encrypts the Pod filesystem.
- B. It replaces a NetworkPolicy.
- C. It grants API permissions.
- D. It identifies objects for selection by policy and other Kubernetes resources.

<details><summary>Answer</summary>

**Correct answer:** D

The `app=payments` label gives NetworkPolicy, admission policy, and other Kubernetes resources a stable selector for identifying the labeled workloads, which is its security-relevant purpose. Labels do not encrypt a Pod's filesystem, do not by themselves grant API permissions, and cannot substitute for an actual NetworkPolicy's enforcement.
</details>

---

**Which Kubernetes mechanism lets a NetworkPolicy target Pods using their labels?**
- A. A ServiceAccount token.
- B. An annotation.
- C. A ConfigMap.
- D. A selector such as `podSelector`.

<details><summary>Answer</summary>

**Correct answer:** D

A selector such as `podSelector` is the mechanism a NetworkPolicy uses to match Pods by their labels and define the policy's subjects. A ServiceAccount token identifies an API caller, an annotation is non-selecting metadata, and a ConfigMap holds unrelated configuration data — none of them is how NetworkPolicy targets Pods.
</details>

---

**Where should a security team place non-identifying audit metadata that must not be used as a selector?**
- A. A taint.
- B. An annotation.
- C. A label.
- D. A Secret.

<details><summary>Answer</summary>

**Correct answer:** B

Annotations carry non-identifying metadata that does not participate in label selectors, making them the right place for audit metadata that must not be selectable. A label would be selectable by policies (the opposite of the requirement), a Secret is meant for sensitive data rather than descriptive metadata, and a taint influences scheduling rather than storing metadata.
</details>

---

**How should dedicated sensitive nodes be protected from general workloads while requiring a protected workload to run only there?**
- A. Use only a taint, because it guarantees placement.
- B. Use only a toleration, because it guarantees placement.
- C. Taints repel Pods that lack matching tolerations; use labels plus required node affinity for the protected workload.
- D. Add an annotation to the node.

<details><summary>Answer</summary>

**Correct answer:** C

A taint repels Pods that lack a matching toleration, while required node affinity makes the protected workload specifically select the labeled sensitive nodes; combining both achieves the stated goal, since a toleration alone only permits placement without guaranteeing it, and a taint alone does not force the protected workload onto those nodes. Using only a taint or only a toleration, or merely adding a node annotation, does not achieve the combination this scenario requires.
</details>

---

**A security-sensitive workload must run only on nodes that have been specifically hardened and labeled for that purpose, so that a compromised, non-hardened node cannot become a placement target for it. Which mechanism directly enforces this placement requirement?**
- A. Pod annotations, since they can override node restrictions.
- B. Node affinity using an ordinary, unprotected node label, so the workload is only scheduled onto nodes carrying that label.
- C. Configuring kube-proxy to restrict pod placements.
- D. Required node affinity selecting a label under the protected `node-restriction.kubernetes.io/` prefix (enforced by the NodeRestriction admission plugin, which a kubelet cannot self-apply or spoof), combined with that label only being present on genuinely hardened nodes.

<details><summary>Answer</summary>

**Correct answer:** D

Because the threat model here explicitly includes a compromised node, an ordinary node label is not sufficient: a kubelet can self-report or spoof an ordinary label on registration (for example claiming a "hardened" label it does not deserve), which the scheduler would then trust. The `node-restriction.kubernetes.io/` label prefix is specifically reserved so that the NodeRestriction admission plugin blocks a kubelet from setting or modifying labels under that prefix on its own Node object; pairing required node affinity on such a protected label with hardened nodes that legitimately carry it is what actually prevents a compromised, non-hardened node from becoming a placement target. B describes the same node-affinity mechanism but with an ordinary label a compromised kubelet could still spoof, which does not meet this threat model. A: Pod annotations cannot override node-level scheduling restrictions. C: kube-proxy has no role in Pod placement.
</details>

---

**What is the main purpose of Kubernetes Resource Quotas?**
- A. To enforce network access policies between pods.
- B. To define the number of nodes in a cluster.
- C. To scale workloads based on resource availability.
- D. To limit the number of resources a namespace can consume.

<details><summary>Answer</summary>

**Correct answer:** D

A ResourceQuota limits the total amount of resources (and object counts) a namespace can consume in aggregate, which is its main purpose. It does not enforce network access policies, define the number of nodes in a cluster, or scale workloads — those belong to NetworkPolicy, cluster provisioning, and autoscalers respectively.
</details>

---

**A HorizontalPodAutoscaler is configured for a Deployment using a CPU `averageUtilization` percentage target, but the Deployment's containers have no resource `requests` set. What is the most likely consequence?**
- A. The HPA will still scale reliably using default estimated values.
- B. The Deployment will be rejected by the API server at creation.
- C. The HPA cannot compute a meaningful CPU utilization percentage for this target, so scaling decisions based on it become unreliable.
- D. The cluster will automatically add resource requests to prevent this issue.

<details><summary>Answer</summary>

**Correct answer:** C

HorizontalPodAutoscaler calculates `averageUtilization` as a percentage of the configured resource requests; without requests set, there is no baseline to compute that percentage against, making this specific utilization-based scaling target unreliable. This dependency applies to CPU/memory utilization-percentage targets specifically — an HPA using `AverageValue`, or custom/external metrics, does not depend on resource requests in the same way. A is false — there is no reliable default fallback for this calculation. B is false — the API server does not require resource requests for Deployment creation. D is false — Kubernetes does not automatically inject resource requests to fix this.
</details>

---

**A namespace's PersistentVolumeClaim binds to a PersistentVolume that was provisioned for a different, more sensitive workload and still contains its data. What access-control gap does this scenario illustrate?**
- A. PVCs replace PVs when scaling storage.
- B. PVCs are automatically created when pods request storage.
- C. Binding alone does not guarantee the previous data was wiped or that access is scoped correctly; the storage class's reclaim policy and sanitization behavior govern whether old data is removed, while separate RBAC controls govern who may create a PVC that could bind to a given class of volume — these are two distinct concerns, and neither is addressed by resource quota, which governs capacity rather than confidentiality.
- D. PVCs dynamically provision PVs without user intervention.

<details><summary>Answer</summary>

**Correct answer:** C

A PVC binds to a PV to let a Pod consume the requested storage, but binding by itself says nothing about whether previous data was securely wiped or whether the binding is scoped to the intended, authorized workload. Two distinct controls address this: the storage class's reclaim policy and any sanitization step determine whether retained data is actually removed before reuse, while RBAC determines which identities may create PVCs against a given storage class in the first place. `ResourceQuota` is a capacity-governance control (limiting how much storage or how many objects a namespace may consume) and does not address data confidentiality or reuse at all, so it should not be relied on for this gap. A and D make incorrect claims about PVCs replacing PVs or fully eliminating user configuration, and B incorrectly claims PVCs are always automatically created.
</details>

---

**A NetworkPolicy exists in a namespace, but Pods in that namespace can still communicate freely regardless of the policy's rules. What is the most likely explanation?**
- A. The Pods are using a ServiceAccount, which overrides NetworkPolicy.
- B. A RoleBinding in the namespace disables NetworkPolicy.
- C. The cluster's CNI plugin does not implement NetworkPolicy enforcement.
- D. The Pods are using a ConfigMap, which overrides NetworkPolicy.

<details><summary>Answer</summary>

**Correct answer:** C

NetworkPolicy is only enforced if the cluster's CNI plugin implements it; without that support, the policy object exists in the API but has no effect on actual traffic. A ServiceAccount (A) and a ConfigMap (D) have no ability to override NetworkPolicy, and a RoleBinding (B) controls API authorization, not network enforcement.
</details>

---

**Two teams share a cluster and must not be able to read each other's Secrets or Deployments by default. Beyond placing them in separate namespaces, what else is required to actually enforce this?**
- A. Nothing further; separate namespaces alone enforce this by default.
- B. Enabling audit logging for the namespaces.
- C. Increasing each namespace's ResourceQuota.
- D. Least-privilege RBAC scoped to each namespace, since namespace separation alone does not restrict API access across namespaces.

<details><summary>Answer</summary>

**Correct answer:** D

Separate namespaces alone do not restrict which identities can read objects in them; least-privilege RBAC bindings scoped to each namespace are required to actually prevent one team's identities from reading the other team's Secrets or Deployments. A is false for the reason just given. B (audit logging) provides evidence, not prevention. C (ResourceQuota) limits resource consumption, not read access.
</details>

---

**Which statement correctly describes a security implication of using a headless Service with a StatefulSet?**
- A. It automatically encrypts traffic between the StatefulSet's Pods.
- B. It removes the need for any RBAC on the StatefulSet's ServiceAccount.
- C. It disables persistent storage for the StatefulSet.
- D. It gives each Pod a stable, individually addressable DNS identity, which can affect how access controls and monitoring should be scoped per replica.

<details><summary>Answer</summary>

**Correct answer:** D

A headless Service used with a StatefulSet gives each Pod a stable, individually addressable DNS name, which is relevant when scoping access controls, monitoring, or per-replica policy, since replicas are individually identifiable rather than interchangeable. A, B, and C describe capabilities the headless Service does not provide: it does not encrypt traffic, does not remove the need for RBAC, and has no effect on persistent storage.
</details>

---

**A DaemonSet-deployed node-monitoring agent requires access to host-level metrics but should not be granted unnecessary Kubernetes API permissions. What is the appropriate control?**
- A. Grant the agent's ServiceAccount `cluster-admin` to avoid permission errors.
- B. Bind the agent's ServiceAccount to a Role or ClusterRole containing only the specific verbs and resources it needs.
- C. Disable RBAC for the DaemonSet's namespace.
- D. Give the agent `automountServiceAccountToken` on every unrelated ServiceAccount in the cluster.

<details><summary>Answer</summary>

**Correct answer:** B

Binding the agent's ServiceAccount to a Role or ClusterRole containing only the specific verbs and resources it actually needs applies least privilege to a component that otherwise needs broad node-level visibility. A grants far more than necessary, C removes authorization checks entirely, and D is both irrelevant and would expose unrelated ServiceAccount tokens unnecessarily.
</details>

---

**A `Service` of type `ClusterIP` selects a set of Pods and uses the default Service behavior (`publishNotReadyAddresses` is not set to `true`). If none of the selected Pods are ready, what happens to traffic sent to the Service?**
- A. The traffic is automatically redirected to a different Service.
- B. The traffic is automatically encrypted and queued indefinitely.
- C. The traffic has no ready endpoint to reach, since kube-proxy only routes to endpoints backed by ready Pods under default Service behavior.
- D. The Service automatically restarts the unready Pods.

<details><summary>Answer</summary>

**Correct answer:** C

Under default Service behavior, kube-proxy routes traffic only to endpoints that current `EndpointSlice` conditions mark as usable (the `ready` condition being the primary one Kubernetes derives from Pod readiness; `EndpointSlice` also tracks `serving` and `terminating` conditions for more precise handling of Pods during termination). If no selected Pod is ready, there is no usable endpoint for kube-proxy to route traffic to, so requests fail to reach a backend. (Setting `publishNotReadyAddresses: true` on the Service changes this by publishing not-ready Pods as endpoints too, which is why the default-behavior assumption matters here.) A and B describe behaviors a Service does not have (it does not redirect to a different Service, nor queue traffic), and D is incorrect because a Service does not restart Pods — that is a different mechanism (e.g. liveness probes trigger kubelet-managed restarts).
</details>

---

**Which controller is appropriate for a recurring scheduled compliance scan?**
- A. CronJob.
- B. ReplicaSet.
- C. DaemonSet.
- D. StatefulSet.

<details><summary>Answer</summary>

**Correct answer:** A

A CronJob creates Jobs on a defined schedule, matching the need for a recurring compliance scan. A ReplicaSet only maintains a replica count, and a StatefulSet or DaemonSet are long-running controllers rather than schedule-driven finite work.
</details>

---
**A namespace must prevent the combined CPU and memory requests/limits of all team workloads from exceeding an agreed tenant budget. Which control is most direct?**
- A. `LimitRange` alone.
- B. Taints and tolerations.
- C. Node affinity.
- D. `ResourceQuota`.

<details><summary>Answer</summary>

**Correct answer:** D

`ResourceQuota` limits the combined CPU, memory, and object usage of all workloads within a namespace against an aggregate budget, which is the most direct control for this scenario. `LimitRange` alone governs individual object defaults, minimums, and maximums rather than an aggregate namespace-wide budget, and taints/tolerations or node affinity affect scheduling, not resource budgets.
</details>
---

**Which statement about the difference between a ConfigMap and a Secret is accurate?**
- A. Both are Kubernetes API objects, but a Secret is intended for sensitive data and a ConfigMap is not, and neither is encrypted at rest by default without separate configuration.
- B. A ConfigMap is always encrypted, while a Secret is never encrypted.
- C. A Secret is a type of ConfigMap with a different label.
- D. A ConfigMap can hold sensitive credentials as safely as a Secret.

<details><summary>Answer</summary>

**Correct answer:** A

Both ConfigMap and Secret are Kubernetes API objects; a Secret is intended for sensitive values while a ConfigMap is meant for non-sensitive configuration, and neither is automatically encrypted at rest unless EncryptionConfiguration is separately configured. RBAC applies to ConfigMaps just as it does to Secrets — the distinction is not about access control being absent for ConfigMaps, but about intended data sensitivity and the additional security-specific handling conventions (such as being the default target for at-rest encryption and stricter review practices) that apply to Secrets. B and C misstate the relationship and default encryption behavior, and D is false because using a ConfigMap for credentials skips those Secret-specific handling conventions.
</details>

---

**A team wants to verify, after the fact, exactly which identity deleted a specific ClusterRole and when. Which Kubernetes feature provides this evidence?**
- A. ReplicaSet
- B. Kubernetes API server audit logging
- C. Horizontal Pod Autoscaler
- D. PodSecurityPolicies

<details><summary>Answer</summary>

**Correct answer:** B

Kubernetes API server audit logging records API requests, including the identity of the caller, the verb performed, and the affected object, which is exactly the evidence needed to determine who deleted a ClusterRole and when. A ReplicaSet manages replica counts, a HorizontalPodAutoscaler adjusts replica counts from metrics, and PodSecurityPolicy is removed from current Kubernetes — none of the three provides this kind of forensic evidence.
</details>

---

**Which statement correctly describes isolation at the Pod boundary?**
- A. Containers in a Pod are isolated from each other by separate network namespaces.
- B. NetworkPolicy creates a separate network namespace for every container in a Pod.
- C. Sharing a Pod network namespace prevents containers from communicating.
- D. A Pod is an isolation boundary from other Pods, but its containers intentionally share its network namespace and can communicate over localhost.

<details><summary>Answer</summary>

**Correct answer:** D

A Pod is an isolation boundary relative to other Pods, but the containers inside one Pod deliberately share that Pod's network namespace and can communicate with each other over localhost, which is the accurate statement about Pod-boundary isolation. Containers within a Pod are not isolated from each other by separate network namespaces, NetworkPolicy operates at the Pod level rather than creating per-container namespaces, and sharing a network namespace enables rather than prevents intra-Pod communication.
</details>

---

**Which framework helps a team map known adversary tactics and techniques to Kubernetes detections and mitigations?**
- A. ResourceQuota.
- B. MITRE ATT&CK for Containers.
- C. CoreDNS.
- D. Pod Security Admission.

<details><summary>Answer</summary>

**Correct answer:** B

MITRE ATT&CK for Containers organizes known adversary tactics and techniques specific to containerized environments, helping teams map them to detections and mitigations, which is the framework described here. ResourceQuota, CoreDNS, and Pod Security Admission manage resource limits, name resolution, and admission control respectively, not adversary technique mapping.
</details>
