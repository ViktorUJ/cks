In order to modify the parameters for the apiserver, we first ssh into the master node and check which parameters the apiserver process is
running with:

````
# ssh to master node
ps aux | grep kube-apiserver
# find path to static posds manifest

#edit api pod manifest
# delete   --kubernetes-service-node-port=31000
# delete service
kubectl delete svc kubernetes
````
