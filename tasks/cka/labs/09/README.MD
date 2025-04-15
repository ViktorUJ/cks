
[Gateway API is Kubernetes ](https://gateway-api.sigs.k8s.io/#:~:text=Gateway%20API%20is%20an%20interface,to%20instantiate%20and%20its%20configuration.)

[doc](https://docs.nginx.com/nginx-gateway-fabric/how-to/traffic-management/advanced-routing/)
[examples](https://github.com/nginx/nginx-gateway-fabric/tree/main/examples)


- run ``check_result`` on work pc to **check result**

## Questions


|        **1**        | Create a Gateway                                                                                                                                                              |
| :-----------------: |:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                            |
| Acceptance criteria | ns `nginx-gateway` <br/> name `nginx-gateway` <br/> gatewayClassName `nginx` <br/> listener : <br/> name `http` port `80` protocol `HTTP`  allowedRoutes from  all namespaces |



|        **2**        | Create default restrict   (HTTPRoute)                                                       |
|:-------------------:|:--------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                          |
| Acceptance criteria | ns `app` <br/> name `restricted` <br/> PathPrefix `/`<br/>  svc `app-restricted`  port `80` |
|        tests        | `curl non-domain.example:30102 -s ` <br/> **result**  `Server Name = restricted`            |


|        **3**        | Create **HTTPRoute** `cka.local`                                                                                                                                                      |
|:-------------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                    |
| Acceptance criteria | ns `app` <br/> name `cka-route` <br/> hostname `cka.local` <br/>  header  `environment = dev` path `/`  svc `app-dev`  port `80`  <br/> path `/`  svc `app-prod`  port `80`           |
|        tests        | `curl cka.local:30102 -s ` **result**   `Server Name = production`   <br/>  `curl cka.local:30102 -s -H "environment: dev" ` **result**  `Server Name = dev`                          |


|        **4**        | Create **HTTPRoute** `dev-cka.local`                                                                         |
|:-------------------:|:-------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                           |
| Acceptance criteria | ns `app` <br/> name `dev-cka-route` <br/> hostname `dev-cka.local` <br/>  path `/`  svc `app-dev`  port `80` |
|        tests        | `curl dev-cka.local:30102 -s ` **result**   `Server Name = dev`                                              |


|        **5**        | Create **HTTPRoute** `weight-cka.local`                                                                                                                                                          |
|:-------------------:|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                               |
| Acceptance criteria | ns `app` <br/> name `weight-cka-route` <br/> hostname `weight-cka.local` <br/>  path `/`  svc `app-weight-v1`  port `80` weight `70` <br/>  path `/`  svc `app-weight-v2`  port `80` weight `30` |
|        tests        | `curl weight-cka.local:30102 -s ` **result**  **70%**  `Server Name = app-weight-v1`   **30%**  `Server Name = app-weight-v2`                                                                    |



|        **6**        | Create **HTTPRoute** `header-cka.local`                                                                                                                                                                                                         |
|:-------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                                                                              |
| Acceptance criteria | ns `app` <br/> name `header-cka-route` <br/> hostname `header-cka.local` <br/>  path `/`  svc `app-dev`  port `80` <br/> **add** Header `User-Type = test-user` <br/> **remove** Header `X-CH ` <br/> **overwrite** Header `User-City` to `NYC` |
|        tests        | `curl header-cka.local:30102 -s  -H "X-CH: CH" -H "User-City: TBC"  ` **result**  Headers :  `User-Type = test-user` ,  `X-CH` was deleted  , `User-City = NYC`                                                                                 |

