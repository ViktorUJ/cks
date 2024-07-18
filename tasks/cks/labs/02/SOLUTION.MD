```
ssh {worker_node}
sudo su
mkdir -p /var/work/tests/artifacts/12/log
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

sysdig  -p"%evt.time,%container.id,%container.name,%user.name,%k8s.ns.name,%k8s.pod.name"   container.image=docker.io/library/nginx:latest>/var/work/tests/artifacts/12/log
# wait 20 sec

```
