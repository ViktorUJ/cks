**What is a primary security advantage of using a cloud provider’s managed Kubernetes service?**  
- A. Automatic scaling of CPU and memory resources.  
- B. Built-in integration with developer IDE tools.  
- C. Regular security patching and updates.  
- D. Unlimited data storage capacities.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which of the following is a recommended practice to secure Kubernetes infrastructure on a cloud provider?**  
- A. Utilize public container images from unverified sources.  
- B. Regularly audit and apply Kubernetes security patches.  
- C. Enable anonymous access to Kubernetes API endpoints.  
- D. Run all pods with root privileges by default.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which of the following is a primary purpose of security controls in a Kubernetes environment?**  
- A. To automate deployment processes.  
- B. To manage network traffic between pods.  
- C. To ensure compliance with legal and regulatory requirements.  
- D. To provide user authentication and authorization.

<details><summary>Answer</summary>
  
**Correct answer:** C, D
</details>

---

**Which of the following are well-known frameworks used for security management in cloud-native environments?**  
- A. OWASP  
- B. HIPAA  
- C. MITRE ATTACK  
- D. PCI DSS

<details><summary>Answer</summary>
  
**Correct answer:** A, C
</details>

---

**Which of the following is not one of the 4Cs of Cloud Native Security?**  
- A. Code  
- B. Culture  
- C. Cloud  
- D. Cluster  
- E. Container  

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**In the context of the 4Cs of Cloud Native Security, what does the “Cluster” focus on?**  
- A. Securing interactions with external APIs.  
- B. Managing container runtime vulnerabilities.  
- C. Protecting the infrastructure that the applications run on.  
- D. Implementing continuous integration pipelines.  

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**What is a namespace in Kubernetes used for?**  
- A. Installing additional software packages.  
- B. Isolating resources within a cluster.  
- C. Managing storage volumes.  
- D. Running scheduled tasks.  

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which of the following is a technique to provide isolation for applications running within Kubernetes?**  
- A. Network policies.  
- B. Storage classes.  
- C. Replica sets.  
- D. Persistent volumes.  

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**Which of the following practices enhance container image security?**  
- A. Using the latest version of images without verification.  
- B. Setting up image vulnerability scanning.  
- C. Allowing images from any public repository.  
- D. Identifying a trusted source for base images.  

<details><summary>Answer</summary>
  
**Correct answer:** B, D
</details>

---

**What is a key benefit of using an artifact repository in a Kubernetes environment?**  
- A. It allows for storing logs from the Kubernetes clusters.  
- B. It helps improve the security and integrity of deployment artifacts.  
- C. It provides automatic scaling of Kubernetes nodes.  
- D. It facilitates communication between microservices.  

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What is an effective method for securing application code in Kubernetes?**  
- A. Using integrated development environments (IDEs).  
- B. Implementing code reviews and static analysis tools.  
- C. Running applications with root privileges.  
- D. Disabling network encryption.  

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which approach enhances workload security in Kubernetes clusters?**  
- A. Deploying all applications in the default namespace.  
- B. Regularly applying security patches and updates to container images.  
- C. Using privileged containers for all applications.  
- D. Allowing unrestricted network access to pods.  

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which of the following can be used to secure communication between the API Server and other Kubernetes components?**  
- A. Network policies.  
- B. TLS certificates.  
- C. iptables configuration.  
- D. Role-based access control.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What mechanism does the Kubernetes API Server use to authenticate user requests?**  
- A. API Tokens.  
- B. Username and password.  
- C. SSH keys.  
- D. OAuth tokens.

<details><summary>Answer</summary>
  
**Correct answer:** A, D
</details>

---

