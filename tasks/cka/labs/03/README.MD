We use the ingress nginx controller.
We have an  application (deployment, service , ingress) in namespace  **meg**. You can check the app via command  `curl http://ckad.local:30102/app` 

Yun need create new deployment,service, ingress  in namespace  **meg** 
 - deployment : name ` meg-app2` , env:  name: `SERVER_NAME` and  value: `megApp2` , all other parameters  copy from  `meg-app` deployment
 - service : name  ` meg-app2`   -> deployment ` meg-app2` 
 - ingress : name  ` meg-app2`   -> service ` meg-app2`  , route to the same address  `curl http://ckad.local:30102/app`  but with header `X-Appversion=v2`

check `    curl -H "X-Appversion: v2" http://ckad.local:30102/app    `

``` 
Server Name: megApp2
URL: http://ckad.local:30102/
Client IP: 10.0.158.196
Method: GET
Protocol: HTTP/1.1
Headers:
X-Forwarded-For: 10.2.25.129
X-Forwarded-Proto: http
X-Scheme: http
X-Request-Id: 78fa94a9ffcab9268864bf006fa67cfa
X-Real-Ip: 10.2.25.129
X-Forwarded-Host: ckad.local:30102
X-Forwarded-Port: 80
X-Forwarded-Scheme: http
User-Agent: curl/7.68.0
Accept: */*
X-Appversion: v2

```


In case of any other header value or unset header, the request should go to the old service. 

check `    curl -H "X-Appversion: v3" http://ckad.local:30102/app    `

``` 
Server Name: megApp
URL: http://ckad.local:30102/
Client IP: 10.0.158.196
Method: GET
Protocol: HTTP/1.1
Headers:
X-Forwarded-For: 10.2.25.129
X-Request-Id: 139e579f92671116b1e12570e564f569
X-Real-Ip: 10.2.25.129
X-Forwarded-Scheme: http
X-Scheme: http
User-Agent: curl/7.68.0
Accept: */*
X-Appversion: v3
X-Forwarded-Host: ckad.local:30102
X-Forwarded-Port: 80
X-Forwarded-Proto: http

```

check `    curl http://ckad.local:30102/app    `

``` 
Server Name: megApp
URL: http://ckad.local:30102/
Client IP: 10.0.158.196
Method: GET
Protocol: HTTP/1.1
Headers:
X-Request-Id: 119892e6edf24b4b794a025a9fb5c87e
X-Real-Ip: 10.2.25.129
X-Forwarded-For: 10.2.25.129
X-Forwarded-Host: ckad.local:30102
X-Forwarded-Port: 80
X-Scheme: http
Accept: */*
X-Forwarded-Proto: http
X-Forwarded-Scheme: http
User-Agent: curl/7.68.0


```