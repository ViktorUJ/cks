# Allowed resources

## **Istio Documentation:**

https://istio.io/v1.26/docs/ and their subdomains

- run ``time_left`` on work pc to **check time**
- run ``check_result`` on work pc to **check result**

## Questions

|        **1**        | **Install Istio with demo profile with helm**                                          |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 15%                                                                                    |
|       Cluster       | cluster2 (`kubectl config use-context cluster2-admin@cluster2`)                        |
|     Requirements    | - Install Istio with demo profile via helm with custom                                 |
|                     | ingress and egress gateways, enable pilot component with                               |
|                     | resources requests: cpu 100m, mem 256Mi, limits: cpu 100m, mem 256Mi                   |
|                     | - Ingress gateway name: `istio-demo-ingress`                                           |
|                     | - Egress gateway name: `istio-demo-egress`                                             |
|                     | - Pilot replicas: 1                                                                    |
| Acceptance criteria | - Istio installed in `istio-system` namespace                                          |
|                     | - Helm chart versions installed: 1.26.3 for base and istiod                            |
|                     | - Deployment `istiod` exists with 1 replica                                            |
|                     | - Deployment `istio-demo-ingress` exists and running                                   |
|                     | - Deployment `istio-demo-egress` exists and running                                    |
|                     | - `istiod` resources: CPU request=100m, Memory request=256Mi                           |
|                     | - `istiod` resources: CPU limit=100m, Memory limit=256Mi                               |
|       NOTE          | Gateway Helm chart 1.26.3 schema is broken - remove values.schema.json from local chart |
---

|        **2**        | **Configure sidecar to allow egress connections**                                      |
| :-----------------: | :--------------------------------------------------------------------------------------|
|     Task weight     | 7%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure sidecars in the black namespace to configure egress traffic to public      |
|                     | services in the green, istio-system and in the same namespace                          |
| Acceptance criteria | - Pods are able to egress to public services                                           |
|                     | - Pods are able to communicate with each other in black ns                             |
|                     | - Policy correctly applied in black ns                                                 |
---

|        **3**        | **Create deny-all AuthorizationPolicy**                                                |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 5%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create AuthorizationPolicy named `deny-all` in violet namespace                      |
|                     | - Deny all traffic within the namespace                                                |
| Acceptance criteria | - All traffic to services in violet is denied                                          |
|                     | - Policy correctly applied                                                             |
---

|        **4**        | **Configure request timeout**                                                          |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 5%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure 3-second timeout for echo-white in white namespace                         |
|                     | - Requests exceeding 3s should return 504 Gateway Timeout                              |
| Acceptance criteria | - Timeout correctly configured                                                         |
|                     | - Requests > 3s return 504, path http://echo-white/invinsible simulates slow response. |
---

|        **5**        | **Fault injection - Fixed delay**                                                      |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 7%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure pink-echo in pink namespace.                                           |
|                     | - Implement 3-second delay on all requests                                             |
| Acceptance criteria | - All requests delayed by 3 seconds                                                    |
|                     | - Delay percentage is 100%                                                             |
---

|        **6**        | **Configure traffic splitting (50/50)**                                                |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 7%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Split traffic in gold namespace: 50% to v1, 50% to v2                                |
| Acceptance criteria | - 100% of traffic goes to v1                                                           |
|                     | - 50% of traffic goes to v2                                                            |
---

|        **7**        | **Expose service via Istio Gateway**                                                   |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create Gateway echo-gateway in istio-system for echo.example.com                     |
|                     | - Create VirtualService to route traffic                                               |
| Acceptance criteria | - echo-copper namespace copper accessible via echo.example.com                         |
|                     | - Gateway and VirtualService correctly configured                                      |
|       TIP           | !!! FOR THIS TASK USE ```hosts``` COMMAND TO GET NODE IP AND NODE PORT                 |
---

|        **8**        | **Configure header-based routing**                                                     |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Route requests with header `commander: shepard` to v1 in magenta namespace           |
|                     | - All other requests go to v2                                                          |
|                     | - Host: ship.milkyway.gal                                                              |
| Acceptance criteria | - Header-based routing works correctly                                                 |
|                     | - Gateway and VirtualService properly configured                                       |
|       TIP           | !!! FOR THIS TASK USE ```hosts``` COMMAND TO GET NODE IP AND NODE PORT                 |
---

