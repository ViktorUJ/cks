### drain master node
````
kubectl  drain {master node name}  --ignore-daemonsets

````

### check kubeadm version

````
kubeadm version

````

### check kubelet version
````
kubelet --version

````

###  install   update packets

````
apt update
apt-mark unhold kubeadm

apt install kubeadm=1.26.0-00  -y
apt-mark hold kubeadm

````

### update control plane
````
kubeadm upgrade plan

kubeadm upgrade apply v1.26.0
````

### update kubelet and kubectl
````
apt-mark unhold kubelet kubectl
apt install kubelet=1.26.0-00   kubectl=1.26.0-00
apt-mark hold kubelet kubectl

service kubelet restart
service kubelet status


````

### uncordon master node
````
kubectl  uncordon {master node name}
````


### drain node
````
drain {worker node } --ignore-daemonsets
````

### ssh to worker node
### update kubeadm
`````
apt update
apt-mark unhold kubeadm
apt install kubeadm=1.26.0-00
apt-mark hold kubeadm
kubeadm upgrade node
`````

### update kubelet and kubectl
````
apt-mark unhold kubectl kubelet
apt install kubelet=1.26.0-00  kubectl=1.26.0-00 -y
apt-mark hold kubectl kubelet
service kubelet restart
service kubelet status

````
### uncordon worker node
````
kubectl  uncordon {worker  node name}
````

### check nodes

````
kubectl get no
````
