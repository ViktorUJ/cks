
````
kubectl config get-contexts -o name > /opt/course/1/contexts



````

```` 
k config view --raw  
# or cat ~./kube/config 

# find cert  and decode  
echo "{sert}" | base64 -d > /opt/course/1/cert

````