#!/bin/bash
echo " *** master node  cka lab-8  k8s-1"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'


#### install NGINX Gateway Fabric
# https://docs.nginx.com/nginx-gateway-fabric/installation/installing-ngf/manifests/


# Install the Gateway API resources
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f -

# Deploy the NGINX Gateway Fabric CRDs

kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.2/deploy/crds.yaml

#Deploy NGINX Gateway Fabric
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.2/deploy/nodeport/deploy.yaml

# set service ports
kubectl patch svc nginx-gateway -n nginx-gateway --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 30102},{"op": "replace", "path": "/spec/ports/1/nodePort", "value": 31139}]'
#

#install lab manifests
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cka/labs/09/k8s-1/scripts/app.yaml
