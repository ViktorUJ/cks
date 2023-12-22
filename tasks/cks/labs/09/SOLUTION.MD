https://kubernetes.io/docs/tutorials/clusters/apparmor

```
k get no
ssh {work node}
```
```

#cat  /opt/course/9/profile

#include <tunables/global>

profile very-secure flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
```
```
apparmor_parser -q  /opt/course/9/profile
apparmor_status
```

```
k label node {work-node} security=apparmor

```
```
k create deploy apparmor --image=nginx:1.19.2 $do > 9.yaml
```
```
#vim 9.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: apparmor
  name: apparmor
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apparmor
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: apparmor
      annotations:                                                                 # add
        container.apparmor.security.beta.kubernetes.io/c1: localhost/very-secure   # add
    spec:
      nodeSelector:                    # add
        security: apparmor             # add
      containers:
      - image: nginx:1.19.2
        name: c1                       # change
        resources: {}
```
```
k -f 9.yaml apply
k get pod -owide | grep apparmor

k logs apparmor-{xxxx}

```
```
/docker-entrypoint.sh: 13: /docker-entrypoint.sh: cannot create /dev/null: Permission denied
/docker-entrypoint.sh: No files found in /docker-entrypoint.d/, skipping configuration
2021/09/15 11:51:57 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
This looks alright, the Pod is running on cluster1-node1 because of the nodeSelector. The AppArmor profile simply denies all filesystem writes, but Nginx needs to write into some locations to run, hence the errors.
```
