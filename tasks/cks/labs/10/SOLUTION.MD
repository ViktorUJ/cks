### create runtime class

````
# vim 10_rtc.yaml

apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc

````
````
kubectl apply -f  10_rtc.yaml

````

### create pod
````
# vim 10_pod.yaml

apiVersion: v1
kind: Pod
metadata:
 labels:
   run: gvisor-test
 name: gvisor-test
 namespace: default
spec:
 nodeSelector:
   runtime: gvizor
 runtimeClassName: gvisor
 containers:
  - image: nginx:1.19.2
    name: gvisor-test

````
````
kubectl apply -f  10_pod.yaml

````

### check  pod ()
````
kubectl get po gvisor-test
````

````
NAME          READY   STATUS    RESTARTS      AGE
gvisor-test   1/1     Running   1 (65s ago)   2m30s

````

###  save log of pod

````
kubectl  exec gvisor-test -- dmesg

kubectl  exec gvisor-test -- dmesg  > /opt/course/10/gvisor-test-dmesg


````

### log of dmesg will be like this
````
    0.000000] Starting gVisor...
[    0.134154] Reticulating splines...
[    0.555629] Verifying that no non-zero bytes made their way into /dev/zero...
[    0.626825] Creating cloned children...
[    0.896914] Synthesizing system calls...
[    1.038331] Waiting for children...
[    1.411535] Constructing home...
[    1.744359] Conjuring /dev/null black hole...
[    1.900935] Adversarially training Redcode AI...
[    2.017423] Accelerating teletypewriter to 9600 baud...
[    2.318312] Feeding the init monster...
[    2.655655] Setting up VFS...
[    2.700019] Setting up FUSE...
[    3.030025] Ready!

````
