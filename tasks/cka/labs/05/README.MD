# PriorityClass

You have a DaemonSet with a specialized monitoring system.
The problem is that under this system is superseded by other pods and you lose the data of the monitoring system.

You must create a PriorityClass and apply it to the DaemonSet monitoring system in NS `monitoring`



|        **1**        | create a PriorityClass and apply it to the DaemonSet                                                                                                                                                             |
| :-----------------: |:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 3%                                                                                                                                                                                                               |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                                                                                                                                                  |
| Acceptance criteria | - PriorityClass name `monitoring` with value `1000000000`  <br/> - DaemonSet `monitoring-system` in  `monitoring` NS has PriorityClass `monitoring`   <br/> -  all pods in `monitoring` NS have status `Running` |
