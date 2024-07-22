```
k get no
```

# On the control-plane node
```
sudo su
kube-bench run -s master -c '1.2.17,1.3.2,1.4.1'
```
*Make recomendations specified in the "== Remediations master ==" block*
*Re-run kube-bench - checks must be PASS*

# On the worker node
```
ssh {work node}

sudo su
kube-bench run -s node -c 4.2.6
```
*Read recomendations specified in the "== Remediations master ==" block*

#### Find a kubelet config file "--config":
```
systemctl status kubelet
```

#### Add argument into the kubelet conbfig file:
```
protectKernelDefaults: true
```

#### Restart the kubelet service
```
systemctl restart kubelet.service
```
*Re-run kube-bench - checks must be PASS*
