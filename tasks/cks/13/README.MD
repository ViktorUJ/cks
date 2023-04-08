 Restrict access to Metadata Server
Task weight: 7%
Use context: kubectl config use-context infra-prod

There is a metadata service available at http://{master_external_ip}:30089 on which Nodes can reach sensitive data,
like cloud credentials for initialisation. By default, all Pods in the cluster also have access to this endpoint. 
The DevSecOps team has asked you to restrict access to this metadata server.

In Namespace metadata-access:

Create a NetworkPolicy named metadata-deny which prevents egress to {master_external_ip} for all Pods but still allows access to everything else
Create a NetworkPolicy named metadata-allow which allows Pods having label role: metadata-accessor to access endpoint {master_external_ip}:30089
There are existing Pods in the target Namespace with which you can test your policies, but don't change their labels.

