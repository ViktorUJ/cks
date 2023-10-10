```
sudo su 
```
``` 
sysdig --help
sysdig --list
sysdig --list | grep container
sysdig --list | grep user
sysdig --list | grep time
sysdig --list | grep k8s

```

```
sysdig  -p"%evt.time,%container.id,%container.name,%user.name,%k8s.ns.name,%k8s.pod.name"   container.image=docker.io/library/nginx:latest

sysdig  -p"%evt.time,%container.id,%container.name,%user.name,%k8s.ns.name,%k8s.pod.name"   container.image=docker.io/library/nginx:latest>/tmp/log
# wait 20 sec 

```