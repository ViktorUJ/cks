# 1.  Container Runtime Sandbox gVisor
Task weight: 4%
cluster : cluster1 (context  cluster1-admin@cluster1 )

- runsc was  installed on node2 (label  node_name=node_2 )
- create RuntimeClass  gvisor with handler runsc
- add label RuntimeClass=runsc  to node2  
- update pods in Namespace team-purple to use  RuntimeClass  gvisor .
- Make sure the Pod runs on node with gvisor  
- Write the dmesg output of the successfully started one of Pod into /var/work/tests/artifacts/1/gvisor-dmesg .

# 2. Image Vulnerability Scanning
Task weight: 2%
cluster : cluster1 (context  cluster1-admin@cluster1 )
- trivy is installed on your worker node
- check image in pods  in team-xxx namespace  , find image  without CRITICAL vulnerability . Other deployment scale to 0 replica.

# 3. Enable audit log 
Task weight: 7%
cluster : cluster2 (context  cluster2-admin@cluster2 )
- logs  /var/logs/kubernetes-api.log
- policy /etc/kubernetes/policy/log-policy.yaml
  1. From Secret resources, level Metadata, namespace prod.
  2. From configmaps ,  level RequestResponse, namespace billing.

# 4. CIS Benchmark
Task weight: 3%
cluster : cluster1 (context  cluster3-admin@cluster3 )

CIS Benchmark  is installed  on nodes

- fix on control-plane :
  1.2.18 Ensure that the --profiling argument is set to false
  1.3.2 Ensure that the --profiling argument is set to false (Automated)
  1.4.1 Ensure that the --profiling argument is set to false (Automated)

- fix on worker node :
  4.2.6 Ensure that the --protect-kernel-defaults argument is set to true (Automated)

# 5. Secrets
Task weight: 2%
cluster : cluster1 (context  cluster1-admin@cluster1 )

from secret db  in team-5 ns  save :
  - user  context to /var/work/tests/artifacts/5/user
  - password  context to /var/work/tests/artifacts/5/password
  - create new secret db-admin { user=xxx  , password=yyyy }
  - create pod  db-admin NS=team-5  image = viktoruj/cks-lab , command = sleep 60000 , and mount secret db-admin   to /mnt/secret

# 6. set tls version  and  allowed ciphers for etcd , kube-api  , kubelet   
Task weight: 6%
cluster : cluster1 (context  cluster4-admin@cluster4 )

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
cluster : cluster5 (context  cluster5-admin@cluster5 )

1. create  encrypt  config (/etc/kubernetes/enc/enc.yaml): 
  
 - aesgcm 
    key1  : c2VjcmV0IGlzIHNlY3VyZQ==
    key2  : dGhpcyBpcyBwYXNzd29yZA==
 - resources: secret 
 

2. create new secret test-secret NS = prod , password=strongPassword
3. encrypt  all secrets in stage  ns     with new config

