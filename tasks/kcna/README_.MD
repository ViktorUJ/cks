**What native runtime is Open Container Initiative (OCI) compliant?**  
A. runC  
B. runV  
C. kata-containers  
D. gvisor

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**Which API object is the recommended way to run a scalable, stateless application on your cluster?**  
A. ReplicaSet  
B. Deployment  
C. DaemonSet  
D. Pod

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**A CronJob is scheduled to run by a user every one hour. What happens in the cluster when it's time for this CronJob to run?**  
A. Kubelet watches API Server for CronJob objects. When it's time for a Job to run, it runs the Pod directly.  
B. Kube-scheduler watches API Server for CronJob objects, and this is why it's called kube-scheduler.  
C. CronJob controller component creates a Pod and waits until it finishes to run.  
D. CronJob controller component creates a Job. Then the Job controller creates a Pod and waits until it finishes to run.

<details><summary>Answer</summary>
  
**Correct answer:** D
</details>

---

**What is the purpose of the kubelet component within a Kubernetes cluster?**  
A. A dashboard for Kubernetes Clusters that allows management and troubleshooting of applications.  
B. A network proxy that runs on each node in your cluster, implementing part of the Kubernetes Service concept.  
C. A component that watches for newly created Pods with no assigned node, and selects a node for them to run on.  
D. An agent that runs on each node in the cluster. It makes sure that containers are running in a Pod.

<details><summary>Answer</summary>
  
**Correct answer:** D
</details>

---

**What is the default value for authorization-mode in Kubernetes API server?**  
A. --authorization-mode=RBAC  
B. --authorization-mode=AlwaysAllow  
C. --authorization-mode=AlwaysDeny  
D. --authorization-mode=ABAC

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**Let's assume that an organization needs to process large amounts of data in bursts, on a cloud-based Kubernetes cluster. For instance: each Monday morning, they need to run a batch of 1000 compute jobs of 1 hour each, and these jobs must be completed by Monday night. What's going to be the most cost-effective method?**  
A. Run a group of nodes with the exact required size to complete the batch on time, and use a combination of taints, tolerations, and nodeSelectors to reserve these nodes to the batch jobs.  
B. Leverage the Kubernetes Cluster Autoscaler to automatically start and stop nodes as they're needed.  
C. Commit to a specific level of spending to get discounted prices (with e.g. “reserved instances” or similar mechanisms).  
D. Use PriorityСlasses so that the weekly batch job gets priority over other workloads running on the cluster, and can be completed on time.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**What is a Kubernetes service with no cluster IP address called?**  
A. Headless Service  
B. Nodeless Service  
C. IPLess Service  
D. Specless Service

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---

**CI/CD stands for:**  
A. Continuous Information / Continuous Development  
B. Continuous Integration / Continuous Development  
C. Cloud Integration / Cloud Development  
D. Continuous Integration / Continuous Deployment

<details><summary>Answer</summary>
  
**Correct answer:** D
</details>

---

**What default level of protection is applied to the data in Secrets in the Kubernetes API?**  
A. The values use AES Symmetric Encryption  
B. The values are stored in plain text  
C. The values are encoded with SHA256 hashes  
D. The values are base64 encoded

<details><summary>Answer</summary>
  
**Correct answer:** D
</details>

---

**What function does kube-proxy provide to a cluster?**  
A. Implementing the Ingress resource type for application traffic.  
B. Forwarding data to the correct endpoints for Services.  
C. Managing data egress from the cluster nodes to the network.  
D. Managing access to the Kubernetes API.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**How long should a stable API element in Kubernetes be supported (at minimum) after deprecation?**  
A. 9 months  
B. 24 months  
C. 12 months  
D. 6 months

<details><summary>Answer</summary>
  
**Correct answer:** C
</details>

---

**What is the name of the lightweight Kubernetes distribution built for IoT and edge computing?**  
A. OpenShift  
B. k3s  
C. RKE  
D. k1s

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Kubernetes ___ allows you to automatically manage the number of nodes in your cluster to meet demand.**  
A. Node Autoscaler  
B. Cluster Autoscaler  
C. Horizontal Pod Autoscaler  
D. Vertical Pod Autoscaler

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which of the following statements is correct concerning Open Policy Agent (OPA)?**  
A. The policies must be written in Python language.  
B. Kubernetes can use it to validate requests and apply policies.  
C. Policies can only be tested when published.  
D. It cannot be used outside Kubernetes.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**In a cloud native world, what does the IaC abbreviation stands for?**  
A. Infrastructure and Code  
B. Infrastructure as Code  
C. Infrastructure above Code  
D. Infrastructure across Code

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**In which framework do the developers no longer have to deal with capacity, deployments, scaling and fault tolerance, and OS?**  
A. Docker Swam  
B. Kubernetes  
C. Mesos  
D. Serverless

<details><summary>Answer</summary>
  
**Correct answer:** D
</details>

---

**Which of the following characteristics is associated with container orchestration?**  
A. Application message distribution  
B. Dynamic scheduling  
C. Deploying application JAR files  
D. Virtual Machine distribution

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>

---

**Which of the following workload require a headless service while deploying into the namespace?**  
A. StatefulSet  
B. CronJob  
C. Deployment  
D. DaemonSet

<details><summary>Answer</summary>
  
**Correct answer:** A
</details>

---


**What is Helm?**  
- A. An open source dashboard for Kubernetes.  
- B. A package manager for Kubernetes applications.  
- C. A custom scheduler for Kubernetes.  
- D. An end to end testing project for Kubernetes applications.

<details><summary>Answer</summary>
  
**Correct answer:** B
</details>