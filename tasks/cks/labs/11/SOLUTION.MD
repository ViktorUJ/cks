### ssh to master node

### get connection parameters to etcd 

```` 
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep etcd
````

### The output is as follows :
````` 
- --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
- --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
- --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
- --etcd-servers=https://127.0.0.1:2379 # optional since we're on same node

`````

### get request to etcd 

```` 
ETCDCTL_API=3 etcdctl \
--cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
--key /etc/kubernetes/pki/apiserver-etcd-client.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt get /registry/secrets/team-green/database-access

````

ETCD in Kubernetes stores data under /registry/{type}/{namespace}/{name} . This is how we came to look for /registry/secrets/teamgreen/
database-access . There is also an example on a page in the k8s documentation which you could save as a bookmark to access fast
during the exam.


