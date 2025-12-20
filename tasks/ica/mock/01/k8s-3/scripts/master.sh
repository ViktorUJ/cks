#!/bin/bash
echo "  *** master node  mock-1  k8s-3"
acrh=$(uname -m)
case $acrh in
x86_64)
  arc_name="amd64"
;;
aarch64)
  arc_name="arm64"
;;
esac

export KUBECONFIG=/root/.kube/config

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

export ISTIO_VERSION=1.26.3
curl -L https://istio.io/downloadIstio | sh -
install istio-$ISTIO_VERSION/bin/istioctl /usr/local/bin/

cat > /tmp/istio-config.yaml <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    base:
      enabled: true
    pilot:
      enabled: true
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
    egressGateways:
    - name: istio-egressgateway
      enabled: true
  values:
    profile: demo
EOF

istioctl install -f /tmp/istio-config.yaml -y

kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: demo-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "app.domain.com"
    - "*"
EOF

# ================================================
# Istio Ingress Gateway Configuration
# ================================================
echo "*** Configuring Istio ingress gateway as NodePort"

# Patch istio-ingress service to NodePort
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"type":"NodePort"}}'

. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_$VERSION_ID/Release.key" | sudo apt-key add -
apt-get update -qq
apt-get  -y install podman cri-tools containers-common
rm /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
cat <<EOF | sudo tee /etc/containers/registries.conf
[registries.search]
registries = ['docker.io']
EOF
cat <<EOF | sudo tee /etc/containers/policy.json
{"default": [{"type": "insecureAcceptAnything"}]}
EOF

podman run -d --name nginx-test -p 8082:80 --restart unless-stopped nginx:alpine

for task in {2..17}; do
  kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/mock/01/k8s-3/scripts/task${task}.yml
done

echo "*** master node  mock-1  k8s-3 ready" > /tmp/master_ready
