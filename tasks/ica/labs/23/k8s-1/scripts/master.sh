#!/bin/bash
echo " *** master node ica lab-23 k8s-1 (WasmPlugin)"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node so Istio and workloads can be scheduled
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/

# Install Istio with a fixed NodePort on the ingress gateway so the worker PC
# can reach it at myapp.local:32080.
cat <<EOF > /root/istio-install.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: NodePort
          ports:
          - port: 80
            targetPort: 8080
            nodePort: 32080
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443
            name: https
EOF
istioctl install -f /root/istio-install.yaml -y

# Deploy the application and expose it through the ingress gateway.
# Adding an HTTP Basic auth WasmPlugin on the gateway is the task of this lab.
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-151/tasks/ica/labs/23/k8s-1/scripts/1.yaml
