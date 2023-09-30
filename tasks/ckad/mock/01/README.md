# Allowed resources

## **Kubernetes Documentation:**

<https://kubernetes.io/docs/> and their subdomains

<https://kubernetes.io/blog/> and their subdomains

This includes all available language translations of these pages (e.g. <https://kubernetes.io/zh/docs/>)

## Questions

|        **1**        | **Deploy a pod named webhttpd using the httpd:alpine image in the `webapp` namespace** |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                        |
| Acceptance criteria | - Name: `webhttpd` <br/>- Image: `httpd:alpine`<br/>- Namespace: `apx-z993845`         |
---
|        **2**        | **Create a new Deployment named `nginx-app` with 3 replicas using image `nginx:alpine-slim`** |
| :-----------------: | :-------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                            |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                               |
| Acceptance criteria | - Deployment: `nginx-app` <br/>- Image: `nginx:alpine-slim`<br/>- Replicas: `2`               |
---
|        **3**        | **Deploy a db pod using the `mysql:8.0` with the labels set to `type=db` in the `dev-db` namespace. Create a secret with the name of dbpassword with the value `my-secret-pw`. Use this secret to define a value for environment variable `MYSQL_ROOT_PASSWORD` to set root password for database** |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 8%                                                                                                                                                                                                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                     |
| Acceptance criteria | - Name: `db-pod` <br/>- Image: `mysql:8.0`<br/>- Labels: `type=db`<br/>- Namespace: `dev-db`<br/>- Secret Name: `dbpassword`<br/>- Secret value: `my-secret-pw`<br/>-Use environment variable `MYSQL_ROOT_PASSWORD` and value of the secret to set up the password for db                           |
---
|        **4**        | **A replicaset `rs-app2223` is created. However the pods are not coming up. Identify and fix the issue.** |
| :-----------------: | :-------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                        |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                           |
| Acceptance criteria | - Once fixed, ensure the ReplicaSet has 4 Ready replicas.                                                 |
---
|        **5**        | **Create a service `msg-service` to expose the redis deployment in the `messaging` namespace within the cluster on port `6379`. Use imperative command.** |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                                                        |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                           |
| Acceptance criteria | - Use imperative commands <br/>- Service: `msg-service`<br/>- Port: `6379`<br/>- `messaging` namespace<br/>- Use the right type of Service                |
---
|        **6**        | **Update the environment variable on the pod text-printer.**                                                       |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------- |
|     Task weight     | ?%                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                    |
| Acceptance criteria | - Use imperative commands <br/>- Service: `messaging-service`<br/>-Port: `6379`<br/>-Use the right type of Service |
---
|        **7**        | ** Run pod `appsec-pod` with `ubuntu:22.04` image as root user and with SYS_TIME capability .**                     |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | ?%                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                     |
| Acceptance criteria | - Pod name: `appsec-pod` <br/>- Image: `ubuntu:22.04`<br/>- User: `root`<br/>- SecurityContext: Capability SYS_TIME |
---
|        **8**        | **Export the logs of the pod `app-xyz3322` to a file located at `/var/logs/app-xyz123.log`. The pod is located in a different namespace. First, identify the namespace where the pod is running.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                    |
| Acceptance criteria | - Logs at `/var/logs/app-xyz123.log`                                                                                                                                                               |
---
|        **9**        | **Add a taint to the node node01 of the cluster. Create a pod called alpha, image: redis with toleration to node01.**                                                                                                                 |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                                                                                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                       |
| Acceptance criteria | - Tains node01:<br/>    key: `app_type`, value: `alpha`, effect: `NoSchedule`<br/>- Create a pod called `alpha`, `image: redis` with toleration to node01.<br/>- node01 with the correct taint? Pod alpha has the correct toleration? |
---
|       **10**        | **Apply a label `app_type=beta` to node controlplane. Create a new deployment called `beta-apps` with `image: nginx` and `replicas: 3`. Set Node Affinity to the deployment to place the PODs on controlplane only.**                                                                                                                                                                                                                                   |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                                                                                         |
| Acceptance criteria | - NodeAffinity: requiredDuringSchedulingIgnoredDuringExecution<br/>- controlplane has the correct labels?<br/>- Deployment beta-apps: NodeAffinity set to requiredDuringSchedulingIgnoredDuringExecution ?<br/>- Deployment beta-apps has correct Key for NodeAffinity?<br/>- Deployment beta-apps has correct Value for NodeAffinity?<br/>- Deployment beta-apps has pods running only on controlplane?<br/>- Deployment beta-apps has 3 pods running? |
---
