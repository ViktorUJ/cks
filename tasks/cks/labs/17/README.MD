Audit Log Policy
Task weight: 7%

Audit Logging has been enabled in the cluster with an Audit Policy located at /etc/kubernetes/audit/policy.yaml on cluster2-master1 .
Change the configuration so that only one backup of the logs is stored.
Alter the Policy in a way that it only stores logs:
1. From Secret resources, level Metadata
2. From "system:nodes" userGroups, level RequestResponse
After you altered the Policy make sure to empty the log file so it only contains entries according to your changes, like using truncate -s 0
/etc/kubernetes/audit/logs/audit.log

NOTE: You can use jq to render json more readable. cat data.json | jq
