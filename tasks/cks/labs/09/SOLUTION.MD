https://kubernetes.io/docs/tutorials/clusters/apparmor

Part 1
First we have a look at the provided profile:

vim /opt/course/9/profile
# /opt/course/9/profile

#include <tunables/global>

profile very-secure flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # Deny all file writes.
  deny /** w,
}
Very simple profile named very-secure which denies all file writes. Next we copy it onto the Node:

➜ scp /opt/course/9/profile cluster1-node1:~/
Warning: Permanently added the ECDSA host key for IP address '192.168.100.12' to the list of known hosts.
profile                                                                           100%  161   329.9KB/s   00:00

➜ ssh cluster1-node1

➜ root@cluster1-node1:~# ls
profile
And install it:

➜ root@cluster1-node1:~# apparmor_parser -q ./profile
Verify it has been installed:

➜ root@cluster1-node1:~# apparmor_status
apparmor module is loaded.
17 profiles are loaded.
17 profiles are in enforce mode.
   /sbin/dhclient
...
   man_filter
   man_groff
   very-secure
0 profiles are in complain mode.
56 processes have profiles defined.
56 processes are in enforce mode.
...
0 processes are in complain mode.
0 processes are unconfined but have a profile defined.
There we see among many others the very-secure one, which is the name of the profile specified in /opt/course/9/profile.

Part 2
We label the Node:

k label -h # show examples

k label node cluster1-node1 security=apparmor
Part 3
Now we can go ahead and create the Deployment which uses the profile.

k create deploy apparmor --image=nginx:1.19.2 $do > 9_deploy.yaml
vim 9_deploy.yaml
# 9_deploy.yaml
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
k -f 9_deploy.yaml create
What the damage?

➜ k get pod -owide | grep apparmor
apparmor-85c65645dc-jbch8     0/1     CrashLoopBackOff  ...   cluster1-node1

➜ k logs apparmor-85c65645dc-w852p
/docker-entrypoint.sh: 13: /docker-entrypoint.sh: cannot create /dev/null: Permission denied
/docker-entrypoint.sh: No files found in /docker-entrypoint.d/, skipping configuration
2021/09/15 11:51:57 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
This looks alright, the Pod is running on cluster1-node1 because of the nodeSelector. The AppArmor profile simply denies all filesystem writes, but Nginx needs to write into some locations to run, hence the errors.

It looks like our profile is running but we can confirm this as well by inspecting the container:

➜ ssh cluster1-node1

➜ root@cluster1-node1:~# crictl pods | grep apparmor
be5c0aecee7c7       4 minutes ago       Ready               apparmor-85c65645dc-jbch8   ...

➜ root@cluster1-node1:~# crictl ps -a | grep be5c0aecee7c7
e4d91cbdf72fb    ...  Exited       c1           6            be5c0aecee7c7

➜ root@cluster1-node1:~# crictl inspect e4d91cbdf72fb | grep -i profile
          "apparmor_profile": "localhost/very-secure",
        "apparmorProfile": "very-secure",

First we find the Pod by it's name and get the pod-id. Next we use crictl ps -a to also show stopped containers. Then crictl inspect shows that the container is using our AppArmor profile. Notice to be fast between ps and inspect as K8s will restart the Pod periodically when in error state.

To complete the task we write the logs into the required location:

k logs apparmor-85c65645dc-jbch8 > /opt/course/9/logs
Fixing the errors is the job of another team, lucky us.
