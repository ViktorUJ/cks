What native runtime is Open Container Initiative (OCI) compliant?

A. runC 
B. runV
C. kata-containers
D. gvisor

Answer: A

---

Which API object is the recommended way to run a scalable, stateless application on your cluster?

A. ReplicaSet
B. Deployment
C. DaemonSet
D. Pod

Answer: B

---
A CronJob is scheduled to run by a user every one hour. What happens in the cluster when it's time for this CronJob to run?

A. Kubelet watches API Server for CronJob objects. When it's time for a Job to run, it runs the Pod directly.
B. Kube-scheduler watches API Server for CronJob objects, and this is why it's called kube-scheduler.
C. CronJob controller component creates a Pod and waits until it finishes to run.
D. CronJob controller component creates a Job. Then the Job controller creates a Pod and waits until it finishes to run.

Answer: D

---
What is the purpose of the kubelet component within a Kubernetes cluster?

A. A dashboard for Kubernetes Clusters that allows management and troubleshooting of applications.
B. A network proxy that runs on each node in your cluster, implementing part of the Kubernetes Service concept.
C. A component that watches for newly created Pods with no assigned node, and selects a node for them to run on.
D. An agent that runs on each node in the cluster. It makes sure that containers are running in a Pod.

Answer: D

---

What is the default value for authorization-mode in Kubernetes API server?

A. --authorization-mode=RBAC
B. --authorization-mode=AlwaysAllow
C. --authorization-mode=AlwaysDeny
D. --authorization-mode=ABAC

Answer: A

---

Let's assume that an organization needs to process large amounts of data in bursts, on a cloud-based Kubernetes cluster. For instance: each Monday morning, they need to run a batch of 1000 compute jobs of 1 hour each, and these jobs must be completed by Monday night. What's going to be the most cost-effective method?

A. Run a group of nodes with the exact required size to complete the batch on time, and use a combination of taints, tolerations, and nodeSelectors to reserve these nodes to the batch jobs.
B. Leverage the Kubernetes Cluster Autoscaler to automatically start and stop nodes as they're needed.
C. Commit to a specific level of spending to get discounted prices (with e.g. “reserved instances” or similar mechanisms).
D. Use PriorityСlasses so that the weekly batch job gets priority over other workloads running on the cluster, and can be completed on time.

Answer: B

---
What is a Kubernetes service with no cluster IP address called?

A. Headless Service
B. Nodeless Service
C. IPLess Service
D. Specless Service

Answer: A

---

CI/CD stands for:

A. Continuous Information / Continuous Development
B. Continuous Integration / Continuous Development
C. Cloud Integration / Cloud Development
D. Continuous Integration / Continuous Deployment

Answer: D

---

What default level of protection is applied to the data in Secrets in the Kubernetes API?

A. The values use AES Symmetric Encryption
B. The values are stored in plain text
C. The values are encoded with SHA256 hashes
D. The values are base64 encoded

Answer: D

---

What function does kube-proxy provide to a cluster?

A. Implementing the Ingress resource type for application traffic.
B. Forwarding data to the correct endpoints for Services.
C. Managing data egress from the cluster nodes to the network.
D. Managing access to the Kubernetes API.
 
Answer: B

---

How long should a stable API element in Kubernetes be supported (at minimum) after deprecation?

A. 9 months
B. 24 months
C. 12 months
D. 6 months

Answer: C

---

What is the name of the lightweight Kubernetes distribution built for IoT and edge computing?

A. OpenShift
B. k3s
C. RKE
D. k1s

Answer: B

---

Kubernetes ___ allows you to automatically manage the number of nodes in your cluster to meet demand.

A. Node Autoscaler
B. Cluster Autoscaler
C. Horizontal Pod Autoscaler
D. Vertical Pod Autoscaler

Answer: B

---

Which of the following statements is correct concerning Open Policy Agent (OPA)?

A. The policies must be written in Python language.
B. Kubernetes can use it to validate requests and apply policies.
C. Policies can only be tested when published.
D. It cannot be used outside Kubernetes.

Answer: B

---

In a cloud native world, what does the IaC abbreviation stands for?

A. Infrastructure and Code
B. Infrastructure as Code
C. Infrastructure above Code
D. Infrastructure across Code

Answer: B

---

In which framework do the developers no longer have to deal with capacity, deployments, scaling and fault tolerance, and OS?

A. Docker Swam
B. Kubernetes
C. Mesos
D. Serverless

Answer: D

---

Which of the following characteristics is associated with container orchestration?

A. Application message distribution
B. Dynamic scheduling
C. Deploying application JAR files
D. Virtual Machine distribution

Answer: B

---

Which of the following workload require a headless service while deploying into the namespace?

A. StatefulSet
B. CronJob
C. Deployment
D. DaemonSet

Answer: A

---

######


What is Helm?

A. An open source dashboard for Kubernetes.
B. A package manager for Kubernetes applications.
C. A custom scheduler for Kubernetes.
D. An end to end testing project for Kubernetes applications.

Answer: B

---

Which is the correct kubectl command to display logs in real time?

A. kubectl logs -p test-container-1
B. kubectl logs -c test-container-1
C. kubectl logs -l test-container-1
D. kubectl logs -f test-container-1

