[README_RU](README_RU.MD)

## [video](https://www.youtube.com/watch?v=vTvTGCol1pk)

## [presentation](https://www.canva.com/design/DAGWcfZPJs4/-hiEe3YOJB2bSEw2r3WAag/view?utm_content=DAGWcfZPJs4&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h40df1da1b4)

# 2 CKAD 


### [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

### Probe Types

| **Probe Type**          | **When Applied**                               | **What Happens if Probe Fails**                                                                                                                                                  | **Interaction with Other Probes**                                                                                                                                                    |
|------------------------|-------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Liveness Probe**     | Regularly during container lifecycle     | Container **restarts** if it fails the `liveness` check. This prevents container hangs and keeps it in working state.                         | Only starts after successful completion of `startup` check, if configured.                                                                                           |
| **Readiness Probe**    | After container startup and during operation    | Container is **excluded from load balancing** until it passes the `readiness` check. Kubernetes won't send traffic to the container until it's ready to handle requests. | Only starts after successful completion of `startup` check, if configured.                                                                                           |
| **Startup Probe**      | Only during initial container startup      | If container fails the `startup` check within the specified period, Kubernetes considers it unable to initialize and restarts the container.                        | Blocks execution of `liveness` and `readiness` checks until `startup` check completes successfully. Helps avoid premature checks during long initialization. |


### Probe Check Types


| **Check Type** | **Description**                                                                                                                                                                                                   |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **httpGet**      | Sends an HTTP request to the specified port and path. Check is considered successful if it returns a status code in the 200–399 range.                                                                                            |
| **tcpSocket**    | Attempts to establish a TCP connection on the specified port. If connection is established successfully, the check is considered passed.                                                                                     |
| **exec**         | Executes the specified command inside the container. Check is considered successful if the command exits with code 0.                                                                                                        |
| **grpc**         | Sends a gRPC request to the specified port and, if necessary, to a specific service. Check is considered successful if the gRPC service responds with `SERVING` status. Requires implementation of the standard gRPC Health Checking Protocol. |




###  Probes are managed by kubelet (checks probes without API server involvement)





### Configuring Endpoints for Kubernetes Probes

To prepare endpoints that will be used in Kubernetes probes, you can implement **Readiness** and **Liveness** endpoints with different functionality:

1. **Readiness Probe Endpoint** (`/ready`):
   - Checks application readiness to handle requests, including established connections to databases, caches, and external services.
   - Returns HTTP status **200 OK** when fully ready and **503 Service Unavailable** if connections to databases or other external services are not established.

2. **Liveness Probe Endpoint** (`/health`):
   - Simple endpoint checking that the application is running and not hung.
   - Returns HTTP status **200 OK** when application is working successfully.


###  Practice. Creating Probes.


Let's create a pod in `default` NS named `pod1` with image `viktoruj/ping_pong:alpine` and environment variable `SRV_PORT`=`80`