**What function does the Kubernetes Controller Manager serve in maintaining desired state configurations?**  
- A. It handles communication between Pods.  
- B. It manages routine tasks such as node health checks and replication.  
- C. It provides a web interface for monitoring cluster resources.  
- D. It allows direct configuration of the cluster’s network policies.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which security measure is essential for protecting the Kubernetes Controller Manager?**  
- A. Enabling Role-Based Access Control (RBAC) for API authorization.  
- B. Using a firewall to block all external traffic to nodes.  
- C. Running the Controller Manager on a separate physical server.  
- D. Disabling all logging mechanisms to minimize data exposure.

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**What is the primary function of the Kubernetes Scheduler in a cluster?**  
- A. To manage network policies.  
- B. To control access to the Kubernetes API.  
- C. To assign Pods to nodes based on resource availability and constraints.  
- D. To store and manage container images.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which of the following contributes to Kubernetes Scheduler’s decision when determining node assignment for a Pod?**  
- A. Node’s label selectors that match the Pod’s node affinity.  
- B. Network bandwidth usage across the nodes.  
- C. Pod’s image pull policy.  
- D. Node’s hardware specifications that match the Pod’s requests.

<details><summary>Answer</summary>
  
**Correct answer:** A, D
</details>

---

**Which of the following options helps enhance the security of the Kubelet on a Kubernetes node?**  
- A. Running the Kubelet under a non-root user account.  
- B. Enabling the read-only port.  
- C. Configuring API Server authentication.  
- D. Using TLS for Kubelet API server communication.

<details><summary>Answer</summary>
  
**Correct answer:** A, D
</details>

---

**What is a potential security risk if the Kubelet’s anonymous-auth is enabled?**  
- A. Unauthorized access to sensitive data on the node.  
- B. Increased latency in pod scheduling.  
- C. Debugging and troubleshooting becomes easier.  
- D. Enhancing cluster performance by offloading tasks to the node.

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**What role does the container runtime play in Kubernetes?**  
- A. It manages the cluster networking.  
- B. It schedules pods and other workloads.  
- C. It starts and stops containers on a node.  
- D. It provides persistent storage services.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which of the following is a common container runtime used in Kubernetes?**  
- A. Syslog  
- B. CRI-O  
- C. HDFS  
- D. Nagios

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What is the primary role of KubeProxy in a Kubernetes cluster?**  
- A. To manage network storage volumes.  
- B. To schedule pod placement on nodes.  
- C. To manage network access for services/interfaces.  
- D. To deploy applications automatically.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which of the following is a key security concern related to KubeProxy?**  
- A. Ensuring communication encryption between nodes.  
- B. Controlling access to the Kubernetes API server.  
- C. Securing service accounts used by proxy services.  
- D. Managing access controls for network policies.

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**Which of the following is a primary security concern for pods in a Kubernetes cluster?**  
- A. Version compatibility with the operating system.  
- B. Network latency between nodes.  
- C. Container vulnerabilities and privilege escalation.  
- D. The graphical user interface performance.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**How can you implement security controls to restrict the actions of pods in a Kubernetes cluster?**  
- A. By using Network Policies to control pod communication.  
- B. By configuring persistent volume claims.  
- C. By setting high availability for the scheduler.  
- D. By encrypting the kube-proxy logs.

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**Which of the following best describes the role of etcd in a Kubernetes cluster?**  
- A. It serves as the user interface for managing containers.  
- B. It is a database that stores the cluster configuration and state.  
- C. It acts as the scheduler for deploying resources in a cluster.  
- D. It functions as the network load balancer.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**How can you secure etcd data to prevent unauthorized access in a Kubernetes cluster?**  
- A. By deploying etcd on the same node as the kubelet.  
- B. By enabling HTTP communication between Kubernetes components and etcd.  
- C. By configuring etcd to use TLS encryption for data in transit.  
- D. By restricting etcd access to only the master nodes.

<details><summary>Answer</summary>
  
**Correct answer:** C, D
</details>

---

