# Allowed resources

## **Kubernetes Documentation:**

<https://kubernetes.io/docs/> and their subdomains

<https://kubernetes.io/blog/> and their subdomains

<https://helm.sh/> and their subdomains

This includes all available language translations of these pages (e.g. <https://kubernetes.io/zh/docs/>)

![preview](./preview.png)

- run ``time_left`` on work pc to **check time**
- run ``check_result`` on work pc to **check result**

## Questions

|        **1**        | **Deploy a pod named webhttpd**                                                |
| :-----------------: | :----------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                |
| Acceptance criteria | - Name: `webhttpd` <br/>- Image: `httpd:alpine`<br/>- Namespace: `apx-z993845` |
---
|        **2**        | **Create a new Deployment named `nginx-app`**                                   |
| :-----------------: | :------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                 |
| Acceptance criteria | - Deployment: `nginx-app` <br/>- Image: `nginx:alpine-slim`<br/>- Replicas: `2` |
---
|        **3**        | **Create secret and  create pod with  environment variable  from secret .**                                                                                                                                  |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                              |
| Acceptance criteria | - secret: ns=`dev-db` name=`dbpassword` key=`pwd` value=`my-secret-pwd`  <br/>- pod: ns=`dev-db` name=`db-pod` image=`mysql:8.0` env.name=`MYSQL_ROOT_PASSWORD` env.value=from secret `dbpassword` key=`pwd` |
---
|        **4**        | **Fix replicaset `rs-app2223` in namespace `rsapp`**            |
| :-----------------: | :-------------------------------------------------------------- |
|     Task weight     | 2%                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`) |
| Acceptance criteria | - ReplicaSet has 2 Ready replicas.                              |
---
|        **5**        | **Create deployment  `msg`  and service `msg-service`**                                                                                                                                                                         |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 2%                                                                                                                                                                                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                 |
| Acceptance criteria | - Deployment : ns=`messaging` name=`msg` image=`redis` replicas=`2`  <br/>- Service: name=`msg-service` Port=`6379` Namespace=`messaging` deployment=`msg` <br/>- Use the right type of Service  <br/>- Use imperative commands |
---
|        **6**        | **Update the environment variable on the pod text-printer.**                                                 |
| :-----------------: | :----------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                              |
| Acceptance criteria | - Change the value of the environment variable to `GREEN`<br/>- Ensure that the logs of the pod was updated. |
---
|        **7**        | **Run pod `appsec-pod` with `ubuntu:22.04` image as root user and with SYS_TIME capability.**                                                              |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                            |
| Acceptance criteria | - Pod name: `appsec-pod` <br/>- Image: `ubuntu:22.04`<br/>- Command: `sleep 4800`<br/>- Container user: `root`<br/>- Allow container capability `SYS_TIME` |
---
|        **8**        | **Export the logs of the pod `app-xyz3322` to a file located at `/opt/logs/app-xyz123.log`. The pod is located in a different namespace. First, identify the namespace where the pod is running.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                    |
| Acceptance criteria | - Logs at `/opt/logs/app-xyz123.log`                                                                                                                                                               |
---
|        **9**        | **Add a taint to the node with label work_type=redis. Create a pod  with toleration.**                                                                                                                                                                            |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                                                                                |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                   |
| Acceptance criteria | - Tains node with label `work_type=redis` :<br/>    key: `app_type`, value: `alpha`, effect: `NoSchedule`<br/>- Create a pod called `alpha`, `image: redis` with toleration to node01.<br/>- node01 with the correct taint? Pod alpha has the correct toleration? |
---
|       **10**        | **Apply a label `app_type=beta` to node controlplane. Create a new deployment called `beta-apps` with `image: nginx` and `replicas: 3`. Run  PODs on controlplane only.**             |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 4%                                                                                                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                       |
| Acceptance criteria | - controlplane has the labels `app_type=beta`<br/>- Deployment `beta-apps` <br/>- Pods of deployment are running only on controlplane?<br/>- Deployment beta-apps has 3 pods running? |
---
|       **11**        | **Create new ingress resource to the service. Make it available at the path `/cat`**                                                                                    |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                         |
| Acceptance criteria | - NameSpace: cat <br/>- service: cat  <br/>- Annotation: `nginx.ingress.kubernetes.io/rewrite-target: /`<br/>- path: `/cat`  <br/>- check ` curl ckad.local:30102/cat ` |
---
|       **12**        | **Create a new pod called `nginx1233` in the `web-ns` namespace with the image `nginx`. Add a livenessProbe to the container to restart it if the command `ls /var/www/html/` probe fails. This check should start after a delay of 10 seconds and run every 60 seconds.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                            |
| Acceptance criteria | - You may delete and recreate the object. Ignore the warnings from the probe.<br/>- Pod: `nginx1233`, namespace: `web-ns`, image `nginx`,  livenessProbe?                                                                                                                  |
---
|       **13**        | **Create a job with the image busybox and name hi-job that executes the command 'echo hello world'.**                                                 |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 3%                                                                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                       |
| Acceptance criteria | - Job name: `hi-job` <br/> - Image: `busybox`<br/>- Command: `echo hello world`<br/>- completions: 3<br/>- backoffLimit: 6<br/>- RestartPolicy: Never |
---
|       **14**        | **Create a pod called `multi-pod` with two containers.**                                                                                                                                                                                             |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                      |
| Acceptance criteria | container 1:<br/>   - name: `alpha`, image: `nginx:alpine-slim`<br/>    - environment variable: `type: alpha`<br/>container 2:<br/>    - name: `beta`, image: `busybox`<br/>    - command: `sleep 4800`<br/>    - environment variable: `type: beta` |
---
|       **15**        | **Create a Persistent Volume with the given specification. Run pod with pv.**                                                                                                                                                                                                                                                          |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 8%                                                                                                                                                                                                                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                        |
| Acceptance criteria | - Volume name: `pv-analytics`<br/>- pvc name: `pvc-analytics`<br/>- Storage: `100Mi`<br/>- Access mode: `ReadWriteOnce`<br/>- Host path: `/pv/analytics`<br/><br/>- pod name: `analytics`<br/>- image: `busybox`<br/>- node: `nodeSelector`<br/>-  node_name: `node_2`<br/>- command: `"sleep 60000"`<br/>- mountPath: `/pv/analytics` |
---
|       **16**        | **Create a CustomResourceDefinition definition and then apply it to the cluster**                                                                                                                                                                           |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                                                                                                                                                                                          |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                             |
| Acceptance criteria | - Name: `operators.stable.example.com`<br/>- Group : `stable.example.com`<br/>- Schema: `<email: string><name: string><age: integer>`<br/>- Scope: `Namespaced`<br/>- Names: `<plural: operators><singular: operator><shortNames: op>`<br/>Kind: `Operator` |
---
|       **17**        | **Write two cli commands to get the top  nodes and top pods  in all namespaces sorted by CPU utilization level. Place these shell commands in the necessary files.**        |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2 %                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                             |
| Acceptance criteria | - Get top nodes and save the command to get this info to `/opt/18/nodes.txt`<br/>- Get pods utilization and sort them by CPU consumtion. Save command to `/opt/18/pods.txt` |
---
|       **18**        | **Add prometheus helm repo and install prometheus chart to the cluster.**                                                                                                                                                                                                        |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                                                                                               |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                  |
| Acceptance criteria | - Add repo `prometheus-community` `https://prometheus-community.github.io/helm-charts`<br/>- Install prometheus from the helm chart to kubernetes cluster<br/>    - Release name: `prom`, namespace: `monitoring`<br/>- helm chart: `prometheus-community/kube-prometheus-stack` |
---
