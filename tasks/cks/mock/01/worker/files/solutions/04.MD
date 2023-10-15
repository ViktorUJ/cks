``` 
kubectl config use-context cluster3-admin@cluster3
```

``` 
k get no 
ssh {control-plane}
```

``` 
sudo su

kube-bench | grep '1.2.17' -A 5
# read   and fix 

kube-bench | grep '1.3.2' -A 5
# read   and fix 

kube-bench | grep '1.4.1' -A 5
# read   and fix 

# exit to work PC

```

``` 
k get no 
ssh {work node}
```

``` 
sudo su

kube-bench | grep '4.2.6' -A 5
# read   and fix 


# exit to work PC

```