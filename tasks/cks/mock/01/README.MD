# 1.  Container Runtime Sandbox gVisor
Task weight: 4%
cluster : cluster1 (  kubectl config use-context   cluster1-admin@cluster1   )

- runsc was  installed on node2 (label  node_name=node_2 )
- create RuntimeClass  gvisor with handler runsc
- add label RuntimeClass=runsc  to node2  
- update pods in Namespace team-purple to use  RuntimeClass  gvisor .
- Make sure the Pod runs on node with gvisor  
- Write the dmesg output of the successfully started one of Pod into /var/work/tests/artifacts/1/gvisor-dmesg .

# 2. Image Vulnerability Scanning
Task weight: 2%
cluster : cluster1 (  kubectl config use-context   cluster1-admin@cluster1   )
- trivy is installed on your worker node
- check image in pods  in team-xxx namespace  , find image  without CRITICAL vulnerability . Other deployment scale to 0 replica.

# 3. Enable audit log 
Task weight: 7%
cluster : cluster2 (  kubectl config use-context   cluster2-admin@cluster2 )
- logs  /var/logs/kubernetes-api.log
- policy /etc/kubernetes/policy/log-policy.yaml
  1. From Secret resources, level Metadata, namespace prod.
  2. From configmaps ,  level RequestResponse, namespace billing.

# 4. CIS Benchmark
Task weight: 3%
cluster : cluster3 (  kubectl config use-context   cluster3-admin@cluster3  )

CIS Benchmark  is installed  on nodes

- fix on control-plane :
  1.2.18 Ensure that the --profiling argument is set to false
  1.3.2 Ensure that the --profiling argument is set to false (Automated)
  1.4.1 Ensure that the --profiling argument is set to false (Automated)

- fix on worker node :
  4.2.6 Ensure that the --protect-kernel-defaults argument is set to true (Automated)

# 5. Secrets
Task weight: 2%
cluster : cluster6 (   kubectl config use-context   cluster6-admin@cluster6 )

from secret db  in team-5 ns  save :
  - user  context to /var/work/tests/artifacts/5/user
  - password  context to /var/work/tests/artifacts/5/password
  - create new secret db-admin { user=xxx  , password=yyyy }
  - create pod  db-admin NS=team-5  image = viktoruj/cks-lab , command = sleep 60000 , and mount secret db-admin   to /mnt/secret

# 6. set tls version  and  allowed ciphers for etcd , kube-api  , kubelet   
Task weight: 6%
cluster : cluster1 (  kubectl config use-context    cluster4-admin@cluster4   )

  kube-api :
   - tls  cipher  =  TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
   - tls min version 1.3 
 
  etcd :
   - tls  cipher  =  TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

  kubelet:
   - tls  cipher  =  TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
   - tls min version 1.3

# 7. encrypt  secrets in  ETCD
Task weight: 6%
cluster : cluster5 (   kubectl config use-context    cluster5-admin@cluster5    )

1. create  encrypt  config (   /etc/kubernetes/enc/enc.yaml   ): 
  
 - aescbc 
    key1  : MTIzNDU2Nzg5MDEyMzQ1Ng==
 - resources: secret 
 

2. create new secret test-secret NS = prod , password=strongPassword
3. encrypt  all secrets in stage  ns     with new config


# 8. Network policy
Task weight: 6%
cluster : cluster6 (   kubectl config use-context    cluster6-admin@cluster6   )
 - create default deny ingress policy in prod-db NS
 - create policy  with allow connections from prod Namespaces to  prod-db
 - create policy  with allow connections from stage Namespaces and have label: role=db-connect
 - create policy  with allow connections from any Namespaces and have label: role=db-external-connect

# 9. AppArmor
Task weight: 3%
cluster : cluster6 (   kubectl config use-context    cluster6-admin@cluster6   )
- install appArmor profile from /opt/course/9/profile (work pc)  to worker node on cluster
- Add label security=apparmor to the Node
- Create a Deployment named apparmor in  apparmor Namespace with:
    image nginx:1.19.2 
    container named c1
    AppArmor profile enabled
    nodeSelector to workerNode
-  save logs of the Pod into /var/work/tests/artifacts/9/log

# 10. Deployment  security
Task weight: 6%
cluster : cluster6 (   kubectl config use-context    cluster6-admin@cluster6   )

Modify deployment secure in secure Namespace  : 
 - prevent escalation
 - Read only root file system
 - user id   3000
 - grup id   3000
 - allow wread to /tmp/  container c1

, security context, user id, prevent escalation, Read only root file system

# 11. RBAC  . 
Task weight: 6%
cluster : cluster6 (kubectl config use-context    cluster6-admin@cluster6 )

- update existing permissions for SA dev in Namespaces  rbac-1 :
  > delete verb    "delete" for pods
  > add verb "watch"  for pods

- create new role  dev   in  rbac-2  Namespaces :
   > resource configmaps , verbs =  get,list
-  create rolebinding  dev in rbac-2   , sa = dev in rbac-1 Namespace

- create pod  dev-rbac  NS=rbac-1  image = viktoruj/cks-lab , command = sleep 60000 , SA=dev

# 12. falco , sysdig 
Task weight: 6%
cluster : cluster7 (  kubectl config use-context    cluster7-admin@cluster7   )

use falco or sysdig , prepare  logs  in format 
time-with-nanosconds, container-id,container-name,user-name ,kubernetes-namespace ,kubernetes-pod-name 
for pod with image nginx 
and store log to /var/work/tests/artifacts/12/log


# 13. image policy webhook
Task weight: 6%
cluster : cluster8 (   kubectl config use-context    cluster8-admin@cluster8   )

configure image policy webhook:
 - /etc/kubernetes/pki/admission_config.json 
 - /etc/kubernetes/pki/webhook/admission_kube_config.yaml
 -  https://image-bouncer-webhook:30020/image_policy   

create pod  test-lasted   in default ns    with image nginx   
   result " Error from server (Forbidden): pods "test" is forbidden: image policy webhook .... latest tag are not allowed"
create pod  test-tag   in default ns    with image nginx:alpine3.17
   result - ok



# 14. fix Dockerfile 
Task weight: 4%
cluster : any

fix Dockerfile    /var/work/14/Dockerfile  

- use FROM image   20.04  version 
- use myuser  for   running  app
- build image cks:14   ( podman installed on worker pc )



