
#### Answer:

Syscalls are used by processes running in Userspace to communicate with the Linux Kernel. There are many available syscalls: https://man7.org/linux/man-pages/man2/syscalls.2.html. It makes sense to restrict these for container processes and Docker/Containerd already restrict some by default, like the reboot Syscall. Restricting even more is possible for example using Seccomp or AppArmor.

But for this task we should simply find out which binary process executes a specific Syscall. Processes in containers are simply run on the same Linux operating system, but isolated. That's why we first check on which nodes the Pods are running:

```sh
root@ip-10-2-7-187:/home/ubuntu# kubectl  get  po -n team-yellow  -o wide
NAME                           READY   STATUS    RESTARTS   AGE     IP             NODE            NOMINATED NODE   RE                                                           ADINESS GATES
deployment1-7d98bcb9cc-5f75b   1/1     Running   0          7m43s   10.0.171.195   ip-10-2-7-187   <none>           <n                                                           one>
deployment2-8587c99955-p8dbq   1/1     Running   0          7m43s   10.0.171.197   ip-10-2-7-187   <none>           <n                                                           one>
root@ip-10-2-7-187:/home/ubuntu# kubectl  get  po -n team-yellow  -o wide
NAME                           READY   STATUS    RESTARTS   AGE     IP             NODE            NOMINATED NODE   READINESS GATES
deployment1-7d98bcb9cc-5f75b   1/1     Running   0          7m53s   10.0.171.195   ip-10-2-7-187   <none>           <none>
deployment2-8587c99955-p8dbq   1/1     Running   0          7m53s   10.0.171.197   ip-10-2-7-187   <none>           <none>

root@ip-10-2-7-187:/home/ubuntu# kubectl  get no
NAME            STATUS   ROLES           AGE     VERSION
ip-10-2-7-187   Ready    control-plane   8m33s   v1.26.0

```

All on `controlplane node `, hence we ssh into it and find the processes for the first Deployment collector1 .

```sh

root@ip-10-2-7-187:/home/ubuntu# crictl pods --name deployment1-7d98bcb9cc-5f75b
POD ID              CREATED             STATE               NAME                           NAMESPACE           ATTEMPT             RUNTIME
0d33d29028c12       9 minutes ago       Ready               deployment1-7d98bcb9cc-5f75b   team-yellow         1                   (default)


root@ip-10-2-7-187:/home/ubuntu# crictl ps --pod 0d33d29028c12
CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID              POD
8b6574beaedf4       2954c3acbc4f7       10 minutes ago      Running             busybox             0                   0d33d29028c12       deployment1-7d98bcb9cc-5f75b


root@ip-10-2-7-187:/home/ubuntu# crictl inspect 8b6574beaedf4 | grep args -A1
        "args": [
          "/app1"

```

* Using crictl pods we first searched for the Pods of Deployment collector1, which has one replica
* We then took one pod-id to find it's containers using crictl ps
* And finally we used crictl inspect to find the process name, which is app1

We can find the process PIDs (two because there are two Pods):

```
root@ip-10-2-7-187:/home/ubuntu# ps aux | grep app1
root       23669  0.0  0.0 709600   992 ?        Ssl  07:37   0:00 /app1
root       31252  0.0  0.0   8168   720 pts/0    S+   07:49   0:00 grep --color=auto app1

```

Using the PIDs we can call strace to find Sycalls:

```sh
root@ip-10-2-7-187:/home/ubuntu# strace -p 23669
strace: Process 23669 attached
epoll_pwait(3, [], 128, 316, NULL, 0)   = 0
futex(0xc000036548, FUTEX_WAKE_PRIVATE, 1) = 1
write(2, "I am working \n", 14)         = 14
epoll_pwait(3, [], 128, 499, NULL, 0)   = 0
epoll_pwait(3, [], 128, 1, NULL, 0)     = 0
futex(0xc000036548, FUTEX_WAKE_PRIVATE, 1) = 1
write(2, "I am working \n", 14)         = 14
futex(0xc000036548, FUTEX_WAKE_PRIVATE, 1) = 1
epoll_pwait(3, [], 128, 499, NULL, 0)   = 0
epoll_pwait(3, [], 128, 1, NULL, 0)     = 0
futex(0xc000036548, FUTEX_WAKE_PRIVATE, 1) = 1
write(2, "I am working \n", 14)         = 14
futex(0xc000036548, FUTEX_WAKE_PRIVATE, 1) = 1
futex(0x4caaa8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caaa8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caaa8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caaa8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caaa8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caaa8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0

 <detached ...>
...
```

First  is ok

Next let's check the Deployment app2 processes:

```sh
root@ip-10-2-7-187:/home/ubuntu# ps aux | grep app2
root       23825  0.0  0.0 709600   992 ?        Ssl  07:37   0:00 /app2
root       32822  0.0  0.0   8168   656 pts/0    S+   07:51   0:00 grep --color=auto app2
root@ip-10-2-7-187:/home/ubuntu# strace -p 23825
strace: Process 23825 attached
epoll_pwait(3, [], 128, 15, NULL, 0)    = 0
futex(0xc000036948, FUTEX_WAKE_PRIVATE, 1) = 1
write(2, "I am working \n", 14)         = 14
kill(666, SIGTERM)                      = -1 ESRCH (No such process)
futex(0xc000036948, FUTEX_WAKE_PRIVATE, 1) = 1
futex(0x4caac8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caac8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caac8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0
futex(0x4caac8, FUTEX_WAIT_PRIVATE, 0, NULL) = 0

```
we  catch  kill(666, SIGTERM)

```sh
kubectl  -n team-yellow scale deploy deployment2 --replicas 0
```
