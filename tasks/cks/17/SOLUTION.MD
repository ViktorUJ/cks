
https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
### create backup kube-api manifest
```` 
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/17_kube-apiserver.yaml
````
### create policy
```` 

````

### edit  kube-apiserver.yaml
```` 
#   vim /etc/kubernetes/manifests/kube-apiserver.yaml

# add lines

- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/etc/kubernetes/audit/logs/audit.log
- --audit-log-maxsize=5
- --audit-log-maxbackup=1

````

### 