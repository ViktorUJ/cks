# Instructions 

## create mock exam env
- update `s3` in [terragrunt.hcl](..%2F..%2F..%2F..%2Fterraform%2Fenvironments%2Fterragrunt.hcl)
- update `region` and `ami id ` (if need it ) in [terragrunt.hcl](..%2F..%2F..%2F..%2Fterraform%2Fenvironments%2Fterragrunt.hcl)
- create  own aws ec2 `KeyPairs`
- update ` key_name` in [env.hcl](env.hcl)
- update `backend_bucket` in [env.hcl](env.hcl)
- run `TASK=01 make run_cks_k8s_mock` from  root repo folder

## connect to  mock exam env
- find `worker_pc_ip` in `terraform output`
- connect to `worker_pc_ip`  with your ssh key and user `ubuntu`
- for checking time run     `time_left` on work pc
- for checking result run   `check_result` on work pc
- for connect to node use `ssh  {kubernetes_nodename}` on work pc

## Delete mock exam env
- `make delete_cks_k8s_mock`

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
### Task weight: 1%
### cluster : cluster1 (`kubectl config use-context cluster1-admin@cluster1`)
- Name: nginx-pod
- Image: nginx:alpine

