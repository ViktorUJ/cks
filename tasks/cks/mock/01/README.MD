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
