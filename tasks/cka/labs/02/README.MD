# Allowed resources
**Kubernetes Documentation:**

https://kubernetes.io/docs/ and their subdomains

https://kubernetes.io/blog/ and their subdomains

This includes all available language translations of these pages (e.g. https://kubernetes.io/zh/docs/)

- run ``time_left`` on work pc to **check time**
- run ``check_result`` on work pc to **check result**

# Questions

|        **1**        | **HPA based on CPU load**                                                                                                                                                                                                                                                                                                                                                                                                  |
| :-----------------: |:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 4%                                                                                                                                                                                                                                                                                                                                                                                                                         |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                                                                                                                                                                                                                            |
| Acceptance criteria | - `runsc` was installed on `node2` (label `node_name=node_2`)<br/>- create `RuntimeClass` `gvisor` with handler `runsc`<br/>- add label `RuntimeClass=runsc` to `node2`<br/>- update pods in Namespace `team-purple` to use `RuntimeClass gvisor`<br/>- Make sure the Pod runs on node with `gvisor`<br/>- Write the `dmesg` output of the successfully started one of Pod into `/var/work/tests/artifacts/1/gvisor-dmesg` |
---
