
|       **11**        | **Secrets in ETCD**. Read the complete Secret content directly from ETCD (using etcdctl )                                                                                                                                                                 |
|:-------------------:|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 7%                                                                                                                                                                                                                                                        |
|       Cluster       | default                                                                                                                                                                                                                                                   |
| Acceptance criteria | - store  plaintext **secret database-access** from **NS=team-green**, using `etcdctl` to  `/var/work/tests/artifacts/11/plaintext`  <br/>-  Write decoded Secret's value of key "pass" into `/var/work/tests/artifacts/11/database-password` |
---
