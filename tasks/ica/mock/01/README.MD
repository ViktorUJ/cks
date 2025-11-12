# Allowed resources

## **Istio Documentation:**

https://istio.io/v1.26/docs/ and their subdomains

- run ``time_left`` on work pc to **check time**
- run ``check_result`` on work pc to **check result**

## Questions

|        **1**        | **Install Istio with demo profile via command line**                                   |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 11%                                                                                    |
|       Cluster       | cluster1 (`kubectl config use-context cluster1-admin@cluster1`)                        |
|     Requirements    | - Install Istio with demo profile via command line with custom                         |
|                     | ingress and egress gateways, enable pilot component with                               |
|                     | resources requests: cpu 500m, mem 1024Mi, limits: cpu 500m, mem 1024Mi                 |
|                     | - Ingress gateway name: `istio-demo-ingress`                                           |
|                     | - Egress gateway name: `istio-demo-egress`                                             |
|                     | - Pilot replicas: 1                                                                    |
| Acceptance criteria | - Istio installed in `istio-system` namespace                                          |
|                     | - Deployment `istiod` exists with 1 replica                                            |
|                     | - Deployment `istio-demo-ingress` exists and running                                   |
|                     | - Deployment `istio-demo-egress` exists and running                                    |
|                     | - `istiod` resources: CPU request=500m, Memory request=1024Mi (or 1Gi)                 |
|                     | - `istiod` resources: CPU limit=500m, Memory limit=1024Mi (or 1Gi)                     |
|       TIP           | SOMETIMES UNTAINTING NODE IS NOT WORKING, IF IT IS NOT WORKING use                     |
|                     | kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-      |
---

|        **2**        | **Inject sidecar into a single pod**                                                   |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Inject sidecar into a single pod named sidecar-pod in orange namespace               |
| Acceptance criteria | - Only one pod injected in orange namespace                                            |
|                     | - Pod has proper annotations                                                           |
|                     | - Namespace haven't been modified                                                      |
---

|        **3**        | **Configure mTLS**                                                                     |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 9%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure STRICT mTLS in the red namespace                                           |
| Acceptance criteria | - mTLS correctly configured in red namespace                                           |
|                     | - policy name `default` applied
---

|        **4**        | **Configure AuthorizationPolicy for specific paths**                                   |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create AuthorizationPolicy named `sun-and-moon` in blue namespace                    |
|                     | - Allow requests only to `/sun` and `/moon` endpoints                                  |
| Acceptance criteria | - Policy allows access to /sun and /moon                                               |
|                     | - All other paths should return 403 code                                               |
---

|        **5**        | **Configure retry policy for HTTP errors**                                             |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create VirtualService for gray-echo in gray namespace                                |
|                     | - Retry policy: 2 attempts, 1s per-try timeout, retry on 5xx errors                    |
| Acceptance criteria | - Retry policy correctly configured                                                    |
|                     | - 5xx errors trigger retries                                                           |
|                     | - To verify retry policy, use curl to send requests to gray-echo/blackhole             |
---

|        **6**        | **Fault injection - HTTP abort**                                                       |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure pink-echo in pink namespace.                                               |
|                     | - All requests should abort with 503 error                                             |
| Acceptance criteria | - All requests return 503 Service Unavailable.                                         |
|                     | - Abort percentage is 100%                                                             |
---

|        **7**        | **Configure circuit breaker and connection pool**                                      |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 9%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure echo in brown namespace                                                    |
|                     | - maxConnections: 1, maxRequestsPerConnection: 3, http1MaxPendingRequests: 10          |
|                     | - consecutive5xxErrors: 3, interval: 5s, baseEjectionTime: 5m                          |
| Acceptance criteria | - Connection pool limits correctly set                                                 |
|                     | - Circuit breaker configured with outlier detection                                    |
---

|        **8**        | **Configure traffic mirroring**                                                        |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Mirror all traffic from nginx v1 to v2 in platinum namespace                         |
|                     | - Mirror percentage: 50%                                                               |
| Acceptance criteria | - Primary traffic goes to v1                                                           |
|                     | - Traffic is mirrored to v2                                                            |
|                     | - Both v1 and v2 receive requests                                                      |
|                     | - Send 10 requests to platinum-echo                                                    |
---

|        **9**        | **Create ServiceEntry for external service**                                           |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create ServiceEntry for echo.free.beeceptor.com in bronze namespace                  |
|                     | - Ports: HTTP (80) and HTTPS (443)                                                     |
|                     | - Resolution: DNS                                                                      |
| Acceptance criteria | - Can access echo.free.beeceptor.com from pods in bronze namespace                     |
|                     | - Both HTTP and HTTPS work                                                             |
---

|       **10**        | **Configure load balancing**                                                           |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure ROUND_ROBIN load balancing for echo-cyan in cyan namespace             |
|                     | - Define subsets v1 and v2                                                             |
| Acceptance criteria | - Load balancer algorithm is ROUND_ROBIN                                               |
|                     | - Traffic distributed evenly                                                           |
---

|       **11**        | **Manual sidecar injection**                                                           |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Manually inject sidecar into sleep-indigo using istioctl kube-inject                 |
|                     | - Deploy in indigo namespace                                                           |
| Acceptance criteria | - Pod has 2 containers (app + istio-proxy)                                             |
|                     | - Sidecar manually injected                                                            |
---

|       **12**        | **Perform Istio canary upgrade**                                                       |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 7%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Install Istio 1.26.3 with revision 1-26-3                                            |
|                     | - Tag revision as latest                                                               |
|                     | - Migrate amber namespace to new version                                               |
| Acceptance criteria | - New control plane running with revision                                              |
|                     | - amber namespace using new version                                                    |
|                     | - Pods restarted with new sidecar                                                      |
---

|       **13**        | **Route 100% traffic to specific version**                                             |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Deploy nginx with v1 and v2 in pearl namespace                                       |
|                     | - Route 100% traffic to v1                                                             |
| Acceptance criteria | - All traffic goes to v1                                                               |
|                     | - v2 receives no traffic                                                               |
---

|       **14**        | **Configure mTLS with workload selector**                                              |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Enforce mTLS in crimson namespace for workloads with app=space                       |
| Acceptance criteria | - PeerAuthentication with selector exists                                              |
|                     | - mTLS mode is STRICT                                                                  |
|                     | - Only affects pods with app=space label                                               |
---

|       **15**        | **Configure Sidecar for egress in lime namespace**                                     |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create Sidecar named default in lime namespace                                       |
|                     | - Allow egress to: itself, olive namespace, istio-system namespace                     |
| Acceptance criteria | - Sidecar resource exists                                                              |
|                     | - Egress hosts correctly configured                                                    |
---

|       **16**        | **Create AuthorizationPolicy in olive namespace**                                      |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create AuthorizationPolicy allow-get-policy in olive namespace                       |
|                     | - Allow /mars path from curl workloads in orchid namespace                              |
|                     | - Apply to pods with app: olive label                                                  |
| Acceptance criteria | - Policy allows /mars from orchid namespace                                             |
|                     | - Other paths/namespaces denied                                                        |
---

|       **17**        | **Create Sidecar with workload selector in coral**                                     |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create Sidecar named default in coral namespace                                      |
|                     | - Allow egress to lime, turquoise, istio-system                                        |
|                     | - Scope to workloads with app=space label                                             |
| Acceptance criteria | - Sidecar with workloadSelector exists                                                 |
|                     | - Egress correctly configured                                                          |
---
