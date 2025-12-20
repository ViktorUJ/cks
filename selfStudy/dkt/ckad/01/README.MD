[README_RU](README_RU.MD)

## [video](https://www.youtube.com/watch?v=4WXSijgYbVw)

## [presentation](https://www.canva.com/design/DAGUf_wVLzU/3loTtTVLbmVJULPuzeI5VA/edit)


**Kubernetes** - container orchestration system. Currently the most popular container orchestration system.
Alternatives: AWS ECS, docker-Swarm, Mesos, Nomad (hashicorp)


<p align="center">
    <a href="https://github.com/ViktorUJ/cks/blob/dkt_ckad_01/selfStudy/dkt/ckad/01/README.MD"><img src="https://kubernetes.io/images/docs/components-of-kubernetes.svg" width="1900" height="600" alt="SRE Learning Platform"/></a>
</p>

[components](https://kubernetes.io/docs/concepts/overview/components/)

[CNI plugins](https://kubernetes.io/docs/concepts/cluster-administration/networking/#cni)


## Main Kubernetes Components

| **Component**      | **Purpose**                                                       | **How to Find**                                                                                    |
|--------------------|-------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| API Server         | Manages requests to the cluster                                   | Static pod. Manifest located at `/etc/kubernetes/manifests/kube-apiserver.yaml`                   |
| etcd               | Stores all cluster state information                              | Static pod. Manifest located at `/etc/kubernetes/manifests/etcd.yaml`                             |
| Scheduler          | Schedules pod launches on nodes                                   | Static pod. Manifest located at `/etc/kubernetes/manifests/kube-scheduler.yaml`                   |
| Controller-Manager | Manages controllers to maintain cluster health                    | Static pod. Manifest located at `/etc/kubernetes/manifests/kube-controller-manager.yaml`          |
| Kubelet            | Manages pods on specific nodes                                    | Installed as a service on nodes. Check: `systemctl status kubelet`                                |
| kube-proxy         | Manages network rules (iptables)                                  | DaemonSet. Check: `kubectl get daemonset kube-proxy --namespace=kube-system`                      |
| CNI                | Provides network communication between pods                       | Installed as plugins. Check: `kubectl get pods --namespace=kube-system`                           |
| DNS                | Provides service name resolution in the cluster                   | Deployed as a service and pod (CoreDNS). Check: `kubectl get svc kube-dns --namespace=kube-system` |



## Kubernetes Primitives


| **Name**                 | **Purpose**                                                                 | **Description**                                                          |
|--------------------------|-----------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Container                | Part of pod configuration                                                   | Cannot be launched separately                                            |
| Pod                      | Runs 1 or more containers with shared network + shared folders + Labels    | Cannot be modified, must be recreated                                    |
| ReplicaSet               | Maintains desired number of pods                                            | Only pod count changes, applied as part of deployment                    |
| Deployment               | Main primitive for applications (ReplicaSet + update history)               | State support, pod parameter updates                                     |
| DaemonSets               | Deploy system daemons                                                       | System daemons such as logging and monitoring                            |
| StatefulSet              | Set of pods with fixed names                                                | State support for Pods                                                   |
| Service                  | Load balancer inside the cluster                                            | Can be external                                                          |
| Job                      | One-time tasks                                                              | Pod + execution result                                                   |
| Cron Job                 | Job + schedule                                                              | Execute tasks on schedule                                                |
| Persistent volume (PV)   | Persistent file system for pods                                             | Size + Access Type + Storage Class                                       |
| Persistent Volume Claims | Template for creating Persistent volumes                                    | Checks if PV is created, creates if needed                               |
| Ingress                  | Connect to application from outside world                                   | Traffic balancing, SSL termination, name-based virtual hosting           |
| ConfigMaps               | Store application configurations                                            | Mounted in Pod as read-only filesystem during startup                    |
| Secrets                  | Store certificates and private data                                         | Mounted in Pod as read-only filesystem or environment variables          |
| Namespace                | Logical separation of applications                                          | Pods, deployments, services, etc. are created in them                    |


## Kubernetes Installation Options


| Name                                                                                             | Complexity          | Cost                                    | Use Case                                    |
|--------------------------------------------------------------------------------------------------|---------------------|-----------------------------------------|---------------------------------------------|
| [Minikube](https://minikube.sigs.k8s.io/docs/)                                                   | Low                 | Free                                    | Learning, testing on local machines         |
| [kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/)                                         | Low                 | Free                                    | Learning, development, testing              |
| [k3s](https://k3s.io/)                                                                           | Low                 | Free                                    | Lightweight clusters, IoT, edge devices     |
| [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)                | Medium              | Free                                    | Production, manual setup                    |
| [MicroK8s](https://microk8s.io/)                                                                 | Low                 | Free                                    | Learning, development, small clusters       |
| [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)                     | Low                 | Paid, depends on resources              | Production, cloud solutions                 |
| [Amazon EKS](https://aws.amazon.com/eks/)                                                        | Low                 | Paid, depends on resources              | Production, cloud solutions                 |
| [Azure Kubernetes Service (AKS)](https://azure.microsoft.com/en-us/services/kubernetes-service/) | Low                 | Paid, depends on resources              | Production, cloud solutions                 |
| [OpenShift](https://www.openshift.com/)                                                          | High                | Paid                                    | Production, enterprise solutions            |
| [Rancher](https://rancher.com/)                                                                  | Medium              | Paid (basic features free)              | Production, multi-cluster solutions         |
| Kubernetes on own servers                                                                        | High                | Varies (depends on infrastructure)      | Production, enterprise solutions            |


## Kubernetes Options for Learning


| Name                                  | Runs On                                | Complexity          | Cost                | Use Case                                                                       |
|---------------------------------------|----------------------------------------|---------------------|---------------------|--------------------------------------------------------------------------------|
| [Minikube](https://minikube.sigs.k8s.io/docs/) | Local machines                         | Low                 | Free                | CKAD                                                                           |
| [k3s](https://k3s.io/)                | Local machines, virtual machines       | Low                 | Free                | CKAD                                                                           |
| [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) | Virtual machines, local machines       | Medium              | Free                | CKAD, CKA, CKS (when running in public cloud)                                  |
| [Killercoda](https://killercoda.com/) | As a service (cloud)                   | Low                 | Free (for educational scenarios) | Interactive scenario learning for CKAD, CKA, CKS. Pre-made scenarios only     |
| [SRE Learning Platform](https://github.com/ViktorUJ/cks)   | AWS, ec2                               | Low                 | Low                 | CKAD, CKA, CKS. Lab work, exam mocks, custom scenarios.                        |


### Running a scenario on our platform 

[video](https://www.youtube.com/watch?v=Xh6sWzafBmw)


[instructions](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)


[DKT64](https://www.youtube.com/watch?v=QuMUzflHsS4)

``` 

TASK=01  make run_ckad_mock_clean

```



## Connecting to the cluster 


###  [HTTP requests to API server](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/)


### [kubernetes lens](https://k8slens.dev/)


###  [kubectl - main tool](https://kubernetes.io/docs/reference/kubectl/overview/)


### Configuration 
```
~/.kube/config

```
You can change the path to configuration 

``` 
export KUBECONFIG=/etc/kubernetes/admin.conf

```

``` 
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://<cluster-api-server-url>:6443
    certificate-authority-data: <base64-encoded-ca-cert>
  name: kubernetes
users:
- name: kubernetes-admin
  user:
    client-certificate-data: <base64-encoded-client-cert>
    client-key-data: <base64-encoded-client-key>
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
    namespace: default
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes

```


``` 
# cluster information 
k version 


# list of nodes 

k get no

# information about a specific node

k describe no ip-10-2-14-14 

k get no ip-10-2-14-14 -o yaml
 

# list of namespaces

k get ns

```

``` 
# create pod

k run nginx --image=nginx 


# delete pod

k delete po nginx

```


```
# generate pod manifest and create pod from manifest
 
k run nginx --image=nginx -o yaml --dry-run=client > pod.yaml


k apply -f pod.yaml


# delete pod using manifest

k delete -f pod.yaml

```

``` 
# create pod with environment variables 

k run nginx --image=nginx --env="key1=value1" --env="key2=value2"

```


### Modifying existing pod 


``` 
# get pod manifest
k get po nginx -o yaml > pod.yaml

# delete existing pod

# modify manifest
vim pod.yaml

# apply manifest
k apply -f pod.yaml

```

### Creating pod with command


```
k run nginx --image=nginx --command -- sleep 1000

```

###  Quick pod deletion (useful on exam)

```
k delete po nginx --force --grace-period=0

```

### View namespaces
``` 
k get ns

```
### Create namespace

```
k create ns my-namespace

```

### Delete namespace

```
k delete ns my-namespace
```

### Create pod in namespace

```
k create ns my-namespace

k run nginx --image=nginx --namespace=my-namespace
``` 

### [Exam task example 1](https://github.com/ViktorUJ/cks/tree/master/tasks/ckad/mock/01) 


|        **1**        | **Deploy a pod named webhttpd**                                                |
| :-----------------: | :----------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                |
| Acceptance criteria | - Name: `webhttpd` <br/>- Image: `httpd:alpine`<br/>- Namespace: `apx-z993845` |

```
k get ns  apx-z993845
k create ns apx-z993845

k run webhttpd --image httpd:alpine -n apx-z993845
k get po -n  apx-z993845


check_result 

``` 


### [Exam task example 6](https://github.com/ViktorUJ/cks/tree/master/tasks/ckad/mock/01) 


|        **6**        | **Update the environment variable on the pod text-printer.**                                                 |
| :-----------------: | :----------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                              |
| Acceptance criteria | - Change the value of the environment variable to `GREEN`<br/>- Ensure that the logs of the pod was updated. |


```
k get pod text-printer -o yaml > 6.yaml

k delete pod text-printer

``` 
``` 
# vim 6.yaml
...
  env:
    - name: COLOR
      value: GREEN
...
```

```
k apply -f 6.yaml

check_result 
```

[Setting up command autocompletion, aliases](https://kubernetes.io/ru/docs/reference/kubectl/cheatsheet/)

**On the exam, always use aliases, command autocompletion and manifest generation**
