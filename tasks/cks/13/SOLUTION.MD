###  create metadata-allow policy
```` 
#  cat 13.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: metadata-allow
  namespace: metadata-access
spec:
  podSelector:
    matchLabels:
        role: metadata-accessor
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.2.2.187/32   # worker private_ip
        - ipBlock:
            cidr: 13.51.64.76/32  # worker public_ip 
      ports:
        - protocol: TCP
          port: 80
          
# kubectl apply -f 13.yaml
````

### create metadata-deny policy
````
#cat 13_deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: metadata-deny
  namespace: metadata-access
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
             - 10.2.2.187/32  # worker private_ip
             - 13.51.64.76/32  # worker public_ip  
      ports:
        - protocol: TCP
          port: 80


# kubectl apply -f 13_deny.yaml

````
### check access from  metadata-accessor  to Metadata Server  
```` 
kubectl  exec  -n  metadata-access metadata-accessor   -- sh -c 'curl 13.51.64.76 -s --connect-timeout 1 '

````
````
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

````
### check access from  all-pod  to Metadata Server 

```` 
kubectl  exec  -n  metadata-access all-pod   -- sh -c 'curl 13.51.64.76 -s --connect-timeout 1'
````
```` 
command terminated with exit code 28
````