[viktoruj/ping_pong:alpine](https://github.com/ViktorUJ/cks/tree/master/docker/ping_pong) - this is an image with an HTTP server that returns in its response all meta-information of the incoming request, including the sender's IP address, all request parameters and headers. Server configuration can be changed using environment variables:



```
k run pod2 --image  viktoruj/ping_pong:alpine --env SRV_PORT=80 -o yaml --dry-run=client > 1.yaml

```

``` 
# vim 1.yaml

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "80"
    image: viktoruj/ping_pong:alpine
    name: pod2
    livenessProbe:                        # add it - probe type
      httpGet:                            # add it - check type
        path: /healthz                    # add it 
        port: 80                          # add it 
        httpHeaders:                      # add it - sets HTTP request headers if needed
        - name: Custom-Header             # add it 
          value: Awesome                  # add it 
      initialDelaySeconds: 3              # add it - wait time before first check
      periodSeconds: 3                    # add it - check frequency
      failureThreshold: 5                 # add it - number of failed checks before container restart

    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}


``` 
``` 
k apply -f 1.yaml

```
Let's check the pod logs to make sure the probe is working
```
k logs  pod2 
```
``` 
Server Name: ping_pong_server                   
URL: http://10.0.130.194:80/healthz
Client IP: 10.2.13.62                           # node IP address where pod is running, since kubelet only checks probes of its own pods
Method: GET
Protocol: HTTP/1.1
Headers:
User-Agent: kube-probe/1.30
Accept: */*
Custom-Header: Awesome                          # header we set in the probe
Connection: close
```


Let's simulate a situation where **livenessProbe** fails

``` 
k delete -f 1.yaml
vim 1.yaml
```


``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "9111"                       # add it - change HTTP server port
    image: viktoruj/ping_pong:alpine
    name: pod2
    livenessProbe:                        # add it - probe type
      httpGet:                            # add it - check type
        path: /healthz                    # add it 
        port: 80                          # add it 
        httpHeaders:                      # add it - sets HTTP request headers if needed
        - name: Custom-Header             # add it 
          value: Awesome                  # add it 
      initialDelaySeconds: 3              # add it - wait time before first check
      periodSeconds: 3                    # add it - check frequency
      failureThreshold: 5                 # add it - number of failed checks before container restart

    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```


``` 
k apply -f 1.yaml

```

``` 
k get po pod2
```
``` 
NAME   READY   STATUS    RESTARTS      AGE
pod2   1/1     Running   1 (15s ago)   33s      # occurred because probe failed 5 times every 3 seconds and kubelet restarted the pod
                                                # but since we didn't set Readiness, the pod was immediately included in load balancing 
```
Let's change the HTTP server port to **80** and add **Readiness** probe on port **9111**, and **Liveness** probe on port 80.


Let's simulate a situation where **Readiness** probe fails.
In this case, the pod won't be forcibly restarted and simply won't be included in load balancing until the **Readiness** probe passes.

``` 
k delete -f 1.yaml
vim 1.yaml
```


``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "80"                       # add it - change HTTP server port
    image: viktoruj/ping_pong:alpine
    name: pod2
    livenessProbe:                        # add it - probe type
      httpGet:                            # add it - check type
        path: /healthz                    # add it 
        port: 80                          # add it 
      initialDelaySeconds: 3              # add it - wait time before first check
      periodSeconds: 3                    # add it - check frequency
      failureThreshold: 3                 # add it - number of failed checks before container restart
    readinessProbe:                       # add it - probe type
      httpGet:                            # add it - check type
        path: /readiness                  # add it 
        port: 9111                        # add it 
      initialDelaySeconds: 9              # add it - wait time before first check
      periodSeconds: 5                    # add it - check frequency
      failureThreshold: 1                 # add it - number of failed checks before container restart      
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```


``` 
k apply -f 1.yaml

```




``` 
k get po pod2
```

``` 

NAME   READY   STATUS    RESTARTS   AGE
pod2   0/1     Running   0          22s   # pod is not included in load balancing until Readiness probe passes, but won't restart

```



### Common Mistakes When Configuring Probes


| **Mistake**                                           | **What It Leads To**                                                                                                                                                                                             |
|------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| No **Liveness Probe**                               | Kubernetes won't restart the container when it hangs or stops, which can lead to prolonged application unavailability.                                                                                                 |
| No **Readiness Probe**                              | Kubernetes will start sending traffic to the container before the application is fully ready to handle requests. Or will send requests when the application cannot process them (lost database connection, etc.). |
| **Liveness** and **Readiness** probes point to the same endpoint | Temporary issues with external dependencies (e.g., database) may cause container restart, even though it could recover on its own.                                                                                    |
| No **Startup Probe** for slowly starting applications | **Liveness** and **Readiness** probes may start checks before full application load completes, leading to premature restarts.                                                                                 |



``` 
k delete -f 1.yaml
```

### [Exam Task Example 12](https://github.com/ViktorUJ/cks/tree/master/tasks/ckad/mock/01) 

---
|       **12**        | **Create a new pod called `nginx1233` in the `web-ns` namespace with the image `nginx`. Add a livenessProbe to the container to restart it if the command `ls /var/www/html/` probe fails. This check should start after a delay of 10 seconds and run every 60 seconds.** |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                            |
| Acceptance criteria | - You may delete and recreate the object. Ignore the warnings from the probe.<br/>- Pod: `nginx1233`, namespace: `web-ns`, image `nginx`,  livenessProbe?                                                                                                                  |
---

``` 
k create ns web-ns

k run nginx1233 --namespace web-ns --image nginx --dry-run=client -o yaml > 12.yaml
```


``` 
# vim 12.yaml

apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx1233
  name: nginx1233
  namespace: web-ns
spec:
  containers:
  - image: nginx
    name: nginx1233                       
    livenessProbe:                         # add it
      exec:                                # add it
        command:                           # add it
        - ls                               # add it
        - /var/www/html/                   # add it
      initialDelaySeconds: 10              # add it
      periodSeconds: 60                    # add it
```
```
k apply -f 12.yaml
```
```
check_result

```

```
-----
 ✓ 12.1 Create a new pod nginx1233 in the web-ns namespace.command
 ✓ 12.2 Create a new pod nginx1233 in the web-ns namespace.delay and period
 
-----


```

### [Requests, Limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)


### [QoS](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)


### [PriorityClass](https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/)



Let's create a pod in `default` NS named `pod2` with image `viktoruj/ping_pong:alpine` and environment variables: 

`ENABLE_LOAD_MEMORY`=`true` 
`ENABLE_LOAD_CPU`=`true` 
`MEMORY_USAGE_PROFILE`=`5=10 7=60`
`CPU_USAGE_PROFILE`=`'1=400=1=60'`


``` 
 k run pod2 --image viktoruj/ping_pong:alpine --env ENABLE_LOAD_MEMORY=true --env ENABLE_LOAD_CPU=true --env MEMORY_USAGE_PROFILE="5=10 7=60" --env CPU_USAGE_PROFILE="1=400=1=60" -o yaml --dry-run=client > 2.yaml
```

``` 
k apply -f 2.yaml

k get  po pod2 
```
``` 
NAME   READY   STATUS    RESTARTS   AGE
pod2   1/1     Running   0          22s

```

For **kubectl top** to work, Metrics Server is needed. Let's check its presence
``` 
kubectl get deployment metrics-server -n kube-system

NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           115m

```
or 

``` 
kubectl get po  -n kube-system | grep  metrics-server

```


Let's check our pod's consumption


``` 
k top po pod2 
```
``` 
NAME   CPU(cores)   MEMORY(bytes)
pod2   63m          9Mi


```

Let's check our pod's QoS

``` 
k describe po pod2
```

```
------

QoS Class:                   BestEffort

------


```

BestEffort is the lowest QoS level, assigned by default when resources are not specified. Pods with this QoS class have no guaranteed access to resources and can be killed if the node runs out of resources.

Let's add requests and limits equal to each other, +30% of our consumption.


``` 
k delete -f 2.yaml

vim 2.yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: ENABLE_LOAD_MEMORY
      value: "true"
    - name: ENABLE_LOAD_CPU
      value: "true"
    - name: MEMORY_USAGE_PROFILE
      value: 5=10 7=60
    - name: CPU_USAGE_PROFILE
      value: 1=400=1=60
    image: viktoruj/ping_pong:alpine
    name: pod2
    resources:
      requests:
        memory: "10Mi"
        cpu: "1300m"
      limits:
        memory: "10Mi"
        cpu: "1300m"
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}



```

```
k apply -f 2.yaml

k describe   po pod2 
```
```

QoS Class:                   Guaranteed


```

Let's create a situation where our pod exceeds memory limits.



``` 
k delete -f 2.yaml

vim 2.yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod2
  name: pod2
spec:
  containers:
  - env:
    - name: ENABLE_LOAD_MEMORY
      value: "true"
    - name: ENABLE_LOAD_CPU
      value: "true"
    - name: MEMORY_USAGE_PROFILE
      value: 5=10 70=60                     # update it
    - name: CPU_USAGE_PROFILE
      value: 1=400=1=60
    image: viktoruj/ping_pong:alpine
    name: pod2
    resources:
      requests:
        memory: "10Mi"
        cpu: "1000m"                       
      limits:
        memory: "10Mi"
        cpu: "1300m"
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}



```

```
k apply -f 2.yaml

k describe   po pod2 
```

``` 
QoS Class:                   Burstable     # since limits don't equal requests

```

``` 
ubuntu@worker:~> k get po pod2
NAME   READY   STATUS    RESTARTS      AGE
pod2   1/1     Running   2 (16s ago)   77s


```
``` 
k describe   po pod2
```
``` 
------
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Mon, 11 Nov 2024 06:20:04 +0000
      Finished:     Mon, 11 Nov 2024 06:20:34 +0000
    Ready:          False
------

```
This happened because our pod exceeded memory limits and was killed by kubelet

A similar situation can be observed when we exceed available memory volume, then kubelet kills pods depending on PriorityClass and QoS.



When CPU limits are exceeded, kubelet doesn't kill pods but simply enables throttling, which leads to pod slowdown.

We have a [lab work](https://github.com/ViktorUJ/cks/blob/master/docs/..%2Ftasks%2Fcka%2Flabs%2F07%2FREADME.MD) where we can try this in practice. [solution](https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/07/worker/files/solutions/1.MD)



# PriorityClass

Get existing PriorityClasses

```
k get priorityclasses

```

``` 
NAME                      VALUE        GLOBAL-DEFAULT   AGE
system-cluster-critical   2000000000   false            18m
system-node-critical      2000001000   false            18m

```

Create PriorityClass named `high-priority` with value `1000000000`

```
k create priorityclass high-priority --value 1000000000 

k get priorityclasses

 
```
Create pod manifest and add PriorityClass `high-priority` to it

``` 
k run pod3 --image viktoruj/ping_pong:alpine   -o yaml --dry-run=client > 3.yaml

vim 3.yaml
``` 

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod3
  name: pod3
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: pod3
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
  priorityClassName: high-priority                  # add it
status: {}

 
```
``` 
k apply -f 3.yaml
k describe po pod3
```
``` 
Name:                 pod3
Namespace:            default
Priority:             1000000000
Priority Class Name:  high-priority

-------

```

You can practice this in more detail in the [lab work](https://github.com/ViktorUJ/cks/blob/master/docs/..%2Ftasks%2Fcka%2Flabs%2F05%2FREADME.MD). Solution can be found [here](https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/05/worker/files/solutions/1.MD)


### [Twelve-Factor App](https://12factor.net/ru/)

### [Ephemeral containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/) - needed for debugging and diagnostics. If images are built correctly, they won't contain anything extra except executables and libraries. Ideally, a **Scratch** image will be used, which weighs 0 bytes.



| Ephemeral Container Capabilities | Description |
|-----------------------------------|----------|
| Works without pod restart     | Temporary container can be started without needing to restart the entire pod. |
| Can attach to any container in the pod | Temporary container allows attaching to any container inside the pod. |
| Can attach to pods with CrashLoop | Temporary container can attach even to pods in CrashLoop state. |
| Can track processes in any container | You can track processes inside any container in the pod using a temporary container. |
| Has access to any container's filesystem | Temporary container can work with the filesystem of any container in the pod. |
| Has the same network as any container in the pod | Temporary container has a shared network interface with other containers in the pod. |
| Can use any Docker image for the temporary container | You can run a temporary container using any Docker image. |


``` 
kubectl   debug  -it   {pod_name} --image {ephemeral_container_image}    -n {k8s_name_space} --target {container_name_in_pod}
```


Let's create a pod in `default` NS named `pod4` with image `viktoruj/ping_pong`. This image doesn't have `bash, sh, etc` utilities, so we won't be able to connect to it via `kubectl exec` or execute any commands inside the pod.

``` 

k run pod4 --image viktoruj/ping_pong

k get po pod4
```

Let's connect to the pod via `kubectl exec` (should get an error)

```
k exec -ti  pod4 -- sh
error: Internal error occurred: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "f1ba06eb91523589c2bae6c098e3140024e88e89d54debee4004e0fc0fe37686": OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH: unknown

```

Let's connect to the pod via `kubectl debug` 

```
kubectl   debug  -it   pod4  --image ubuntu --target pod4 
 
```
Get PIDs of running processes inside the container
``` 
ps -aux

USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.1 1233220 5284 ?        Ssl  19:15   0:00 /app         # PID 1 is our HTTP server
root          20  0.0  0.0   4296  3128 pts/0    Ss   19:16   0:00 /bin/bash
root        2950  0.0  0.0   7628  3604 pts/0    R+   19:22   0:00 ps -aux


```
Get list of files from our main container
``` 
ls /proc/1/root/
app  dev  etc  proc  sys  var

```
### [Logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)


Let's create a pod in `default` NS named `pod5` with two containers: 
- `app` with image `viktoruj/ping_pong` and envs `SRV_PORT=8080` `SERVER_NAME=app` 
- `side-car` with image `viktoruj/ping_pong` and envs `SRV_PORT=8081` `SERVER_NAME=side-car`  

```
k run pod5 --image viktoruj/ping_pong --env SRV_PORT=8080 --env SERVER_NAME=app --dry-run=client -o yaml > 5.yaml

``` 


``` 
# vim 5.yaml

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod5
  name: pod5
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "8080"
    - name: SERVER_NAME
      value: app
    image: viktoruj/ping_pong
    name: app
    resources: {}

  - env:
    - name: SRV_PORT
      value: "8081"
    - name: SERVER_NAME
      value: side-car
    image: viktoruj/ping_pong
    name: side-car
    resources: {}

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}


```

``` 
k apply -f 5.yaml
k get po pod5

```
``` 
NAME   READY   STATUS    RESTARTS   AGE
pod5   2/2     Running   0          4m16s

```

Get logs from `app` container in `pod5` pod

```
k logs pod5 -c app
```
``` 
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=pod5
SERVER_NAME=app                              
SRV_PORT=8080
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP_PROTO=tcp
HOME=/
enableLoadCpu: false, cpuMaxProc: 1

```

Get logs from `side-car` container in `pod5` pod

```
k logs pod5 -c side-car
```

``` 
k logs pod5 -c side-car -f   # get logs in real time

```

Add Label to our pod `app=http-server`

```
k delete -f 5.yaml
vim 5.yaml
```
``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod5
    app: http-server
  name: pod5
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "8080"
    - name: SERVER_NAME
      value: app
    image: viktoruj/ping_pong
    name: app
    resources: {}

  - env:
    - name: SRV_PORT
      value: "8081"
    - name: SERVER_NAME
      value: side-car
    image: viktoruj/ping_pong
    name: side-car
    resources: {}

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```
Create pod6 identical to pod5

```
cp 5.yaml 6.yaml
vim 6.yaml
```

``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod6
    app: http-server
  name: pod6
spec:
  containers:
  - env:
    - name: SRV_PORT
      value: "8080"
    - name: SERVER_NAME
      value: app
    image: viktoruj/ping_pong
    name: app
    resources: {}

  - env:
    - name: SRV_PORT
      value: "8081"
    - name: SERVER_NAME
      value: side-car
    image: viktoruj/ping_pong
    name: side-car
    resources: {}

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

```

``` 
k apply -f 6.yaml


```
Get all pods with label app=http-server
``` 
# k get po -l app=http-server 

NAME   READY   STATUS    RESTARTS   AGE
pod5   2/2     Running   0          2m40s
pod6   2/2     Running   0          7s

```

Get logs from all pods with **label** `app=http-server` and container **app**

```
k logs  -c app -l  app=http-server
```

Show logs with source prefix 
``` 
k logs  -c app --prefix  -l  app=http-server
```

```  
 k logs  -c app --prefix  -l  app=http-server
[pod/pod5/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod5/app] KUBERNETES_SERVICE_PORT=443
[pod/pod5/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod5/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod5/app] HOME=/
[pod/pod5/app] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod6/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod6/app] KUBERNETES_SERVICE_PORT=443
[pod/pod6/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod6/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod6/app] HOME=/
[pod/pod6/app] enableLoadCpu: false, cpuMaxProc: 1

