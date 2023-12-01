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
|        **5**        | **Create pod web-app with image "nginx:stable". Expose its port 80 and name it http-web.** |
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
|        **7**        | **Create a single web-srv based on image caddy:alpine in default namespace. The container in the pod must have web-srv-con.**
| :-----------------: | :-------------------------------------------------------------------------------------- |
|     Task weight     | 1%                                                                                      |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                         |
| Acceptance criteria | - Name: `web-srv`<br/>- Image: `caddy:alpine`<br/>- Container name: `web-srv-con`                    |
---
|        **8**        | **2 pods are running in the namspace db-redis named redis-node-\*. You have to scale down nuber of replicas to 1.** |
| :-----------------: | :--------------------------------------------------------------------------------------- |
|     Task weight     |  1%                                                                                                                 |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                      |
| Acceptance criteria | - Name: `redis-node-\*`<br/>- Nubmer of pods running: 1                                                                                |
---
|        **9**        | **Export pods in all namespase to /var/work/tests/artifacts/9/pods.json**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - list of nodes to /var/work/tests/artifacts/9/pods.json                              |
---
|        **10**        | **Create a new PersistentVolume poc-web-pv, set accessMode ReadWriteOnce, size 1Gi and hostPath /Volumes/Data. Bond it with  PersistentVolumeClaim poc-web-pvc in poc-web namespace, size 1Gi. Finally create a new Deployment poc-web-deploy in Namespace poc-web and mount that volume to /project/data. Use nginx:alpine for deployment image.**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 8%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - poc-web-pvc bonds poc-web-pv volume and it is mounted to pods in poc-web-deploy deployment      |
---
|        **11**        | **Show Pods and their containers resource usage orderd by memory usage**             |
| :-----------------: | :------------------------------------------------------------------------------------ |
|     Task weight     | 1%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                       |
| Acceptance criteria | - Script that shows pods and their container resource usage by memory usage to /var/work/tests/artifacts/11/pods.sh      |




