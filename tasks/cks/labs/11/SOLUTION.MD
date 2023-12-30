```
mkdir /var/work/tests/artifacts/11/ -p
```

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
--cacert /etc/kubernetes/pki/etcd/ca.crt get /registry/secrets/team-green/database-access >/var/work/tests/artifacts/11/plaintext

````
```
ETCDCTL_API=3 etcdctl \
--cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
--key /etc/kubernetes/pki/apiserver-etcd-client.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt get /registry/secrets/team-green/database-access
# find password and store it to /var/work/tests/artifacts/11/database-password
```
