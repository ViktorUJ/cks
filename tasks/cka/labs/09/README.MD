
[Gateway API is Kubernetes ](https://gateway-api.sigs.k8s.io/#:~:text=Gateway%20API%20is%20an%20interface,to%20instantiate%20and%20its%20configuration.)

curl IP  or not in domain -> svc `app-restricted`
`curl cka.local:30102` -> svc `app-prod`
`curl -H "environment: dev" cka.local:30102` -> svc `app-mobile`
`curl cka.local:30102`    from mobile -> svc `app-mobile`
`curl dev-cka.local:30102` -> svc `app-dev`
`curl cka.local:30102` from forbidden country -> svc `app-restricted`