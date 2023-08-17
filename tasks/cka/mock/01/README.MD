# Instructions 

## create mock exam env
- update `s3` in [terragrunt.hcl](..%2F..%2F..%2F..%2Fterraform%2Fenvironments%2Fterragrunt.hcl)
- update `region` and `ami id ` (if need it ) in [terragrunt.hcl](..%2F..%2F..%2F..%2Fterraform%2Fenvironments%2Fterragrunt.hcl)
- create  own aws ec2 `KeyPairs`
- update ` key_name` in [env.hcl](env.hcl)
- update `backend_bucket` in [env.hcl](env.hcl)
- run `TASK=01 make run_cka_k8s_mock` from  root repo folder

## connect to  mock exam env
- find `worker_pc_ip` in `terraform output`
- connect to `worker_pc_ip`  with your ssh key and user `ubuntu`
- for checking time run     `time_left` on work pc
- for checking result run   `check_result` on work pc
- for connect to node use `ssh  {kubernetes_nodename}` on work pc

## Delete mock exam env
- `make delete_cka_k8s_mock`

# Allowed resources 
**Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)


# Questions

## 1. Deploy a pod named nginx-pod using the nginx:alpine image.
### Task weight: 1%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Name: nginx-pod
- Image: nginx:alpine


## 2. Deploy a messaging pod using the redis:alpine image with the labels set to tier=msg
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Pod Name: messaging
- Image: redis:alpine
- Labels: tier=msg



## 3. Create a namespace named apx-x9984574  
### Task weight: 1%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Namespace: apx-x9984574

## 4. Get the list of nodes in JSON format and store it in a file at /var/work/tests/artifacts/4/nodes.json 
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- list of nodes  /var/work/tests/artifacts/4/nodes.json   

## 5. Create a service messaging-service to expose the messaging application within the cluster on port 6379
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Use imperative commands.
- Service: messaging-service
- Port: 6379
- Type: ClusterIp
- Use the right labels 

## 6. Create a deployment named hr-web-app using the image nginx:alpine with 2 replicas
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Name: hr-web-app
- Image: nginx:alpine
- Replicas: 2 

## 7. Create a static pod named static-busybox with label pod-type=static-pod  on the controlplane node that uses the busybox image and the command sleep 60000.
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Name: static-busybox
- Image: busybox
- label: pod-type=static-pod
- command:  sleep 60000

## 8. Create a POD in the finance namespace named temp-bus with the image redis:alpine.
### Task weight: 1%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Namespace: finance 
- Name: temp-bus
- Image Name: redis:alpine

## 9. Use JSON PATH query to retrieve the osImages of all the nodes and store it in a file /var/work/tests/artifacts/9/os.json  each node - new line
### Task weight: 3%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

-  file /var/work/tests/artifacts/9/os.json


## 10. Create a pod called multi-pod with two containers
### Task weight: 5%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Pod Name: multi-pod
- Container 1, name: alpha, image: nginx , variable  name=alpha
- Container 2: name: beta, image: busybox, command: sleep 4800 , variable  name=beta


## 11. Expose the hr-web-app as service
### Task weight: 4%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- The web application listens on port 80
- Name: hr-web-app-service
- Type: NodePort
- Endpoints: 2
- Port: 80
- NodePort: 30082


## 12. Create a Persistent Volume with the given specification . Run pod with pv
### Task weight: 6%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Volume name: pv-analytics
- pvc name: pvc-analytics
- Storage: 100Mi
- Access mode: ReadWriteOnce
- Host path: /pv/analytics

- pod name: analytics
- image: busybox
- node: nodeSelector -  node_name: node_2
- command : "sleep 60000"
- mountPath: /pv/analytics

## 13. Take a backup of the etcd cluster and save it to  /var/work/tests/artifacts/13/etcd-backup.db
### Task weight: 3%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)
- etcd backup   on control-plane   node   /var/work/tests/artifacts/13/etcd-backup.db


