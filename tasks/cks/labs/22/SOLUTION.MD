````
#vim deny_prod-db.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: prod-db
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
    - to:
      ports:
        - protocol: TCP
          port: 53
        - protocol: UDP
          port: 53

````
```
k apply -f   deny_prod-db.yaml
```
````
# vim deny_prod-stack-1.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: prod-stack-1
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
    - to:
      ports:
        - protocol: TCP
          port: 53
        - protocol: UDP
          port: 53

````
```
k apply -f deny_prod-stack-1.yaml
```
````
# vim allow_prod-db_backend.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-db-backend
  namespace: prod-db
spec:
  podSelector:
    matchLabels:
      app: mysql
  policyTypes:
    - Ingress
  ingress:
    - from:
       - podSelector:
            matchLabels:
              app: backend
         namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: prod-stack-1

      ports:
        - protocol: TCP
          port: 80


````
```
k apply -f  allow_prod-db_backend.yaml
```
````
#vim allow_prod-stack-1_backend_frontend.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-frontend
  namespace: prod-stack-1
spec:
  podSelector:
    matchLabels:
     app: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
       - podSelector:
            matchLabels:
              app: frontend

      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: prod-db
          podSelector:
            matchLabels:
              app: mysql
      ports:
        - protocol: TCP
          port: 80


````
````
k apply -f allow_prod-stack-1_backend_frontend.yaml
````

````
# vim allow_prod-stack-1_frontend_client.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-client
  namespace: prod-stack-1
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
             kubernetes.io/metadata.name: user-client
      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 80


````
```
k apply -f allow_prod-stack-1_frontend_client.yaml

```

### test

````
#from backend pod
curl mysql.prod-db.svc --connect-timeout 1   -v   #  work
curl google.com    --connect-timeout 1     -v     # not  work   (Network is unreachable)
curl frontend     --connect-timeout 1     -v # not work (Connection timed)


#from frontend  pod
curl  backend    --connect-timeout 1               # work
curl mysql.prod-db.svc --connect-timeout 1   -v    #  not work
curl google.com    --connect-timeout 1     -v      # not  work




# from db pod
curl backend.prod-stack-1.svc --connect-timeout 1   -v    #  not work
curl google.com    --connect-timeout 1     -v      # not  work

# from  user-client
curl frontend.prod-stack-1.svc --connect-timeout 1   -v    #   work
curl backend.prod-stack-1.svc --connect-timeout 1   -v    #  not work
curl mysql.prod-db.svc --connect-timeout 1   -v   # not work
curl google.com    --connect-timeout 1     -v      # work


````
