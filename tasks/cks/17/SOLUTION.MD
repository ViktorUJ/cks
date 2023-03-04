
https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
### create backup kube-api manifest
```` 
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/17_kube-apiserver.yaml
````
### create policy
```` 
# vim   /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
    - group: ""
      resources: ["secrets"]
- level: RequestResponse
  userGroups: ["system:nodes"]
- level: None

````

### edit  kube-apiserver.yaml
```` 
#   vim /etc/kubernetes/manifests/kube-apiserver.yaml

# add lines

- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/etc/kubernetes/audit/logs/audit.log
- --audit-log-maxsize=5
- --audit-log-maxbackup=1

# ----- add volumes , and mount volumes 

...
volumes:
- name: audit
  hostPath:
    path: /etc/kubernetes/audit-policy.yaml
    type: File

- name: log
  hostPath:
    path: /var/log/kubernetes/audit/
    type: DirectoryOrCreate


volumeMounts:
  - mountPath: /etc/kubernetes/audit/policy.yaml
    name: audit
    readOnly: true
  - mountPath: /etc/kubernetes/audit/logs
    name: log
    readOnly: false

````

clean previous logs 
```` 
rm /etc/kubernetes/audit/logs/audit.log
````

check logs 

```` 
tail etc/kubernetes/audit/logs/audit.log  -f  | jq
````