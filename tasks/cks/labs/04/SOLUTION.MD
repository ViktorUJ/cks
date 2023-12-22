https://kubernetes.io/docs/tutorials/security/ns-level-pss/

```
k get ns team-red --show-labels

kubectl label --overwrite ns team-red  pod-security.kubernetes.io/enforce=baseline

k get ns team-red --show-labels
```

```
k get po -n team-red
# delete all pods in ns team-red

k delete po {pod_names} -n  team-red --force
```

```
k get po -n team-red

# No resources found in team-red namespace.

```

```
k  events  replicasets.apps  -n team-red
mkdir /var/work/tests/artifacts/4/ -p
k  events  replicasets.apps  -n team-red >/var/work/tests/artifacts/4/events.log
```
