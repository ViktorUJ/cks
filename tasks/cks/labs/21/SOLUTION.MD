### scan all images
````
trivy i nginx:1.16.1-alpine | grep -E 'CVE-2020-10878|CVE-2020-1967'
````

````
trivy i k8s.gcr.io/kube-apiserver:v1.18.0| grep -E 'CVE-2020-10878|CVE-2020-1967'
````

````
trivy i k8s.gcr.io/kube-controller-manager:v1.18.0| grep -E 'CVE-2020-10878|CVE-2020-1967'
````

````
trivy i docker.io/weaveworks/weave-kube:2.7.0| grep -E 'CVE-2020-10878|CVE-2020-1967'
````
