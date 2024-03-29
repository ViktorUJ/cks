https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/

```
sudo su

mkdir -p /etc/kubernetes/policy/

```
```
# vim /etc/kubernetes/policy/log-policy.yaml

apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: "" # core API group
    resources: ["secrets"]
  namespaces: ["prod"]
- level: RequestResponse
  resources:
  - group: "" # core API group
    resources: ["configmaps"]
  namespaces: ["billing"]
- level: None
```
```
# vim /etc/kubernetes/manifests/kube-apiserver.yaml

apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.2.16.248:6443
  creationTimestamp: null
  labels:
    component: kube-apiserver
    tier: control-plane
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=10.2.16.248
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --enable-admission-plugins=NodeRestriction
    - --enable-bootstrap-token-auth=true
    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    - --etcd-servers=https://127.0.0.1:2379
    - --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
    - --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
    - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
    - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
    - --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
    - --requestheader-allowed-names=front-proxy-client
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --requestheader-extra-headers-prefix=X-Remote-Extra-
    - --requestheader-group-headers=X-Remote-Group
    - --requestheader-username-headers=X-Remote-User
    - --secure-port=6443
    - --service-account-issuer=https://kubernetes.default.svc.cluster.local
    - --service-account-key-file=/etc/kubernetes/pki/sa.pub
    - --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
    - --service-cluster-ip-range=10.96.0.0/12
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    - --audit-policy-file=/etc/kubernetes/policy/log-policy.yaml           # add
    - --audit-log-path=/var/logs/kubernetes-api.log                        # add

    image: registry.k8s.io/kube-apiserver:v1.28.0
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 8
      httpGet:
        host: 10.2.16.248
        path: /livez
        port: 6443
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    name: kube-apiserver
    readinessProbe:
      failureThreshold: 3
      httpGet:
        host: 10.2.16.248
        path: /readyz
        port: 6443
        scheme: HTTPS
      periodSeconds: 1
      timeoutSeconds: 15
    resources:
      requests:
        cpu: 250m
    startupProbe:
      failureThreshold: 24
      httpGet:
        host: 10.2.16.248
        path: /livez
        port: 6443
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ca-certs
      readOnly: true
    - mountPath: /etc/ca-certificates
      name: etc-ca-certificates
      readOnly: true
    - mountPath: /etc/pki
      name: etc-pki
      readOnly: true
    - mountPath: /etc/kubernetes/pki
      name: k8s-certs
      readOnly: true
    - mountPath: /usr/local/share/ca-certificates
      name: usr-local-share-ca-certificates
      readOnly: true
    - mountPath: /usr/share/ca-certificates
      name: usr-share-ca-certificates
      readOnly: true

    - mountPath: /etc/kubernetes/policy/log-policy.yaml    # add
      name: audit                                          # add
      readOnly: true                                       # add
    - mountPath: /var/logs/                                # add
      name: audit-log                                      # add
      readOnly: false

  hostNetwork: true
  priority: 2000001000
  priorityClassName: system-node-critical
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - hostPath:
      path: /etc/ssl/certs
      type: DirectoryOrCreate
    name: ca-certs
  - hostPath:
      path: /etc/ca-certificates
      type: DirectoryOrCreate
    name: etc-ca-certificates
  - hostPath:
      path: /etc/pki
      type: DirectoryOrCreate
    name: etc-pki
  - hostPath:
      path: /etc/kubernetes/pki
      type: DirectoryOrCreate
    name: k8s-certs
  - hostPath:
      path: /usr/local/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-local-share-ca-certificates
  - hostPath:
      path: /usr/share/ca-certificates
      type: DirectoryOrCreate
    name: usr-share-ca-certificates

  - name: audit                                             # add
    hostPath:                                               # add
      path: /etc/kubernetes/policy/log-policy.yaml          # add
      type: File                                            # add
                                                            # add
  - name: audit-log                                         # add
    hostPath:                                               # add
      path: /var/logs/                                      # add
      type: DirectoryOrCreate                               # add


status: {}


```
```
service kubelet restart
k get no
k get secret -n prod
k get configmaps -n billing


```

```
# cat /var/logs/kubernetes-api.log | jq  | grep secrets  -B 5 -A 5

--
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "Metadata",
  "auditID": "a6b8945f-4914-4ba9-a80a-ea2441ad1e4f",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/prod/secrets/db",
  "verb": "get",
  "user": {
    "username": "system:serviceaccount:prod:k8api",
    "uid": "cd47986d-8f88-4451-9de4-77fb3e9d46bb",
    "groups": [
--
  "sourceIPs": [
    "10.0.229.65"
  ],
  "userAgent": "curl/8.2.1",
  "objectRef": {
    "resource": "secrets",
    "namespace": "prod",
    "name": "db",
    "apiVersion": "v1"
  },
  "responseStatus": {


```

```
# cat /var/logs/kubernetes-api.log | jq  | grep configmaps  -B 5 -A 5


--
  "sourceIPs": [
    "10.2.16.248"
  ],
  "userAgent": "kubectl/v1.28.0 (linux/arm64) kubernetes/855e7c4",
  "objectRef": {
    "resource": "configmaps",
    "namespace": "billing",
    "name": "bill",
    "apiVersion": "v1"
  },
  "requestReceivedTimestamp": "2023-09-27T19:14:33.778635Z",
--
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "0266674d-db53-4a3d-bf9c-940c6aa43440",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/billing/configmaps/bill?fieldManager=kubectl-edit&fieldValidation=Strict",
  "verb": "patch",
  "user": {
    "username": "kubernetes-admin",
    "groups": [
      "system:masters",


```
