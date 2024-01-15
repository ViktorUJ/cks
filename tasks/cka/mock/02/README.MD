# Allowed resources

## **Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)

## Questions

|        **1**        | find a pod in `dev-1` namespace with labels `team=finance` and maximum memory usage . Add label `usage=max` to it        |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                        |
| Acceptance criteria | - pod from `dev-1`  NS  <br/> - with label `team=finance` <br/> -  has max memory usage  <br/> - has label `usage=max` |
---
|        **2**        | Deploy a `util` pod using the `busybox:1.36` image in the `dev` namespace. Use `sleep 3600 command` to keep it running. |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                        |
| Acceptance criteria | - Pod Name: `util` <br/> - Namespace: `dev` <br/> - Image: `busybox:1.36`<br> - Commands: `sleep 3600`                 |
---
|        **3**        | Create a `namespace` named `team-elephant`                                       |
| :-----------------: |:--------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                 |
| Acceptance criteria | - Namespace: `team-elephant` <br/> Namespace is present in the namespaces list. |
---
|        **4**        | Create pod `alpine` with image `alpine:3.15` and and command `sleep 6000` . Make sure the pod  is running on node with label `disk=ssd`. |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                       |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                          |
| Acceptance criteria | - Pod is running on the node with label disk=ssd.                                                                                        |
---
|        **5**        | Create deployment `web-app` with image `viktoruj/ping_pong:latest` and `2` replicas. Container port should be configured on port `8080` and named `http-web`.         |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                      |
| Acceptance criteria | - Deployment name: `web-app`<br/> - Image: `viktoruj/ping_pong:latest`<br/> - Replicas: `2`<br/> Deployment pods are running, containers' ports 8080 named http-web. |
---
|        **6**        | Create a service `web-app-svc` to expose the `web-app` deployment on port `8080` on cluster nodes.                                                                             |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 3%                                                                                                                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                |
| Acceptance criteria | - Use imperative commands to create mainifest. <br/> - Service: `web-app-svc`<br/>- Port: `8080` <br/>- Type: `NodePort`<br/>- Use the right labels to select targer port.     |
---
|        **7**        | Create a pod `web-srv` based on image `viktoruj/ping_pong:latest` in the default namespace. The container in the pod should named `app1`.|
| :-----------------: |:--------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                       |
| Acceptance criteria | - Pod name: `web-srv`<br/>- Image: `viktoruj/ping_pong:latest`<br/>- Container name: `app1`                                           |
---
|        **8**        | 2 pods are running in the namespace `db-redis` named `redis-node-xxxx`. You need to scale down number of replicas to `1`. |
| :-----------------: |:--------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                        |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                           |
| Acceptance criteria | - Name: `redis-node-xxxx`<br/>- Number of pods running: 1 <br/> - Nuber of pods is scaled down to 1. <br/>                |
---
|        **9**        | Write cli commands with  shows pods from `dev-2` namespace in  `json` format . script is  located  `/var/work/artifact/9.sh` |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                    |
| Acceptance criteria | - script shows pods from `dev-2` namespace in json format <br/> - script is  located  `/var/work/artifact/9.sh`                    |
---
|       **10**        | **Create a Persistent Volume with the given specification. Run pod with pv.**                                                                                                                                                                                                                                                          |
|:-------------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 8%                                                                                                                                                                                                                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                        |
| Acceptance criteria | - Volume name: `pv-analytics`<br/>- pvc name: `pvc-analytics`<br/>- Storage: `100Mi`<br/>- Access mode: `ReadWriteOnce`<br/>- Host path: `/pv/analytics`<br/><br/>- pod name: `analytics`<br/>- image: `busybox`<br/>- node: `nodeSelector`<br/>-  node_name: `node_2`<br/>- command: `"sleep 60000"`<br/>- mountPath: `/pv/analytics` |
---
|       **11**        | **Update Kubernetes cluster.**                                                                                                                                   |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 7%                                                                                                                                                               |
|       Cluster       | cluster2 (`kubectl config use-context cluster2-admin@cluster2`)                                                                                                  |
| Acceptance criteria | - The cluster is running Kubernetes 1.28.0, update it to 1.28.4 .<br/>- Use apt package manager and kubeadm for this.<br/>- Use ssh to connect to the instances. |
---
|       **12**        | **Create new ingress resource to the service. Make it available at the path `/cat`**                                                                                   |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                        |
| Acceptance criteria | - NameSpace: cat <br/>- service: cat  <br/>- Annotation: `nginx.ingress.kubernetes.io/rewrite-target: /`<br/>- path: `/cat`  <br/>- check ` curl cka.local:30102/cat ` |
---
|        **13**        | In the Namespace `team-elephant` create a new ServiceAccount `pod-sa`. Assing an account permissions to `list and get` `pods` using Role `pod-sa-role`  and RoleBinding `pod-sa-roleBinding` |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 5%                                                                                                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                              |
| Acceptance criteria | - Pods are running in the Namespace team-elephant can be listed using pod-sa service account.                                                                                                |
---
|        **14**       | Create a **DaemonSet** named **team-elephant-ds**  with the requested parameters                                                                                                                                                                                                       |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 5%                                                                                                                                                                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                        |
| Acceptance criteria | - DaemonSet: `team-elephant-ds`<br/> - Namespace: `team-elephant`<br/> - Image: `viktoruj/ping_pong`<br/> - Labels: `team=team-elephant`, `env=dev` <br/> - requests CPU: `50m`<br/> - requests  Memory: `50Mi`<br/> - Pods are running on **all nodes**, including **control plane**. |
---
|        **15**        | **Create a Pod named multi-pod in the default namespace. Pod should have 3 containers: box1, box2 and box3. Containers should use temporary volume to exchange information. Configure containers box2 and box3 according the acceptance criteria below.**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 4%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Pod name: `multi-pod`<br/> - Container name: `box1`<br/> - Image: `caddy:alpine`<br/> - Container name: `box2`<br/> - Image: `busybox:1.36`<br/> - Command: `while true; do date >> /vol/time.out; sleep 3;`<br/> - Container name: `box3`<br/> - Image: `busybox:1.36`<br/> - Command: `tail -f /vol/time.out;`<br/> kubectl log multi-pod -c box3 displays date output for every 3 seconds.     |
---
|        **16**        | Write cli commands with  shows the latest events in the whole cluster, ordered by creation time `metadata.creationTimestamp`. |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                              |
| Acceptance criteria | - Events ordered by creation time <br/> - script is  located  `/var/work/artifact/16.sh`                                              |
---
|        **17**        | Write cli commands with show  names of all namespaced api resources in Kubernetes cluster            |
| :-----------------: |:-----------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                      |
| Acceptance criteria | - show  names of all namespaced api resources <br/> - script is  located  `/var/work/artifact/17.sh` |
---
|        **18**        | cluster3 seems to have an issue - one of node is not joined. It also might be outdated, so make sure it is running same Kubernetes version as control plane. You should fix the issue. |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                                                                                                                        |
| Acceptance criteria | - k8s3_node_node_2 is running the same Kubernetes version as control plane, rejoined to the cluster and is in Ready status.                                                            |
---
|        **19**        | Create static pod `stat-pod` in the `default` namespace. Expose it via service `stat-pod-svc`.                                                                                                                                                                                   |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                                                                                                                               |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                  |
| Acceptance criteria | - Pod name: `stat-podv`<br/>- Image: `viktoruj/ping_pong:latest`<br/> - requests  CPU: `100m`<br/> - requests  Memory: `128Mi` <br/> - app port `8080` <br/> - Service name: `stat-pod-svc`<br/> - Service type: `NodePort` <br/> - NodePort: `30084`  <br/> - Pod is accessible from control plane node. <br/> 
---
|        **20**        | Backup etcd and save it on the control plane node at `/var/work/tests/artifacts/20/etcd-backup.db` . Restore etcd from `/var/work/tests/artifacts/20/etcd-backup_old.db` on control plane node . |
| :-----------------: |:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                                                                               |
|       Cluster       | cluster4 (`kubectl config use-context cluster4-admin@cluster4`)                                                                                                                                  |
| Acceptance criteria | - backup etcd to `/var/work/tests/artifacts/20/etcd-backup.db`  <br/> - restore etcd from `/var/work/tests/artifacts/20/etcd-backup_old.db`                                                      |
---
|       **21**        | **Network policy.**                                                                                                                                                                                                                                                                                                                                  |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 6%                                                                                                                                                                                                                                                                                                                                                   |
|       Cluster       | cluster5 (`kubectl config use-context cluster5-admin@cluster5`)                                                                                                                                                                                                                                                                                      |
| Acceptance criteria | - create default deny ingress policy in `prod-db` NS<br/>- create policy with allow connections from `prod` Namespaces to `prod-db`<br/>- create policy with allow connections from `stage` Namespaces and have label: `role=db-connect`<br/>- create policy with allow connections from `any` Namespaces and have label: `role=db-external-connect` |
---