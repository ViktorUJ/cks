inspect definitions of deployments

```` 
kubectl  exec deployment1-6d65bf9fc9-clj5x   -n restricted -- cat  /var/secret/secret ; echo
kubectl  exec deployment2-64487c7d-nhnds  -n restricted -- sh -c  "echo \$SECRET_USERNAME"
 
````

