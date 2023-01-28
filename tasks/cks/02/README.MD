Task weight: 4%

use 


Falco is installed with default configuration on node cluster1-worker1 . Connect using ssh cluster1-worker1 . Use it to:
1. Find a Pod running image nginx which creates unwanted package management processes inside its container.
2. Find a Pod running image httpd which modifies /etc/passwd .
Save the Falco logs for case 1 under /opt/course/2/falco.log in format:
No other information should be in any line. Collect the logs for at least 30 seconds.
Afterwards remove the threads (both 1 and 2) by scaling the replicas of the Deployments that control the offending Pods down to 0.