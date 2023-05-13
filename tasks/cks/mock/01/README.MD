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
  2. From configmap,  level RequestResponse, namespace billing.

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
