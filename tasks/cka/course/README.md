[Русская версия](README_RU.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md) · [日本語版](README_JP.md)

# CKA + CKAD: a practical self-study guide to Kubernetes

A joint practical course for a preparation for two certifications of CNCF and Linux
Foundation at the same time:

- **CKA** (Certified Kubernetes Administrator) - an administration of a cluster:
  an installation, a maintenance, a network, the storages, a security, a troubleshooting.
- **CKAD** (Certified Kubernetes Application Developer) - a development and a running
  of the applications in Kubernetes: the workloads, a configuration, an observability,
  the services.

The exams overlap a lot (the workloads, the services, a configuration, the storages,
an observability), so it is more efficient to study them together than separately. A
common core is covered once, and the specifics of each exam are moved into separate parts.
The course is tied to the labs in `tasks/cka/labs`.

> **A version of Kubernetes.** The course is aimed at an actual version of the exams -
> Kubernetes `v1.35` (the programs of CKA and CKAD 2025-2026). Both exams are
> practical, in a live cluster from a command line: CKA - 2 hours, CKAD - 2
> hours, a passing score is 66%.

## How the course is built

Every topic is a folder with a number. Inside there are the localized files. A main
language is Russian (`ru.md`), and the translations are made from it: English
(`README.md`), Spanish (`es.md`), French (`fr.md`), German (`de.md`) and Georgian
(`ge.md`). A switcher of the languages is in the first line of every file.

Every chapter is marked with the exam it belongs to:

- 🟦 **CKA** - only for an administrator
- 🟩 **CKAD** - only for a developer
- 🟪 **CKA + CKAD** - a common topic for both exams

At the end of the course there are two separate guides that collect the chapters and the
labs for a specific exam:

- [A program and the labs for CKA](CKA.md)
- [A program and the labs for CKAD](CKAD.md)

All the terms of the course are collected in a single reference:

- [A glossary of the course](GLOSSARY.md) - all the terms by the chapters with the links

## The official programs of the exams

CKA (the domains and a weight):

| A domain | A weight |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (the domains and a weight):

| A domain | A weight |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## Contents

### Part 0. A foundation for the beginners (an optional one) 🟪 CKA + CKAD

A preparatory part for those who come without a solid base on the networks, DNS, TLS,
the containers, Linux and YAML. If you are confident with these topics - you can go
straight to Part 1. This part has no labs of its own: it is a foundation the rest of the
chapters rely on (the skills from 0.5-0.7 are applied directly in the node and the
network labs).

- 0.1. [Networking from scratch: IP, ports, CIDR, and NAT](00-1-net/README.md)
- 0.2. [DNS from scratch: how names turn into addresses](00-2-dns/README.md)
- 0.3. [TLS and certificates from scratch: HTTPS, keys, and certificate authorities](00-3-tls/README.md)
- 0.4. [Containers and Docker from scratch: images, layers, registries, and runtime](00-4-containers/README.md)
- 0.5. [Linux and node tools from scratch: SSH, sudo, systemd, logs, files](00-5-linux/README.md)
- 0.6. [YAML from scratch: indentation, lists, dictionaries, and Kubernetes manifests](00-6-yaml/README.md)
- 0.7. [Linux networking under the hood: network namespaces, veth, and routing](00-7-netns/README.md)
- 0.8. [vim in 15 minutes: survive and configure it for YAML](00-8-vim/README.md)

### Part 1. The basics of Kubernetes 🟪 CKA + CKAD

1. [Introduction: Kubernetes, the CKA and CKAD exams, and how this course is built](01/README.md)
2. [Kubernetes architecture: the control plane and worker nodes](02/README.md)
3. [Working with kubectl: the imperative and the declarative approach](03/README.md)
4. [Pods: the lifecycle, creation and configuration](04/README.md)
5. [ReplicaSet and Deployment](05/README.md)
6. [Namespaces, labels, selectors and annotations](06/README.md)
7. [Services: ClusterIP, NodePort, LoadBalancer and Endpoints](07/README.md)

