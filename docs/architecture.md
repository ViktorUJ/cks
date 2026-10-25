[Русский](architecture_RU.md) · English · [Español](architecture_ES.md) · [Français](architecture_FR.md) · [Deutsch](architecture_DE.md) · [ქართული](architecture_GE.md) · [繁體中文](architecture_TW.md) · [日本語](architecture_JP.md) · [Home](../README.MD)

<a id="architecture"></a>

# Platform architecture

Practical environments are defined as code. The Makefile selects a scenario, Terragrunt coordinates Terraform modules, and Terraform creates the necessary AWS resources and outputs connection details.

Self-managed Kubernetes scenarios install clusters with **kubeadm**. **Amazon EKS** labs use managed Kubernetes on AWS. Depending on the scenario, the platform creates VPCs, subnets, security groups, EC2 instances (including Spot), S3, and other required resources.

<details>
<summary>Repository structure</summary>

| Path | Purpose |
|---|---|
| [Makefile](../Makefile) | Commands for launching, deleting, and inspecting environments and checking the project |
| [tasks](../tasks) | Courses, tasks, labs, and mock exams |
| [tasks/cka](../tasks/cka) | Joint CKA + CKAD course, [labs](../tasks/cka/labs), and [CKA mock exams](../tasks/cka/mock) |
| [tasks/ckad](../tasks/ckad) | [CKAD mock exams](../tasks/ckad/mock) |
| [tasks/cks](../tasks/cks) | CKS course, [labs](../tasks/cks/labs), and [mock exams](../tasks/cks/mock) |
| [tasks/eks](../tasks/eks) | Amazon EKS course and labs |
| [tasks/ica](../tasks/ica) | Istio / ICA course, labs, and mock exams |
| [tasks/kcsa](../tasks/kcsa) | KCSA course, questions, and mock exams |
| [tasks/kcna](../tasks/kcna) | [KCNA mock exams](../tasks/kcna/mock) |
| [tasks/lfcs](../tasks/lfcs) | Practical LFCS mock exams |
| [tasks/hr](../tasks/hr) | HR scenarios |
| [tasks/aws_AI_practitioner](../tasks/aws_AI_practitioner) | [AWS Certified AI Practitioner mock exams](../tasks/aws_AI_practitioner/mock) |
| [terraform](../terraform) | Infrastructure definitions |
| [terraform/environments](../terraform/environments) | Terragrunt configuration and local environment directories |
| [terraform/modules](../terraform/modules) | Reusable Terraform modules |
| [docs](../docs) | Lab catalog, instructions, and additional materials |
| [CHANGELOG](../CHANGELOG/CHANGELOG.MD) | Project changelog |

</details>

<details>
<summary>Kubernetes, runtimes, OS, and CNI</summary>

You can use the [k8s_self_managment](../terraform/modules/k8s_self_managment) module for your own scenarios. It defines a self-managed Kubernetes cluster; the Kubernetes version, runtime, OS, AMI, and network are set by each scenario's configuration.

The project uses or has used the following options:

| Component | Options |
|---|---|
| Kubernetes | Historical scenarios with versions 1.21-1.34; check `env.hcl` and the course description for newer exercises |
| Container runtime | `containerd`, `containerd_gvizor`; older scenarios also use `docker` and `cri-o` |
| Self-managed cluster node OS | Ubuntu 20.04 LTS and 22.04 LTS, depending on the scenario |
| CNI | Calico or Cilium, depending on the scenario |

The previous platform description listed Docker with Kubernetes 1.21-1.23, CRI-O with 1.21-1.29, and containerd and `containerd_gvizor` with 1.21-1.33, as well as defaults of Kubernetes 1.33 for CKA/CKS and Ubuntu 22.04 for CKS. These describe older configurations, not a compatibility matrix for new labs. Select current settings from the chosen exercise's source files; the [Kubernetes release history](https://kubernetes.io/releases/) is available on the project website.

</details>
