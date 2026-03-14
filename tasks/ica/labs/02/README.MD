[Russian version ](README_RU.MD)


# Lab 01 — Installing Istio on a Kubernetes Cluster

## Overview

In this lab you will install the Istio service mesh on a Kubernetes cluster (set up with kubeadm), deploy the Bookinfo demo application, and verify that sidecar injection is working.

## Infrastructure

The environment is provisioned in AWS (`eu-north-1`) using Terragrunt and includes:

| Component  | Description                                      |
|------------|--------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` with public subnets           |
| `ssh-keys` | SSH keys for node access                         |
| `k8s-1`   | Kubernetes `1.35.2` (kubeadm)                    |
| `worker`   | Workstation with `kubectl` and cluster access    |

Instances: `t4g.medium` (master), Ubuntu `22.04`

## Provisioning

```bash
TASK=01 make run_ica_task
```

## Step-by-Step Instructions

### 1. Install istioctl

Download and install the Istio CLI tool:

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
```

Check the installed version:

```bash
istioctl version --remote=false
```

```
client version: 1.29.1
```

### 2. Install Istio on the Cluster

Install Istio using the `demo` profile with the Ingress Gateway exposed as a NodePort service:

```bash
cat <<EOF > istio-kubeadm.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    ingressGateways:
    - name: istio-ingressgateway
      k8s:
        service:
          type: NodePort
          ports:
          - port: 80
            targetPort: 8080
            nodePort: 32080   # fixed HTTP port
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443   # fixed HTTPS port
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y
```

Make sure all Istio components are running:

```bash
kubectl get pods -n istio-system
```

```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-egressgateway-7f67df695d-z7jg5    1/1     Running   0          53s
istio-ingressgateway-76768cbcf6-l8rwt   1/1     Running   0          53s
istiod-76d6698857-wmvhs                 1/1     Running   0          61s
```

### 3. Enable Sidecar Injection

Label the `default` namespace so that Istio automatically injects the Envoy sidecar proxy into every new pod:

```bash
kubectl label namespace default istio-injection=enabled
```

### 4. Deploy the Bookinfo Application

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

Verify that each pod shows `2/2` ready containers (the application container + the istio-proxy sidecar):

```bash
kubectl get pods
```

```
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-6cc9f5cc44-csr7h       2/2     Running   0          50s
productpage-v1-7f885b46fc-qqd29   2/2     Running   0          49s
ratings-v1-77b8b6df5b-kfdx8       2/2     Running   0          50s
reviews-v1-fdbf79cd8-zs7qf        2/2     Running   0          50s
reviews-v2-674c6d8b4-p5r65        2/2     Running   0          50s
reviews-v3-7b775c7568-m44z7       2/2     Running   0          50s
```

### 5. Configure the Gateway

Apply the Gateway and VirtualService resources to route external traffic through the Ingress Gateway:

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

Verify that the application is reachable:

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
```

```
<title>Simple Bookstore App</title>
```

## Cleanup

To delete the cluster and all related resources:

```bash
TASK=01 make delete_ica_task
```
