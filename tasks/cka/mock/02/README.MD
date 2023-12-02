# Allowed resources

## **Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)

## Questions

|        **1**        | **Create persistent volume in the dev namespace**   |
| :-----------------: | :-------------------------------------------------------------- |
|     Task weight     | 1%                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`) |
| Acceptance criteria | - Namespace: `dev` <br/>- PV: `dev-pv`                |
---
|        **2**        | **Deploy a utility pod using the busybox:1.36 image. Make sure "date" command is executed every 10 seconds.** |
| :-----------------: | :-------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                         |
| Acceptance criteria | - Pod Name: `utility` <br/>- Image: `busybox:1.36`<br> - Commands: `date, sleep 10`           |
---
|        **3**        | **Create a namespace named team-elephant**                       |
| :-----------------: | :-------------------------------------------------------------- |
|     Task weight     | 1%                                                              |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`) |
| Acceptance criteria | - Namespace: `team-elephant`                                     |
---
|        **4**        | **Create pod alpine with image "alpine:3.15" and make sure it is running on node with label disk=ssd.** |
| :-----------------: | :---------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                          |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                             |
| Acceptance criteria | - pod is running on the node with label disk=ssd                                                |
---
|        **5**        | **Create pod web-app with image "nginx:stable". Container port should be configured on port 80 and named http-web.** |
| :-----------------: | :---------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                          |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                             |
| Acceptance criteria | - pod is running, container's port 80 named http-web                                              |
---
|        **6**        | **Create a service web-app-svc to expose the web-app application on port 8080 on cluster nodes.**                             |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                        |
| Acceptance criteria | - Use imperative commands to create mainifest. <br/> - Service: `web-app-svc`<br/>- Port: `8080` <br/>- Type: `NodePort`<br/>- Use the right labels to select targer port. |
---
|        **7**        | **Create a single pod web-srv based on image caddy:alpine in the default namespace. The container in the pod should named app1.**
| :-----------------: | :-------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                         |
| Acceptance criteria | - Name: `web-srv`<br/>- Image: `caddy:alpine`<br/>- Container name: `app1`              |
---
|        **8**        | **2 pods are running in the namspace db-redis named redis-node-\*. You have to scale down number of replicas to 1.** |
| :-----------------: | :--------------------------------------------------------------------------------------- |
|     Task weight     |  1%                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                      |
| Acceptance criteria | - Name: `redis-node-\*`<br/>- Number of pods running: 1                                                                                |
---
|        **9**        | **Export pods from all namespaces to /var/work/tests/artifacts/9/pods.json**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - list of pods to /var/work/tests/artifacts/9/pods.json                              |
---
|        **10**        | **Create a new PersistentVolume poc-web-pv, set accessMode ReadWriteOnce, size 1Gi and hostPath /project/data. Bond it with  PersistentVolumeClaim poc-web-pvc in poc-web namespace, size 1Gi. Finally create a new Deployment poc-web-deploy in Namespace poc-web and mount that volume to /project/data. Use nginx:alpine for deployment image.**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 8%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - poc-web-pvc bonded to poc-web-pv volume and volume is mounted to pods in poc-web-deploy deployment      |
---
|        **11**        | **Show Pods and their containers resource usage orderd by memory usage**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Script that shows pods and their container resource usage by memory usage to /var/work/tests/artifacts/11/pods.sh      |
---
|        **12**        | **Create Ingress. Point it service web-app-svc, path /, port 8080**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 3%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Ingress is created and point to the right service and right port     |
---
|        **13**        | **In the Namespace team-elephant create a new ServiceAccount pod-sa. Assing an account permissions to list and get pods using Role and RoleBinding**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 5%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Pods are running in the Namespace team-elephant can be listed using pod-sa service account.     |
---
|        **14**        | **Create a DaemonSet named team-elephant-ds, image: caddy:alpine, labels: team=team-elephant and type=daemonset. Pods configuration, CPU: 100m, Memory: 128Mi. Pods should run on all nodes including control plane and in Namespace team-elephant**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 4%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Pods are running on all nodes including control plane and in Namespace team-elephant.     |
---
|        **15**        | **Create a Pod named multi-pod in the default namespace. Pod should have 3 containers: box1, box2 and box3. Containers should use temporary volume to exchange information. Container box1, image: caddy:alpine, container box2, image: busybox:1.36, command: while true; do date >> /vol/time.log; sleep 3;. Container box3, image: busybox:1.36busybox:1.36, commmand: tail -f /vol/time.log.**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 4%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - kubectl log multi-pod -c box3 should display date output for every 3 seconds.     |
---
|        **16**        | **Shows the latest events in the whole cluster, ordered by creation time (metadata.creationTimestamp). Write output to /var/work/tests/artifacts/16/events.log**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Events ordered by creation time to /var/work/tests/artifacts/16/events.log    |
---
|        **17**        | **Export names of all namespaced resources in Kubernetes to /var/work/tests/artifacts/17/namespaced_resources.out**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - List of namespaced resources to /var/work/tests/artifacts/17/namespaced_resources.out    |
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

