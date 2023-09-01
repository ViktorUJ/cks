Head to https://github.com/kubernetes/dashboard/tree/master/docs to find documentation about the dashboard. This link is not on the allowed list of urls during the real exam. This means you should be provided will all information necessary in case of a task like this.

First we have a look in Namespace kubernetes-dashboard:

```sh
➜ k -n kubernetes-dashboard get pod,svc
NAME                                             READY   STATUS    RESTARTS   AGE
pod/dashboard-metrics-scraper-7b59f7d4df-fbpd9   1/1     Running   0          24m
pod/kubernetes-dashboard-6d8cd5dd84-w7wr2        1/1     Running   0          24m

NAME                                TYPE        ...   PORT(S)                        AGE
service/dashboard-metrics-scraper   ClusterIP   ...   8000/TCP                       24m
service/kubernetes-dashboard        NodePort    ...   9090:32520/TCP,443:31206/TCP   24m
```

We can see one running Pod and a NodePort Service exposing it. Let's try to connect to it via a NodePort, we can use IP of any Node:

(your port might be a different)

```sh
➜ k get node -o wide
NAME                     STATUS   ROLES    AGE   VERSION   INTERNAL-IP    ...
cluster1-controlplane1   Ready    master   37m   v1.24.1   192.168.100.11 ...
cluster1-node1           Ready    <none>   36m   v1.24.1   192.168.100.12 ...
cluster1-node2           Ready    <none>   34m   v1.24.1   192.168.100.13 ...

➜ curl http://192.168.100.11:32520
<!--
Copyright 2017 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

```

The dashboard is not secured because it allows unsecure HTTP access without authentication and is exposed externally. It's is loaded with a few parameter making it insecure, let's fix this.

First we create a backup in case we need to undo something:

```sh
k -n kubernetes-dashboard get deploy kubernetes-dashboard -oyaml > 8_deploy_kubernetes-dashboard.yaml
```

Then:

```sh
k -n kubernetes-dashboard edit deploy kubernetes-dashboard
```

The changes to make are :

```sh
  template:
    spec:
      containers:
      - args:
        - --namespace=kubernetes-dashboard
        - --authentication-mode=token        # change or delete, "token" is default
        - --auto-generate-certificates       # add
        #- --enable-skip-login=true          # delete or set to false
        #- --enable-insecure-login           # delete
        image: kubernetesui/dashboard:v2.0.3
        imagePullPolicy: Always
        name: kubernetes-dashboard
```

Next, we'll have to deal with the NodePort Service:

```sh

k -n kubernetes-dashboard get svc kubernetes-dashboard -o yaml > 8_svc_kubernetes-dashboard.yaml # backup

k -n kubernetes-dashboard edit svc kubernetes-dashboard
```

And make the following changes:

```yaml
 spec:
  clusterIP: 10.107.176.19
  externalTrafficPolicy: Cluster   # delete
  internalTrafficPolicy: Cluster
  ports:
  - name: http
    nodePort: 32513                # delete
    port: 9090
    protocol: TCP
    targetPort: 9090
  - name: https
    nodePort: 32441                # delete
    port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  sessionAffinity: None
  type: ClusterIP                  # change or delete
status:
  loadBalancer: {}
```

Let's confirm the changes, we can do that even without having a browser:

```sh
➜ k run tmp --image=nginx:1.19.2 --restart=Never --rm -it -- bash
If you don't see a command prompt, try pressing enter.
root@tmp:/# curl http://kubernetes-dashboard.kubernetes-dashboard:9090
curl: (7) Failed to connect to kubernetes-dashboard.kubernetes-dashboard port 9090: Connection refused

➜ root@tmp:/# curl https://kubernetes-dashboard.kubernetes-dashboard
curl: (60) SSL certificate problem: self signed certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.

➜ root@tmp:/# curl https://kubernetes-dashboard.kubernetes-dashboard -k
<!--
Copyright 2017 The Kubernetes Authors.
```

We see that insecure access is disabled and HTTPS works (using a self signed certificate for now). Let's also check the remote access:

(your port might be a different)

```sh
➜ curl http://192.168.100.11:32520
curl: (7) Failed to connect to 192.168.100.11 port 32520: Connection refused

➜ k -n kubernetes-dashboard get svc
NAME                        TYPE        CLUSTER-IP       ...   PORT(S)
dashboard-metrics-scraper   ClusterIP   10.111.171.247   ...   8000/TCP
kubernetes-dashboard        ClusterIP   10.100.118.128   ...   9090/TCP,443/TCP
```

Much better.
