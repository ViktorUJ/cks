

#### Answer:

Making Namespaces use Pod Security Standards works via labels. We can simply edit it:
```sh
k edit ns team-red
```

Now we configure the requested label:

```yaml
# kubectl edit namespace team-red
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: team-red
    pod-security.kubernetes.io/enforce: baseline # add
  name: team-red
...
```

This should already be enough for the default Pod Security Admission Controller to pick up on that change. Let's test it and delete the Pod to see if it'll be recreated or fails, it should fail!

```sh
➜ k -n team-red get pod
NAME                                    READY   STATUS    RESTARTS   AGE
container-host-hacker-dbf989777-wm8fc   1/1     Running   0          115s

➜ k -n team-red delete pod container-host-hacker-dbf989777-wm8fc
pod "container-host-hacker-dbf989777-wm8fc" deleted

➜ k -n team-red get pod
No resources found in team-red namespace.
```

Usually the ReplicaSet of a Deployment would recreate the Pod if deleted, here we see this doesn't happen. Let's check why:

```sh
➜ k -n team-red get rs
NAME                              DESIRED   CURRENT   READY   AGE
container-host-hacker-dbf989777   1         0         0       5m25s

➜ k -n team-red describe rs container-host-hacker-dbf989777
Name:           container-host-hacker-dbf989777
Namespace:      team-red
...
Events:
  Type     Reason            Age                   From                   Message
  ----     ------            ----                  ----                   -------
...
  Warning  FailedCreate      2m41s                 replicaset-controller  Error creating: pods "container-host-hacker-dbf989777-bjwgv" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "containerdata")
  Warning  FailedCreate      2m2s (x9 over 2m40s)  replicaset-controller  (combined from similar events): Error creating: pods "container-host-hacker-dbf989777-kjfpn" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "containerdata")
  ```
There we go! Finally we write the reason into the requested file so that Mr Scoring will be happy too!

```sh
# /opt/course/4/logs
Warning  FailedCreate      2m2s (x9 over 2m40s)  replicaset-controller  (combined from similar events): Error creating: pods "container-host-hacker-dbf989777-kjfpn" is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "containerdata")
Pod Security Standards can give a great base level of security! But when one finds themselves wanting to deeper adjust the levels like baseline or restricted... this isn't possible and 3rd party solutions like OPA could be looked at.
```
