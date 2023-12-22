
https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

```
sudo su
mkdir /etc/kubernetes/enc/  -p

```
```
# vim /etc/kubernetes/enc/enc.yaml

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
      - identity: {}

````
```
# vim /etc/kubernetes/manifests/kube-apiserver.yaml

apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.20.30.40:443
  creationTimestamp: null
  labels:
    app.kubernetes.io/component: kube-apiserver
    tier: control-plane
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    ...
    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml  # add this line
    volumeMounts:
    ...
    - name: enc                           # add this line
      mountPath: /etc/kubernetes/enc      # add this line
      readOnly: true                      # add this line
    ...
  volumes:
  ...
  - name: enc                             # add this line
    hostPath:                             # add this line
      path: /etc/kubernetes/enc           # add this line
      type: DirectoryOrCreate             # add this line
  ...
```

```
service kubelet restart
k get no
# wait k8s ready
```
```
k create secret generic test-secret -n prod --from-literal password=strongPassword
```
```
# encrypt all secrets in stage ns with new config

kubectl get secrets -n stage -o json | kubectl replace -f -

```

```
# check

ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/stage/stage | hexdump -C

```