```
Show logs from all containers in pods with **label** `app=http-server` and source prefix

```
k logs   --prefix  --all-containers   -l  app=http-server 
``` 
``` 
[pod/pod5/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod5/app] KUBERNETES_SERVICE_PORT=443
[pod/pod5/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod5/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod5/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod5/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod5/app] HOME=/
[pod/pod5/app] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod5/side-car] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod5/side-car] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod5/side-car] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod5/side-car] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod5/side-car] KUBERNETES_SERVICE_PORT=443
[pod/pod5/side-car] HOME=/
[pod/pod5/side-car] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod6/app] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod6/app] KUBERNETES_SERVICE_PORT=443
[pod/pod6/app] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod6/app] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod6/app] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod6/app] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod6/app] HOME=/
[pod/pod6/app] enableLoadCpu: false, cpuMaxProc: 1
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP_PORT=443
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
[pod/pod6/side-car] KUBERNETES_SERVICE_HOST=10.96.0.1
[pod/pod6/side-car] KUBERNETES_SERVICE_PORT=443
[pod/pod6/side-car] KUBERNETES_SERVICE_PORT_HTTPS=443
[pod/pod6/side-car] KUBERNETES_PORT=tcp://10.96.0.1:443
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
[pod/pod6/side-car] KUBERNETES_PORT_443_TCP_PROTO=tcp
[pod/pod6/side-car] HOME=/
[pod/pod6/side-car] enableLoadCpu: false, cpuMaxProc: 1

