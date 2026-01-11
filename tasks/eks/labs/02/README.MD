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

cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"
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
          values: ["spot" ,"on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge" ]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 * 24h = 720h
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
EoF

kubectl apply -f default-nodepool.yaml

```

получим имя кластера и karpenter_node_iam_role_name  из аутпута 

```
......
19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"

20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"

......
```

```
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005" # replace with your karpenter_node_iam_role_name
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01" # replace with your cluster name
  tags:
      Name: "eks2-viktor-01-default" # replace with your cluster name
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01

  blockDeviceMappings:
    - deviceName: /dev/xvda    # root
      ebs:
        volumeType: gp3
        volumeSize: 25Gi       # размер
        iops: 3000             # для gp3 можно настраивать iops/throughput (необязательно)
        throughput: 125        # MiB/s (необязательно)
        encrypted: true
        deleteOnTermination: true

EoF
kubectl -f default-nodeclass.yaml create
```

проверяем статус EC2NodeClass   и  NodePool

```
 # kubectl  get ec2nodeclasses.karpenter.k8s.aws

NAME      READY   AGE
default   True    2m17s

# kubectl  get nodepools.karpenter.sh

NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m


```
если EC2NodeClass   или  NodePool не в статусе  READY делаем describe   и проверяем логи контроллера

```
# kubectl describe ec2nodeclasses.karpenter.k8s.aws default 

.....
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, St                atus: Unknown -> True, Reason: AMIsReady
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReser                vationsReady, Status: Unknown -> True, Reason: CapacityReservationsReady
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady,                 Status: Unknown -> True, Reason: SubnetsReady
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroup                sReady, Status: Unknown -> True, Reason: SecurityGroupsReady
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfi                leReady, Status: Unknown -> True, Reason: InstanceProfileReady
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSuc                ceeded, Status: Unknown -> True, Reason: ValidationSucceeded
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status                : Unknown -> True, Reason: Ready


```
```
# kubectl describe nodepools.karpenter.sh

....
Events:
  Type     Reason               Age                   From       Message
  ----     ------               ----                  ----       -------
  Normal   ValidationSucceeded  59m                   karpenter  Status condition transitioned, Type: ValidationSucc, Status: Unknown -> True, Reason: ValidationSucceeded
  Normal   NodeClassReady       59m                   karpenter  Status condition transitioned, Type: NodeClassReadytus: Unknown -> False, Reason: NodeClassNotFound, Message: NodeClass not found on cluster
  Normal   Ready                59m                   karpenter  Status condition transitioned, Type: Ready, Status:own -> False, Reason: UnhealthyDependents, Message: NodeClassReady=False
  Warning                       7m27s (x27 over 59m)  karpenter  Failed resolving NodeClass
  Normal   NodeClassReady       6m46s                 karpenter  Status condition transitioned, Type: NodeClassReadytus: False -> True, Reason: NodeClassReady
  Normal   Ready                6m46s                 karpenter  Status condition transitioned, Type: Ready, Status:e -> True, Reason: Ready


```
```
# kubectl logs  -n karpenter  -l app.kubernetes.io/instance=karpenter | jq

......
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "commit": "1ad0d78",
  "controller": "nodeclass",
  "controllerGroup": "karpenter.k8s.aws",
  "controllerKind": "EC2NodeClass",
  "EC2NodeClass": {
    "name": "default"
  },
  "namespace": "",
  "name": "default",
  "reconcileID": "5fe4f70b-e3af-4116-b939-ce6756321a00",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.233Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "commit": "1ad0d78",
  "controller": "nodeclass",
  "controllerGroup": "karpenter.k8s.aws",
  "controllerKind": "EC2NodeClass",
  "EC2NodeClass": {
    "name": "default"
  },

......
```

проверяем  nodeclaims

```
#  kubectl  get nodeclaims.karpenter.sh


NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s


```

проверяем состояние пода нашего апликейшена

```
# kubectl  get po -n team-19


```
проверяем ноды кластера 

```
#  kubectl  get no


NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6

```
удалим наше приложение у проверим  и проверим что нода созданная карпентором удалилась (это пройдет не сразу )

```
#   kubectl   delete -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml

namespace "team-19" deleted
deployment.apps "team19" deleted from team-19 namespace
service "team19" deleted from team-19 namespace

```

```

#  kubectl  get po -n team-19

No resources found in team-19 namespace.

```

```
#  kubectl  get nodeclaims.karpenter.sh
No resources found


```
```
# kubectl  get no

NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4

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