**Which of the following is a primary security concern when using persistent storage in Kubernetes?**  
- A. Storage performance degradation.  
- B. Unauthorized access to sensitive data.  
- C. Lack of storage capacity.  
- D. High storage costs.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**How can Kubernetes Secrets improve the security of storage configurations within a cluster?**  
- A. By enhancing data encryption.  
- B. By providing a mechanism to store sensitive information, like passwords, in a secure manner.  
- C. By increasing storage space.  
- D. By improving the speed of data retrieval.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What is the purpose of Kubernetes Pod Security Standards?**  
- A. To restrict the version of Kubernetes that can be used.  
- B. To provide guidelines for the isolation of Kubernetes workloads to protect the system from malicious pods.  
- C. To ensure that only certain container registries can be used.  
- D. To specify which Kubernetes resources can be accessed by nodes.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which of the following is a valid enforcement level in Kubernetes Pod Security Standards?**  
- A. Restricted  
- B. Basic  
- C. Closed  
- D. Enforced

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**Which of the following accurately describes the role of Pod Security Admissions in Kubernetes?**  
- A. They are responsible for scheduling pods to appropriate nodes.  
- B. They enforce policies that dictate what pods can run and how they can operate within a cluster.  
- C. They manage the lifecycle of Kubernetes nodes.  
- D. They handle communication between pods.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What is a primary benefit of using Pod Security Admissions in a Kubernetes environment?**  
- A. They improve the efficiency of networking between pods.  
- B. They ensure compliance with organizational security policies by controlling pod-level access and operations.  
- C. They facilitate the dynamic scaling of pods based on resource usage.  
- D. They provide automatic updates to the Kubernetes version used in the cluster.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What is the primary purpose of a Kubernetes ServiceAccount?**  
- A. To monitor network traffic.  
- B. To authenticate nodes to the API server.  
- C. To grant permissions to applications running in a pod.  
- D. To authenticate external users to the cluster.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which authentication method allows Kubernetes to integrate with an external identity provider?**  
- A. Client certificates.  
- B. Service Accounts.  
- C. Integrating with OIDC (OpenID Connect).  
- D. Static Bearer Token.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which of the following Kubernetes components is responsible for making authorization decisions?**  
- A. API Server  
- B. Scheduler  
- C. Controller Manager  
- D. Kubelet

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**In Kubernetes, which of these is a role-based access control (RBAC) component?**  
- A. ClusterRole  
- B. PodSecurityPolicy  
- C. ServiceAccount  
- D. Namespace

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**What is the primary purpose of Kubernetes Secrets?**  
- A. To store sensitive information such as passwords, tokens, and keys.  
- B. To monitor the health of Kubernetes nodes.  
- C. To provide high availability for pods.  
- D. To configure network policies for namespaces.

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**How can Kubernetes Secrets enhance security compared to storing sensitive data directly in environment variables?**  
- A. They offer encryption at rest.  
- B. They provide automatic backup of sensitive data.  
- C. They allow granular access controls to sensitive information.  
- D. They integrate with third-party identity providers.

<details><summary>Answer</summary>
  
**Correct answer:** A, C
</details>

---

**Which Kubernetes feature can be used to limit the scope and traffic within certain namespaces to enhance isolation?**  
- A. Network Policies  
- B. ConfigMaps  
- C. Persistent Volumes  
- D. Node Selectors

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**What is the primary benefit of using Kubernetes namespaces for isolation and segmentation in a cluster?**  
- A. They provide high availability for applications.  
- B. They allow you to create new API objects.  
- C. They enable resource and access constraints within a cluster.  
- D. They speed up pod deployment.

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**Which Kubernetes component is primarily responsible for storing audit logs?**  
- A. kube-scheduler  
- B. etcd  
- C. kube-apiserver  
- D. kube-controller-manager

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**What is the main purpose of Kubernetes audit logs?**  
- A. To monitor network traffic  
- B. To track changes in resource usage over time  
- C. To maintain a record of the sequence of activities affecting the cluster
