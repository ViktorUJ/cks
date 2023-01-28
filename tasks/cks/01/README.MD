Task weight: 1%

You have access to multiple clusters from your main terminal through kubectl contexts. Write all context names into
/opt/course/1/contexts , one per line.
From the kubeconfig extract the certificate of user restricted@infra-prod and write it decoded to /opt/course/1/cert .


````
kubectl config get-contexts -o name > /opt/course/1/contexts



````

```` 
k config view --raw  
# or cat ~./kube/config 

# find cert  and decode  
echo "{sert}" | base64 -d > /opt/course/1/cert

````