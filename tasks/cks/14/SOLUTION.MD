
#### Answer:

Syscalls are used by processes running in Userspace to communicate with the Linux Kernel. There are many available syscalls: https://man7.org/linux/man-pages/man2/syscalls.2.html. It makes sense to restrict these for container processes and Docker/Containerd already restrict some by default, like the reboot Syscall. Restricting even more is possible for example using Seccomp or AppArmor.

But for this task we should simply find out which binary process executes a specific Syscall. Processes in containers are simply run on the same Linux operating system, but isolated. That's why we first check on which nodes the Pods are running:

```sh
➜ k -n team-yellow get pod -owide
NAME                                 ...   NODE               NOMINATED NODE   ...
collector1-7585cc58cb-n5rtd   1/1    ...   cluster1-node1   <none>           ...
collector1-7585cc58cb-vdlp9   1/1    ...   cluster1-node1   <none>           ...
collector2-8556679d96-z7g7c   1/1    ...   cluster1-node1   <none>           ...
collector3-8b58fdc88-pjg24    1/1    ...   cluster1-node1   <none>           ...
collector3-8b58fdc88-s9ltc    1/1    ...   cluster1-node1   <none>           ...
```

All on `cluster1-node1`, hence we ssh into it and find the processes for the first Deployment collector1 .

```sh
➜ ssh cluster1-node1

➜ root@cluster1-node1:~# crictl pods --name collector1
POD ID              CREATED             STATE        NAME                          ...
21aacb8f4ca8d       17 minutes ago      Ready        collector1-7585cc58cb-vdlp9   ...
186631e40104d       17 minutes ago      Ready        collector1-7585cc58cb-n5rtd   ...

➜ root@cluster1-node1:~# crictl ps --pod 21aacb8f4ca8d
CONTAINER ID        IMAGE               CREATED          ...       POD ID
9ea02422f8660       5d867958e04e1       12 minutes ago   ...       21aacb8f4ca8d

➜ root@cluster1-node1:~# crictl inspect 9ea02422f8660 | grep args -A1
        "args": [
          "./collector1-process"
```

* Using crictl pods we first searched for the Pods of Deployment collector1, which has two replicas
* We then took one pod-id to find it's containers using crictl ps
* And finally we used crictl inspect to find the process name, which is collector1-process

We can find the process PIDs (two because there are two Pods):

```
➜ root@cluster1-node1:~# ps aux | grep collector1-process
root       35039  0.0  0.1 702208  1044 ?        Ssl  13:37   0:00 ./collector1-process
root       35059  0.0  0.1 702208  1044 ?        Ssl  13:37   0:00 ./collector1-process
```

Using the PIDs we can call strace to find Sycalls:

```sh
➜ root@cluster1-node1:~# strace -p 35039
strace: Process 35039 attached
futex(0x4d7e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
kill(666, SIGTERM)                      = -1 ESRCH (No such process)
epoll_pwait(3, [], 128, 999, NULL, 1)   = 0
kill(666, SIGTERM)                      = -1 ESRCH (No such process)
epoll_pwait(3, [], 128, 999, NULL, 1)   = 0
kill(666, SIGTERM)                      = -1 ESRCH (No such process)
epoll_pwait(3, ^Cstrace: Process 35039 detached
 <detached ...>
...
```

First try and already a catch! We see it uses the forbidden Syscall by calling kill(666, SIGTERM).

Next let's check the Deployment collector2 processes:

```sh
➜ root@cluster1-node1:~# ps aux | grep collector2-process
root       35375  0.0  0.0 702216   604 ?        Ssl  13:37   0:00 ./collector2-process

➜ root@cluster1-node1:~# strace -p 35375
strace: Process 35375 attached
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
...
```

Looks alright. What about collector3:

```sh
➜ root@cluster1-node1:~# ps aux | grep collector3-process
root       35155  0.0  0.1 702472  1040 ?        Ssl  13:37   0:00 ./collector3-process
root       35241  0.0  0.1 702472  1044 ?        Ssl  13:37   0:00 ./collector3-process

➜ root@cluster1-node1:~# strace -p 35155
strace: Process 35155 attached
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4d9e68, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
epoll_pwait(3, [], 128, 999, NULL, 1)   = 0
epoll_pwait(3, [], 128, 999, NULL, 1)   = 0
...
```

Also nothing about the forbidden Syscall. So we finalise the task:

```sh
k -n team-yellow scale deploy collector1 --replicas 0
```

And the world is a bit safer again.
