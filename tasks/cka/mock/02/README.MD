# Allowed resources

## **Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)

## Questions

|        **1**        | find a pod in dev-1 namespace with labels `team=finance` and maximum memory usage . Add label `usage=max` to it |
| :-----------------: |:-----------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                      |
| Acceptance criteria | - Namespace: `dev` <br/>- PV: `dev-pv`                                                               |
---
|        **2**        | Deploy a **util** pod using the **busybox:1.36** image in the **dev** namespace. Use **sleep 3600 command** to keep it running. |
| :-----------------: |:--------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                 |
| Acceptance criteria | - Pod Name: `util` <br/> - Namespace: `dev` <br/> - Image: `busybox:1.36`<br> - Commands: `sleep 3600`                          |
---
|        **3**        | Create a **namespace** named **team-elephant**                                  |
| :-----------------: |:--------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                 |
| Acceptance criteria | - Namespace: `team-elephant` <br/> Namespace is present in the namespaces list. |
---
|        **4**        | **Create pod `alpine` with image `alpine:3.15` and and command `sleep 6000` . Make sure the pod  is running on node with label `disk=ssd`.** |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                           |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                              |
| Acceptance criteria | - Pod is running on the node with label disk=ssd.                                                                                            |
---
|        **5**        | Create deployment **web-app** with image **viktoruj/ping_pong:latest** and **2** replicas. Container port should be configured on port **8080** and named **http-web**. |
| :-----------------: |:------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 2%                                                                                                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                         |
| Acceptance criteria | - Deployment name: `web-app`<br/> - Image: `viktoruj/ping_pong:latest`<br/> - Replicas: `2`<br/> Deployment pods are running, containers' ports 8080 named http-web.    |
---
|        **6**        | **Create a service web-app-svc to expose the web-app deployment on port 8080 on cluster nodes.**                             |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                        |
| Acceptance criteria | - Use imperative commands to create mainifest. <br/> - Service: `web-app-svc`<br/>- Port: `8080` <br/>- Type: `NodePort`<br/>- Use the right labels to select targer port. |
---
|        **7**        | Create a pod **web-srv** based on image **viktoruj/ping_pong:latest** in the default namespace. The container in the pod should named app1.|
| :-----------------: | :-------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                         |
| Acceptance criteria | - Pod name: `web-srv`<br/>- Image: `viktoruj/ping_pong:latest`<br/>- Container name: `app1`              |
---
|        **8**        | **2 pods are running in the namspace db-redis named redis-node-\*. You have to scale down number of replicas to 1.** |
| :-----------------: | :--------------------------------------------------------------------------------------- |
|     Task weight     |  1%                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                     |
| Acceptance criteria | - Name: `redis-node-\*`<br/>- Number of pods running: 1 <br/> - Nuber of pods is scaled down to 1. <br/>            |
---
|        **9**        | **Export pods from all namespaces in json format to /var/work/tests/artifacts/9/pods.json**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - List of pod from all namespaces written to /var/work/tests/artifacts/9/pods.json.                              |
---
|        **10**        | **Create a new PersistentVolume poc-web-pv, size 100Mi and mount it to the folder /project/data. Persistent Volume poc-web-pvc in poc-web namespace should bond with volume and claim 100Mi. Finally create a new Deployment poc-web-deploy in Namespace poc-web and mount that volume to /project/data. nginx:alpine image should be used for deployment.**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 8%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - PV name: `poc-web-pv`<br/> - accessMode: `ReadWriteOnce`<br/> - Size: `100Mi`<br/> - hostPath: `/project/data`<br/> - PersistentVolumeClaim: `poc-web-pvc`<br/>  - Namespace: `poc-web`<br/> - Size: `100Mi`<br/> - Deployment: `poc-web-deploy`<br/> - Image: `nginx:alpine`<br/> poc-web-pvc bonded to poc-web-pv volume and volume is mounted to pods in poc-web-deploy deployment      |
---
|        **11**        | **Show Pods and their containers resource usage orderd by memory usage**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Script that shows pods and their container resource usage by memory usage to /var/work/tests/artifacts/11/pods.sh      |
---
|        **12**        | **Create Ingress web-app-ingress. Point it service web-app-svc, path /, port 8080**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 3%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Ingress name: `web-app-ingress`<br/> - Path: `/`<br/> - Service: `web-app-svc`<br/> - Port: `8080`<br/> Ingress is created and points to the right service and right port.     |
---
|        **13**        | **In the Namespace team-elephant create a new ServiceAccount pod-sa. Assing an account permissions to list and get pods using Role and RoleBinding**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 5%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Pods are running in the Namespace team-elephant can be listed using pod-sa service account.     |
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
| Acceptance criteria | - Events ordered by creation time <br/> - script is  located  `/var/work/16.sh`                                              |
---
|        **17**        | Write cli commands with show  names of all namespaced api resources in Kubernetes cluster   |
| :-----------------: |:--------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                          |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                             |
| Acceptance criteria | - show  names of all namespaced api resources <br/> - script is  located  `/var/work/17.sh` |
---
|        **18**        | **cluster2 seems to have an issue - cluster2-node1 is not joined. It also might be outdated, so make sure it is running same Kubernetes version as control plane. You should fix the issue.**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 8%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster2-admin@cluster2`)                       |
| Acceptance criteria | - cluster2-node1 is running the same Kubernetes version as control plane, rejoined to the cluster and is in Ready status.  |
---
|        **19**        | **Create static pod stat-pod in the default namespace. Expose it via service stat-pod-svc.**                  |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 2%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Name: `stat-podv`<br/>- Image: `caddy:alpine`<br/>- CPU: `100m`<br/> - Memory: `128Mi`<br/> - Service name: `stat-pod-svc`<br/> - Service type: `NodePort`<br/> Pod is accessible from control plane node. <br/>
---
|        **20**        | **Backup etcd and save it on the control plane node at /var/work/tests/artifacts/20/etcd-backup.db. Create pod web-srv with image nginx. Now restore the backup and make sure pod web-srv has disappeared.**                  |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 2%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Name: `web-srv`<br/> - Image: `nginx`<br/> Make sure pod web-srv has disappeared after restore. <br/>  |
---
