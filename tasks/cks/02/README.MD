Runtime Security with Falco
Task weight: 4%


Install falco on worker-node-1.
```` 
https://falco.org/docs/getting-started/installation/#rule-update
````
Connect using ssh worker-node-1. Use it to:
Pod running image nginx which creates unwanted package management processes inside its container. Find a Pod running image httpd which modifies /etc/passwd. Save the Falco logs for case 1 under /opt/course/2/falco.log in format:
time-with-nanosconds,container-id,container-name,user-name
No other information should be in any line. Collect the logs for at least 30 seconds.
Afterwards remove the threads (both 1 and 2) by scaling the replicas of the Deployments that control the offending Pods down to 0.