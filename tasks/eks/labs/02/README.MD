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
    cpu: 4
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

NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m



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

продеплоим  тестовое приложение 
``` 
 kubectl   apply  -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```
проверим что появился нодеклэйм нода и под  в статусе реди
``` 
# kubectl get  nodeclaims.karpenter.sh

NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s


```

``` 
#  kubectl get no
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6

```
``` 
# kubectl get po -n team-19
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11
```
проскалируем нашего приложение до 6 подов
``` 
#   kubectl scale deployment -n team-19  team19 --replicas 6

deployment.apps/team19 scaled

```
проверим состояние подов нашего деплоймента 

``` 
#   kubectl get po -n team-19


NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s


```
проверим нодеклеймы 
``` 
# kubectl  get nodeclaims.karpenter.sh
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m


```
видим что добавилась еще нода для наших деплойментов


отскалируем наш деплоймент до 16 реплик

``` 
kubectl scale deployment -n team-19  team19 --replicas 16
```

проверим состояние подов нашего деплоймента 

``` 
#   kubectl get po -n team-19

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
видим что часть подов в статусе **Pending**

## Limit Resources

проверии лимиты нодепула
``` 
#   kubectl get nodepools.karpenter.sh  default -o jsonpath='{.spec.limits}' | jq

{
  "cpu": 4
}

```
проверяем нодеклеймы 

``` 
# kubectl  get nodeclaims.karpenter.sh
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```
у t4g.small 2   vCPU  . мы упираемся в лимиты по CPU

проверим  это в логах карпентера 

``` 
kubectl logs  -n karpenter  -l app.kubernetes.io/instance=karpenter  | jq | grep ERROR -A 20
```
``` 
......
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
.....
```

**"error": "all available instance types exceed limits for nodepool (NodePool=default)"**

увеличим  cpu лимиты  нодепула до 6 

``` 
kubectl edit nodepools.karpenter.sh default
```
``` 
......
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # set to 6 
.....
```
проверяем нодеклеймы 
``` 
#   kubectl get nodeclaims.karpenter.sh


NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m

```
видим что добавилась еще 1 нода 


проверяем состояние подов нашего апликейшена 

``` 
 #    kubectl get po -n team-19
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
теперь  все наши поды готовы к работе 