Answer: D

---

How to load and generate data required before the Pod startup?

A. Use an init container with shared file storage.
B. Use a PVC volume.
C. Use a sidecar container with shared volume.
D. Use another pod with a PVC.

Answer: A

---

What is the core functionality of GitOps tools like Argo CD and Flux?

A. They track production changes made by a human in a Git repository and generate a human-readable audit trail.
B. They replace human operations with an agent that tracks Git commands.
C. They automatically create pull requests when dependencies are outdated.
D. They continuously compare the desired state in Git with the actual production state and notify or act upon differences.

Answer: D

---

Which Kubernetes resource workload ensures that all (or some) nodes run a copy of a Pod?

A. ReplicaSet
B. StatefulSet
C. DaemonSet
D. Deployment

Answer: C

---

We can extend the Kubernetes API with Kubernetes API Aggregation Layer and CRDs. What is CRD?

A. Custom Resource Definition
B. Custom Restricted Definition
C. Customized RUST Definition
D. Custom RUST Definition

Answer: A

---

The Kubernetes project work is carried primarily by SIGs. What does SIG stand for?

A. Special Interest Group
B. Software Installation Guide
C. Support and Information Group
D. Strategy Implementation Group

Answer: A

---

What is the order of 4C’s in Cloud Native Security, starting with the layer that a user has the most control over?

A. Cloud -> Container -> Cluster -> Code
B. Container -> Cluster -> Code -> Cloud
C. Cluster -> Container -> Code -> Cloud
D. Code -> Container -> Cluster -> Cloud

Answer: D

---

Which group of container runtimes provides additional sandboxed isolation and elevated security?

A. rune, cgroups
B. docker, containerd
C. runsc, kata
D. crun, cri-o

Answer: C

---

What is the common standard for Service Meshes?

A. Service Mesh Specification (SMS)
B. Service Mesh Technology (SMT)
C. Service Mesh Interface (SMI)
D. Service Mesh Function (SMF)

Answer: C

---

Which statement about Ingress is correct?

A. Ingress provides a simple way to track network endpoints within a cluster.
B. Ingress is a Service type like NodePort and ClusterIP.
C. Ingress is a construct that allows you to specify how a Pod is allowed to communicate.
D. Ingress exposes routes from outside the cluster to services in the cluster.

Answer: D

---

What best describes cloud native service discovery?

A. It's a mechanism for applications and microservices to locate each other on a network.
B. It's a procedure for discovering a MAC address, associated with a given IP address.
C. It's used for automatically assigning IP addresses to devices connected to the network.
D. It's a protocol that turns human-readable domain names into IP addresses on the Internet.

Answer: A

---

Which storage operator in Kubernetes can help the system to self-scale, self-heal, etc?

A. Rook
B. Kubernetes
C. Helm
D. Container Storage Interface (CSI)

Answer: A

---

What fields must exist in any Kubernetes object (e.g. YAML) file?

A. apiVersion, kind, metadata
B. kind, namespace, data
C. apiVersion, metadata, namespace
D. kind, metadata, data

Answer: A

---

Which of the following would fall under the responsibilities of an SRE?

A. Developing a new application feature.
B. Creating a monitoring baseline for an application.
C. Submitting a budget for running an application in a cloud.
D. Writing policy on how to submit a code change.

Answer: B

---

What are the initial namespaces that Kubernetes starts with?

A. default, kube-system, kube-public, kube-node-lease
B. default, system, kube-public
C. kube-default, kube-system, kube-main, kube-node-lease
D. kube-default, system, kube-main, kube-primary

Answer: A

---

What is a probe within Kubernetes?

A. A monitoring mechanism of the Kubernetes API.
B. A pre-operational scope issued by the kubectl agent.
C. A diagnostic performed periodically by the kubelet on a container.
D. A logging mechanism of the Kubernetes API.

Answer: C

---

Which Kubernetes feature would you use to guard against split brain scenarios with your distributed application?

A. Replication controllers
B. Consensus protocols
C. Rolling updates
D. StatefulSet

Answer: [D](https://kubernetes.io/docs/tasks/run-application/force-delete-stateful-set-pod/#:~:text=split%20brain%20scenario%20in%20quorum%2Dbased%20systems)  

---

What feature must a CNI support to control specific traffic flows for workloads running in Kubernetes?

A. Border Gateway Protocol
B. IP Address Management
C. Pod Security Policy
D. Network Policies

Answer: D

---

What is the main role of the Kubernetes DNS within a cluster?

A. Acts as a DNS server for virtual machines that are running outside the cluster.
B. Provides a DNS as a Service, allowing users to create zones and registries for domains that they own.
C. Allows Pods running in dual stack to convert IPv6 calls into IPv4 calls.
D. Provides consistent DNS Names for Pods and Services for workloads that need to communicate with each other.

Answer: D

---

Scenario: You have a Kubernetes cluster hosted in a public cloud provider. When trying to create a Service of type LoadBalancer, the external-ip is stuck in the "Pending" state. Which Kubernetes component is failing in this scenario?

A. Cloud Controller Manager
B. Load Balancer Manager
C. Cloud Architecture Manager
D. Cloud Load Balancer Manager

Answer: A

---

