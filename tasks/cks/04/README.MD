Question 4 | Pod Security Standard
Task weight: 8%

There is Deployment container-host-hacker in Namespace team-red which mounts /run/containerd as a hostPath volume on the Node where its running.
This means that the Pod can access various data about other containers running on the same Node.

To prevent this configure Namespace team-red to enforce the baseline Pod Security Standard. Once completed, delete the Pod of the Deployment mentioned above.

Check the ReplicaSet events and write the event/log lines containing the reason why the Pod isn't recreated into /opt/course/4/logs.