
[Gateway API is Kubernetes ](https://gateway-api.sigs.k8s.io/#:~:text=Gateway%20API%20is%20an%20interface,to%20instantiate%20and%20its%20configuration.)

[doc](https://docs.nginx.com/nginx-gateway-fabric/how-to/traffic-management/advanced-routing/)
[examples](https://github.com/nginx/nginx-gateway-fabric/tree/main/examples)

curl IP  or not in domain -> svc `app-restricted`


`curl cka.local:30102` -> svc `app-prod`


`curl -H "environment: dev" cka.local:30102` -> svc `app-mobile`


`curl cka.local:30102`    from mobile -> svc `app-mobile`


`curl dev-cka.local:30102` -> svc `app-dev`


`curl cka.local:30102` from forbidden country -> svc `app-restricted`


`curl weight-cka.local:30102` -> svc `app-weight-v1` 70% ,  svc `app-weight-v2` 30%  

`curl header-cka.local:30102` -> svc `app-dev` . remove header `user-type: dev` . add header `user-name: test-user` . modify header `user-city` to `NYC`

| URL + Headers (Request Details)                                                                        | Curl Command                                                      | Expected Result            |
|--------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|----------------------------|
| Request from an IP address or not using the proper domain                                              | `curl http://<IP>:30102` or `curl http://non-domain.example`        | Service `app-restricted`   |
| Request to `cka.local:30102`                                                                            | `curl cka.local:30102`                                              | Service `app-prod`         |
| Request with header `environment: dev` to `cka.local:30102`                                             | `curl -H "environment: dev" cka.local:30102`                        | Service `app-mobile`       |
| Request from a mobile device to `cka.local:30102` (using a mobile UA, e.g., Android User-Agent)           | `curl -H "User-Agent: Android" cka.local:30102`                     | Service `app-mobile`       |
| Request to `dev-cka.local:30102`                                                                        | `curl dev-cka.local:30102`                                          | Service `app-dev`          |
| Request to `cka.local:30102` originating from a forbidden country (with IP/geo info from forbidden region) | `curl cka.local:30102` *(with originating IP/geo info from a forbidden country)* | Service `app-restricted`   |