### Part 2. The workloads and the scheduling 🟪 CKA + CKAD

8. [Deployment: rolling update and rollback](08/README.md)
9. [Deployment strategies: blue/green and canary](09/README.md) 🟩 CKAD
10. [Jobs and CronJobs](10/README.md)
11. [DaemonSet and StatefulSet](11/README.md)
12. [The scheduling of the Pods: nodeName, nodeSelector, affinity](12/README.md)
13. [Taints and tolerations](13/README.md)
14. [The resources: requests, limits, LimitRange and ResourceQuota](14/README.md)
15. [Static Pods, PriorityClass and several schedulers](15/README.md)
16. [The autoscaling of the workloads: HPA](16/README.md)

### Part 3. A configuration and a security of the applications 🟪 CKA + CKAD

17. [The commands, the arguments and the environment variables](17/README.md)
18. [ConfigMap](18/README.md)
19. [Secret](19/README.md)
20. [The SecurityContext and the capabilities](20/README.md)
21. [The ServiceAccount; the authentication, the authorization, the admission](21/README.md)

### Part 4. A design and a build of the applications 🟩 CKAD

22. [The multi-container Pods: a sidecar, an adapter, an ambassador, an init](22/README.md)
23. [The images of the containers: a building, a Dockerfile, an optimization](23/README.md)
24. [The volumes for the applications: an emptyDir and the ephemeral volumes](24/README.md)

### Part 5. A storage of the data 🟪 CKA + CKAD

25. [The Volumes, the PersistentVolume and the PersistentVolumeClaim](25/README.md)
26. [A StorageClass, a dynamic provisioning and a storing in a StatefulSet](26/README.md)

### Part 6. An observability and a maintenance 🟪 CKA + CKAD

27. [The checks of a state: the liveness, the readiness and the startup probes](27/README.md)
28. [A logging and a monitoring: the logs, the metrics-server, a kubectl top](28/README.md)
29. [A debugging of the applications and an obsolescence of an API](29/README.md)

### Part 7. The services and a network 🟪 CKA + CKAD

30. [A network model of Kubernetes, a network of the pods and a CNI](30/README.md)
31. [A Service from the inside, a DNS and a CoreDNS](31/README.md)
32. [An Ingress and the Ingress controllers](32/README.md)
33. [A Gateway API](33/README.md)
34. [NetworkPolicy](34/README.md)

### Part 8. An architecture of a cluster, an installation and a configuration 🟦 CKA

35. [An installation of a cluster with a help of kubeadm](35/README.md)
- 35A. [A high availability (HA): several control plane nodes, the topologies of etcd and a balancer](35-2-ha/README.md) 🟦 CKA
- 35B. [A designing and a sizing of a cluster: an infrastructure, a topology, IaC](35-3-design/README.md) 🟦 CKA
36. [An upgrade of a cluster (a lifecycle)](36/README.md)
37. [A backup and a restore of etcd](37/README.md)
38. [RBAC: Role, ClusterRole and the bindings](38/README.md)
39. [The TLS certificates, kubeconfig and a CSR API](39/README.md)
40. [The interfaces of an extension: CNI, CSI, CRI](40/README.md)
41. [The CRD and the operators](41/README.md)
42. [Helm](42/README.md)
43. [Kustomize](43/README.md)

### Part 9. Troubleshooting 🟦 CKA

44. [A debugging of the failures of the applications](44/README.md)
45. [A debugging of a control plane and of the worker nodes](45/README.md)
46. [A debugging of the services and of a network](46/README.md)

### Part 10. A preparation for the exams

47. [The exam CKAD: a format, a time management, JSONPath and a productivity of kubectl](47/README.md) 🟩 CKAD
48. [The exam CKA: a format, a time management and a strategy](48/README.md) 🟦 CKA
