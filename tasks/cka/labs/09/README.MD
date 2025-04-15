
[Gateway API is Kubernetes ](https://gateway-api.sigs.k8s.io/#:~:text=Gateway%20API%20is%20an%20interface,to%20instantiate%20and%20its%20configuration.)

[doc](https://docs.nginx.com/nginx-gateway-fabric/how-to/traffic-management/advanced-routing/)
[examples](https://github.com/nginx/nginx-gateway-fabric/tree/main/examples)

curl IP  or not in domain -> svc `app-restricted`


`curl cka.local:30102` -> svc `app-prod`


`curl -H "environment: dev" cka.local:30102` -> svc `app-dev`


`curl dev-cka.local:30102` -> svc `app-dev`


`curl cka.local:30102` from forbidden country -> svc `app-restricted`


`curl weight-cka.local:30102` -> svc `app-weight-v1` 70% ,  svc `app-weight-v2` 30%  

`curl header-cka.local:30102` -> svc `app-dev` . remove header `X-CH` . add header `User-Type: test-user` . modify header `User-City` to `NYC`


- run ``check_result`` on work pc to **check result**

## Questions


|        **1**        | Create a Gateway                                                                                                                                                              |
| :-----------------: |:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                            |
| Acceptance criteria | ns `nginx-gateway` <br/> name `nginx-gateway` <br/> gatewayClassName `nginx` <br/> listener : <br/> name `http` port `80` protocol `HTTP`  allowedRoutes from  all namespaces |



|        **2**        | Create default restrict   (HTTPRoute)                                                                |
|:-------------------:|:--------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                          |
| Acceptance criteria | ns `app` <br/> name `restricted` <br/> PathPrefix `/`<br/>  svc `app-restricted`  port `80` |



|        **3**        | Create **HTTPRoute** `cka.local`                                                                                                         |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                       |
| Acceptance criteria | ns `app` <br/> name `cka-route` <br/> hostname `cka.local` <br/>  header  `environment = dev` path `/`  svc `app-dev`  port `80`  <br/> path `/`  svc `app-prod`  port `80` |



|        **4**        | Create **HTTPRoute** `dev-cka.local`                                                                                                         |
|:-------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                       |
| Acceptance criteria | ns `app` <br/> name `dev-cka-route` <br/> hostname `dev-cka.local` <br/>  path `/`  svc `app-dev`  port `80`   |



|        **5**        | Create **HTTPRoute** `weight-cka.local`                                                                                                                                                          |
|:-------------------:|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                               |
| Acceptance criteria | ns `app` <br/> name `weight-cka-route` <br/> hostname `weight-cka.local` <br/>  path `/`  svc `app-weight-v1`  port `80` weight `70` <br/>  path `/`  svc `app-weight-v2`  port `80` weight `30` |




|        **6**        | Create **HTTPRoute** `header-cka.local`                                                                                                                                                                                                         |
|:-------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|     Task weight     | 1%                                                                                                                                                                                                                                              |
| Acceptance criteria | ns `app` <br/> name `header-cka-route` <br/> hostname `header-cka.local` <br/>  path `/`  svc `app-dev`  port `80` <br/> **add** Header `User-Type = test-user` <br/> **remove** Header `X-CH ` <br/> **overwrite** Header `User-City` to `NYC` |




| URL + Headers (Request Details)                                                                        | Curl Command                                                      | Expected Result            |
|--------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|----------------------------|
| Request from an IP address or not using the proper domain                                              | `curl http://<IP>:30102` or `curl http://non-domain.example`        | Service `app-restricted`   |
| Request to `cka.local:30102`                                                                            | `curl cka.local:30102`                                              | Service `app-prod`         |
| Request with header `environment: dev` to `cka.local:30102`                                             | `curl -H "environment: dev" cka.local:30102`                        | Service `app-mobile`       |
| Request from a mobile device to `cka.local:30102` (using a mobile UA, e.g., Android User-Agent)           | `curl -H "User-Agent: Android" cka.local:30102`                     | Service `app-mobile`       |
| Request to `dev-cka.local:30102`                                                                        | `curl dev-cka.local:30102`                                          | Service `app-dev`          |
| Request to `cka.local:30102` originating from a forbidden country (with IP/geo info from forbidden region) | `curl cka.local:30102` *(with originating IP/geo info from a forbidden country)* | Service `app-restricted`   |
