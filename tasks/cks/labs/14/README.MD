Task weight: 4%

There are Pods in Namespace team-yellow. 
A security investigation noticed that some processes running in these Pods are using the Syscall kill,
which is forbidden by a Team Yellow internal policy.

Find the offending Pod(s) and remove these by reducing the replicas of the parent Deployment to 0.