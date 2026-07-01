#!/bin/bash
echo " *** master node ica lab-12 k8s-1 (troubleshooting)"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

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

# ============================================================================
# Deploy a deliberately BROKEN setup for the troubleshooting lab.
#
#   BUG 1: namespace "default" is NOT labelled for injection
#          -> the ping-pong pod comes up 1/1 (no sidecar).
#   BUG 2: the VirtualService routes to subset "v2", but the DestinationRule
#          only defines subset "v1" -> requests through the gateway get 503.
#
# The student must diagnose both with istioctl (analyze / proxy-config /
# proxy-status) and fix them.  See README.MD.
# ============================================================================
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: ping-pong
  namespace: default
  labels:
    app: ping-pong
spec:
  ports:
  - port: 8080
    name: http
    targetPort: 8080
  selector:
    app: ping-pong
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ping-pong
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ping-pong
      version: v1
  template:
    metadata:
      labels:
        app: ping-pong
        version: v1
    spec:
      containers:
      - name: ping-pong
        image: viktoruj/ping_pong:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: SERVER_NAME
          value: "Ping-Pong-V1"
---
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.local"
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ping-pong-dr
  namespace: default
spec:
  host: ping-pong
  subsets:
  - name: v1
    labels:
      version: v1
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - main-gateway
  http:
  - route:
    - destination:
        host: ping-pong
        subset: v2   # BUG: subset v2 does not exist in the DestinationRule
EOF