## 14. Create a Pod called redis-storage with image: redis:alpine with a Volume of type emptyDir that lasts for the life of the Pod
### Task weight: 4%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Pod name: redis-storage 
- container name: redis-storage
- image: redis:alpine
- volumes.name: data
- volumes.type: emptyDir
- volumes.sizeLimit: 500Mi
- volumeMounts.mountPath: /data/redis
- volumeMounts.name: data

## 15. Create a new pod called super-user-pod with image busybox:1.28. Allow the pod to be able to set system_time.
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)
- Pod name : super-user-pod
- container name: super-user-pod
- Container Image: busybox:1.28
- command:  sleep for 4800 seconds.
- capability:   SYS_TIME 


## 16. Create a new deployment called nginx-deploy, with image nginx:1.16 and 1 replica. Next upgrade the deployment to version 1.17 using rolling update.
### Task weight: 3%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- Deployment : nginx-deploy. 
- Image: nginx:1.16
- Task: Upgrade the version of the deployment to 1:17 with image 1.17
- Task: Record the changes for the image upgrade

## 17. Create a new user called john. Grant him access to the cluster. John should have permission to create, list, get, update and delete pods in the development namespace . 
### Task weight: 6%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- create ns development
- create private key , and csr
- CSR: john-developer Status:Approved
- Role Name: developer, namespace: development, Resource: Pods , verbs: create,list,get
- rolebinding : name=developer-role-binding , role=developer,  user=john , namespace=development
- Access: User 'john' has appropriate permissions


## 18. Create a new service account with the name pvviewer. Grant this Service account access to list all PersistentVolumes in the cluster by creating an appropriate cluster role called pvviewer-role and ClusterRoleBinding called pvviewer-role-binding. Next, create a pod called pvviewer with the image: redis and serviceAccount: pvviewer in the default namespace.
### Task weight: 5%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- ServiceAccount: pvviewer
- ClusterRole: pvviewer-role ,  resources - persistentvolumes   , verbs - list,get
- clusterrolebinding: pvviewer-role-binding
- Pod: pvviewer
- image: viktoruj/cks-lab:latest
- command: sleep 60000

## 19. Create a Pod called non-root-pod , image: redis:alpine
### Task weight: 2%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)

- pod name : non-root-pod
- image: redis:alpine
- runAsUser: 1000
- fsGroup: 2000

#### tmp

## 20. Taint the worker node node01 to be Unschedulable. Once done, create a pod called dev-redis, image redis:alpine, to ensure workloads are not scheduled to this worker node. Finally, create a new pod called prod-redis and image: redis:alpine with toleration to be scheduled on node01.
### Task weight: 3%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)
- key: env_type, value: production, operator: Equal and effect: NoSchedule
- Key = env_type ,  Value = production ,  Effect = NoSchedule
- pod 'dev-redis' (no tolerations) is not scheduled on node01?
- Create a pod 'prod-redis' to run on node01

####  /tmp 

## 21.  Resolve dns  svc and pod .Create a nginx pod called nginx-resolver using image nginx, expose it internally with a service called nginx-resolver-service.
### Task weight: 3%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)
- Pod: nginx-resolver
- image: nginx
- Service: nginx-resolver-service
- lookup pod  name : test-nslookup
- lookup pod  image : busybox:1.28
- service file : /var/work/tests/artifacts/21/nginx.svc 
- pod file : /var/work/tests/artifacts/21/nginx.pod

## 22. Update Kubernetes
### Task weight: 7%
### cluster : cluster2 (`kubectl config use-context cluster2-admin@cluster2`)
- The cluster is running Kubernetes 1.25.0 , update it to 1.26.0 .
- Use apt package manager and kubeadm for this.
- Use ssh  to connect to the instances.

## 23. Network policy
### Task weight: 6%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)
 - create default deny ingress policy in `prod-db` NS
 - create policy with allow connections from `prod` Namespaces to `prod-db`
 - create policy with allow connections from `stage` Namespaces and have label: `role=db-connect`
 - create policy with allow connections from `any` Namespaces and have label: `role=db-external-connect`

### 24 . secret as env and file  in pod 


### 26 . deployment . antiafinity  , distruption buget 