```

If the container restarted, you can view logs from the previous container with the `--previous` flag


### Init Containers

Let's create a pod in `default` NS named `pod7` with image `viktoruj/ping_pong:alpine` and init container `init` with image `viktoruj/ping_pong:alpine` and command `echo '**** init '; sleep 10`


```
k run pod7 --image viktoruj/ping_pong:alpine --dry-run=client -o yaml > 7.yaml

vim 7.yaml
```

```
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod7
  name: pod7
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: pod7
    resources: {}
  initContainers:                                          # add it
  - name: init                                             # add it
    image: viktoruj/ping_pong:alpine                       # add it
    command: ["sh", "-c", "echo '**** init '; sleep 10"]   # add it

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
 
```

``` 
#  k get po pod7

NAME   READY   STATUS     RESTARTS   AGE
pod7   0/1     Init:0/1   0          10s

```
Get init container logs

```
k logs  pod7  -c init

**** init

```

Let's simulate a situation where the init container exits with an error

```
k delete -f 7.yaml
vim 7.yaml

```

``` 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod7
  name: pod7
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: pod7
    resources: {}
  initContainers:                                          
  - name: init                                             
    image: viktoruj/ping_pong:alpine                       
    command: ["sh", "-c", "echo '**** init '; slerrrrep 10"]   # update it

  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

``` 
k apply -f 7.yaml
k get po pod7
```


```
NAME   READY   STATUS                  RESTARTS      AGE
pod7   0/1     Init:CrashLoopBackOff   1 (11s ago)   12s

```
Get init container logs

```
k logs  pod7  -c init
```

``` 
**** init
sh: slerrrrep: not found

```