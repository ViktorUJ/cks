# Allowed resources

## **Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)

## Questions

---
| <div style="width:120px">**1**</div> | <div style="width:400px">**Deploy a pod named nginx-pod using the nginx:alpine image**</div> |
| :----------------------------------: | :------------------------------------------------------------------------------------------- |
|             Task weight              | 1%                                                                                           |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                              |
|         Acceptance criteria          | - Name: `nginx-pod` <br/>- Image: `nginx:alpine`                                             |
---
| <div style="width:120px">**2**</div> | <div style="width:400px">**Deploy a messaging pod using the redis:alpine image with the labels set to tier=msg** </div> |
| :----------------------------------: | :---------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 1%                                                                                                                      |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                         |
|         Acceptance criteria          | - Pod Name: `messaging` <br/>- Image: `redis:alpine`<br> - Labels: `tier=msg`                                           |
---
| <div style="width:120px">**3**</div> | <div style="width:400px">**Create a namespace named apx-x9984574**</div> |
| :----------------------------------: | :----------------------------------------------------------------------- |
|             Task weight              | 1%                                                                       |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)          |
|         Acceptance criteria          | - Namespace: `apx-x9984574`                                              |
---
| <div style="width:120px">**4**</div> | <div style="width:400px">**Get the list of nodes in JSON format and store it in a file at `/var/work/tests/artifacts/4/nodes.json`**</div> |
| :----------------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 2%                                                                                                                                         |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                            |
|         Acceptance criteria          | - list of nodes `/var/work/tests/artifacts/4/nodes.json`                                                                                   |
---
| <div style="width:120px">**5**</div> | <div style="width:400px"> **Create a service messaging-service to expose the messaging application within the cluster on port 6379**</div> |
| :----------------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 2%                                                                                                                                         |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                            |
|         Acceptance criteria          | - Use imperative commands. <br/> - Service: `messaging-service`<br/>- Port: `6379` <br/>- Type: `ClusterIp`<br/>- Use the right labels     |
---
| <div style="width:120px">**6**</div> | <div style="width:400px"> **Create a deployment named `hr-web-app` using the image nginx:alpine with 2 replicas**</div> |
| :----------------------------------: | :---------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 2%                                                                                                                      |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                         |
|         Acceptance criteria          | - Name: `hr-web-app`<br/>- Image: `nginx:alpine`<br/>- Replicas: `2`                                                    |
---
| <div style="width:120px">**7**</div> | <div style="width:400px"> **Create a static pod named static-busybox with label pod-type=static-pod  on the controlplane node that uses the busybox image and the command sleep 60000.**</div> |
| :----------------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 2%                                                                                                                                                                                             |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                |
|         Acceptance criteria          | - Name: `static-busybox`<br/>- Image: `busybox`<br/>- label: `pod-type=static-pod`<br/> - command: sleep 60000                                                                                 |
---
| <div style="width:120px">**8**</div> | <div style="width:400px"> **Create a POD in the finance namespace named temp-bus with the image redis:alpine.**</div> |
| :----------------------------------: | :-------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 1%                                                                                                                    |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                       |
|         Acceptance criteria          | - Namespace: `finance`<br/>- Name: `temp-bus`<br/>- Image: `redis:alpine`                                             |
---
| <div style="width:120px">**9**</div> | <div style="width:400px"> **Use JSON PATH query to retrieve the osImages of all the nodes and store it in a file `/var/work/tests/artifacts/9/os.json` each node - new line.**</div> |
| :----------------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|             Task weight              | 3%                                                                                                                                                                                   |
|               Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                      |
|         Acceptance criteria          | file `/var/work/tests/artifacts/9/os.json`                                                                                                                                           |
---
| <div style="width:120px">**10**</div> | <div style="width:400px"> **Create a pod called multi-pod with two containers** </div>                                                                                                          |
| :-----------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 5%                                                                                                                                                                                              |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                 |
|          Acceptance criteria          | - Pod Name: `multi-pod`<br/>- Container 1, name: *alpha*, image: *nginx* , variable *name=alpha*<br/>- Container 2: name: *beta*, image: *busybox*, command: *sleep 4800*, variable *name=beta* |
---
| <div style="width:120px">**11**</div> | <div style="width:400px"> **Expose the hr-web-app as service**</div>                                                                                           |
| :-----------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 4%                                                                                                                                                             |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                |
|          Acceptance criteria          | - The web application listens on port 80<br/>- Name: `hr-web-app-service`<br/>- Type: `NodePort`<br/>- Endpoints: `2`<br/>- Port: `80`<br/>- NodePort: `30082` |
---
| <div style="width:120px">**12**</div> | <div style="width:400px"> **Create a Persistent Volume with the given specification. Run pod with pv.** </div>                                                                                                                                                                                                                         |
| :-----------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 6%                                                                                                                                                                                                                                                                                                                                     |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                        |
|          Acceptance criteria          | - Volume name: `pv-analytics`<br/>- pvc name: `pvc-analytics`<br/>- Storage: `100Mi`<br/>- Access mode: `ReadWriteOnce`<br/>- Host path: `/pv/analytics`<br/><br/>- pod name: `analytics`<br/>- image: `busybox`<br/>- node: `nodeSelector`<br/>-  node_name: `node_2`<br/>- command: `"sleep 60000"`<br/>- mountPath: `/pv/analytics` |
---
| <div style="width:120px">**13**</div> | <div style="width:400px"> **Take a backup of the etcd cluster and save it to /var/work/tests/artifacts/13/etcd-backup.db**</div> |
| :-----------------------------------: | :------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 3%                                                                                                                               |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                  |
|          Acceptance criteria          | - etcd backup on control-plane node `/var/work/tests/artifacts/13/etcd-backup.db`                                                |
---
| <div style="width:120px">**14** | <div style="width:400px"> **Create a Pod called redis-storage with image: redis:alpine with a Volume of type emptyDir that lasts for the life of the Pod**</div>                                                                                                     |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|           Task weight           | 4%                                                                                                                                                                                                                                                                   |
|             Cluster             | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                      |
|       Acceptance criteria       | - Pod name: `redis-storage`<br/>- container name: `redis-storage`<br/>- image: `redis:alpine`<br/>- volumes.name: `data`<br/>- volumes.type: `emptyDir`<br/>- volumes.sizeLimit: `500Mi`<br/>- volumeMounts.mountPath: `/data/redis`<br/>- volumeMounts.name: `data` |
---
| <div style="width:120px">**15**</div> | <div style="width:400px"> **Create a new pod called super-user-pod with image busybox:1.28. Allow the pod to be able to set system_time.**</div>                               |
| :-----------------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 2%                                                                                                                                                                             |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                |
|          Acceptance criteria          | - Pod name: `super-user-pod`<br/>- container name: `super-user-pod`<br/>- Container Image: `busybox:1.28`<br/>- command:  sleep for 4800 seconds.<br/>- capability: `SYS_TIME` |
---
| <div style="width:120px">**16**</div> | <div style="width:400px"> **Create a new deployment called nginx-deploy, with image nginx:1.16 and 1 replica. Next upgrade the deployment to version 1.17 using rolling update.**</div> |
| :-----------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 3%                                                                                                                                                                                      |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                         |
|          Acceptance criteria          | - Deployment : nginx-deploy.<br/>- Image: nginx:1.16<br/>- Task: Upgrade the version of the deployment to 1:17 with image 1.17<br/>- Task: Record the changes for the image upgrade     |
---
| <div style="width:120px">**17**</div> | <div style="width:400px"> **Create a new user called john. Grant him access to the cluster. John should have permission to create, list, get, update and delete pods in the development namespace.** </div>                                                                                                                                                                       |
| :-----------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 6%                                                                                                                                                                                                                                                                                                                                                                                |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                   |
|          Acceptance criteria          | - create ns `development`<br/>- create private key and csr<br/>- CSR: `john-developer` with Status:Approved<br/>- Role Name: `developer`, namespace: `development`, Resource: `Pods` , verbs: `create,list,get`<br/>- rolebinding: name=`developer-role-binding` , role=`developer`,  user=`john` , namespace=`development`<br/>- Access: User 'john' has appropriate permissions |
---
| <div style="width:120px">**18**</div> | <div style="width:400px"> **Create a new service account with the name pvviewer. Grant this Service account access to list all PersistentVolumes in the cluster by creating an appropriate cluster role called pvviewer-role and ClusterRoleBinding called pvviewer-role-binding. Next, create a pod called pvviewer with the image: redis and serviceAccount: pvviewer in the default namespace.**</div> |
| :-----------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 5%                                                                                                                                                                                                                                                                                                                                                                                                        |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                                           |
|          Acceptance criteria          | - ServiceAccount: `pvviewer`<br/>- ClusterRole: `pvviewer-role`, resources - `persistentvolumes`, verbs - `list,get`<br/>- clusterrolebinding: `pvviewer-role-binding`<br/>- Pod: `pvviewer`<br/>- image: `viktoruj/cks-lab:latest`<br/>- command: `sleep 60000`                                                                                                                                          |
---
| <div style="width:120px">**19**</div> | <div style="width:400px"> **Create a Pod called non-root-pod, image: redis:alpine**</div>            |
| :-----------------------------------: | :--------------------------------------------------------------------------------------------------- |
|              Task weight              | 2%                                                                                                   |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                      |
|          Acceptance criteria          | - pod name: `non-root-pod`<br/>- image: `redis:alpine`<br/>- runAsUser: `1000`<br/>- fsGroup: `2000` |
---
| <div style="width:120px">**20** | <div style="width:400px"> **Create  secret, configmap. Create a pod with mount secret and configmap.**</div>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|           Task weight           | 8%                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|             Cluster             | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|       Acceptance criteria       | - namespace: prod-apps<br/>- secret: name=prod-secret,  ns=prod-apps, variables  var1=aaa, var2=bbb<br/>- configmap: configmap_name=prod-config,ns=prod-apps,file_name_for_configmap=config.yaml, file_content= "test config"<br/>- pod: name=prod-app, ns=prod-apps,<br/>- container1: name=app1, image=viktoruj/cks-lab:latest , command="sleep 60000", volume_name=config, volume_type=configmap, mount_path="/app/configs", ENV=from secret "prod-secret"<br/>- container2: name=app2, image=viktoruj/cks-lab:latest , command="sleep 60000", volume_name=secret, volume_type=secret, mount_path="/app/secrets" |
---
| <div style="width:120px">**21**</div> | <div style="width:400px"> **Resolve dns svc and pod. Create a nginx pod called nginx-resolver using image nginx, expose it internally with a service called nginx-resolver-service.**</div>                                                                                                 |
| :-----------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|              Task weight              | 3%                                                                                                                                                                                                                                                                                          |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                             |
|          Acceptance criteria          | - Pod: `nginx-resolver`<br/>- image: `nginx`<br/>- Service: `nginx-resolver-service`<br/>- lookup pod  name : `test-nslookup`<br/>- lookup pod image : `busybox:1.28`<br/>- service file: `/var/work/tests/artifacts/21/nginx.svc`<br/>- pod file: `/var/work/tests/artifacts/21/nginx.pod` |
---
| <div style="width:120px">**22**</div> | <div style="width:400px"> **Resolve dns  svc and pod .Create a nginx pod called nginx-resolver using image nginx, expose it internally with a service called nginx-resolver-service.**</div> |
| :-----------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 7%                                                                                                                                                                                           |
|                Cluster                | cluster2 (`kubectl config use-context cluster2-admin@cluster2`)                                                                                                                              |
|          Acceptance criteria          | - The cluster is running Kubernetes 1.25.0, update it to 1.26.0 .<br/>- Use apt package manager and kubeadm for this.<br/>- Use ssh to connect to the instances.                             |
---
| <div style="width:120px">**23**</div> | <div style="width:400px"> **Network policy.**</div>                                                                                                                                                                                                                                                                                                  |
| :-----------------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 6%                                                                                                                                                                                                                                                                                                                                                   |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                      |
|          Acceptance criteria          | - create default deny ingress policy in `prod-db` NS<br/>- create policy with allow connections from `prod` Namespaces to `prod-db`<br/>- create policy with allow connections from `stage` Namespaces and have label: `role=db-connect`<br/>- create policy with allow connections from `any` Namespaces and have label: `role=db-external-connect` |
---
| <div style="width:120px">**24**</div> | <div style="width:400px"> **Create daemonset to run pods on all nodes (control-plane too)**</div>                   |
| :-----------------------------------: | :------------------------------------------------------------------------------------------------------------------ |
|              Task weight              | 6%                                                                                                                  |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                     |
|          Acceptance criteria          | - namespace: `app-system`<br/>- ds: `name=important-app`, image=`nginx`<br/>- run on  all nodes (control-plane too) |
---
| <div style="width:120px">**25**</div> | <div style="width:400px"> **Create deployment and spread the pods on all nodes(control-plane too). Add PodDisruptionBudget**</div>                                                                        |
| :-----------------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|              Task weight              | 8%                                                                                                                                                                                                        |
|                Cluster                | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                           |
|          Acceptance criteria          | - namespace: `app2-system`<br/>- deployment: `name=important-app2` , image=`nginx`, replicas=`3`<br/>- PodAntiAffinity: `nodename`<br/>- PodDisruptionBudget: `name=important-app2` min available pod = 1 |
---
