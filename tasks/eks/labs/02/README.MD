# Lab: Karpenter Basics

## Description

This lab will introduce you to **Karpenter** — an automatic node scaling tool for Amazon EKS clusters. Karpenter dynamically creates and removes EC2 instances based on your application needs, optimizing costs and performance.

**What you will learn:**
- How to configure basic NodePool and EC2NodeClass
- How Karpenter automatically scales nodes when load changes
- How to manage resources through limits
- How consolidation and node size optimization work
- How to update nodes when configuration changes (drift)
- How to use multiple NodePools for different workload types

## Table of Contents
- [Environment Setup](#environment-setup)
  - [Starting the Lab](#starting-the-lab)
  - [Resources Created](#resources-created)
  - [Prerequisites](#prerequisites)
- [Basic NodePool Configuration](#basic-nodepool-configuration)
  - [Verifying Karpenter Operation](#verifying-karpenter-operation)
  - [Creating a Test Application](#creating-a-test-application)
  - [Creating NodePool and EC2NodeClass](#creating-nodepool-and-ec2nodeclass)
  - [Verifying Automatic Node Creation](#verifying-automatic-node-creation)
- [Application Scaling](#application-scaling)
  - [Horizontal Scaling](#horizontal-scaling)
  - [Automatic Node Addition](#automatic-node-addition)
- [Resource Limits](#resource-limits)
  - [Configuring CPU Limits](#configuring-cpu-limits)
  - [Diagnosing Limit Issues](#diagnosing-limit-issues)
- [Node Lifecycle Management (Disruption)](#node-lifecycle-management-disruption)
- [Node Size Optimization (RightSizing)](#node-size-optimization-rightsizing)
  - [Automatic Optimal Size Selection](#automatic-optimal-size-selection)
  - [Node Replacement on Requirement Changes](#node-replacement-on-requirement-changes)
- [Node Configuration Updates (Drift)](#node-configuration-updates-drift)
  - [AMI Image Updates](#ami-image-updates)
  - [Automatic Migration to New Versions](#automatic-migration-to-new-versions)
- [Working with Multiple NodePools](#working-with-multiple-nodepools)
  - [Workload Isolation via Taints and Tolerations](#workload-isolation-via-taints-and-tolerations)
  - [Specialized Nodes for Jobs](#specialized-nodes-for-jobs)
- [Resource Cleanup](#resource-cleanup)


## Environment Setup

### Starting the Lab

To start the lab, run the following command:

```bash
TASK=02 make run_eks_task
```

**What happens when you run this command:**
- Terraform/Terragrunt automatically deploys all necessary infrastructure in AWS
- The process takes approximately 15-20 minutes
- The command output will show important information (SSH connection, resource names)

### Resources Created

When you run the command, the following AWS infrastructure will be deployed:

#### Network Infrastructure (VPC)
- **VPC** with CIDR block `10.10.0.0/16` in region `eu-central-1`
- **Public subnets** (for resources with internet access):
  - `eks-AZ-1` (10.10.1.0/24) in availability zone `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) in availability zone `eu-central-1b`
- **Private subnets** (for internal resources):
  - `private-subnet-1` (10.10.15.0/24) for EKS nodes in `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) for EKS nodes in `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) for RDS in `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) for RDS in `eu-central-1b`
- **NAT Gateway** for outbound internet traffic from private subnets

#### EKS Cluster
- **EKS Control Plane** version `1.34` (Kubernetes control plane)
- **Fargate profile** for system pods (kube-system, karpenter)
- **Karpenter** version `1.8.1` (autoscaling controller)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Karpenter Configuration
- Karpenter controller with dedicated resources:
  - CPU: 0.4 cores (requests and limits)
  - Memory: 0.5Gi (requests and limits)
- Automatic subnet discovery via `karpenter.sh/discovery` tags

#### Additional Components
- **Security Groups** with appropriate security rules
- **IAM roles and policies** for Karpenter and EKS
- **OIDC provider** for AWS service integration

#### Main Configuration File

All infrastructure parameters are defined in the `tasks/eks/labs/02/env.hcl` file. To change the configuration, edit the appropriate parameters in this file.

### Prerequisites

Make sure you have:
- **AWS CLI** with appropriate access rights
- Increased node limits in the `eu-central-1` region (if necessary)


## Basic NodePool Configuration

### Verifying Karpenter Operation

**Step 1: Connect to the Worker Node**

Find the SSH connection string in the command output and connect to the worker node:

```bash
# Example output:
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # Use your IP address and password
```

**Step 2: Check Karpenter Controller Status**

Verify that the Karpenter controller is running:

```bash
kubectl get po -n karpenter
```

**Expected result:**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**Step 3: Check Existing NodePools and EC2NodeClass**

Verify that no NodePools are created yet:

```bash
kubectl get nodepools
```

**Result:**
```
No resources found
```

Check EC2NodeClass:

```bash
kubectl get ec2nodeclasses
```

**Result:**
```
No resources found
```

**What this means:** NodePool and EC2NodeClass are the main Karpenter resources. NodePool defines which nodes to create, and EC2NodeClass defines how to configure them (AMI, subnets, security groups, etc.).

### Creating a Test Application

Let's deploy a simple test application:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Result:**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**Step 4: Check Pod Status**

Check the status of created pods:

```bash
kubectl get po -n team-19
```

**Result:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**Note:** The pod is in `Pending` status. This is normal at this stage.

**Step 5: Diagnose the Problem**

Let's look at detailed pod information:

```bash
kubectl describe po -n team-19
```

**Important part of the output:**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**Problem explanation:**
- The pod cannot be scheduled on any node
- All 3 existing nodes are Fargate nodes for system pods (kube-system, karpenter)
- The Fargate profile is configured only for specific namespaces, and `team-19` is not included
- We need to create a NodePool so Karpenter can create suitable EC2 nodes


### Creating NodePool and EC2NodeClass

**Step 6: Create NodePool**

NodePool defines the parameters of nodes that Karpenter will create:

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # Label for node identification
    spec:
      requirements:
        # Supported processor architectures
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # Operating system
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # Instance types: spot (cheaper) or on-demand (more stable)
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # Instance categories (t - burstable, m - general purpose, r - memory optimized)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # Instance generation (greater than 2 = newer)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # Instance sizes
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # Reference to EC2NodeClass with AWS settings
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # Node lifetime (30 days)
      expireAfter: 720h # 30 * 24h = 720h
  # Resource limits for the entire NodePool
  limits:
    cpu: 4  # Maximum 4 CPUs for all nodes in this pool
  # Consolidation (optimization) settings
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # Remove empty or underutilized nodes
    consolidateAfter: 30s  # 30 seconds after the node becomes empty
EoF

kubectl apply -f default-nodepool.yaml
```

**Step 7: Get Parameters from Terraform Output**

Find the following values in the `make run_eks_task` command output:

```bash
# Example output:
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Step 8: Create EC2NodeClass**

EC2NodeClass defines AWS-specific node settings:

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # IAM role for nodes (replace with yours from Terraform output)
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # AMI image selection
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023, latest version
  # Subnet selection by tags
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Replace with your cluster name
  # Security group selection by tags
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Replace with your cluster name
  # Tags for created EC2 instances
  tags:
      Name: "eks2-viktor-01-default"  # Replace with your cluster name
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # Replace with your cluster name
  # Disk configuration
  blockDeviceMappings:
    - deviceName: /dev/xvda    # Root disk
      ebs:
        volumeType: gp3        # Disk type (gp3 - modern, performant)
        volumeSize: 25Gi       # Disk size
        iops: 3000             # IOPS for gp3
        throughput: 125        # Throughput MiB/s
        encrypted: true        # Disk encryption
        deleteOnTermination: true  # Delete disk when instance terminates
EoF

kubectl create -f default-nodeclass.yaml
```


### Verifying Automatic Node Creation

**Step 9: Check Resource Status**

Verify that EC2NodeClass is created and ready:

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Expected result:**
```
NAME      READY   AGE
default   True    2m17s
```

Check NodePool:

```bash
kubectl get nodepools.karpenter.sh
```

**Expected result:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**If status is not READY:**

Diagnose EC2NodeClass:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**Example successful output:**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

Check NodePool:

```bash
kubectl describe nodepools.karpenter.sh default
```

**If there are errors, check controller logs:**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Example successful logs:**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**Step 10: Check NodeClaim**

NodeClaim is a request to create a node. Karpenter creates a NodeClaim, which then becomes a real EC2 instance:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**What we see:**
- A NodeClaim named `default-c549s` was created
- Instance type `t3a.small` was selected (2 vCPU, 2GB RAM)
- Using a spot instance (cheaper)
- Node is in zone `eu-central-1a`

**Step 11: Check Application Pod**

Now the pod should start successfully:

```bash
kubectl get po -n team-19
```

**Result:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**Status changed to `Running`!**

**Step 12: Check Cluster Nodes**

Let's look at all nodes in the cluster:

```bash
kubectl get no
```

**Result:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**Note:**
- First 3 nodes are Fargate (for system pods)
- Last node is an EC2 instance created by Karpenter

### Verifying Automatic Node Deletion

**Step 13: Delete the Application**

Let's delete our application:

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Result:**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**Step 14: Check Pod Deletion**

```bash
kubectl get po -n team-19
```

**Result:**
```
No resources found in team-19 namespace.
```

**Step 15: Wait for NodeClaim Deletion**

Wait approximately 30 seconds (the `consolidateAfter` value in NodePool) and check:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
No resources found
```

**Karpenter automatically deleted the NodeClaim because the node became empty!**

**Step 16: Check Nodes**

```bash
kubectl get no
```

**Result:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**EC2 node deleted! Only Fargate nodes remain.**

**Conclusion:** Karpenter automatically manages node lifecycle — creates them when needed and deletes them when no longer needed, optimizing costs.


## Application Scaling

In this section, we'll explore how Karpenter automatically adds nodes when load increases.

### Horizontal Scaling

**Step 1: Deploy Test Application**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Step 2: Check Created Resources**

Check NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

Check nodes:

```bash
kubectl get no
```

**Result:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

Check pods:

```bash
kubectl get po -n team-19
```

**Result:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### Automatic Node Addition

**Step 3: Scale to 6 Replicas**

Let's increase the number of application replicas:

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**Result:**
```
deployment.apps/team19 scaled
```

**Step 4: Check Pod Status**

```bash
kubectl get po -n team-19
```

**Result:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**All 6 pods successfully started!**

**Step 5: Check NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Note:** Karpenter automatically added a second node (`default-gm8sj`) because one node was insufficient to accommodate all 6 pods.

**Step 6: Scale to 16 Replicas**

Let's increase the load even more:

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**Step 7: Check Pod Status**

```bash
kubectl get po -n team-19
```

**Result:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**Problem:** Some pods are in `Pending` status. Why? Let's move to the next section to find out.


## Resource Limits

In this section, we'll understand why some pods remained in `Pending` status and learn how to manage resource limits in NodePool.

### Configuring CPU Limits

**Step 1: Check Current NodePool Limits**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**Result:**
```json
{
  "cpu": 4
}
```

**What this means:** The NodePool has a limit of 4 CPUs. This means the total CPU count of all nodes in this pool cannot exceed 4 cores.

**Step 2: Check Existing NodeClaims**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Analysis:**
- We have 2 nodes of type `t4g.small`
- Each `t4g.small` has 2 vCPUs
- Total: 2 nodes × 2 vCPUs = 4 vCPUs
- **We've reached the limit!** Karpenter cannot create more nodes.

### Diagnosing Limit Issues

**Step 3: Check Karpenter Logs**

Let's see what the controller logs say:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**Result:**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**Key message:** `"all available instance types exceed limits for nodepool"`

This confirms that Karpenter cannot create new nodes due to the CPU limit.

**Step 4: Increase CPU Limit**

Let's increase the CPU limit to 6 cores:

```bash
kubectl edit nodepools.karpenter.sh default
```

Find the `limits` section and change the value:

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # Change to 6
```

Save the changes (`:wq` in vim or Ctrl+O, Enter, Ctrl+X in nano).

**Step 5: Check New Node Creation**

Wait a few seconds and check NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**Great!** Karpenter created a third node (`default-gpgn9`).

**Step 6: Check Application Pods**

```bash
kubectl get po -n team-19
```

**Result:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**All 16 pods are now `Running`!**

### Verifying Automatic Consolidation

**Step 7: Reduce Replica Count**

Let's reduce the replica count to 3:

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**Step 8: Monitor Karpenter Logs**

Watch logs in real-time:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**You'll see consolidation messages:**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**What's happening:**
- Karpenter detected an underutilized node (`underutilized`)
- Decided to delete the node (`decision: delete`)
- First marks the node with taint `karpenter.sh/disrupted:NoSchedule`
- Moves pods to other nodes
- Deletes the node

**Step 9: Check Remaining Nodes**

Wait about a minute and check:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**Only one node remains!** Karpenter deleted the extra nodes, optimizing costs.

### Additional Information About Limits

Limits can be set on various resource types:
- **cpu** — number of processor cores
- **memory** — amount of RAM
- **gpu** — number of GPUs (for ML/AI workloads)
- **nodes** — maximum number of nodes

**Example configuration with multiple limits:**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

Learn more about limits in the [official Karpenter documentation](https://karpenter.sh/docs/concepts/nodepools/#speclimits).


## Node Lifecycle Management (Disruption)

Karpenter supports automatic node lifecycle management through the `consolidateAfter` parameter in the NodePool specification.

**Key concepts:**

- **consolidateAfter** — wait time before deleting a node after it becomes empty or underutilized
- **consolidationPolicy** — consolidation policy:
  - `WhenEmpty` — delete only completely empty nodes
  - `WhenEmptyOrUnderutilized` — delete empty and underutilized nodes (recommended)

**Example configuration:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # Delete 30 seconds after becoming free
```

**How it works:**

1. Karpenter constantly monitors resource usage on nodes
2. When a node becomes empty or underutilized, Karpenter starts a timer
3. If after the specified time (`consolidateAfter`) the node is still not needed, Karpenter:
   - Marks the node with taint `karpenter.sh/disrupted:NoSchedule`
   - Gracefully moves pods to other nodes
   - Deletes the node

**Additional parameters:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # Don't delete more than 10% of nodes simultaneously
```

Learn more about disruption in the [official documentation](https://karpenter.sh/docs/concepts/disruption/).

---

## Node Size Optimization (RightSizing)

Karpenter automatically selects the optimal node size based on pod requirements. This is called "right-sizing" — choosing the most suitable and economical instance type.

### Automatic Optimal Size Selection

**Step 1: Set CPU Limit**

Let's increase the NodePool limit to 10 cores:

```bash
kubectl edit nodepools.karpenter.sh default
```

Change:

```yaml
spec:
  limits:
    cpu: 6     # Change to 10
```

**Step 2: Deploy Application with Large Requirements**

Let's deploy an application that requests 3 CPUs:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Step 3: Check Created NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**Note:** Karpenter selected a `t3.xlarge` instance with 4 vCPUs to accommodate the pod requesting 3 CPUs.

**Step 4: Check Node Details**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**Important labels:**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### Node Replacement on Requirement Changes

**Step 5: Reduce Pod Requirements**

Let's change the CPU requirements in the deployment:

```bash
kubectl edit deployments.apps -n team-19 team19
```

Find the `resources` section and change:

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # Change to "50m" (50 millicores)
        memory: 500Mi
```

Save the changes.

**Step 6: Monitor Karpenter Logs**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**You'll see:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**What's happening:**
- Karpenter detected that the node is underutilized (`underutilized`)
- Decided to replace the node (`decision: replace`)
- Creating a new, cheaper node

**Creating new NodeClaim:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**Launching new instance:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**Step 7: Check New NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**Great!** Karpenter replaced `t3.xlarge` (4 vCPU) with `t4g.small` (2 vCPU), which is significantly cheaper.

**Step 8: Cleanup**

Delete the deployment:

```bash
kubectl delete deployments.apps -n team-19 team19
```

Wait for NodeClaim deletion:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
No resources found
```

**Conclusion:** Karpenter automatically optimizes node sizes, choosing the most economical options that meet application requirements.


## Node Configuration Updates (Drift)

Drift is a mechanism for automatically updating nodes when the EC2NodeClass configuration changes. When you change AMI, security groups, user data, or other parameters, Karpenter automatically replaces existing nodes with new ones with the updated configuration.

### AMI Image Updates

**Step 1: Get AMI for Previous EKS Version**

Let's get the AMI ID for EKS version 1.33:

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**Result:**
```
ami-0fc1cdef3ebc3a8fe
```

**Step 2: Set Old AMI in EC2NodeClass**

Edit EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Find the `amiSelectorTerms` section and change:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Was
```

To:

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # Specific AMI ID for version 1.33
```

**Step 3: Deploy Application**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Step 4: Check Node Version**

```bash
kubectl get no
```

**Result:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- Version 1.33!
```

**Note:** The node is using Kubernetes version 1.33.5 (from the old AMI).

### Automatic Migration to New Versions

**Step 5: Return to Automatic AMI Selection**

Edit EC2NodeClass back:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Change to:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Automatic selection of latest version
```

**What happens:**
- Karpenter detects the change in EC2NodeClass
- Determines that the existing node uses outdated configuration (drift)
- Automatically creates a new node with updated AMI
- Gracefully moves pods to the new node
- Deletes the old node

**Step 6: Check Node Update**

Wait about a minute and check nodes:

```bash
kubectl get no
```

**Result (after ~30 seconds):**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- New version!
```

**Result (after ~4 minutes):**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**Great!** Karpenter automatically replaced the node with a new one with the updated AMI version (1.34.2).

**Step 7: Cleanup**

```bash
kubectl delete deployments.apps -n team-19 team19
```

Wait for NodeClaim deletion:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
No resources found
```

**Conclusion:** Drift allows automatic node updates when configuration changes without manual intervention. This is especially useful for:
- Updating AMI (security patches, new Kubernetes versions)
- Changing security groups
- Updating user data scripts
- Changing IAM roles

---

## Working with Multiple NodePools

In production environments, it's often necessary to separate workloads across different node groups. For example:
- Ingress controllers on dedicated nodes
- Powerful nodes for periodic tasks (jobs)
- Nodes with GPUs for ML/AI workloads
- Nodes with large memory for databases

### Workload Isolation via Taints and Tolerations

**Scenario:** We need to run periodic jobs with large resource requirements (CPU, memory, GPU).

**Requirements:**
1. Regular pods should not be placed on these nodes (only jobs)
2. While a job is running on the node, consolidation should not occur
3. As soon as the job completes, the node should be deleted

### Specialized Nodes for Jobs

**Step 1: Create Specialized NodePool**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # Label for identification
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 days
      # IMPORTANT: Taint prevents regular pods from running on these nodes
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # Pods without matching toleration cannot start
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # Delete ONLY empty nodes (not during job execution)
    consolidateAfter: 10s           # Quick deletion after job completion
EoF

kubectl apply -f job-nodepool.yaml
```

**Key differences from default NodePool:**

1. **Taints** — prevent regular pods from running:
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — node is deleted only when completely empty (doesn't interrupt running jobs)

3. **consolidateAfter: 10s** — quick deletion after completion

**Step 2: Get Parameters from Terraform Output**

Find in the output:

```bash
# Example:
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Step 3: Create EC2NodeClass for Jobs**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # Replace with yours
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Replace with your cluster name
  tags:
      Name: "eks2-viktor-01-job"  # Replace with your cluster name
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```


**Step 4: Check Resource Status**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Result:**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**Result:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**If status is not READY**, perform diagnostics:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Step 5: Run Job with Toleration**

Create a job that can run on nodes with taint `workType=job`:

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration allows the pod to run on nodes with matching taint
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity ensures the pod runs specifically on job NodePool nodes
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**Step 6: Check NodeClaim Creation**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Result:**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**Check pod:**

```bash
kubectl get po
```

**Result (during execution):**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**Result (after completion):**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**Check nodes:**

```bash
kubectl get no
```

**Result:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**Step 7: Check Automatic Node Deletion**

Wait approximately 10-15 seconds after job completion and check nodes:

```bash
kubectl get no
```

**Result:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Node successfully deleted!** Karpenter automatically deleted the node 10 seconds after job completion.

**Conclusion:** Using multiple NodePools with taints and tolerations allows you to:
- Isolate different workload types
- Optimize costs (quick node deletion after job completion)
- Prevent regular pods from running on specialized nodes
- Flexibly manage consolidation policies for different workload types



## Resource Cleanup

After completing the lab, you need to delete all created resources to avoid unnecessary costs.

**Step 1: Check for Active NodeClaims**

Make sure there are no active NodeClaims:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Expected result:**
```
No resources found
```

**If there are active NodeClaims:**

1. Check if there are running pods on the nodes:

```bash
kubectl get pods --all-namespaces -o wide
```

2. Delete deployments, pods, or jobs:

```bash
# Example deleting deployment
kubectl delete deployment -n team-19 team19

# Example deleting job
kubectl delete job testjob
```

3. After deleting pods, manually delete NodeClaim (if necessary):

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**Step 2: Check Cluster Nodes**

Make sure only Fargate nodes remain:

```bash
kubectl get no
```

**Expected result:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**All nodes should start with `fargate-`.**

**Step 3: Delete Infrastructure**

Delete all resources created for the lab:

```bash
TASK=02 make delete_eks_task
```

**Command output:**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**Enter `y` to confirm deletion.**

**What will be deleted:**
- Worker node
- Karpenter controller and related resources
- SSH keys
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC and network infrastructure

**The deletion process will take approximately 10-15 minutes.**

---

## Conclusion

Congratulations! You have successfully completed the Karpenter basics lab.

**What you learned:**

1. **Basic configuration** — creating NodePool and EC2NodeClass for automatic node management
2. **Automatic scaling** — Karpenter dynamically adds nodes when load increases
3. **Managing limits** — controlling maximum resources through limits
4. **Consolidation** — automatic deletion of empty and underutilized nodes to optimize costs
5. **Right-sizing** — automatic selection of optimal node sizes based on pod requirements
6. **Drift** — automatic node updates when configuration changes (AMI, security groups, etc.)
7. **Multiple NodePools** — isolating different workload types through taints, tolerations, and affinity

**Key Karpenter advantages:**

- **Fast scaling** — nodes are created in seconds, not minutes
- **Cost optimization** — automatic selection of the most economical instance types
- **Flexibility** — support for spot and on-demand instances, various architectures (amd64, arm64)
- **Simplicity** — declarative configuration through Kubernetes resources
- **Automation** — minimal manual intervention in node management

**Additional resources:**

- [Official Karpenter documentation](https://karpenter.sh/docs/)
- [Best Practices for Karpenter](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Troubleshooting Guide](https://karpenter.sh/docs/troubleshooting/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

**Next steps:**

- Explore advanced Karpenter features (weighted NodePools, custom AMI, GPU support)
- Integrate Karpenter with your production applications
- Set up monitoring and alerting for Karpenter
- Optimize costs through analysis of spot vs on-demand instance usage
