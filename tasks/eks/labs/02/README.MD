# Karpenter Workshop

## Table of Contents
- [Setup](#setup)
- [Basic NodePool](#basic-nodepool)
- [Scaling Application](#scaling-application)
- [Limit Resources](#limit-resources)
- [Disruption](#disruption)
- [RightSizing](#rightsizing)
- [Drift](#drift)
- [Multi NodePools](#multi-nodepools)
- [Cost Optimization](#cost-optimization)
- [Scheduling Constraints](#scheduling-constraints)
- [Disruption Control](#disruption-control)
- [Control Pod Density](#control-pod-density)
- [EC2 Node Class](#ec2-node-class)
- [Observability](#observability)
- [Migrating from Cluster Autoscaler](#migrating-from-cluster-autoscaler)
- [Clean Up](#clean-up)
- [Workshop Catalog](#workshop-catalog)

## Setup

### Running the Lab

To run this lab, execute the following command:

```bash
TASK=02 make run_eks_task
```

### Created Resources

When executing the command, AWS infrastructure will be deployed using Terraform/Terragrunt, including the following components:

#### Network Infrastructure (VPC)
- **VPC** with CIDR block `10.10.0.0/16` in region `eu-central-1`
- **Public subnets**:
  - `eks-AZ-1` (10.10.1.0/24) in availability zone `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) in availability zone `eu-central-1b`
- **Private subnets**:
  - `private-subnet-1` (10.10.15.0/24) for EKS nodes in `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) for EKS nodes in `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) for RDS in `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) for RDS in `eu-central-1b`
- **NAT Gateway** for outbound internet traffic from private subnets

#### EKS Cluster
- **EKS Control Plane** version `1.34`
- **Fargate profile** for system pods
- **Karpenter** version `1.8.1`
- **EKS Add-ons** (coredns, kube-proxy, vpc-cni, eks-pod-identity-agent)

#### Karpenter Configuration
- Karpenter controller with resources:
  - CPU: 0.4 cores (requests and limits)
  - Memory: 0.5Gi (requests and limits)
- Automatic subnet discovery via `karpenter.sh/discovery` tags

#### Additional Components
- **Security Groups** with appropriate rules
- **IAM roles and policies** for Karpenter and EKS
- **OIDC provider** for AWS services integration

#### Main Configuration File

All infrastructure parameters are defined in `tasks/eks/labs/02/env.hcl`. To modify the configuration, edit the corresponding parameters.

### Prerequisites

Ensure you have configured:
- AWS CLI with appropriate access permissions, and increased node limits in region `eu-central-1`

## Basic NodePool
 найдите в аутпуте  ssh конекшен стринг и  залогинтесь на воркер ноду 
 ```
 ........

18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "
......... 
 ```
проверьте что карпентер контроллер работает
```
#  kubectl get po -n karpenter


NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m

```
проверьте NodePool и EC2NodeClass
```
# kubectl get nodepools
No resources found

```

```
# kubectl get ec2nodeclasses
No resources found
```

создадим тестовое приложение 
```
#   kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml



namespace/team-19 created
deployment.apps/team19 created
service/team19 created

```
проверим состояние подов приложения 

```
# kubectl get po -n team-19

NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```
```
#  kubectl describe  po -n team-19

.....
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.


```
это  потому что у нас нет доступных нод для этих подов . фаргейт профиль поднимает фаргейт только для неймспейсов kube-system и karpenter

создадим ec2nodeclasses  и nodepool
```


```


## Scaling Application
...existing code...

## Limit Resources
...existing code...

## Disruption
...existing code...

## RightSizing
...existing code...

## Drift
...existing code...

## Multi NodePools
...existing code...

## Cost Optimization
...existing code...

## Scheduling Constraints
...existing code...

## Disruption Control
...existing code...

## Control Pod Density
...existing code...

## EC2 Node Class
...existing code...

## Observability
...existing code...

## Migrating from Cluster Autoscaler
...existing code...

## Clean Up
...existing code...

## Workshop Catalog
...existing code...