---
|       **---**        | **Expose the hr-web-app as service**                                                                                                                           |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                |
| Acceptance criteria | - The web application listens on port 80<br/>- Name: `hr-web-app-service`<br/>- Type: `NodePort`<br/>- Endpoints: `2`<br/>- Port: `80`<br/>- NodePort: `30082` |
---
|       **---**        | **Create a Persistent Volume with the given specification. Run pod with pv.**                                                                                                                                                                                                                                                          |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                                                                                                                                                                                                                                                                     |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                        |
| Acceptance criteria | - Volume name: `pv-analytics`<br/>- pvc name: `pvc-analytics`<br/>- Storage: `100Mi`<br/>- Access mode: `ReadWriteOnce`<br/>- Host path: `/pv/analytics`<br/><br/>- pod name: `analytics`<br/>- image: `busybox`<br/>- node: `nodeSelector`<br/>-  node_name: `node_2`<br/>- command: `"sleep 60000"`<br/>- mountPath: `/pv/analytics` |
---
|       **---**        | **Take a backup of the etcd cluster and save it to /var/work/tests/artifacts/13/etcd-backup.db** |
| :-----------------: | :----------------------------------------------------------------------------------------------- |
|     Task weight     | 3%                                                                                               |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                  |
| Acceptance criteria | - etcd backup on control-plane node `/var/work/tests/artifacts/13/etcd-backup.db`                |
---
|       **---**        | **Create a Pod called redis-storage with image: redis:alpine with a Volume of type emptyDir that lasts for the life of the Pod**                                                                                                                                     |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                                                                                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                      |
| Acceptance criteria | - Pod name: `redis-storage`<br/>- container name: `redis-storage`<br/>- image: `redis:alpine`<br/>- volumes.name: `data`<br/>- volumes.type: `emptyDir`<br/>- volumes.sizeLimit: `500Mi`<br/>- volumeMounts.mountPath: `/data/redis`<br/>- volumeMounts.name: `data` |
---
|       *---**        | **Create a new pod called super-user-pod with image busybox:1.28. Allow the pod to be able to set system_time.**                                                               |
| :-----------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                                                                                             |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                |
| Acceptance criteria | - Pod name: `super-user-pod`<br/>- container name: `super-user-pod`<br/>- Container Image: `busybox:1.28`<br/>- command:  sleep for 4800 seconds.<br/>- capability: `SYS_TIME` |
---
|       **---*        | **Create a new deployment called nginx-deploy, with image nginx:1.16 and 1 replica. Next upgrade the deployment to version 1.17 using rolling update.**                             |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 3%                                                                                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                     |
| Acceptance criteria | - Deployment : nginx-deploy.<br/>- Image: nginx:1.16<br/>- Task: Upgrade the version of the deployment to 1:17 with image 1.17<br/>- Task: Record the changes for the image upgrade |
---
|       **---**        | **Create a new user called john. Grant him access to the cluster. John should have permission to create, list, get, update and delete pods in the development namespace.**                                                                                                                                                                                                        |
| :-----------------: |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 6%                                                                                                                                                                                                                                                                                                                                                                                |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                   |
| Acceptance criteria | - create ns `development`<br/>- create private key and csr<br/>- CSR: `john-developer` with Status:Approved<br/>- Role Name: `developer`, namespace: `development`, Resource: `pods` , verbs: `create,list,get`<br/>- rolebinding: name=`developer-role-binding` , role=`developer`,  user=`john` , namespace=`development`<br/>- Access: User 'john' has appropriate permissions |
---
|       **---**        | **Create a new service account with the name pvviewer. Grant this Service account access to list all PersistentVolumes in the cluster by creating an appropriate cluster role called pvviewer-role and ClusterRoleBinding called pvviewer-role-binding. Next, create a pod called pvviewer with the image: redis and serviceAccount: pvviewer in the default namespace.** |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 5%                                                                                                                                                                                                                                                                                                                                                                        |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                           |
| Acceptance criteria | - ServiceAccount: `pvviewer`<br/>- ClusterRole: `pvviewer-role`, resources - `persistentvolumes`, verbs - `list,get`<br/>- clusterrolebinding: `pvviewer-role-binding`<br/>- Pod: `pvviewer`<br/>- image: `viktoruj/cks-lab:latest`<br/>- command: `sleep 60000`                                                                                                          |
---
|       **---**        | **Create a Pod called non-root-pod, image: redis:alpine**                                            |
| :-----------------: | :--------------------------------------------------------------------------------------------------- |
|     Task weight     | 2%                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                      |
| Acceptance criteria | - pod name: `non-root-pod`<br/>- image: `redis:alpine`<br/>- runAsUser: `1000`<br/>- fsGroup: `2000` |
---
|       **---*        | **Create  secret, configmap. Create a pod with mount secret and configmap.**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 8%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Acceptance criteria | - namespace: prod-apps<br/>- secret: name=prod-secret,  ns=prod-apps, variables  var1=aaa, var2=bbb<br/>- configmap: configmap_name=prod-config,ns=prod-apps,file_name_for_configmap=config.yaml, file_content= "test config"<br/>- pod: name=prod-app, ns=prod-apps,<br/>- container1: name=app1, image=viktoruj/cks-lab:latest , command="sleep 60000", volume_name=config, volume_type=configmap, mount_path="/app/configs", ENV=from secret "prod-secret"<br/>- container2: name=app2, image=viktoruj/cks-lab:latest , command="sleep 60000", volume_name=secret, volume_type=secret, mount_path="/app/secrets" |
---
|       **---**        | **Resolve dns svc and pod. Create a nginx pod called nginx-resolver using image nginx, expose it internally with a service called nginx-resolver-service.**                                                                                                                                 |
| :-----------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|     Task weight     | 3%                                                                                                                                                                                                                                                                                          |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                             |
| Acceptance criteria | - Pod: `nginx-resolver`<br/>- image: `nginx`<br/>- Service: `nginx-resolver-service`<br/>- lookup pod  name : `test-nslookup`<br/>- lookup pod image : `busybox:1.28`<br/>- service file: `/var/work/tests/artifacts/21/nginx.svc`<br/>- pod file: `/var/work/tests/artifacts/21/nginx.pod` |
---
|       **---**        | **Update Kubernetes cluster.**                                                                                                                                   |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 7%                                                                                                                                                               |
|       Cluster       | cluster2 (`kubectl config use-context cluster2-admin@cluster2`)                                                                                                  |
| Acceptance criteria | - The cluster is running Kubernetes 1.25.0, update it to 1.26.0 .<br/>- Use apt package manager and kubeadm for this.<br/>- Use ssh to connect to the instances. |
---
|       **---**        | **Network policy.**                                                                                                                                                                                                                                                                                                                                  |
| :-----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                                                                                                                                                                                                                                                                                   |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                      |
| Acceptance criteria | - create default deny ingress policy in `prod-db` NS<br/>- create policy with allow connections from `prod` Namespaces to `prod-db`<br/>- create policy with allow connections from `stage` Namespaces and have label: `role=db-connect`<br/>- create policy with allow connections from `any` Namespaces and have label: `role=db-external-connect` |
---
|       **---**        | **Create DaemonSet to run pods on all nodes (control-plane too)**                                                   |
| :-----------------: |:--------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 6%                                                                                                                  |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                     |
| Acceptance criteria | - namespace: `app-system`<br/>- ds: `name=important-app`, image=`nginx`<br/>- run on  all nodes (control-plane too) |
---
|       **25**        |**Backup and restore ectd**                                                                                                                                                                 |
| :-----------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|     Task weight     | 8%                                                                                                                                                                                                        |
|       Cluster       | cluster1 (`kubectl config use-contextluster1-admin@cluster1`)                                                                                                                                           |
| Acceptance criteria | Backup  etcd save it on the controlplane node at /root/etcd-backup.db. Create pod nginx with image nginx. Now restore the backup and make sure pod nginx has disappeard.
