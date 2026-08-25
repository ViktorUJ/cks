[Русская версия](RUNBOOK_RU.md) · [Versión en español](RUNBOOK_ES.md) · [Version française](RUNBOOK_FR.md) · [Deutsche Version](RUNBOOK_DE.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [繁體中文版](RUNBOOK_TW.md) · [日本語版](RUNBOOK_JP.md)
# EKS Troubleshooting Reference: Symptom, Cause, Check

[Course contents](README.md) · [Glossary](GLOSSARY.md)

## How to use this

This is a consolidated version of the “Troubleshooting workflow and tools” sections from chapters 45, 46, and 47, assembled into one file for on-call use: paging through three chapters during an incident is inconvenient.
Use it as follows: first identify the symptom CLASS using the “Quick entry by symptom” table, then go to the corresponding layer and work through it from top to bottom. Classification matters more than the tool: a pod in `ContainerCreating` and a 503 from a load balancer require different commands.
This reference contains only the workflow, checklists, and commands. Root-cause analysis, mechanics, and explanations remain in chapters 45-47; links to them appear in every row of the navigator.

## Quick entry by symptom

| What you see | Class | Where to go |
|---|---|---|
| `kubectl get nodes` is empty, no nodes | node did not join | [node](#node-did-not-join-the-cluster), [chapter 45](45/en.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | node did not join | [node](#node-did-not-join-the-cluster), [chapter 45](45/en.md) |
| node group in `CREATE_FAILED` or `DEGRADED` | node did not join | [node](#node-did-not-join-the-cluster), [chapter 45](45/en.md) |
| kubelet log contains `node "" not found` | node: DNS and private DNS name | [node](#node-did-not-join-the-cluster), [chapter 45](45/en.md) |
| node is visible but `NotReady` | CNI is not ready, a different layer | [node](#node-did-not-join-the-cluster), [chapter 45](45/en.md), chapter 8 |
| pod in `ContainerCreating`, `failed to assign an IP address to container` | network: IP and ENI | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| pod-to-pod or pod-to-RDS `connection timed out`, DNS resolves | network: security group | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| request leaves, but the connection hangs | network: NACL and ephemeral ports | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| pod cannot resolve names or pass readiness | network: pod-specific SG | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| DNS works intermittently, intermittent timeouts | network: DNS | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| excessive DNS load for external names | network: `ndots:5` effect | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| target group targets are `unhealthy`, 502 `Bad gateway` | network: load balancer | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| 503 `Service unavailable` from a service behind an LB | network: no healthy targets | [network](#network-failures-in-a-running-cluster), [chapter 46](46/en.md) |
| `You must be logged in to the server (Unauthorized)` | access: authentication | [access](#access-denied-human-and-pod), [chapter 47](47/en.md) |
| `couldn't get current server API group list: Unauthorized` | access: kubeconfig or region | [access](#access-denied-human-and-pod), [chapter 47](47/en.md) |
| `Forbidden: cannot <verb> resource` | access: RBAC | [access](#access-denied-human-and-pod), [chapter 47](47/en.md) |
| pod fails with `AccessDenied` when calling AWS | pod access: STS and role | [access](#access-denied-human-and-pod), [chapter 47](47/en.md) |
| pod fails with `WebIdentityErr: failed to retrieve credentials` | pod access: IRSA | [access](#access-denied-human-and-pod), [chapter 47](47/en.md) |

## Node did not join the cluster

Chapter 45. The symptom is the same, an empty `kubectl get nodes` and `NodeCreationFailure`, but the causes lie in different layers. Work through them from top to bottom:

1. IAM layer: node instance role permissions and role authorization in the cluster (section 45.2).
2. Network layer: path to the API server endpoint on port 443, endpoint type, DNS (section 45.3).
3. User data and bootstrap layer: `bootstrap.sh` on AL2, `nodeadm`/`NodeConfig` on AL2023 (45.4).
4. Kubelet layer: the daemon is running, kubeconfig and certificate are intact, registration completed (45.5).

The logic is to ask EKS first with `describe-nodegroup`, then check role authorization (inexpensive, and it is most often the culprit), then network access to the endpoint, and only then access the node for cloud-init and kubelet logs. Distinguish “no nodes” from `NotReady`: the latter with a live kubelet is almost always CNI, covered in chapter 8.

| Symptom | Likely cause | What to check |
|---|---|---|
| `NodeCreationFailure`, no nodes | node role is not authorized | `aws eks list-access-entries`, `aws-auth` |
| no nodes, IAM is correct | no path to the API on port 443 | SG, NAT/IGW route, endpoint type |
| no nodes, private cluster | endpoint does not resolve | DNS, VPC DHCP options set |
| no nodes, custom AMI | bootstrap did not run | `/var/log/cloud-init-output.log` |
| no nodes, kubelet crashes | corrupted kubeconfig/certificate | `journalctl -u kubelet` |
| node exists but is `NotReady` | CNI is not ready, pods have no IPs | `aws-node` pod, node events (chapter 8) |
| log contains `node "" not found` | no private DNS name | DHCP options, DNS in the VPC |

```bash
# 1. what EKS itself reports about the node group
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. whether the cluster sees nodes
kubectl get nodes
# 3. whether the node role is authorized
aws eks list-access-entries --cluster-name prod
# legacy path: mappings in aws-auth
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. on the node through SSM Session Manager: bootstrap/cloud-init log
sudo cat /var/log/cloud-init-output.log
# 5. on the node: kubelet status and logs
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

Access the node without SSH through SSM Session Manager: it requires the SSM agent and permissions. If SSM is unavailable, use the instance console output (system log) and `/var/log`.

## Network failures in a running cluster

Chapter 46. The cluster works and nodes are `Ready`, but the network can fail in different ways. First classify the symptom: no IP, broken connectivity, DNS, or 5xx from the load balancer. The class determines the layer and command. `describe pod` and `get pods -o wide` are inexpensive and rule out IP problems first, `describe-target-health` immediately localizes a load-balancer failure, and VPC Flow Logs are the final line of investigation for disruptions that neither IP nor health checks explain. Remember the layer difference: a security group is stateful and operates at the ENI level, whereas a NACL is stateless and operates at the subnet level, so return traffic on ephemeral ports must be explicitly allowed in the NACL.

| Symptom | Likely cause | What to check |
|---|---|---|
| `failed to assign an IP address` | no free IPs on the node or in the subnet | `describe pod`, `AvailableIpAddressCount` |
| pod-to-pod or pod-to-RDS timeout | SG does not allow traffic | `describe-network-interfaces` Groups, RDS SG |
| disruption, but the request leaves | NACL blocks ephemeral ports | NACL inbound/outbound rules, VPC Flow Logs |
| DNS has intermittent timeouts | CoreDNS, conntrack, per-ENI throttling | CoreDNS metrics (chapter 33), conntrack, PPS |
| excessive DNS load for external names | `ndots:5` effect | search domains, FQDN with a trailing dot |
| 502 or 503 from a service behind an LB | targets are `unhealthy` | `describe-target-health`, health check, SG |
| targets are `unhealthy`, pod is alive | health check path/port or SG | health check path and port, load balancer SG |
| pod has neither DNS nor readiness | pod-specific SG instead of node SG | pod `SecurityGroupPolicy`, TCP/UDP 53, inbound traffic from node SG |

```bash
# 1. pod events: reason for ContainerCreating and IP assignment
kubectl describe pod <pod>
# 2. where the pod is and which node it is on
kubectl get pods -o wide
# 3. ENI, IP, and SGs for a specific address
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. free addresses in the subnet
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. load balancer target health
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# whether the service has ready endpoints
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. test name resolution from a pod
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# pod-specific SG: application mode and search for an SG ID error
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. on the node: collect a VPC CNI network dump (ipamd/plugin logs, ENI, eni-configs)
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

The ipamd state is also available directly from its local endpoint: `/v1/enis` shows assigned ENIs and IPs, and `/v1/pods` shows address assignments to pods.

## Access denied: human and pod

Chapter 47. Access failures fall into two independent axes, and the on-call engineer’s first question is which one is broken: a human or CI cannot enter the cluster, or a pod receives `AccessDenied` when calling AWS. The rejection code completes the classification. `Unauthorized` (401) is an authentication failure: there is no token, it has expired, or the identity is not mapped; fix it in kubeconfig, credentials, and the mapping (access entry or aws-auth). `Forbidden` (403) is an authorization failure: the identity is already known, but RBAC does not grant permission; fix it in the Role, ClusterRole, and bindings. `AccessDenied` from a pod points to IRSA or Pod Identity. A quick “cluster or me” branch: if `aws sts get-caller-identity` shows the wrong identity, the problem is local, the profile, region, or credentials.

| Symptom | Likely cause | What to check |
|---|---|---|
| `Unauthorized`, `must be logged in` | wrong identity or it is not mapped | `sts get-caller-identity`, `list-access-entries` |
| `Unauthorized` immediately after `edit aws-auth` | own mapping was removed | `get cm aws-auth`, restore through an access entry |
| `Forbidden: cannot <verb>` | RBAC does not grant permission | `kubectl auth can-i`, Role and bindings |
| `couldn't get server API group` | corrupted kubeconfig or wrong region | `update-kubeconfig`, `current-context`, profile |
| pod `AccessDenied` with IRSA | trust policy, OIDC, SA annotation | OIDC provider, `sub`/`aud`, `role-arn` annotation |
| pod `WebIdentityErr` | token is not mounted, wrong role | recreate the pod, check trust policy |
| pod `AccessDenied` with Pod Identity | no association, agent, or token | `list-pod-identity-associations`, agent, token in the pod |

```bash
# who AWS actually sees me as
aws sts get-caller-identity
# authentication mode and cluster accessConfig
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# who is mapped through access entries
aws eks list-access-entries --cluster-name <cluster>
# contents of aws-auth (if the mode still uses it)
kubectl -n kube-system get cm aws-auth -o yaml
# authz: what I am allowed to do at all
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# regenerate kubeconfig and check the context
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# pod axis: role annotation on the ServiceAccount (IRSA)
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# Pod Identity associations
aws eks list-pod-identity-associations --cluster-name <cluster>
# whether the Pod Identity agent is running
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# whether the Pod Identity token is mounted in the pod itself (no file means the agent/association did not work)
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

Recover a locked-out cluster through the EKS API: use `update-cluster-config` with `authenticationMode=API_AND_CONFIG_MAP`, then `create-access-entry` and `associate-access-policy` with `AmazonEKSClusterAdminPolicy` (section 47.4). Reverting to `CONFIG_MAP` is not possible.

## What to inspect when nothing adds up

- **VPC Flow Logs** record whether a packet received `ACCEPT` or `REJECT` at the ENI or subnet level. `REJECT` indicates an SG or NACL, while missing return packets after an outbound request point to a stateless NACL and ephemeral ports.
- **Control plane logs** (api, audit, authenticator) must be enabled in advance, not after the fact: authenticator logs show whether the incoming identity is mapped (chapters 21 and 34).
- **`aws-cni-support.sh` through SSM** collects ipamd and plugin logs together with ENI/IP state and configuration into a `/var/log/eks_<instance-id>_<...>.tar.gz` archive, without SSH access to the node.
- **`/var/log/aws-routed-eni` logs** (`ipamd.log`, `plugin.log`) are read on the node when a pod is stuck with `failed to assign an IP address` and it is unclear whether IPs are exhausted or an ENI failed to come up.

## What is not here

This is not a replacement for the chapters: it does not contain root-cause explanations, layer mechanics, or analysis of why a symptom appears as it does. Those are in chapters 45, 46, and 47. This file contains only the workflow and commands.
The course troubleshooting labs (119, 120, 121, and 126 on security groups for pods) are not duplicated here; complete them in their respective assignments.
