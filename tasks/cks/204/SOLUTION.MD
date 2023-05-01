````
mkdir /etc/kubernetes/etcd/

````

```` 
# vim /etc/kubernetes/etcd/etcd_encrypt.yaml

apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:

      - aesgcm:
          keys:
            - name: key1
              secret: MTIzNDU2Nzg5MDEyMzQ1Ng==
      - identity: {}

````
```` 
# vim /etc/kubernetes/manifests/kube-apiserver.yaml

# add   
......


- --encryption-provider-config=/etc/kubernetes/etcd/etcd_encrypt.yaml

........
 volumeMounts:
    - mountPath: /etc/kubernetes/etcd
      name: etcd
      readOnly: true
......
volumes:
  - hostPath:
      path: /etc/kubernetes/etcd
      type: DirectoryOrCreate
    name: etcd


````

```` 
# you can restart kube-api faster 
# service kubelet restart 
````

```` 
kubectl  create secret generic  database-access-4  --from-literal pass=VerryStrongPassword4 --namespace prod
````

```` 
# create script for reading secret from ETCD
# vim 1.sh

ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/prod/database-access-4

````
```` 
chmod +x 1.sh 

./1.sh
````

```` 
# check    ..... :enc:aesgcm ....

````

```` 
# encript all secrets in prod ns 
kubectl get secrets -n prod  -o json | kubectl replace -f -

````

```` 
# update  EncryptionConfiguration

# vim /etc/kubernetes/etcd/etcd_encrypt.yaml

apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: MTIzNDU2Nzg5MDEyMzQ1Ng==
      - aesgcm:
          keys:
            - name: key1
              secret: MTIzNDU2Nzg5MDEyMzQ1Ng==
      - identity: {}
````

```` 
# restart kube-api pod

crictl ps | grep api
crictl stop {container_id}

````

```` 
# encript all secrets in prod ns  with new config 
kubectl get secrets -n prod  -o json | kubectl replace -f -
````

```` 
./1.sh 

# check    ..... :enc:aescbc .... 
````

```` 
# disable  encription 
# update  EncryptionConfiguration

# vim /etc/kubernetes/etcd/etcd_encrypt.yaml

apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - identity: {}
      - aescbc:
          keys:
            - name: key1
              secret: MTIzNDU2Nzg5MDEyMzQ1Ng==
      - aesgcm:
          keys:
            - name: key1
              secret: MTIzNDU2Nzg5MDEyMzQ1Ng==

````

```` 
# decript all secrets in prod ns  with new config 
kubectl get secrets -n prod  -o json | kubectl replace -f -
````

```` 
# vim /etc/kubernetes/manifests/kube-apiserver.yaml

# delete    
......


- --encryption-provider-config=/etc/kubernetes/etcd/etcd_encrypt.yaml

........
 volumeMounts:
    - mountPath: /etc/kubernetes/etcd
      name: etcd
      readOnly: true
......
volumes:
  - hostPath:
      path: /etc/kubernetes/etcd
      type: DirectoryOrCreate
    name: etcd

````

