
[Gateway API is Kubernetes ](https://gateway-api.sigs.k8s.io/#:~:text=Gateway%20API%20is%20an%20interface,to%20instantiate%20and%20its%20configuration.)

curl IP  or not in domain -> http 403 (Forbidden)
`curl cka.local:30102` -> prod
`curl -H "environment: dev" cka.local:30102` -> dev
`curl cka.local:30102`    from mobile -> mobile
`curl dev-cka.local:30102` -> dev
`curl cka.local:30102` from forbidden country -> http 403 (Forbidden)