|        **9**        | **Configure selective sidecar injection**                                              |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 5%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Enable namespace-level injection for turquoise namespace                             |
|                     | - Disable injection for turquoise-echo deployment only                                 |
|                     | - Other pods (sleep-turquoise) should get automatic injection                          |
| Acceptance criteria | - Namespace has istio-injection=enabled                                                |
|                     | - turquoise-echo deployment has no sidecar (1/1 containers)                            |
|                     | - sleep-turquoise pod has sidecar (2/2 containers)                                     |
---

|       **10**        | **Configure Egress Gateway**                                                           |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 9%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Route traffic to echo.free.beeceptor.com through egress gateway                      |
|                     | - Create Gateway, VirtualService, and DestinationRule in emerald namespace             |
| Acceptance criteria | - Traffic flows through egress gateway                                                 |
|                     | - Can access echo.free.beeceptor                                                       |
|                     | - Egress gateway logs show requests                                                    |
---

|       **11**        | **Configure Gateway routing for specific path**                                        |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 5%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create Gateway demo-gateway in istio-system (if not exists)                          |
|                     | - Configure VirtualService in sapphire namespace                                       |
|                     | - Route app.domain.com/moon to echo service                                            |
| Acceptance criteria | - Path /moon routes to echo                                                            |
|                     | - Gateway binding correct                                                              |
|       TIP           | !!! USE ```hosts``` COMMAND TO GET PORT. TEST: curl http://app.domain.com:PORT/moon    |
---

|       **12**        | **Create ServiceEntry with STATIC resolution**                                         |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 6%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create ServiceEntry nginx-test in turquoise namespace.                               |
|                     | - Resolve nginx-test.ica to node IP:8082 (STATIC resolution)                           |
|                     | - Create VirtualService nginx-test-vs                                                  |
| Acceptance criteria | - Can access nginx-test.ica from pods                                                  |
|                     | - STATIC resolution to node IP                                                         |
| Limitations:        | due to current setup use node IP instead of hostname set additional params to test
|                     | addresses:
|                     | - 240.240.0.100
|                     | and curl via
|                     | curl http://240.240.0.100:8082
# TODO: Make permanent working with hostname w/o crutches
---

|       **13**        | **Install Istio with Demo profile**                                                 |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Install with demo profile                                                         |
|                     | - Hub: docker.io/istio, Version: 1.26.3, Revision: 1-26-3                             |
|                     | - Enable egress gateway: istio-egress-gateway                                          |
|                     | - Pilot resources: cpu 100m, memory 200Mi                                              |
| Acceptance criteria | - Demo profile installed                                                            |
|                     | - Egress gateway enabled                                                              |
|                     | - Pilot resources correct                                                             |
---

|       **14**        | **Configure external access for echo service**                                         |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Configure echo-silver in silver namespace for external access                        |
|                     | - Host: test.gateway.ica                                                               |
|                     | - Edit existing echo-vs and echo-gateway                                               |
| Acceptance criteria | - echo service accessible via test.gateway.ica                                         |
|                     | - VirtualService and Gateway updated                                                   |
---

|       **15**        | **Create AuthorizationPolicy in navy namespace**                                       |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 5%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create AuthorizationPolicy allow-get-policy in navy namespace                        |
|                     | - Allow requests from turquoise namespace to /pluto path only                            |
| Acceptance criteria | - Requests from turquoise to /pluto succeed                                              |
|                     | - Other paths return 403                                                               |
---

|       **16**        | **Configure port-level load balancing**                                                |
| :-----------------: | :------------------------------------------------------------------------------------- |
|     Task weight     | 4%                                                                                     |
|       Cluster       | cluster3 (`kubectl config use-context cluster3-admin@cluster3`)                        |
|     Requirements    | - Create DestinationRule example-dr in maroon namespace                                |
|                     | - Global load balancer: ROUND_ROBIN                                                    |
|                     | - Port 443 override: LEAST_CONN                                                        |
| Acceptance criteria | - Global LB is ROUND_ROBIN                                                             |
|                     | - Port 443 uses LEAST_CONN                                                             |
---
