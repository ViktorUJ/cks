# Allowed resources

## **Kubernetes Documentation:**

<https://kubernetes.io/docs/> and their subdomains

<https://kubernetes.io/blog/> and their subdomains

This includes all available language translations of these pages (e.g. <https://kubernetes.io/zh/docs/>)

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
|        **3**        | **Deploy a db pod using the `mysql:8.0` with the labels set to `type=db` in the `dev-db` namespace. Create a secret with the name of dbpassword with the value `my-secret-pw`. Use this secret to define a value for environment variable `MYSQL_ROOT_PASSWORD` to set root password for database** |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                     |
| Acceptance criteria | - Name: `db-pod` <br/>- Image: `mysql:8.0`<br/>- Labels: `type=db`<br/>- Namespace: `dev-db`<br/>- Secret Name: `dbpassword`<br/>- Secret key: `pwd`<br/>- Secret value: `my-secret-pw`<br/>- Use environment variable `MYSQL_ROOT_PASSWORD` and value of the secret to set up the password for db  |
---
|        **4**        | **A replicaset `rs-app2223` in namespace `rsapp` is created. However the pods are not coming up. Identify and fix the issue.** |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                |
| Acceptance criteria | - ReplicaSet has 2 Ready replicas.                                                                                             |
---
|        **5**        | **Create a service `msg-service` to expose the `msg` deployment with `redis` image in the `messaging` namespace within the cluster on port `6379`. Use imperative commands.** |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                                            |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                               |
| Acceptance criteria | - Use imperative commands <br/>- Service: `msg-service`<br/>- Port: `6379`<br/>- Namespace: `messaging`<br/>- Use the right type of Service                                   |
---
|        **6**        | **Update the environment variable on the pod text-printer.**                                                 |
| :-----------------: | :----------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                              |
| Acceptance criteria | - Change the value of the environment variable to `GREEN`<br/>- Ensure that the logs of the pod was updated. |
---
|        **7**        | **Run pod `appsec-pod` with `ubuntu:22.04` image as root user and with SYS_TIME capability.**                                                              |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                            |
| Acceptance criteria | - Pod name: `appsec-pod` <br/>- Image: `ubuntu:22.04`<br/>- Command: `sleep 4800`<br/>- Container user: `root`<br/>- Allow container capability `SYS_TIME` |
---
|        **8**        | **Export the logs of the pod `app-xyz3322` to a file located at `/opt/logs/app-xyz123.log`. The pod is located in a different namespace. First, identify the namespace where the pod is running.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                    |
| Acceptance criteria | - Logs at `/opt/logs/app-xyz123.log`                                                                                                                                                               |
---
|        **9**        | **Add a taint to the node node01 of the cluster. Create a pod called alpha, image: redis with toleration to node01.**                                                                                                                 |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 2%                                                                                                                                                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                       |
| Acceptance criteria | - Tains node01:<br/>    key: `app_type`, value: `alpha`, effect: `NoSchedule`<br/>- Create a pod called `alpha`, `image: redis` with toleration to node01.<br/>- node01 with the correct taint? Pod alpha has the correct toleration? |
---
|       **10**        | **Apply a label `app_type=beta` to node controlplane. Create a new deployment called `beta-apps` with `image: nginx` and `replicas: 3`. Set Node Affinity to the deployment to place the PODs on controlplane only.**                                                                                                                                                                 |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                                                                                                                                                                                                                                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                       |
| Acceptance criteria | - NodeAffinity: `requiredDuringSchedulingIgnoredDuringExecution`<br/>- controlplane has the labels `app_type=beta`<br/>- Deployment `beta-apps`<br/>- Deployment beta-apps has correct Key for NodeAffinity?<br/>- Deployment beta-apps has correct Value for NodeAffinity?<br/>- Pods of deployment are running only on controlplane?<br/>- Deployment beta-apps has 3 pods running? |
---
|       **11**        | **Create new ingress resource to the service. Make it available at the path `/cat`**                                                                                      |
| :-----------------: |:------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | ?%                                                                                                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                         |
| Acceptance criteria | - NameSpace: cat <br/>- service: cat  <br/>- Annotation: `nginx.ingress.kubernetes.io/rewrite-target: /`<br/>- path: `/cat`  <br/>- check ` curl ckad.local:30102/cat ` |
---
|       **12**        | **Create a new pod called `nginx1233` in the `web-ns` namespace with the image `nginx`. Add a livenessProbe to the container to restart it if the command `ls /var/www/html/` probe fails. This check should start after a delay of 10 seconds and run every 60 seconds.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                            |
| Acceptance criteria | - You may delete and recreate the object. Ignore the warnings from the probe.<br/>- Pod: `nginx1233`, namespace: `web-ns`, image `nginx`,  livenessProbe?                                                                                                                  |
---
|       **13**        | **Create a job with the image busybox and name hi-job that executes the command 'echo hello;sleep 30;echo world'.**                                                 |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | ?%                                                                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                     |
| Acceptance criteria | - Job name: `hi-job` <br/> - Image: `busybox`<br/>- Command: `echo hello;sleep 30;echo world`<br/>- Completions: 3<br/>- BackoffLimit: 6<br/>- RestartPolicy: Never |
---
|       **14**        | **Create a pod called `multi-pod` with two containers.**                                                                                                                                                                                             |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                      |
| Acceptance criteria | container 1:<br/>   - name: `alpha`, image: `nginx:alpine-slim`<br/>    - environment variable: `type: alpha`<br/>container 2:<br/>    - name: `beta`, image: `busybox`<br/>    - command: `sleep 4800`<br/>    - environment variable: `type: beta` |
---
|       **15**        | **Create a PersistentVolume called `my-volume` with size: `50MiB` reclaim policy: `retain`, Access Modes: `ReadWriteMany` and hostPath: `/opt/data`**    |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                       |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                          |
| Acceptance criteria | - PersistentVolume `my-volume`<br/>- Volume size: `50MiB`<br/>- Reclaim policy: `retain`<br/>- Access Modes: `ReadWriteMany`<br/>- hostPath: `/opt/data` |
---
|       **16**        | **Create a CustomResourceDefinition definition and then apply it to the cluster**                                                                                                                                                                           |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                                                                          |
|       Cluster       | cluster2 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                             |
| Acceptance criteria | - Name: `operators.stable.example.com`<br/>- Group : `stable.example.com`<br/>- Schema: `<email: string><name: string><age: integer>`<br/>- Scope: `Namespaced`<br/>- Names: `<plural: operators><singular: operator><shortNames: op>`<br/>Kind: `Operator` |
---
|       **17**        | **Write two cli commands to get utilisation of the nodes and pods in all namespaces sorted by CPU utilization. Put this shell commands to the required files.**                                           |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2 %                                                                                                                                                                                                       |
|       Cluster       | cluster2 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                           |
| Acceptance criteria | - Get CPU and Memory utilisation of the nodes and save the command to get this info to `/opt/18/nodes.txt`<br/>- Get pods utilization and sort them by CPU consumtion. Save command to `/opt/18/pods.txt` |
---
|       **18**        | **Add prometheus helm repo and install prometheus chart to the cluster.**                                                                                                                                                                                                        |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                                                                                                                                               |
|       Cluster       | cluster2 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                  |
| Acceptance criteria | - Add repo `prometheus-community` `https://prometheus-community.github.io/helm-charts`<br/>- Install prometheus from the helm chart to kubernetes cluster<br/>    - Release name: `prom`, namespace: `monitoring`<br/>- helm chart: `prometheus-community/kube-prometheus-stack` |
---
