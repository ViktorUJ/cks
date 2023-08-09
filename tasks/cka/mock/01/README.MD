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


## 11. Create a Persistent Volume with the given specification . Run pod with pv
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
