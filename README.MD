# repo for learning k8s (CKAD, CKA , CKS)


## k8s_self_managment terraform module 
### script support  version 
``` 
k8s version  : [ 1.21 , 1.26 ]   https://kubernetes.io/releases/
Rintime : 
    docker                   [1.21 , 1.23]
    cri-o                    [1.21 , 1.26]
    containerd               [1.21 , 1.26]   # cks default 
    containerd_gvizor        [1.21 , 1.26] 
OS for nodes  : 
   ubuntu  :  20.04 LTS  ,  22.04 LTS 
CNI :
 calico   # wave??
```
### about script
````
- use aws
- create vpc , subnets
- create  ec2 (spot ) master and workers 
- init master node by kubeadm 
- copy join token to s3
- load   join token  from s3 to worker node and join to the cluster .

````
## Requirements
```` 
terrafrom  >= v1.1.7
terragrunt >= v0.36.1
aws IAM user  + Access key  (or IAM role ) with  Admin privilege  form VPC, EC2  
aws profile 
````


# setup 

## update terragrunt config
````
cd environments
# set region , s3 , and dynamoDB
vim terragrunt.hcl

````
## create VPC 
````
cd environments/cks/vpc
# edit  cidrs and AZ 
vim terragrunt.hcl
terragrunt apply
````

## create k8s 
````
cd environments/cks/k8s
# edit  k8s version ,s3 , nodes size ,key_name  , and etc 
vim terragrunt.hcl
terragrunt apply
````
## login to master node
````
# find {master_external_ip} in terraform output
# login to master node via ssh    

````

## Init logs  (Into nodes )
```
tail -f /var/log/cloud-init-output.log

```

# clean
## destroy k8s cluster 
````
cd environments/cks/k8s
terragrunt destroy
````

## destroy vpc  
````
cd environments/cks/vpc
terragrunt destroy
````
