```
sudo su
```
````
# check  admission_config.json
cat  /etc/kubernetes/pki/admission_config.json
````
````
# check  admission_kube_config.yaml
cat  /etc/kubernetes/pki/webhook/admission_kube_config.yaml
````

```
# vim  /etc/kubernetes/pki/webhook/admission_kube_config.yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/webhook/server.crt
    server: https://image-bouncer-webhook:30020/image_policy  # add
  name: bouncer_webhook
contexts:
- context:
    cluster: bouncer_webhook
    user: api-server
  name: bouncer_validator
current-context: bouncer_validator
preferences: {}
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/pki/apiserver.crt
    client-key:  /etc/kubernetes/pki/apiserver.key

```

```
# vim /etc/kubernetes/manifests/kube-apiserver.yaml
# add to api parametrs

- --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
- --admission-control-config-file=/etc/kubernetes/pki/admission_config.json

```

```
service kubelet restart

```

```
k run test-tag --image nginx
```
```
Error from server (Forbidden): pods "test-tag" is forbidden: image policy webhook backend denied one or more images: Images using latest tag are not allowed

```

```
k run test-tag --image nginx:alpine3.17
k get po test-tag
```
```
NAME       READY   STATUS    RESTARTS   AGE
test-tag   1/1     Running   0          4m47s

```
