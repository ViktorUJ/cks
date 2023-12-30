-> https://kubernetes.io/docs/home/
and find  template for **RuntimeClass**

```
# vim 1.yaml

# RuntimeClass is defined in the node.k8s.io API group
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  # The name the RuntimeClass will be referenced by.
  # RuntimeClass is a non-namespaced resource.
  name: gvisor
# The name of the corresponding CRI configuration
handler: runsc
```

```
k apply -f 1.yaml
k get runtimeclasses.node.k8s.io
```
```
k get no --show-labels
```

```
k label nodes {node2} RuntimeClass=runsc
```
```
k get deployment -n team-purple
k edit deployment -n team-purple

# add runtimeClassName:  gvisor
# add nodeSelector:
#       RuntimeClass: runsc
# to all deployments
```

```
# ckeck pods in  ns  team-purple
k get po -n team-purple

```

```
mkdir -p /var/work/tests/artifacts/1/
```
```
k get po -n team-purple

k exec {pod1} -n team-purple -- dmesg

# find    Starting gVisor..

k exec {pod1} -n team-purple -- dmesg >/var/work/tests/artifacts/1/gvisor-dmesg

```