отскалируем наше приложение до 3 под 
``` 
kubectl scale deployment -n team-19  team19 --replicas 3
```
в  логах контроллера мы увидим , что контроллер увидел недоиспользованные ноды и их удалил 
``` 
kubectl logs  -n karpenter  -l app.kubernetes.io/instance=karpenter  -f | jq

```
``` 
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "namespace": "",
  "name": "",
  "reconcileID": "9f332b96-08dc-437e-a2a6-6db4de6a6016",
  "command-id": "b64d8a05-1a56-4f27-a408-6c441f95641d",
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
  ],
  "replacement-nodes": []
}
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.347Z",
  "logger": "controller",
  "message": "tainted node",
  "commit": "1ad0d78",
  "controller": "node.termination",
  "controllerGroup": "",
  "controllerKind": "Node",
  "Node": {
    "name": "ip-10-10-16-30.eu-central-1.compute.internal"
  },
  "namespace": "",
  "name": "ip-10-10-16-30.eu-central-1.compute.internal",
  "reconcileID": "2e09de9a-8988-4ba2-9193-edaa531572a5",
  "NodeClaim": {
    "name": "default-gpgn9"
  },
  "taint.Key": "karpenter.sh/disrupted",
  "taint.Value": "",
  "taint.Effect": "NoSchedule"
}
{
  "level": "INFO",
  "time": "2026-01-13T17:52:23.462Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "namespace": "",
  "name": "",
  "reconcileID": "2b857488-a858-4a6d-87b0-8c82aaf9d2ae",
  "command-id": "a576675b-e234-49d0-93a3-77f3034af36e",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-67.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-k4crl"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ],
  "replacement-nodes": []
}
{
  "level": "INFO",
  "time": "2026-01-13T17:52:23.629Z",
  "logger": "controller",
  "message": "tainted node",
  "commit": "1ad0d78",
  "controller": "node.termination",
  "controllerGroup": "",
  "controllerKind": "Node",
  "Node": {
    "name": "ip-10-10-16-67.eu-central-1.compute.internal"
  },
  "namespace": "",
  "name": "ip-10-10-16-67.eu-central-1.compute.internal",
  "reconcileID": "918fc9c2-4fa2-44e8-9929-de88a556c0d0",
  "NodeClaim": {
    "name": "default-k4crl"
  },
  "taint.Key": "karpenter.sh/disrupted",
  "taint.Value": "",
  "taint.Effect": "NoSchedule"
}
{
  "level": "INFO",
  "time": "2026-01-13T17:53:03.256Z",
  "logger": "controller",
  "message": "deleted node",
  "commit": "1ad0d78",
  "controller": "node.termination",
  "controllerGroup": "",
  "controllerKind": "Node",
  "Node": {
    "name": "ip-10-10-16-30.eu-central-1.compute.internal"
  },
  "namespace": "",
  "name": "ip-10-10-16-30.eu-central-1.compute.internal",
  "reconcileID": "f43541f4-7efd-40a6-b8c9-995be55ac9e1",
  "NodeClaim": {
    "name": "default-gpgn9"
  }
}
{
  "level": "INFO",
  "time": "2026-01-13T17:53:03.523Z",
  "logger": "controller",
  "message": "deleted nodeclaim",
  "commit": "1ad0d78",
  "controller": "nodeclaim.lifecycle",
  "controllerGroup": "karpenter.sh",
  "controllerKind": "NodeClaim",
  "NodeClaim": {
    "name": "default-gpgn9"
  },
  "namespace": "",
  "name": "default-gpgn9",
  "reconcileID": "23321c83-f9c4-4927-ba30-1f99a997b59c",
  "provider-id": "aws:///eu-central-1b/i-01f658c89d1f5a570",
  "Node": {
    "name": "ip-10-10-16-30.eu-central-1.compute.internal"
  }
}
{
  "level": "INFO",
  "time": "2026-01-13T17:53:12.896Z",
  "logger": "controller",
  "message": "deleted node",
  "commit": "1ad0d78",
  "controller": "node.termination",
  "controllerGroup": "",
  "controllerKind": "Node",
  "Node": {
    "name": "ip-10-10-16-67.eu-central-1.compute.internal"
  },
  "namespace": "",
  "name": "ip-10-10-16-67.eu-central-1.compute.internal",
  "reconcileID": "2a955a80-1fd1-4e8e-9de8-0c2364d35a83",
  "NodeClaim": {
    "name": "default-k4crl"
  }
}
{
  "level": "INFO",
  "time": "2026-01-13T17:53:13.131Z",
  "logger": "controller",
  "message": "deleted nodeclaim",
  "commit": "1ad0d78",
  "controller": "nodeclaim.lifecycle",
  "controllerGroup": "karpenter.sh",
  "controllerKind": "NodeClaim",
  "NodeClaim": {
    "name": "default-k4crl"
  },
  "namespace": "",
  "name": "default-k4crl",
  "reconcileID": "0c4014fd-1faf-4403-921d-a7d0c5c9d167",
  "provider-id": "aws:///eu-central-1b/i-05b6326885f000b9b",
  "Node": {
    "name": "ip-10-10-16-67.eu-central-1.compute.internal"
  }
}

```
проверим нодеклэймы 
```` 
kubectl  get nodeclaims.karpenter.sh
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m

````
видим что осталось только одна нода .


лимиты мы можем установливать на  различные рессурсы  (cpu , memory,gpu , nodes ) . подробно можно посмотреть в официальной [документации](https://karpenter.sh/docs/concepts/nodepools/#speclimits)


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
