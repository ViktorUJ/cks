#!/bin/bash
echo " *** master node ica lab-18 k8s-1 (Telemetry API)"
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

# Install Istio (default profile) with distributed tracing wired to the zipkin
# endpoint that the Jaeger addon exposes (zipkin.istio-system:9411).
# Access logging is DISABLED by default and no Telemetry exists yet — enabling
# access logs and trace sampling via the Telemetry API is the task of this lab.
cat <<EOF > /root/istio-install.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default
  meshConfig:
    enableTracing: true
    extensionProviders:
    - name: zipkin
      zipkin:
        service: zipkin.istio-system.svc.cluster.local
        port: 9411
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

# Deploy the Jaeger addon (creates the jaeger deployment and the zipkin/tracing
# Services in istio-system) so traces have a real backend to be collected in.
until kubectl get ns istio-system >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/jaeger.yaml

# Deploy the application, a curl client, and expose the app through the gateway.
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-151/tasks/ica/labs/18/k8s-1/scripts/1.yaml
